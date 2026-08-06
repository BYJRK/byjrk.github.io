---
title: "System.Text.Json 相较于老牌 Newtonsoft.Json 目前仍缺失的功能及补救方法"
slug: "builtin-json-vs-newtonsoft"
description: "本文对比了 System.Text.Json 与 Newtonsoft.Json 仍存在的功能差异，并给出常见场景下的取舍建议。"
date: 2026-08-06
tags:
  - dotnet
  - csharp
  - json
categories:
  - dotnet
---

在 [之前的文章](../introduce-built-in-json) 中，我们梳理了截止到目前的 .NET 10，内置的 JSON 库都有哪些常用的功能。一般情况下，使用内置的 `System.Text.Json` 库已经足够满足大部分的 JSON 处理需求了，但在一些特定的场景下，仍然会遇到一些功能缺失的问题。本文将对比老牌的 `Newtonsoft.Json` 库，列出一部分缺失的功能，并提供一些补救方法。

## JSONPath

JSONPath 是一种用路径表达式从 JSON 文档中定位节点的查询语法。它可以处理对象属性、数组下标、通配符、递归查找和条件筛选等场景；例如 `$.store.books[?(@.price < 10)].title` 表示找出价格低于 10 的书名。

`Newtonsoft.Json` 的 LINQ to JSON API 内置了 JSONPath 支持。将 JSON 解析为 `JToken` 后，使用 `SelectToken` 获取单个节点，或使用 `SelectTokens` 获取多个匹配节点：

```csharp
using Newtonsoft.Json.Linq;

var root = JToken.Parse("""
{
  "store": {
    "books": [
      { "title": "C# in Depth", "price": 45 },
      { "title": "JSON 入门", "price": 9 }
    ]
  }
}
""");

// 按路径获取一个节点。
var firstTitle = root.SelectToken("$.store.books[0].title")?.Value<string>();

// 使用通配符和筛选条件获取多个节点。
var cheapTitles = root
    .SelectTokens("$.store.books[?(@.price < 10)].title")
    .Select(token => token.Value<string>());
```

相对地，`System.Text.Json` 截至 .NET 10 仍没有提供 JSONPath 查询 API。现阶段，我们恐怕只能用 `JsonNode` 的索引器逐层访问，从而一定程度上绕开这个限制：

```csharp
using System.Text.Json.Nodes;

var root = JsonNode.Parse("""
{
  "store": {
    "books": [
      { "title": "C# in Depth", "price": 45 },
      { "title": "JSON 入门", "price": 9 }
    ]
  }
}
""");

var firstTitle = root?["store"]?["books"]?[0]?["title"]?.GetValue<string>();

var cheapTitles = root?["store"]?["books"]?
    .AsArray()
    .Where(book => book?["price"]?.GetValue<decimal>() < 10)
    .Select(book => book?["title"]?.GetValue<string>());
```

但这种方式终究只是个临时方案，适合访问固定层级或自行编写少量遍历逻辑，但它不是 JSONPath 的替代品。如果业务逻辑依赖大量的 JSONPath，那么建议还是继续使用
`Newtonsoft.Json`，或者使用一些第三方库。这个我们后面会提到。

## PopulateObject 填充既有对象

反序列化的一般流程是“从 JSON 创建一个全新的对象实例”。但有些场景下，我们希望把 JSON 的内容**填充到一个已经存在的对象上**：JSON 中出现的属性被覆盖，未出现的属性保持原值。典型场景包括用 JSON 片段更新配置对象、实现部分更新（partial update）、或者把反序列化结果合并到已有状态（例如 ViewModel）中。

`Newtonsoft.Json` 通过 `JsonConvert.PopulateObject` 直接支持这一需求：

```csharp
using Newtonsoft.Json;

var config = new AppConfig
{
    Host = "localhost",
    Port = 8080,
    TimeoutSeconds = 30
};

// 只覆盖 JSON 中出现的属性，其余保持原值。
JsonConvert.PopulateObject("""{ "Port": 9090 }""", config);

Console.WriteLine($"{config.Host}:{config.Port}, Timeout={config.TimeoutSeconds}");
// localhost:9090, Timeout=30

public class AppConfig
{
    public string? Host { get; set; }
    public int Port { get; set; }
    public int TimeoutSeconds { get; set; }
}
```

而 `System.Text.Json` 截至 .NET 10 仍没有能把 JSON 原地填充到调用方传入的既有对象中的对应 API。.NET 8 起的 `JsonObjectCreationHandling.Populate` 是另一回事：它只能在反序列化新对象时，复用其已经初始化的属性或集合，不能替代这里的 `PopulateObject`。补救方法只能是退而求其次：先把 JSON 反序列化成新实例，再手动把需要的属性拷贝到既有对象上；或者解析为 `JsonNode` / `JsonDocument` 后自行遍历，只更新 JSON 中出现的属性。本质上，都是要自己动手造 Newtonsoft 已有的轮子：

```csharp
using System.Text.Json;
using System.Text.Json.Nodes;

var config = new AppConfig
{
    Host = "localhost",
    Port = 8080,
    TimeoutSeconds = 30
};

var patch = JsonNode.Parse("""{ "Port": 9090 }""")!.AsObject();
foreach (var (name, value) in patch)
{
    if (name == nameof(AppConfig.Port))
    {
        config.Port = value!.GetValue<int>();
    }
}
```

对于属性较多或有嵌套结构的对象，这种手写遍历很快就会变得难以维护。如果项目里确实有大量这样的的需求，继续保留 `Newtonsoft.Json` 处理这部分逻辑，会比围绕 `System.Text.Json` 打补丁要省心得多。

## DataTable 与 DataSet

`DataTable` 和 `DataSet` 是 ADO.NET 中用于承载表格数据及其关系的类型。`Newtonsoft.Json` 内置了对它们的转换器：`DataTable` 会被表示为对象数组，而 `DataSet` 会以表名为属性名、各表的行数组为属性值。

```csharp
using System.Data;
using Newtonsoft.Json;

var table = new DataTable("Users");
table.Columns.Add("Id", typeof(int));
table.Columns.Add("Name", typeof(string));
table.Rows.Add(1, "张三");
table.Rows.Add(2, "李四");

var tableJson = JsonConvert.SerializeObject(table, Formatting.Indented);
// [
//   { "Id": 1, "Name": "张三" },
//   { "Id": 2, "Name": "李四" }
// ]

var dataSet = new DataSet();
dataSet.Tables.Add(table);
var dataSetJson = JsonConvert.SerializeObject(dataSet, Formatting.Indented);
// {
//   "Users": [
//     { "Id": 1, "Name": "张三" },
//     { "Id": 2, "Name": "李四" }
//   ]
// }

DataTable? restoredTable = JsonConvert.DeserializeObject<DataTable>(tableJson);
DataSet? restoredDataSet = JsonConvert.DeserializeObject<DataSet>(dataSetJson);
```

`System.Text.Json` 截至 .NET 10 则没有为 `System.Data` 命名空间中的 `DataTable`、`DataSet` 及相关类型提供内置转换器，不能直接完成上述序列化或反序列化。官方建议通过自定义 `JsonConverter<T>` 支持这些类型；但这不只是补上几行代码：需要明确 JSON 格式、列的数据类型、`DBNull` 的表示方式，以及反序列化时是否允许自动推断列结构。

如果项目只是要向前端或 API 输出查询结果，更建议在数据访问层将行投影为 DTO、匿名对象或字典等，再交给 `System.Text.Json` 序列化。反之，如果需要和既有的 `DataTable` / `DataSet` JSON 格式双向兼容，那最好还是继续使用 `Newtonsoft.Json` 而不是折磨自己。

## TypeNameHandling 与多态序列化

在序列化多态类型（基类引用指向派生类实例）时，仅靠属性本身往往无法还原出具体的派生类型，因此常见的操作时在 JSON 中额外写入类型信息作为“鉴别器”（discriminator），通常是一个额外的 `$type` 字段。

`Newtonsoft.Json` 通过 `TypeNameHandling` 枚举自动处理这一需求。默认值是 `None`；将其设置为 `Auto` 后，对于嵌套属性或集合元素，只要声明类型与实际运行时类型不一致，就会在 JSON 中写入 `$type` 字段；反序列化时则会根据 `$type` 自动还原为对应的派生类型，无需任何手工干预：

```csharp
using Newtonsoft.Json;

public abstract class Animal
{
    public string? Name { get; set; }
}

public class Dog : Animal
{
    public string? Breed { get; set; }
}

public class Cat : Animal
{
    public bool IsIndoor { get; set; }
}

List<Animal> animals =
[
    new Dog { Name = "Woffy", Breed = "Golden Retriever" },
    new Cat { Name = "Milo", IsIndoor = true }
];

var settings = new JsonSerializerSettings
{
    TypeNameHandling = TypeNameHandling.Auto
};

var json = JsonConvert.SerializeObject(animals, Formatting.Indented, settings);
// [
//   {
//     "$type": "Demo.Dog, Demo",
//     "Breed": "Golden Retriever",
//     "Name": "Woffy"
//   },
//   {
//     "$type": "Demo.Cat, Demo",
//     "IsIndoor": true,
//     "Name": "Milo"
//   }
// ]

// 反序列化时自动根据 $type 还原为 Dog 和 Cat。
var restored = JsonConvert.DeserializeObject<List<Animal>>(json, settings);
```

可以看到，默认写入的 `$type` 是 CLR 类型全名加简单程序集名，即 `命名空间.类型名, 程序集名` 的形式。如果配置为使用完整程序集信息，还会带上版本、区域性和公钥令牌等内容。整个过程完全由 `Newtonsoft.Json` 自动完成，业务代码只需配置一个开关，不需要在类型上做任何标注，派生类型之间也无需提前声明继承关系。

`System.Text.Json` 则默认不提供任何自动的类型信息写入。如果我们直接序列化上面的 `List<Animal>`，得到的 JSON 只会包含基类 `Animal` 声明的属性（也就是只剩 `Name`），派生类特有的 `Breed`、`IsIndoor` 会被静默丢弃，反序列化时也因为无法实例化抽象类而直接抛异常。

从 .NET 7 开始，`System.Text.Json` 提供了基于**鉴别器字段**的多态序列化支持，但需要我们在基类上通过特性显式声明所有允许的派生类型：

```csharp
using System.Text.Json;
using System.Text.Json.Serialization;

[JsonPolymorphic(TypeDiscriminatorPropertyName = "$type")] // 默认如此，可以省略
[JsonDerivedType(typeof(Dog), typeDiscriminator: "dog")]
[JsonDerivedType(typeof(Cat), typeDiscriminator: "cat")]
public abstract class Animal
{
    public string? Name { get; set; }
}

public class Dog : Animal
{
    public string? Breed { get; set; }
}

public class Cat : Animal
{
    public bool IsIndoor { get; set; }
}

List<Animal> animals =
[
    new Dog { Name = "Woffy", Breed = "Golden Retriever" },
    new Cat { Name = "咪咪", IsIndoor = true }
];

var json = JsonSerializer.Serialize(animals,
    new JsonSerializerOptions { WriteIndented = true });
// [
//   {
//     "$type": "dog",
//     "Breed": "Golden Retriever",
//     "Name": "Woffy"
//   },
//   {
//     "$type": "cat",
//     "IsIndoor": true,
//     "Name": "咪咪"
//   }
// ]

var restored = JsonSerializer.Deserialize<List<Animal>>(json);
```

不难看出，这种方案的局限性相当明显：

- **派生类型必须提前注册**。需要通过 `JsonDerivedType` 特性或代码配置，列出所有允许参与多态序列化的派生类型，本质上是一个“白名单”。如果之后新增了派生类型却忘了注册，序列化时会直接抛异常。
- **基类需要感知全部派生类型**。这与 `Newtonsoft.Json` 的“基类无感知、运行时自动识别”形成了鲜明对比，在派生类型分散于多个程序集、或由插件动态扩展的场景下尤为不便。
- **开放泛型派生类型不方便处理**。可以注册具体的封闭泛型类型，例如 `Derived<int>`，但不能把开放泛型 `Derived<T>` 一次性注册为通用的派生类型。

如果不想使用特性（例如基类来自第三方库，不便修改），也可以通过 `JsonSerializerOptions.TypeInfoResolver` 以代码方式配置 `JsonPolymorphismOptions`，达到同样的效果，但“白名单”这一本质并没有改变：

```csharp
var options = new JsonSerializerOptions
{
    TypeInfoResolver = new DefaultJsonTypeInfoResolver
    {
        Modifiers =
        {
            typeInfo =>
            {
                if (typeInfo.Type != typeof(Animal))
                {
                    return;
                }

                typeInfo.PolymorphismOptions = new JsonPolymorphismOptions
                {
                    TypeDiscriminatorPropertyName = "$type",
                    DerivedTypes =
                    {
                        new JsonDerivedType(typeof(Dog), "dog"),
                        new JsonDerivedType(typeof(Cat), "cat")
                    }
                };
            }
        }
    }
};
```

### 为什么要设计成这样？

`System.Text.Json` 的这种“麻烦”并非能力不足，而是有意为之的安全设计。

回顾 `Newtonsoft.Json` 的 `TypeNameHandling`：JSON 中的 `$type` 是一个程序集限定名，反序列化器会据此在运行时加载并实例化**任意**类型。这意味着，只要攻击者能够控制输入的 JSON，就可以构造 payload 指向程序集中某个“危险”的类型，借助其构造函数、属性 setter 或终结器执行副作用，轻则造成拒绝服务，重则实现远程代码执行。因此官方文档也反复强调：处理不可信数据时，必须配合自定义的 `SerializationBinder` 来限制可解析的类型范围——但这个“补救措施”本身就是把白名单的责任又交还给了开发者。

这类“反序列化任意类型”的漏洞并非 .NET 独有。Java 生态中广为人知的 fastjson 就是前车之鉴：它的 `AutoType` 特性同样允许在 JSON 中通过 `@type` 指定任意类，自 2017 年被曝出的远程代码执行漏洞（CVE-2017-18349）开始，官方陷入了“发布黑名单补丁—被研究者绕过—再发补丁”的漫长拉锯战，绕过版本一直延续到 1.2.80 之后。最终 fastjson 不得不默认关闭 `AutoType`，并推出全面重构的 fastjson2——但即便是 2.x 版本，此后仍陆续被曝出多个严重漏洞，例如 2.0.62 及之前的版本存在可导致远程代码执行的哈希碰撞绕过，直到 2.0.63 才修复。这段历史充分说明：**允许数据驱动类型实例化，是一条先天就布满陷阱的道路**。

`System.Text.Json` 的设计者显然吸取了这些教训，选择了“默认安全”（secure by default）的路线：

- **鉴别器是不透明字符串**，而非程序集限定名。JSON 中不再泄漏程序集和命名空间等内部信息，也让数据格式与具体语言、框架解耦。
- **反序列化采用白名单机制**。只有显式注册过的派生类型才会被还原，攻击者无法通过篡改鉴别器字段来实例化意料之外的类型，从机制上根除了任意类型加载的风险。
- **多态契约显式化**。基类上声明的派生类型列表本身就是一份文档，代码审查时可以一目了然地看出哪些类型会出现在 JSON 边界上。

所以，与其说这是 `System.Text.Json` 的“功能缺失”，不如说是一次在安全与便利之间的明确取舍：它放弃了 `TypeNameHandling` 式的便利，换来了无需额外配置即可抵御反序列化攻击的安心。只有在需要与既有的 `$type` 程序集限定名格式兼容时，才有必要保留 `Newtonsoft.Json`；而对于新代码，鉴别器 + 白名单的方案是更值得推荐的选择。

## BSON

BSON（Binary JSON）是 MongoDB 设计的一种二进制文档格式，可以看作 JSON 的二进制超集：它在 JSON 的类型之外还定义了日期、ObjectId、二进制数据等额外类型，并且每个字段都带有类型标记，文档本身则记录了总长度，因此解析器可以快速定位、跳过不需要的字段。

`Newtonsoft.Json` 通过独立的 [Newtonsoft.Json.Bson](https://www.nuget.org/packages/Newtonsoft.Json.Bson) 包提供 BSON 支持，用法与 JSON 基本一致，只是把读写器换成 `BsonDataReader` / `BsonDataWriter`：

```csharp
using Newtonsoft.Json;
using Newtonsoft.Json.Bson;

var book = new Book { Title = "示例", Price = 42 };

byte[] bson;
using (var ms = new MemoryStream())
using (var writer = new BsonDataWriter(ms))
{
    JsonSerializer.CreateDefault().Serialize(writer, book);
    bson = ms.ToArray();
}

Book? restored;
using (var ms = new MemoryStream(bson))
using (var reader = new BsonDataReader(ms))
{
    restored = JsonSerializer.CreateDefault().Deserialize<Book>(reader);
}
```

而 `System.Text.Json` 并没有内置 BSON 支持。如果需要读写 BSON（例如对接 MongoDB），可以使用官方的 [MongoDB.Bson](https://www.nuget.org/packages/MongoDB.Bson) 包。

{{< notice tip >}}
**BSON 并不比 JSON 更省空间。** “二进制格式”容易让人联想到压缩，但实际上 BSON 为了可遍历性付出了代价：每个元素都要额外存储一个字节的类型标记，字符串和文档还要带上长度前缀，字段名也依然以原文存储。对于常见的小对象，BSON 序列化结果往往跟 JSON 大小不相上下，甚至可能还更大。BSON 的优势在于解析效率和类型保真（日期、二进制数据无需 Base64 或字符串约定），而不是体积。
{{< /notice >}}

另外，如果真正诉求只是“用二进制格式紧凑地保存/传输数据”，那么还可以考虑专门的二进制序列化方案，例如 [MessagePack](https://msgpack.org/)。它会为整数选择足够表示数值的紧凑编码；至于字段名是否变成数组下标或整数，则取决于具体实现和配置。以 .NET 下的 [MessagePack-CSharp](https://github.com/MessagePack-CSharp/MessagePack-CSharp) 为例，显式使用整数 `[Key]` 时，对象会按数组形式编码，通常比重复写字符串字段名更省空间。对于以数值、二进制数据为主的模型，它往往会比 JSON 或 BSON 更小、更快，但具体效果还是要以实际数据测试为准。MessagePack 有许多跨语言实现，跨语言互通通常不是问题；MessagePack-CSharp 也支持源生成器，性能表现很好。

## 总结

对于大多数新项目，`System.Text.Json` 已经足够成熟，性能、AOT 和与 .NET 平台的整合也更有优势。一般的对象序列化、配置读写和 Web API，都可以优先从它开始；多态场景则建议使用鉴别器加白名单的方式，别为了省一点配置又把任意类型反序列化的口子打开。

不过，`Newtonsoft.Json` 也没有过时。JSONPath、`DataTable` / `DataSet`、填充既有对象、BSON，以及需要兼容历史 `$type` 格式的场景，继续使用它往往比自己补一堆转换器更省事。两者完全可以在同一个项目中各司其职，不必为了“统一”而强行替换。

还有一些差异，比如反序列化后的回调，对于模型没有的成员的处理，显式 `null` 以及可空性约束等配置，本文就不赘述了。大家可以在遇到的时候去查阅相关的文档。
