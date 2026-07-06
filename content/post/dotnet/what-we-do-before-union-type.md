---
title: "在 C# 15 的 Union 类型到来之前我们都是怎么过的？"
slug: "what-we-do-before-union-type"
description: ".NET 11 的预览版为我们提前剧透了 Union 类型的到来，那么在这个类型正式发布之前，我们都是怎么模拟它的能力的？我们又是如何解决相关问题的？本文我们就来回顾一下在 C# 中模拟 Union 类型的各种方案，以及它们各自的优缺点。"
date: 2026-05-09
tags:
    - dotnet
    - csharp
    - union
categories:
    - dotnet
    - csharp
---

截止到目前，.NET 11 已经出了三个预览版了，并且也为我们带来了万众期待的 Union 类型。关于这个类型，有不少大佬已经讨论过了，这里贴两个供大家参考：

- [hez2010 的知乎文章](https://zhuanlan.zhihu.com/p/2029276293867258416)
- [Nick Chapsas 视频](https://www.youtube.com/live/C5mozkE5x20)

所以这里我们就不赘述关于 Union 类型的语法、作用、底层原理之类的内容了。我们这次要聊一聊的是，在 Union 类型到来之前，我们都是怎么过的，或者说我们面临的问题都是如何解决的。通过对以往方式的讨论，我们或许会更加意识到 Union 类型有多么棒。

## Union 类型的核心目标

在回顾旧方案之前，我们先明确一下 Union 类型想要解决的核心问题：

1. **归类某些类型，但是不必共享行为**：我们希望把几种相关的类型归为一组，但它们之间不需要有继承关系或共同的接口实现。
2. **在编译时能够穷尽各种情况**：当我们对一个联合类型的值进行处理时，编译器能够检查我们是否覆盖了所有可能的情况。
3. **减少心智负担和运行时错误**：类型系统应该在编译期就帮我们排除掉"忘记处理某种情况"的隐患。
4. **锦上添花，最好还能减少装箱的开销**。

带着这些目标，我们来看看过去 C# 开发者们是怎么做的。

## 枚举类型 enum

在了解 Union 类型时，我们常常会看到诸如返回不同状态的代码，比如：

```csharp
public union Result(Success, Error);

public Result GetResult() { /* 最终返回 Result 中的某种具体类型的实例 */ }
```

在没有 Union 类型的时候，很多人第一反应就是使用枚举：

```csharp
public enum Status
{
    Success,
    Failed
}

public Status GetResult() { /* ... */ }
```

枚举类型本质上是值类型，只能包含单个分类，**不能包含更多的内部信息**。如果 `Success` 需要携带返回数据，`Failed` 需要携带错误信息，枚举就无能为力了。你不得不额外定义配套的字段或类来传递这些信息，导致数据和状态分离，增加了维护成本。

## 包含多个属性的类

既然枚举无法携带数据，很自然的想法就是定义一个"大而全"的类，把所有可能用到的属性都放进去：

```csharp
class Result<T>
{
    public T? Data { get; set; }
    public Exception? Error { get; set; }
    public bool IsSuccess => Error is null;
}
```

这样的类型无法限制类成员之间的关系，只能依靠人为的约束和尽可能多的防御性编程。

比如上面这个例子，可能会出现 `Data` 和 `Error` 同时存在的情况，导致 `IsSuccess` 不可靠。如果成员变多，会更加不可控，势必会出现更多人为的检查：

```csharp
var result = GetResult();
if (result.IsSuccess)
{
    // 编译器无法保证 result.Data 不为 null
    // 我们只能祈祷调用方遵守约定
    Console.WriteLine(result.Data!.ToString());
}
```

类型系统在这里完全帮不上忙，正确性全靠程序员的自觉和代码审查。

## object 类型

将变量声明为 `object` 类型确实可以一定程度上实现表示多种类型的能力，并且借助模式匹配及 `switch` 语法可以实现灵活的功能：

```csharp
object result = GetSomething();

switch (result)
{
    case int i:
        Console.WriteLine($"Integer: {i}");
        break;
    case string s:
        Console.WriteLine($"String: {s}");
        break;
    default:
        throw new NotSupportedException();
}
```

但有几个明显的问题：

1. **编译时无法得知变量类型，缺乏代码提示**：`object` 可以表示任何东西，IDE 无法给出有意义的智能提示。
2. **难以涵盖所有情况**：编译器不会检查你是否处理了所有可能的类型，必须手动提供兜底方案（`default` 分支）。
3. **可能存在装箱拆箱的开销**：值类型赋值给 `object` 时会发生装箱，带来额外的性能开销。
4. **类型安全性差**：任何类型都可以赋值进去，运行时出错的风险很高。

## 空的抽象基类或接口

比 `object` 类型稍微好一点的做法是定义一个空的抽象基类或接口：

```csharp
public abstract class Result { }

public class Success<T> : Result
{
    public T Data { get; }
    public Success(T data) => Data = data;
}

public class Error : Result
{
    public string Message { get; }
    public Error(string message) => Message = message;
}
```

这样可以一定程度上限制可能性，提高编译时期的严谨性，但仍然有几个问题：

1. **必须保证所有类型都继承自该抽象类**：对于内置类型（如 `int`、`string`）或者来自第三方库的类型，我们完全无能为力，无法把它们纳入这个联合体系。
2. **仍然需要提供兜底方案**：`switch` 表达式中编译器不知道有哪些派生类，所以 exhaustive check 无从谈起。
3. **无法保证封闭性**：其他开发者随时可以写出新的继承该抽象类的类型，而你无法阻止。这就破坏了"有限种可能"的语义。

## OneOf 第三方库

在 C# 社区中，[OneOf](https://github.com/mcintyre321/OneOf) 是一个非常流行的用于模拟 Union 类型的库。它的基本用法如下：

```csharp
using OneOf;

public OneOf<User, NotFound, ValidationError> GetUser(int id)
{
    if (id <= 0)
        return new ValidationError("Invalid ID");
    
    var user = _db.FindUser(id);
    if (user is null)
        return new NotFound();
    
    return user;
}

// 使用
var result = GetUser(42);
result.Match(
    user => Console.WriteLine(user.Name),
    notFound => Console.WriteLine("User not found"),
    error => Console.WriteLine(error.Message)
);
```

这个库确实可以实现类型的联合，以及编译时的穷尽检查（通过 `Match` 方法要求你处理所有类型）。但存在一些弊端：

### 缺乏语言级别的语法糖

它不是语言特性，无法享受 C# 语法糖带来的便捷。你只能用它自己的 `Match` 等方法，**不能用原生的 `switch` 语句、模式匹配等**：

```csharp
// 这是做不到的：
var result = GetUser(42);
var message = result switch  // ❌ 编译错误
{
    User u => u.Name,
    NotFound _ => "Not found",
    ValidationError e => e.Message
};
```

### 代码繁杂

当联合的类型较多时，代码会显得繁杂。类型声明变成 `OneOf<T1, T2, ..., Tn>`，而 `Match` 语法中需要大量的 lambda 表达式：

```csharp
OneOf<int, string, double, bool, DateTime> value = ...;

value.Match(
    i => HandleInt(i),
    s => HandleString(s),
    d => HandleDouble(d),
    b => HandleBool(b),
    dt => HandleDateTime(dt)
);
```

### 缺乏领域签名

`OneOf<User, NotFound, ValidationError>` 这样的类型虽然能表达联合，但缺乏语义上的清晰度。每次看到这个类型，你都需要在脑海中翻译一遍它的含义。

相比之下，`union Result(User, NotFound, ValidationError)` 这样的语法更直观，能够直接从类型定义中理解它的用途和意义。

`OneOf<int, string>` 则更是难以理解它的用途——它到底表示什么业务含义？无法从类型定义中推断出它的意义。

### 泛型参数顺序泄露到 API 设计里

`OneOf<User, NotFound>` 和 `OneOf<NotFound, User>` 是两个**不同的类型**，虽然它们表达的语义是一样的。这意味着如果你在一个地方用了 `OneOf<A, B>`，另一个地方用了 `OneOf<B, A>`，它们之间无法直接兼容，这会给 API 设计带来不必要的约束和混乱。

## Union 类型的到来

现在，让我们看看 C# 15 的 Union 类型如何解决上述所有问题：

```csharp
public record class User(string Name);
public record class NotFound();
public record class ValidationError(string Message);

public union Result(User, NotFound, ValidationError);

public Result GetUser(int id)
{
    if (id <= 0)
        return new ValidationError("Invalid ID");
    
    var user = _db.FindUser(id);
    if (user is null)
        return new NotFound();
    
    return user; // 隐式转换
}

// 使用
var result = GetUser(42);

// ✅ 原生支持 switch 表达式和模式匹配
var message = result switch
{
    User u => $"Found: {u.Name}",
    NotFound _ => "User not found",
    ValidationError e => $"Error: {e.Message}"
    // 不需要兜底分支！编译器知道只有这三种可能
};
```

### 底层原理

本质上，Union 类型是编译器帮你生成的一个结构体，加上一个 `object?` 字段和隐式转换。当声明 `union Pet(Cat, Dog, Bird)` 时，实际上编译器后台会生成类似下面的代码：

```csharp
[System.Runtime.CompilerServices.Union]
public struct Pet : System.Runtime.CompilerServices.IUnion
{
    // 为每个情况类型生成构造函数
    public Pet(Cat value) => Value = value;
    public Pet(Dog value) => Value = value;
    public Pet(Bird value) => Value = value;

    // 核心存储：单个 object? 字段
    public object? Value { get; }
}
```

核心组件是 `IUnion` 接口，以及 `[Union]` 特性：

```csharp
public interface IUnion
{
    object? Value { get; }
}
```

编译器会借助隐式转换等方式，在后台实现相关逻辑：

```csharp
Pet pet = new Dog("Rex");
// 实际上是 new Pet(new Dog("Rex"))

pet switch
{
    Dog d => d.Name,  // 编译器检查：pet.Value is Dog d
    Cat c => c.Name,
    Bird b => b.Name,
};
```

{{< notice tip >}}
如果你现在就想体验 Union 类型，可以下载 .NET 11 预览版 SDK。不过需要注意的是，早期预览版中 `UnionAttribute` 和 `IUnion` 尚未内置在运行时中，需要手动添加 Polyfill 代码。
{{< /notice >}}

## 总结

回顾过去，C# 开发者为了模拟 Union 类型的能力，尝试过枚举、"大而全"的类、`object`、抽象基类、第三方库等各种方案。但它们各自都有明显的缺陷：要么无法携带数据，要么缺乏类型安全，要么语法繁琐，要么语义不清晰。

C# 15 引入的原生 Union 类型，不仅提供了简洁优雅的语法，更重要的是它让类型系统能够在编译期就帮我们保证正确性——穷尽检查、隐式转换、原生模式匹配支持，这些都是过去任何方案都无法同时满足的。

Union 类型的到来，标志着 C# 在类型系统上又迈出了一大步。对于那些熟悉 F#、Rust 或 TypeScript 中联合类型的开发者来说，绝对算得上等来了自己的“福报”。期待 C# 在未来能继续引入更多强大的类型特性，让我们的代码更安全、更简洁、更易维护。
