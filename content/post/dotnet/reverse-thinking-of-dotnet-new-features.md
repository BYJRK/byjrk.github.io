---
title: "逆向思考 .NET 一些版本的新特性"
slug: "reverse-thinking-of-dotnet-new-features"
description: ".NET 为什么要在某个版本引入某个新特性？这背后的思考和逻辑是什么？或许我们可以借助逆向思考的方式来理解。"
date: 2025-06-03
tags:
    - dotnet
    - csharp
---

.NET 作为一个近年来更新频率稳定的平台，每个版本都会引入一些新的特性和改进。这些新特性往往是为了提高开发效率、增强性能或改善用户体验。然而，很多时候我们可能会对某些新特性的引入感到疑惑，甚至认为它们并不是那么必要。

在这篇文章中，我想借助几个例子来分享我的思考，并给大家提供一个有意思的视角：逆向思考 .NET 新特性背后的逻辑和思考方式。

## 匿名类型、lambda 表达式和扩展方法

在 C# 3 中，.NET 引入了匿名类型、lambda 表达式和扩展方法等特性。我们先来简单回顾一下这些特性都是什么。

```csharp
// 匿名类型
var mapped = people.Select(p => new { p.Name, p.Age });
// Lambda 表达式
var filtered = people.Where(p => p.Age > 18);
// 扩展方法
public static class StringExtensions
{
    public static IEnumerable<T> Where<T>(this IEnumerable<T> source, Func<T, bool> predicate)
    {
        foreach (var item in source)
        {
            if (predicate(item))
            {
                yield return item;
            }
        }
    }
}
```

相信大家看了上面我“别有用心”的实例之后，一定不难发现：这些新特性似乎都与 LINQ 有关，而 LINQ 正是在 C# 3.0 中引入的。

因此，我们不难得出结论：这些新特性都是为了支持 LINQ 的语法而添加的。它们使得我们可以更简洁地编写查询代码，提升了代码的可读性和可维护性。

当然了，这三个特性绝不仅仅是为了支持 LINQ 而存在的。它们在其他场景下也有着广泛的应用。例如，匿名类型可以用于快速创建临时数据结构，lambda 表达式可以用于方便地声明事件处理和回调，而扩展方法则可以让我们为现有类型添加新的功能。它们都是相当强大的功能。

## 丢弃运算符

我们再来看一个例子。C# 7 引入了丢弃运算符（`_`），它可以用于忽略不需要的值。这看起来似乎是一个小特性，但如果我们再去看这个版本引入的其他几个特性，就不难发现它们之间的关系了：

```csharp
// C# 7.0-
int value;
if (int.TryParse(input, out value))
{
    // ...
}

Tuple<int, string> GetResults() { }
var results = GetResults();
var value = results.Item1; // 忽略 Item2

// C# 7.0+
if (int.TryParse(input, out var _))
{
    // ...
}

(int, string) GetResults() { }
var (value, _) = GetResults(); // 使用元组解构
```

不难发现，C# 7 还引入了新的 `out` 变量声明和元组解构语法。而在这些语法中，丢弃运算符都可以起到便捷的作用。因此，我们可以说，这几个新的特性是密不可分的，所以它们也得以在这个版本中同时出现。

## `init` 访问器与记录类

C# 9 引入了 `init` 访问器和记录类（record class）。记录类为我们提供了相当便捷的声明不可变数据类型的方式，并且重写了 `Equals`、`GetHashCode` 和 `ToString` 等方法，来提供更好的语义。

默认情况下，一个记录类中的属性都是只读的，即：

```csharp
public record Person(string Name, int Age);

// 相当于
public class Person
{
    public string Name { get; init; }
    public int Age { get; init; }

    public override bool Equals(object? obj) { /* ... */ }
    public override int GetHashCode() { /* ... */ }
    public override string ToString() { /* ... */ }
}
```

因此，`init` 访问器与记录类一起出现是很自然的。它们共同提供了一种声明不可变数据类型的方式，使得我们可以更方便地创建和使用不可变对象。

## 顶级语句与隐式引入

C# 9 引入了顶级语句，而 C# 10 引入了隐式引入。这样我们既不用再写 `Program` 及 `Main` 方法，也不用再写很多常见的 `using` 语句了。然后，在那段时间，我们还得到了什么呢？我们得到了 ASP.NET Core Minimal APIs。

```csharp
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();
app.MapGet("/", () => "Hello World!");
app.Run();
```

这些代码就很大程度上借助了顶级语句和隐式引入的特性。它们使得我们可以更简洁地编写 ASP.NET Core 应用程序。C# 用这层简洁的伪装，让更多的人认为用它开发 Web 应用程序是件很简单的事情（笑）。

另外，从此，C# 也可以用 1 行代码实现 Hello World 了。

```csharp
Console.WriteLine("Hello World!");
```

## 接口的抽象静态成员

在以前的 C# 版本中，接口只能包含方法、属性、事件和索引器等成员，而不能包含静态成员。相信这是绝大多数 .NET 开发者的共识，也是绝大多数开发者在入门时的认知，以及在其他编程语言中的经验。

然而，在 C# 11 中，我们可以在接口中声明抽象静态成员了：

```csharp
public interface IShape
{
    double Area { get; }
    static abstract IShape Create(double size);
}

public class Circle : IShape
{
    public double Radius { get; }
    public double Area => Math.PI * Radius * Radius;

    public static Circle Create(double size) => new Circle(size);
}
```

这样的声明会要求实现该接口的类必须提供这个静态方法。那么这个新特性有什么用呢？

很快，我们在 C# 12 中就看到了它的应用：`INumber` 接口的引入。这个接口定义了数字类型的通用行为，其中就包含了不少静态的成员，比如 `Parse`、`Zero` 等等。

不难想象，如果没有这个新的接口特性，这个接口的实现肯定是做不到的。

## 结论

其实其他类似的例子还有很多，比如 `ref struct`、`readonly struct` 等与 `Span` 及 `Memory` 相关的特性，`IAsyncEnumerable` 与 `Channel` 等等。

通过这些例子，我们可以看到，.NET 的新特性往往是为了支持某个特定的功能或语法而引入的。它们之间有着密切的关系。有的是为了支持某个功能的实现，有的是为了优化某个语法的使用体验，有的则是为了提供更好的性能或可读性。

至于为什么有的特性并不是完全在同一个版本出现，这也是有一些原因的。其中一个原因是，.NET 的新特性往往需要经过多次迭代和完善才能最终稳定下来。有可能直到某个版本要发布时，想要添加的新特性仍然不够成熟，因此为了辅助它而诞生的特性可能会提前在该版本上线，而它所辅助的特性则会在下一个版本中引入。

希望通过这篇文章，大家能够对 .NET 的新特性有一个更深入的理解。逆向思考这些特性背后的逻辑和思考方式，可以帮助我们更好地理解它们的设计初衷和应用场景，也能让我们在使用这些特性时更加得心应手。这样的例子见得多了，可能会有一种“微软在开发某功能时引入的新特性因为太好用了，所以顺便下放给我们使用”的感觉吧😂。
