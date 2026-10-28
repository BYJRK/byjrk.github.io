---
title: "怎样有意义地使用 C# 15 的联合类型？"
slug: "how-to-better-utilize-union-types"
description: "C# 15 终于迎来了期待已久的联合类型（union type）。语法学会了，那它到底该用在哪？本文聊聊怎样才能真正发挥它的价值：为什么不放在函数入参上，而是放在返回值上。"
date: 2026-10-23
tags:
    - csharp
    - dotnet
    - syntax
    - pattern-matching
categories:
    - dotnet
    - csharp
---

随着 .NET 11 的推进，C# 15 的联合类型（union type）已经基本定型了。之前我写过一篇 [《在 C# 15 的 Union 类型到来之前我们都是怎么过的？》](/posts/what-we-do-before-union-type)，回顾了枚举、`object`、抽象基类、`OneOf` 等各种模拟方案，也顺带介绍了 Union 类型的语法和底层原理。所以这篇就不再重复基本用法了。

这篇文章想聊的是另一个问题：怎样才能把联合类型用出价值。

## 怎样才能用得有价值？

在了解了联合类型的基本用法后，一个问题随之而来：究竟应该怎么使用它呢？

这时候可能有人觉得：这不简单嘛，用在入参上不就行了。比如经典的 `Pet` 的例子，我们让一个方法接收 `Pet` 类型的参数，然后在函数里根据它实际的类型做不同的处理。比如打印一只宠物的信息：

```csharp
void PrintPet(Pet pet)
{
    var info = pet switch
    {
        Cat c => $"一只叫 {c.Name} 的猫",
        Dog d => $"一只叫 {d.Name} 的狗",
        Bird b => $"一只叫 {b.Name} 的鸟",
    };
    Console.WriteLine(info);
}

PrintPet(new Cat("Tom"));

union Pet(Cat, Dog, Bird);
```

看起来没毛病。但仔细想想：函数接收到参数后的第一件事，就是对参数做 `switch`，然后分成三条完全独立的路径。这跟函数重载比起来有什么优势呢？

```csharp
void PrintPet(Cat c) => Console.WriteLine($"一只叫 {c.Name} 的猫");
void PrintPet(Dog d) => Console.WriteLine($"一只叫 {d.Name} 的狗");
void PrintPet(Bird b) => Console.WriteLine($"一只叫 {b.Name} 的鸟");

PrintPet(new Cat("Tom"));
```

没错，我们完全可以用最简单的函数重载来实现相同的效果。调用方的代码一个字都不用改，而重载版本还有一些额外的好处：

- **分派发生在编译期**。调用哪个重载在编译时就确定了，不需要在运行时做类型检查。
- **没有装箱**。编译器生成的联合类型内部用 `object?` 存值，如果 case type 里有值类型（比如 `union IntOrString(int, string)`），就会装箱。而 `Print(int)` 和 `Print(string)` 两个重载则完全没有这个开销。
- **更符合 C# 开发者的习惯**。重载是 C# 从第一天就有的东西，谁都看得懂，没有心智负担。

{{< notice note >}}
非要说有什么缺点的话，那就是函数重载没有办法保证穷尽这些类型。我们把这些动物包装为一个 `Pet` 联合类型来传参。那以后如果我们新增了某种动物，编译器就能提醒我们在 `switch` 里处理新的情况，而重载则不会有任何提示。
{{< /notice >}}

再举个更常见的例子。在操作文件时，我们经常希望一个方法既能接受 `string` 路径，也能接受 `FileInfo` 对象（这有点像是 Python，很多方法接受 `str` 或 `Path`）：

```csharp
// 用联合类型
public union FileSource(string, FileInfo);
void Load(FileSource source) { ... }

// 用重载
void Load(string path) => Load(new FileInfo(path));
void Load(FileInfo file) { ... }
```

这时候重载的优势反而更明显了，因为重载很多时候可以直接转发给另一个（通常是一个最底层的重载，或者还有可能是一个不公开的方法），逻辑反而更集中。这也是 .NET 基础库里大量 API 一直以来的写法。

### 多个维度会不会好一些？

这时候可能会有人想：既然一个参数用重载就够了，那如果有两个联合类型的参数呢？多一些维度之后，重载的短板就出现了，此时会不会联合类型更有优势？比如还是宠物的例子，这次我们再添加一个食物类型：

```csharp
public record class Fish;
public record class Bone;
public record class Seed;

public union Food(Fish, Bone, Seed);
```

如果用重载，`Feed(Cat, Fish)`、`Feed(Cat, Bone)`……一共要写 3 × 3 = 9 个，听起来就很劝退。用联合类型的话，只需要一个方法：

```csharp
void Feed(Pet pet, Food food)
{
    var reaction = (pet, food) switch
    {
        (Cat, Fish) => "猫吃得很开心",
        (Cat, Bone) => "猫闻了闻，走开了",
        (Cat, Seed) => "猫一脸嫌弃",
        (Dog, Fish) => "狗勉强吃了几口",
        (Dog, Bone) => "狗吃得很开心",
        // ……还有 4 种组合
    };
    Console.WriteLine(reaction);
}
```

方法签名确实只剩一个了，但仔细看看，好像也没好多少。9 种组合一种都没少，只不过是从 9 个重载搬到了 9 个 `switch` 分支里。该匹配的维度还是得在函数里逐一匹配，该处理的情况一个都躲不掉，依旧繁琐。

### 问题出在哪？

绕了一圈会发现，问题不在于参数有几个，而在于 `switch` 写在了哪里。联合类型的声明本身并没有带来什么，它真正发力的地方只有一个，那就是**被 `switch` 消费的那一刻**：

- 编译器能确认你处理了所有情况，不需要写兜底分支
- 每个分支里，你拿到的都是具体的、强类型的值
- 将来如果给联合类型加了一种新的 case，所有没处理它的 `switch` 都会冒出警告

而当联合类型作为入参时，消费它的是函数自己（被调用方），`switch` 只会写在函数内部这一个地方。偏偏 C# 早就为被调用方提供了按类型分派的手段——重载。所以联合类型在这里并没有填补什么空白，顶多是换了一种写法。

{{< notice note >}}
当然也不是绝对的。下面这些情况下，联合类型作为入参还是有意义的：

1. **值本来就是以联合类型的形式存在的**。比如它是从某个集合 `List<Pet>` 里取出来的，或者是另一个函数的返回值，调用方手里根本就没有具体类型，这时候没法利用重载
2. **函数并不关心具体是哪种**，只是把它存起来或者原样传递下去
{{< /notice >}}

## 用在返回值上：这才是主场

既然入参这条路走不太通，那就换个方向：函数和外界打交道，除了入参，还有返回值。这时候重载的弊端就显现出来了，因为函数重载有一个众所周知的限制：**不能只靠返回值类型来区分重载**。一个函数只能声明一个返回值类型。那么当一个函数可能产生几种截然不同的结果时，以前我们是怎么做的？

- **抛异常**：成功时返回值，失败时抛出异常。但异常是"隐形"的，签名上看不出来，调用方很容易忘了 `catch`，而且异常本身也不便宜
- **Try 模式**：`bool TryParse(string s, out int result)`。只能表达"成功/失败"两种，失败的原因也带不出来
- **返回元组、大对象、`object`、抽象基类、OneOf……**：这些在 [上一篇文章](/posts/what-we-do-before-union-type) 里已经逐个吐槽过了，这里就不再展开

这些方案或多或少都有点别扭。而联合类型恰好填上了这个空白：**它让一个函数可以名正言顺地返回"几种不同类型之一"。**。这不是简单的枚举，而是真正不同类型的对象，可以包含各自的其他属性。更妙的是，后续我们用 `switch` 消费时，编译器会帮我们检查是否处理了所有情况，不需要兜底分支。

### 拿到返回值，立刻 switch

来看一个更贴近实际的例子。假设我们要根据 ID 查询一个用户，可能的结果有三种：找到了、不存在、没有权限。

```csharp
public record class User(int Id, string Name);
public record class NotFound(int Id);
public record class Forbidden(string Reason);

public union GetUserResult(User, NotFound, Forbidden);
```

查询函数这样写：

```csharp
GetUserResult GetUser(int id, Account current)
{
    if (!current.CanReadUsers)
        return new Forbidden("当前账号没有查询用户的权限");

    var user = _db.Users.Find(id);
    if (user is null)
        return new NotFound(id);

    return user;
}
```

函数签名本身就是一份文档：看一眼返回值类型，就知道会有哪几种结果。调用方拿到返回值之后，直接 `switch` 就行：

```csharp
var message = GetUser(42, account) switch
{
    User u => $"你好，{u.Name}",
    NotFound nf => $"用户 {nf.Id} 不存在",
    Forbidden f => $"无权访问：{f.Reason}",
};
```

如果是在 ASP.NET Core 的 Minimal API 里，那就更舒服了，直接把每种结果映射成对应的 HTTP 响应：

```csharp
app.MapGet("/users/{id}", (int id, Account account, UserService service) =>
    service.GetUser(id, account) switch
    {
        User u => Results.Ok(u),
        NotFound => Results.NotFound(),
        Forbidden f => Results.Problem(f.Reason, statusCode: 403),
    });
```

没有嵌套 `if`，没有 `null` 检查，也没有 `try-catch`，还没有兜底分支。每种结果都有一个明确的去处。

当某一天需求变了：`GetUser` 需要多返回一种情况，比如"用户已被封禁"。那么，我们只需要新增一种类型，并把它添加到之前的联合类型中：

```csharp
public record class Banned(int Id, DateTime Until);

public union GetUserResult(User, NotFound, Forbidden, Banned);
```

改完这一行，编译器就会**在每一个没有处理 `Banned` 的 `switch` 处给出警告**。此时我们就可以顺着警告挨个修过去，一个都不会漏。如果用的是抛异常的方案，那就只能祈祷所有调用方都记得去 `catch` 一个新的异常类型了。

这就是联合类型最核心的价值：**把"可能出现哪些结果"从文档和约定，变成了编译器能检查的东西。**而这种价值，在"一处产生、多处消费"的返回值场景下会被放大，在"一处消费"的入参场景下则基本被重载抵消掉了。

## 总结

联合类型的语法很简单，但它的价值并不在声明，而在于**消费**——也就是 `switch` 模式匹配带来的完备性检查。顺着这个思路：

- 放在**入参**上时，消费者是函数自己，而 C# 早就有函数重载可以按类型分派，并且没有运行时开销。所以很多时候，重载才是更好的选择
- 放在**返回值**上时，消费者是调用方，而返回值恰恰是重载无能为力的地方。拿到返回值后立刻 `switch`，既能清晰地处理每一种结果，又能在将来新增 case 时获得编译器的全面提醒

所以下次想用联合类型的时候，不妨先问自己一句：这个 `switch` 会写在谁那里？如果答案是"调用方"，那就放心大胆地用吧。
