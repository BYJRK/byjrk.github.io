---
title: "盘点 LINQ 在最近几个 .NET 版本中新增的功能和特性"
slug: "linq-new-features-added-in-recent-dotnet"
description: "随着 .NET 平台的不断发展，LINQ 也在不断地引入新的特性和改进，以提升开发者的生产力和代码的可读性。本文将介绍 .NET 6~9 中新增的 LINQ 特性。"
date: 2025-09-25
tags:
    - dotnet
    - csharp
    - linq
---

LINQ 表达式相信每一位 C# 开发者都不陌生，LINQ 作为 C# 语言的核心功能之一，极大地简化了数据查询和操作的过程。随着 .NET 平台的不断发展，LINQ 也在不断地引入新的特性和改进，以提升开发者的生产力和代码的可读性。本文将介绍最近几个版本的 .NET 中新增的 LINQ 特性。

## .NET 6

.NET 5 作为首次合并了 .NET Framework 和 .NET Core 的版本，标志着 .NET 生态系统的统一。这一版本并没有引入什么新的 LINQ 特性，但是在随后的第一个 LTS 版本 .NET 6 中，微软引入了很多新功能。

### 1. Chunk 方法

`Chunk` 方法允许开发者将一个序列分割成多个固定大小的块。这在处理大数据集时非常有用，可以帮助减少内存占用和提高性能。

```csharp
var numbers = Enumerable.Range(1, 10);
var chunks = numbers.Chunk(3);
foreach (var chunk in chunks)
{
    Console.WriteLine(string.Join(", ", chunk));
}
// 输出:
// 1, 2, 3
// 4, 5, 6
// 7, 8, 9
// 10
```

如果最后一块的元素数量不足指定大小，它将包含剩余的所有元素。

### 2. MinBy & MaxBy

在以前我们有 `Min` 和 `Max` 方法，用来获取序列中的最小值和最大值。这对于最传统的值类型，尤其是数字类型来说是非常易用且易懂的：

```csharp
var numbers = new List<int> { 1, 2, 3, 4, 5 };
var min = numbers.Min(); // 1
var max = numbers.Max(); // 5
```

但如果我们面对的是一个较为复杂的对象，比如：

```csharp
public class Person
{
    public string Name { get; set; }
    public int Age { get; set; }
}
```

现在我们想获取年龄最大的人，使用传统的方式就会比较繁琐且性能低下了：

```csharp
var people = new List<Person>
{
    new Person { Name = "Alice", Age = 30 },
    new Person { Name = "Bob", Age = 25 },
    new Person { Name = "Charlie", Age = 35 }
};

// 方法一
var oldestPerson = people.OrderByDescending(p => p.Age).First();

// 方法二
var oldestAge = people.Max(p => p.Age);
var oldestPerson = people.First(p => p.Age == oldestAge);
```

而在 .NET 6 中，我们可以直接使用 `MaxBy` 和 `MinBy` 方法来简化这个过程：

```csharp
var oldestPerson = people.MaxBy(p => p.Age);
var youngestPerson = people.MinBy(p => p.Age);
```

### 3. DistinctBy 等

与上面的 `MinBy` 和 `MaxBy` 类似，`DistinctBy` 等方法也是允许我们基于某个属性来进行去重、交集和差集操作，并最终返回原始对象。比如下面的例子中，我们可以得到所有名字不重复的人：

```csharp
var people = new List<Person>
{
    new Person { Name = "Alice", Age = 30 },
    new Person { Name = "Bob", Age = 25 },
    new Person { Name = "Charlie", Age = 35 },
    new Person { Name = "Alice", Age = 28 }
};

var distinctByName = people.DistinctBy(p => p.Name);
```

`IntersectBy` 和 `ExceptBy` 也是类似的用法。它们允许我们基于某个属性来进行交集和差集操作。具体的代码这里就不展示了，大家在用到的时候相信很快就能上手。

### 4. FirstOrDefault 等方法的重载

在这个版本中，`FirstOrDefault`、`LastOrDefault`、`SingleOrDefault` 这些方法允许传入一个自定义的默认值，而不是返回类型的默认值（例如 `null` 或 `0`）。这在某些情况下可以减少代码量，提高可读性。

```csharp
var num = numbers.FirstOrDefault(n => n > 10, -1); // 如果没有找到符合条件的元素，返回 -1

var student = students.SingleOrDefault(s => s.Id == 1, new Student { Id = 0, Name = "Unknown" }); // 如果没有找到符合条件的元素，返回一个新的 Student 对象，而不是 null
```

这对于引用类型来说，或许可以借助 `??` 操作符来实现类似的功能；但对于值类型来说，这个重载就显得非常好用了。

### 5. Take

C# 8 引入了索引和范围的概念，这使得我们可以更方便地从集合中获取子集。比如：

```csharp
var numbers = Enumerable.Range(1, 10).ToArray();
var firstThree = numbers[..3]; // 获取前3个元素
var lastThree = numbers[^3..]; // 获取后3个元素
var middleThree = numbers[3..6]; // 获取第4到第6个元素
```

现在，`Take` 方法也支持传入一个范围。这样我们就不需要再搭配使用 `Skip` 等方法了：

```csharp
var numbers = Enumerable.Range(1, 10);

// 以前的做法
var middleThree = numbers.Skip(3).Take(3);
// 现在可以直接使用范围
var middleThree = numbers.Take(3..6);
```

### 6. Zip

对于 `Zip` 方法，现在多了一个重载，允许我们组合三个序列。或许在特定情况下，这一功能会派上用场。但奇怪的是，微软并没有提供更多的重载来支持更多的序列。

如果我们有组合更多序列的需求，可以考虑多次使用 `Zip` 方法来实现：

```csharp
var numbers1 = new[] { 1, 2, 3 };
var numbers2 = new[] { 4, 5, 6 };
var numbers3 = new[] { 7, 8, 9 };
var zipped = numbers1
    .Zip(numbers2, (n1, n2) => (n1, n2))
    .Zip(numbers3, (pair, n3) => (pair.n1, pair.n2, n3));
```

## .NET 7

这个版本虽然在方法上仅新增了两个，但 LINQ 在性能上得到了显著提升。微软对 LINQ 的实现进行了优化，减少了内存分配和提高了执行速度。

### Order & OrderDescending

在 .NET 7 中，微软引入了 `Order` 和 `OrderDescending` 方法，这两个方法允许我们对序列进行排序，而不需要指定排序的键。它们会根据元素默认的比较器进行排序。

有了这个新方法，当我们不需要指定排序键时，代码会更加简洁，而且因为减少了委托的使用，也会略微减小一些性能开销：

```csharp
var numbers = new List<int> { 3, 1, 4, 1, 5, 9 };
var sortedNumbers = numbers.OrderBy(x => x);
var sortedNumbers = numbers.Order();
```

不过这里仍然有必要强调一下，对于传统的集合类型，比如数组和 `List<T>`，我们如果有原地（in-place）排序的需求，还是应该使用它们自带的 `Sort` 方法，因为它们会直接修改原始集合。这种时候如果使用 LINQ 的 `Order().ToArray()` 等方法，反而会带来不必要的内存分配和性能开销：

```csharp
var arr = new[] { 3, 1, 4, 1, 5, 9 };
var list = new List<int> { 3, 1, 4, 1, 5, 9 };

Array.Sort(arr); // 原地排序
list.Sort(); // 原地排序
```

## .NET 8

这个版本并没有引入新的 LINQ 方法，但值得一提的是，`Random` 新引入了 `Shuffle` 方法，也就是洗牌算法。这个方法可以随机打乱一个序列的顺序：

```csharp
var numbers = Enumerable.Range(1, 10);

var shuffledNumbers = Random.Shared.Shuffle(numbers);
```

## .NET 9

### Index

在 .NET 9 中，微软引入了 `Index` 方法。这个方法并不是类似 `IndexOf`，而是可以将一个序列包装为一些包含了 `Index` 和 `Item` 的元组（`ValueTuple`），方便我们在遍历时获取元素的索引。

```csharp
IEnumerable<int> numbers = new[] { 10, 20, 30, 40, 50 };

foreach (var (index, item) in numbers.Index())
{
    Console.WriteLine($"Index: {index}, Item: {item}");
}
```

其实在以前，我们借助 `Select` 方法也可以实现类似的功能。`Select` 方法有一些重载，允许我们在选择元素的同时获取它们的索引：

```csharp
foreach (var pair in numbers.Select((item, index) => (index, item)))
{
    Console.WriteLine($"Index: {pair.index}, Item: {pair.item}");
}
```

不过 `Index` 方法的语义会更加明确一些，也更加易用了。

### CountBy

`CountBy` 方法允许我们根据某个键对序列进行分组，并计算每个组的元素数量。它返回一个包含键和值的元组序列。

比如我们有一个产品列表：

```csharp
public class Product
{
    public string Name { get; set; }
    public string Category { get; set; }
}
```

我们可以使用 `CountBy` 方法来统计每个类别的产品数量：

```csharp
var products = new List<Product>
{
    new Product { Name = "Apple", Category = "Fruit" },
    new Product { Name = "Banana", Category = "Fruit" },
    new Product { Name = "Carrot", Category = "Vegetable" },
    new Product { Name = "Broccoli", Category = "Vegetable" },
    new Product { Name = "Chicken", Category = "Meat" }
};

var categoryCounts = products.CountBy(p => p.Category);
// 结果:
// [("Fruit", 2), ("Vegetable", 2), ("Meat", 1)]
```

在以前，我们可以借助 `GroupBy` 方法来实现类似的功能：

```csharp
var categoryCounts = products
    .GroupBy(p => p.Category)
    .Select(g => (Category: g.Key, Count: g.Count()));
```

### AggregateBy

`AggregateBy` 方法允许我们根据某个键对序列进行分组，并对每个组应用一个聚合函数。它返回一个包含键和值的元组序列。

首先我们简单回顾一下 `Aggregate` 方法。这个方法允许我们对序列中的元素进行累积操作，比如计算总和、乘积等：

```csharp
var numbers = new[] { 1, 2, 3, 4, 5 };
var sum = numbers.Aggregate((acc, n) => acc + n); // 15
var product = numbers.Aggregate((acc, n) => acc * n); // 120
```

现在，`AggregateBy` 方法允许我们先根据某个键对序列进行分组，然后对每个组应用一个聚合函数。比如我们有一些订单，我们想计算每个客户的订单总金额：

```csharp
public class Order
{
    public string Customer { get; set; }
    public decimal Amount { get; set; }
}

var results = orders.AggregateBy(
    order => order.Customer, // 分组键
    (acc, order) => acc + order.Amount, // 聚合函数
    0m // 初始值
);
```

这个例子看似可以用 `GroupBy` 和 `Select` 来实现，但实际上 `AggregateBy` 的性能会更好一些，因为它避免了中间集合的创建。`GroupBy` 会创建一个中间的分组集合，而 `AggregateBy` 则直接在遍历时进行聚合操作。

## 关于 By 的思考

在 LINQ 中，名称带有 `By` 的方法有很多。这里的 `By` 虽然都表示要基于某个方式（比如属性、键等）来进行操作，但它们为方法带来的语义并不完全相同。一般来说分为两种情形：

- 基于某个键进行操作，并在最后返回对象本身（而不是这个键）
  - `MinBy`、`MaxBy`、`OrderBy`、`DistinctBy`、`IntersectBy`、`ExceptBy`
- 基于某个键进行分组（再进行后续操作）
  - `GroupBy`、`CountBy`、`AggregateBy`

因为两种不同的语义，某些方法其实是有可能引起误会的。比如 `DintinctBy`，到底应该是以某个键来去重，还是应该以某个键分组后再在每组中进行去重呢？

细心观察会发现，LINQ 并没有提供诸如 `SumBy`、`AverageBy` 等方法。因为这些方法首先没有什么必要，其次也会引起歧义。比如 `SumBy`，它是应该先分组再求和，还是直接对某个键求和呢？如果是前者，那它的语义就和 `AggregateBy` 很接近了；如果是后者，那它其实和传了一个 `selector` 的 `Sum` 一样。

那么 `CountBy` 又该怎么去理解呢？如果将 `Count` 理解为一种聚合操作，那么它其实和 `AggregateBy` 的语义是类似的。那么是不是说，对于一个聚合操作，它的 `By` 意思就是分组了呢？其实也未必，因为 `Max` 同样也可以看作是一种聚合操作，或者最起码我们确实可以用一个 `Aggregate` 来实现不是吗？所以这些方法的名称可能有点绕，需要大家在使用时多加注意。

## 总结

随着 .NET 平台的不断发展，LINQ 也在不断地引入新的特性和改进。这些新特性不仅提升了开发者的生产力，也使代码更加简洁和易读。希望本文能帮助大家更好地理解和使用这些新特性，提升开发效率。同时也鼓励大家，在有条件的情况下，尽量使用最新版本的 .NET，以便享受到这些改进和优化带来的好处。
