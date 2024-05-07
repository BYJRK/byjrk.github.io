---
title: "为什么 IEnumerable 对象没有 ForEach 方法？"
description: 为什么 IEnumerable 不像 List 那样拥有一个 ForEach 方法？
slug: "why-ienumerable-no-foreach"
image: https://s2.loli.net/2024/04/17/diwtgBYmexonr14.jpg
date: 2024-04-17
tags:
    - csharp
    - dotnet
---

## 便捷的 ForEach 方法

C# 中，`List` 类型（其他还包括 `ImmutableList` 等）拥有一个名为 `ForEach` 的方法。它的作用可以理解为传统 `foreach` 语句的另一种函数式的写法。比如：

```c#
var list = new List<int> { 1, 2, 3, 4, 5 };
// 传统的 foreach 语句
foreach (var n in list)
{
    Console.WriteLine(n);
}
// 便捷的 ForEach 方法可以实现相同的效果
list.ForEach(n => Console.WriteLine(n));
```

（One-liner 狂喜）

此外，`Array` 类还拥有一个 `ForEach` 静态方法，同样可以实现类似的功能。但很快我们就会发现，为什么这么好用的方法，我们却不能用在一个 `IEnumerable` （这里指的是泛型接口 `IEnumerable<T>`，下面不再赘述）接口类型上呢？

{{<notice note>}}
在某些读者可能会发问之前，我把“丑话说在前面”：将一个 `IEnumerable` 类型使用 `ToList()` 方法转为 `List`，只为使用 `ForEach()` 绝对不是一个好主意，因为这很可能会涉及到消耗 LINQ 语句，创建新对象，以及逐个填充元素等。
{{</notice>}}

其实这样设计是有原因的。我大概总结了这么几条，大家听一听是不是这么个道理。

## 添加 ForEach 方法的后果

### 破坏接口的纯粹性

这句话如果说得再“专业”一点，就是违背了 SOLID 原则中的“单一职责原则”（Single responsibility principle）以及“接口隔离原则”（Interface segregation principle）。

怎么讲？我们可以看一下 `IEnumerable` 接口的定义：

```c#
namespace System.Collections.Generic
{
    public interface IEnumerable<out T> : IEnumerable
    {
        new IEnumerator<T> GetEnumerator();
    }
}
```

非常地干净。就连它的名字也表明了，它只是表明一个对象拥有“被枚举”的能力。但是 `ForEach` 方法通常会伴随着一些执行逻辑，这可能就与接口的初衷不符了。

不同于 LINQ 中的 `Select`、`Where`、`OrderBy` 等，它们都是对于数据的映射、筛选、排序等，通常不会包含什么逻辑操作。试想，如果 LINQ 中包含了逻辑操作，尤其还是耗时的操作（比如占用 CPU 的复杂计算、IO 操作等）时，LINQ 的使用将会变得不那么可靠。

所以，假如 `ForEach` 方法中也存在这样的耗时操作，我们更应该考虑的做法是使用异步编程（比如创建多个异步任务，然后使用 `Task.WhenAll` 方法进行等待），使用 `Parallel` 类或者 PLINQ 等，从而使得我们的 `IEnumerable` 对象只包含数据序列，不包含不可控的操作逻辑。

这里给出一个简单的使用异步的例子：

```c#
IEnumerable<int> items = ...;
var tasks = items.Select(x => CalculateValueAsync(x));
await Task.WhenAll(tasks);
var results = tasks.Select(t => t.Result).ToList();
```

### 方法带来的副作用

诚然，我们可以自己写一个扩展方法，从而让 `IEnumerable` 对象能够像 `List` 那样使用 `ForEach` 方法：

```c#
static class EnumerableExtensions
{
    public static void ForEach<T>(this IEnumerable<T> items, Action<T> action)
    {
        foreach (var item in items)
        {
            action.Invoke(item);
        }
    }
}
```

但这可能会造成对 LINQ 现有功能的污染。为什么这么说呢？

我们来想一想，LINQ 提供的功能主要是做什么的？其实主要是对于数据的映射、筛选、排序等。这些方法通常都被认为不会对原始数据造成影响，或者修改。虽然这些方法也会接收一个回调，但是这个回调一定是个 `Func`，从而返回映射后的对象、筛选及排序的依据等。

但是 `ForEach` 方法则不同，它接收的是一个 `Action`，那就是说这个回调并不需要返回什么。此时我们的操作通常就有可能会对原始数据产生影响了。比如：

```c#
List<Employee> employees = ...;

employees.ForEach(e => {
    if (e.IsPromoted) // 如果员工晋升，则涨薪
        e.Salary += 1000;
})
```

所以，使用 `ForEach` 时我们是倾向于对于原本的数据进行一定的操作的。

当然这里仅仅表示一种推测，实际的用法并不绝对。即便我们使用 LINQ 中的 `Select` 等方法，也同样是可以做到对于数据的修改的，这一点 LINQ 并没有办法阻止我们。所以这里主要还是一个“轻重”关系。相较于 LINQ 的方法，`ForEach` 是更倾向于会对数据进行操作的。

### 性能和资源等方面的考虑

还有一个点，就是 拥有 `ForEach` 方法的 `List`（类似的还有 `Array.ForEach` 静态方法），它们被操作的对象都有一个显著特点：元素数量是已知（或者说有限）的。这一点非常重要，因为一个 `IEnumerable` 对象完全有可能是无限的！

```c#
IEnumerable<int> GenerateNumbers()
{
    while (true)
    {
        yield return 0;
    }
}
```

从这个角度考虑，对一个容量未知的集合轻易开展 `ForEach` 这样的操作，其实是充满风险的。不仅如此，`ForEach` 方法不像是 `foreach` 语句那样，可以在其中书写 `continue`、`break` 或 `return` 等语句，这就意味着它一旦开始，就只能将整个集合中的全部元素逐个来一遍才行了。

所以从这个角度考虑，不给 `IEnumerable` 对象提供这样的扩展方法，似乎是非常有道理的。当然，你依旧可以说，LINQ 的方法遇到这样的极端情况，同样束手无策呀？的确，但 LINQ 针对的就是 `IEnumerable` 类型，这是无法避免的，只能希望开发者清楚自己面对的集合是有限的还是无限的。

**＜2024 年 5 月 7 日更新＞**

最近 Nick Chapsas 在他的[一期视频](https://www.youtube.com/watch?v=0iTMIxZeyXg)中讨论了 `ForEach` 方法的性能。通过 Benchmark（在视频的约 5:45 处）可以看出，它的性能是显著低于传统的 `for` 以及 `foreach` 的：

```
| Method  | Mean       | Allocation |
| ------- | ---------- | ---------- |
| for     |   424.9 us |          - |
| foreach |   426.4 us |          - |
| ForEach | 1,785.0 us |       88 B |
```

{{<notice info>}}
关于上面的表格，有一些需要额外补充的内容：

1. 上面的表格省去了一些列，只保留了主要部分
2. 测试环境是最新的 .NET 9（预览版），所以 `foreach` 与 `for` 拥有近乎一样的性能，且没有内存开销
3. `ForEach` 速度慢了约 4 倍，且拥有内存开销（因为存在委托和相应的闭包）
{{</notice>}}

所以这更加证明了，`ForEach` 方法并不是一个高性能的方法，如果我们需要对一个集合进行遍历，还是应该使用传统的 `for` 或 `foreach`。

## 总结

总的来说，虽然为 `IEnumerable<T>` 添加一个 `ForEach` 方法在技术上是可行的，但由于设计哲学、清晰的代码维护、性能考虑和潜在的副作用，.NET 框架设计者选择不在 `IEnumerable<T>` 中直接提供这样的方法。不过，大家如果需要，可以自定义扩展方法来实现这一功能。但前提是要清楚这样做可能会带来的后果。
