---
title: "如何高效读取 XML 中所需的内容（其二）"
slug: "xml-read-benchmarks-2"
description: 这次我们的任务是读取 XML 文档中位于具体位置的某个节点的值，看看 LINQ to XML、XPath 以及正则表达式之间的性能差别。
image: https://s2.loli.net/2024/10/11/XEIhj5DuRS6Wa4n.png
date: 2024-09-27
tags:
    - csharp
    - dotnet
    - xml
    - benchmark
---

我们继续[上一次的内容](/posts/xml-read-benchmarks)，再来看一看关于 XML 内容读取有哪些意想不到的性能差别。这次我们用于演示的 XML 文本依旧是来自 W3Schools 的[一个样例](https://www.w3schools.com/xml/simple.xml)，大致内容如下：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<breakfast_menu>
  <food>
    <name>Belgian Waffles</name>
    <price>$5.95</price>
    <description>Two of our famous Belgian Waffles with plenty of real maple syrup</description>
    <calories>650</calories>
  </food>
  <!-- 省略中间的三个 food -->
  <food>
    <name>Homestyle Breakfast</name>
    <price>$6.95</price>
    <description>Two eggs, bacon or sausage, toast, and our ever-popular hash browns</description>
    <calories>950</calories>
  </food>
</breakfast_menu>
```

我们这次的任务是：获取最后一个 `food` 的 `calories` 的值（即 `950`）。这次我们的选手有：LINQ to XML、`XPath` 以及正则表达式。对于 `XPath`，我们同样在 `XDocument` 上进行操作（只需要引入 `System.Xml.XPath` 命名空间即可）。

## LINQ to XML

我们先来看一看 LINQ to XML（即 `System.Xml.Linq` 命名空间）该如何实现吧。

```c#
public int Elements()
{
    var foods = doc.Root.Elements("food");
    var lastFood = foods.Last();
    return (int)lastFood.Element("calories");
}
```

其实，这里因为我们很清楚 XML 文档的结构，所以上面的内容可以简化为：

```c#
public int Elements()
    => (int)doc.Root.Elements().Last().Elements().Last();
```

这样是可以提高一点性能的，因为我们不需要检查每个节点的名字。

另外，我们还可以使用 `Descendants` 这个方法，从而减少一些 `Elements` 的调用。最极端的情况下，因为我们要获取的元素正好是最后一个，所以我们甚至别的什么都不用做，直接调用 `Descendants` 就可以了：

```c#
public int Descendants()
    => (int)doc.Root.Descendants().Last();
```

## XPath

接下来我们看一看使用 XPath 表达式该如何实现：

```c#
public int XPath()
    => (int)doc.XPathSelectElement("//food[last()]/calories");
```

这里我们借助 XPath 表达式的特殊语法，直接选取了最后一个 `food` 节点的 `calories` 子节点。或者，因为我们知道总共五个 `food` 节点，所以我们也可以将上面的 `last()` 替换为 `5`。这样确实会换来一点点提升，但是非常不明显，而且有耍赖的嫌疑，所以我们就不这么做了。

上面的方式其实效率并不是最高的，因为 `//food` 会搜索整个 XML 文档，寻找所有名称为 `food` 的节点。如果我们能够将 XPath 表达式写得更加精确，是能够提升一些性能的：

```c#
public int XPathOptimized()
    => (int)doc.XPathSelectElement("/breakfast_menu/food[last()]/calories");
```

这样，我们就只需要搜索 `breakfast_menu` 节点下的 `food` 节点，而不是整个文档了。这个不经意的小改动，就能够带来显著的性能提升（约 4~5 倍！）。

## 正则表达式

最后，我们再来看一看正则表达式的实现。这个实现方式就非常简单粗暴了。我们只需要匹配 `calories` 节点，并拿到最后一个的值即可：

```c#
private readonly Regex regex = new Regex(@"<calories>(\d+)</calories>");

public int Regex()
{
    var matches = regex.Matches(xml);
    return int.Parse(matches[^1].Groups[1].Value);
}
```

但其实我们仍然有相当大的优化空间。因为我们这里需要的是最后一个 `calories` 节点，所以我们不需要匹配全部的 `calories` 节点，只需要匹配到最后一个即可。实现这一操作的方式，除了修改表达式本身以外，我们还可以借助 `RegexOptions.RightToLeft` 这个选项：

```c#
private readonly Regex regex = new Regex(@"<calories>(\d+)</calories>", RegexOptions.RightToLeft);

public int RegexOptimized()
{
    var match = regex.Match(xml);
    return int.Parse(match.Groups[1].Value);
}
```

通过这样的一个简单操作，我们再次可以换来约 4~5 倍的性能提升。

## 性能对比

现在，我们可以来看一看比赛的结果了：

| Method              | Mean       | Error       | StdDev   | Gen0   | Gen1   | Allocated |
|-------------------- |-----------:|------------:|---------:|-------:|-------:|----------:|
| Elements            |   101.3 ns |    10.07 ns |  0.55 ns | 0.0101 | 0.0001 |     128 B |
| Descendants         |   243.4 ns |    26.84 ns |  1.47 ns | 0.0062 | 0.0005 |      80 B |
| RegexMatch          |   605.7 ns |   158.79 ns |  8.70 ns | 0.1278 | 0.0010 |    1608 B |
| RegexMatchOptimized |   128.1 ns |    59.86 ns |  3.28 ns | 0.0305 | 0.0002 |     384 B |
| XPathOptimized      | 1,297.4 ns |   927.55 ns | 50.84 ns | 0.3681 | 0.0038 |    4624 B |
| XPath               | 5,099.2 ns | 1,591.05 ns | 87.21 ns | 0.8087 | 0.0076 |   10208 B |

不知道这样的结果有没有出乎大家的意料呢？不难发现，看似不起眼的 LINQ to SQL 方法，居然能轻易击败了优化过的正则表达式以及 XPath，尤其是 XPath 的速度居然会这么慢，进入了微秒级别。

另一方面，在上一次比赛中胜出的正则表达式，这次居然也不敌 LINQ to XML，尤其是如果不优化，那么正则表达式的性能还要再差上不少。

所以，这次的跑分再次向我们证明，对于 XML 文档的读取，LINQ to XML 是最好的选择，可以说是不仅好用，而且高效。

## One More Thing

说到跑分，这种时候怎么少得了 `Span` 呢？

```c#
public int Span()
{
	var xml = Xml.AsSpan();
	return int.Parse(xml.Slice(xml.LastIndexOf("<calories>") + 10, xml.LastIndexOf("</calories>") - (xml.LastIndexOf("<calories>") + 10)));
}
```

至于结果嘛：

| Method  | Mean        | Error     | StdDev   | Ratio | RatioSD | Allocated |
|-------- |------------:|----------:|---------:|------:|--------:|----------:|
| Span    |    22.30 ns |  0.435 ns | 0.024 ns |  0.22 |    0.00 |         - |
