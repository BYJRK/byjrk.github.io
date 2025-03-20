---
title: "BSON 与 MessagePack 的异同及如何选择"
slug: "bson-vs-msgpack"
description: "BSON 与 MessagePack 有什么异同呢？它们的性能以及空间利用率如何呢？在实际应用中，我们应该如何选择呢？这篇文章我们就来探讨一下这些问题。"
date: 2025-03-20
tags:
    - data
    - csharp
---

BSON 与 MessagePack 是两种常见的二进制数据格式。他们都提供了序列化与反序列化功能，支持灵活的数据格式，也广泛地被各种编程语言所支持。但是它们之间有什么异同呢？它们的性能以及空间利用率如何呢？在实际应用中，我们应该如何选择呢？

## 基本信息

BSON（Binary JSON）是一种二进制编码的 JSON 格式，由 MongoDB 开发，主要用于 MongoDB 数据库中数据的存储和传输。它扩展了 JSON 格式，增加了对额外数据类型的支持，如日期、时间戳和二进制数据。

MessagePack 是一种高效的二进制序列化格式，旨在实现尽可能小的体积和尽可能快的处理速度。它支持多种编程语言，常用于网络通信和数据存储。

## 相同点

BSON 和 MessagePack 在多个方面具有相似之处。首先，它们都将数据编码为二进制形式，与基于文本的 JSON 相比，可以减小数据体积，提高传输效率。JSON 虽然具有可读性的优势，但在处理大量数据时，其文本特性会导致解析速度较慢，且占用更多的存储空间。而二进制格式则避免了这些问题，它们以计算机更容易处理的方式存储数据，从而提高了效率。

其次，它们都支持多种数据类型，包括基本类型（如整数、浮点数、字符串、布尔值）和复杂类型（如数组、二进制、日期等）。这使得它们可以灵活地处理各种数据结构，满足不同应用场景的需求。

此外，两者都提供了多种编程语言的实现，使得它们可以在不同的系统和平台之间进行数据交换。无论是使用 Python、Java、C#、Go，还是其他编程语言，我们都可以找到相应的库来使用它们。最后，它们都提供了高效的序列化和反序列化机制，使得开发者可以方便地进行数据的相关操作。

那么，同样都是二进制数据，它们是否都具备相当高的空间利用率以及性能呢？

## 不同点

然而，BSON 和 MessagePack 之间也存在一些关键差异。这些差异导致了它们的空间利用率，以及各自所擅长的功能并不相同。

BSON 的设计目标是主要用于 MongoDB 的数据存储和传输，而 MessagePack 则追求最高的性能和最小的体积。这种设计理念上的差异直接影响了它们在空间利用率和性能方面的表现。由于 BSON 包含一些额外的元数据（如字段长度等），因此其空间效率相对较低；而 MessagePack 使用紧凑的表示方式来编码数据，例如使用更少的字节来表示较小的整数，因此空间效率非常高。MessagePack 的设计哲学是“尽可能地小”，这使得它在对数据大小有严格要求的场景中成为理想的选择。

在性能方面，BSON 的序列化和反序列化速度相对较慢，而 MessagePack 的序列化和反序列化速度非常快。这是因为 MessagePack 的编码方式更加简单高效，减少了处理数据所需的计算量。然而，BSON 在 MongoDB 中有许多优化，例如在索引方面，BSON 的结构允许 MongoDB 高效地遍历和查询数据，这弥补了其在通用性能上的一些不足。具体来说，MongoDB 可以利用 BSON 中存储的字段长度等信息，快速定位到需要的数据，而不需要像解析 JSON 那样逐个字符地扫描。在可读性方面，BSON 具有一定的可读性，因为它与 JSON 结构相似；而 MessagePack 的可读性不佳，因为它是一种纯粹的二进制格式。

## 代码对比

这里，我们在 C# 中用一个简单的例子来对比 BSON 和 MessagePack。我们使用 [`Newtonsoft.Json.Bson`](https://www.nuget.org/packages/Newtonsoft.Json.Bson) 和 [`MessagePack`](https://www.nuget.org/packages/MessagePack) 这两个库来实现。

首先，我们设计一个包含一些属性的类，并且为它填充一些数据：

```csharp
public class MyModel
{
    public int Id { get; set; }
    public string Name { get; set; }
    public DateTime CreatedAt { get; set; }
    public bool IsActive { get; set; }
    public decimal Price { get; set; }
    public double Rating { get; set; }
    public Guid UniqueId { get; set; }
    public byte[] Data { get; set; }
    public List<string> Tags { get; set; }
    public Dictionary<string, int> Counts { get; set; }
    public long BigNumber { get; set; }
    public short SmallNumber { get; set; }
    public char Initial { get; set; }
    public TimeSpan Duration { get; set; }
    public Uri Website { get; set; }
    public Version Version { get; set; }
    public object DynamicValue { get; set; }
    public Status Status { get; set; }
}

public enum Status
{
    Pending,
    InProgress,
    Completed
}

var model = new MyModel
{
    Id = 123,
    Name = "My Model",
    CreatedAt = DateTime.UtcNow,
    IsActive = true,
    Price = 99.99m,
    Rating = 4.5,
    UniqueId = Guid.NewGuid(),
    Data = new byte[] { 1, 2, 3 },
    Tags = new List<string> { "tag1", "tag2" },
    Counts = new Dictionary<string, int> { { "a", 1 }, { "b", 2 } },
    BigNumber = 123456789012345,
    SmallNumber = 123,
    Initial = 'A',
    Duration = TimeSpan.FromMinutes(15),
    Website = new Uri("https://www.example.com"),
    Version = new Version(1, 0, 0),
    DynamicValue = new { Value = "dynamic" },
    Status = Status.InProgress
};
```

然后，我们用两种方法来序列化这个对象。首先是 BSON：

```csharp
using Newtonsoft.Json;
using Newtonsoft.Json.Bson;

using (var fs = File.OpenWrite(@"bson.dat"))
using (var writer = new BsonWriter(fs))
{
    var serializer = new JsonSerializer();
    serializer.Serialize(writer, model);
}
```

然后是 MessagePack。这里为了序列化，我们还需要为模型类添加一些特性，包括：

- 为类添加 `[MessagePackObject]`
- 为每个属性依次添加 `[Key(0)]`、`[Key(1)]`、`[Key(2)]`……

```csharp
using (var fs = File.OpenWrite(@"msgpack.dat"))
{
    var data = MessagePackSerializer.Serialize(model);
    fs.Write(data);
}
```

然后，我们观察文件大小：

- BSON：381 字节
- MsgPack：166 字节

可以明显看出，BSON 在空间利用率上完全没有优势。

{{< notice note >}}
实际上，就算是对比 JSON，BSON 也未必会有显著的优势。BSON 的优势主要来自对日期、二进制数据、数字等的处理，而 JSON 只能全部以字符串的形式存储。对于 100,000,000 这样的大数字，JSON 需要 9 个字符，而 BSON 只需要 4 个字节；但对于 1.0 这样的小数，JSON 需要 3 个字符，而 BSON 只需要 8 个字节。不仅如此，BSON 还包含了额外的元数据，如字段名称、字段长度等，这也导致了 BSON 的空间效率并没有相较于 JSON 有多少提升。
{{< /notice >}}

## 总结

总而言之，BSON 和 MessagePack 都是优秀且现代的二进制序列化格式。BSON 的优势在于与 JSON 的兼容性和对丰富数据类型的支持，使得它在 MongoDB 等数据库应用中表现出色；MessagePack 的优势在于其高性能和高空间效率，这使得它在网络通信、大数据处理等需要快速传输和处理大量数据的场景中更有优势。在实际应用中，我们应当根据具体需求选择合适的格式。
