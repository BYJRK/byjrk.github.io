---
title: "System.Text.Json：.NET 内置的 JSON 库"
slug: "introduce-built-in-json"
description: "从早期的 Newtonsoft.Json 一统天下，到如今 System.Text.Json 成为内置默认选择。本文系统梳理 .NET 内置 JSON 库的历史背景、基本用法、Record 支持、JsonNode 动态 DOM 以及源生成器等特性。"
date: 2026-07-06
tags:
    - dotnet
    - csharp
    - json
    - serialization
    - source-generator
categories:
    - dotnet
---

在 .NET 平台上提到 JSON 序列化，很多人第一时间想到的还是 Newtonsoft.Json。这款诞生于 2006 年的第三方库长期占据 NuGet 下载量榜首，一度几乎是 .NET 项目的"标配"。但自 .NET Core 3.0 起，框架已经内置了 System.Text.Json 这款现代化的 JSON 库，并在 ASP.NET Core 中将其设为默认序列化器。

本文就来系统地梳理一下 System.Text.Json 的历史背景、基本用法、Record 支持、JsonNode 动态 DOM 以及源生成器等特性，帮助你全面了解这款内置 JSON 库。

## 历史

### 早期的官方库

.NET 早期有两个官方 JSON 库，但均是面向特定框架的延伸，而非通用解决方案：

**`JavaScriptSerializer`**（`System.Web.Script.Serialization`，.NET 3.5）随 ASP.NET AJAX 一同引入。功能相当原始，不支持 LINQ、不支持复杂类型映射，而且锁在 `System.Web` 程序集内，非 Web 项目根本无法引用。

**`DataContractJsonSerializer`**（`System.Runtime.Serialization.Json`，.NET 3.0）面向 WCF 设计，序列化行为由 `[DataContract]` / `[DataMember]` 特性驱动。它对类型结构有严格要求，对字典、匿名类型等常见场景支持有限，且不与 Web API 路径对齐。

### Newtonsoft.Json 的崛起

正是因为官方库的局限，`Newtonsoft.Json` 应运而生。它实现了当时官方库所缺少的一切：灵活的转换器体系、LINQ to JSON（`JObject`/`JArray`）、丰富的序列化选项，以及对动态类型和跟踪引用等复杂场景的良好支持。它很快成为 .NET 生态中最流行的第三方库，长期占据 NuGet 下载量榜首。微软也在 ASP.NET Web API 和早期的 ASP.NET Core（直到 2.x）中采用它作为默认序列化器。

{{< notice info >}}
`Newtonsoft.Json` 由 James Newton-King 于 2006 年创建。包名中的 "Newtonsoft" 取自作者姓氏 Newton-King，而 Json.NET 则是它更广为人知的别称。
{{< /notice >}}

### 现代化的挑战

然而，Newtonsoft.Json 的设计根植于早期 .NET，随着 .NET 的现代化，它的两个先天缺陷逐渐显现：

- **高度依赖反射**：内部大量使用 `string`（UTF-16）中间表示，在高并发、低延迟场景下内存分配和 GC 压力成为瓶颈
- **阻碍裁剪和 NativeAOT**：反射阻止编译器静态分析代码依赖，导致裁剪无法移除未使用的成员；NativeAOT 所需的部分反射 API 直接不可用

### System.Text.Json 的诞生

2019 年 9 月，随 .NET Core 3.0 发布，微软推出了内置库 `System.Text.Json`。它以 UTF-8 字节流为核心，从设计层面就为低分配、高吞吐量而优化，序列化性能在大多数场景下从第一个版本起就超过了 Newtonsoft.Json。ASP.NET Core 3.0 同步将默认序列化器从 Newtonsoft.Json 切换为 System.Text.Json，并将 Newtonsoft.Json 从共享框架中移除。

不过，初版的功能覆盖局限相当明显，许多 Newtonsoft 用户习以为常的特性都不支持。此后多个版本持续补齐：

- （.NET 5）支持公共字段的序列化
- （.NET 5）支持通过带参数的构造函数创建不可变对象（包括 C# 9 record）
- （.NET 6）支持源生成器，避免使用反射，更好地支持 NativeAOT 发布
- （.NET 6）JsonNode（可变 DOM），类似 JObject
- （.NET 8）内置命名策略新增 `SnakeCaseLower`、`SnakeCaseUpper`、`KebabCaseLower`、`KebabCaseUpper`（`CamelCase` 从 .NET Core 3.0 起即可用）

## 基本用法

了解了它的来龙去脉之后，我们来看看实际该怎么用。

### 序列化与反序列化

`JsonSerializer` 是主要入口，提供 `Serialize` / `Deserialize` 静态方法：

```csharp
var person = new Person { Name = "Alice", Age = 30 };

string json = JsonSerializer.Serialize(person);
// {"Name":"Alice","Age":30}

Person? result = JsonSerializer.Deserialize<Person>(json);
```

如果需要与 `Stream` 或网络 I/O 直接交互，可以用 UTF-8 字节数组的重载，避免中间字符串分配：

```csharp
byte[] bytes = JsonSerializer.SerializeToUtf8Bytes(person);
Person? result = JsonSerializer.Deserialize<Person>(bytes);

// 也支持直接读写 Stream
await JsonSerializer.SerializeAsync(stream, person);
Person? result = await JsonSerializer.DeserializeAsync<Person>(stream);
```

### 配置（JsonSerializerOptions）

通过 `JsonSerializerOptions` 控制序列化行为。由于首次构造时会做元数据缓存，建议**声明为静态字段复用**，避免重复开销：

```csharp
private static readonly JsonSerializerOptions s_options = new()
{
    WriteIndented = true,
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
};

string json = JsonSerializer.Serialize(person, s_options);
```

常用选项一览：

| 选项 | 说明 |
| --- | --- |
| `WriteIndented` | 输出带缩进的格式化 JSON |
| `PropertyNamingPolicy` | 属性名转换策略（见下文） |
| `PropertyNameCaseInsensitive` | 反序列化时属性名大小写不敏感 |
| `DefaultIgnoreCondition` | 全局忽略条件，如统一忽略所有 null 值 |
| `IncludeFields` | 将公共字段也纳入序列化（.NET 5+） |
| `AllowTrailingCommas` | 允许 JSON 末尾多余的逗号 |
| `ReadCommentHandling` | 允许读取 JSON 中的注释 |

#### 命名策略

`PropertyNamingPolicy` 统一转换所有属性名的大小写风格：

```csharp
// camelCase → {"firstName":"Alice"}
PropertyNamingPolicy = JsonNamingPolicy.CamelCase

// snake_case（.NET 8+）→ {"first_name":"Alice"}
PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower

// SCREAMING_SNAKE_CASE（.NET 8+）→ {"FIRST_NAME":"Alice"}
PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseUpper
```

{{< notice tip >}}
`PropertyNamingPolicy` 只影响**序列化输出**的键名。如果希望反序列化时也能匹配不同大小写的 JSON 键，还需要开启 `PropertyNameCaseInsensitive = true`。
{{< /notice >}}

#### Web 预设（.NET 5+）

`JsonSerializerDefaults.Web` 是专为 Web API 场景准备的快捷预设，一次性启用 camelCase + 大小写不敏感 + 数字可来自字符串：

```csharp
var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
```

ASP.NET Core 的 JSON 配置默认就使用该预设。

### 特性标注

当需要对个别成员做精细控制时，可以在属性或字段上标注特性，优先级高于全局选项。

#### `[JsonPropertyName]`

指定该成员在 JSON 中使用的键名，不受命名策略影响：

```csharp
public class Person
{
    [JsonPropertyName("full_name")]
    public string Name { get; set; }
}
// → {"full_name":"Alice"}
```

#### `[JsonIgnore]`

排除某个成员，不参与序列化和反序列化：

```csharp
public class User
{
    public string Name { get; set; }

    [JsonIgnore]
    public string PasswordHash { get; set; }
}
```

用 `Condition` 参数可以做条件忽略，而不是始终忽略：

```csharp
[JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
public string? Nickname { get; set; }

[JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
public int Score { get; set; }  // 值为 0 时不输出
```

与之等效的全局写法：

```csharp
new JsonSerializerOptions
{
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
}
```

#### `[JsonInclude]`（.NET 5+）

默认只处理公共属性（property）。要将**公共字段**（field）也纳入序列化，有两种方式：

```csharp
// 方式一：逐个标注
public class Point
{
    [JsonInclude] public int X;
    [JsonInclude] public int Y;
}

// 方式二：全局开启（适合字段较多时）
new JsonSerializerOptions { IncludeFields = true }
```

{{< notice tip >}}
虽然可以全局开启 `IncludeFields`，但公共字段在现代 C# 中并不常用，全局开启会让所有类型的序列化行为都受到影响。更推荐的做法是为涉及字段的特殊类型单独创建一个专用的 `JsonSerializerOptions` 实例，按需传入即可。
{{< /notice >}}

#### `[JsonPropertyOrder]`（.NET 6+）

控制属性在 JSON 输出中的排列顺序，数值越小越靠前，默认值为 `0`：

```csharp
public class ApiResponse
{
    [JsonPropertyOrder(-1)]   // 排在最前
    public bool Success { get; set; }

    public string Message { get; set; } // 默认 0

    [JsonPropertyOrder(1)]    // 排在最后
    public object? Data { get; set; }
}
```

## Record 类型

前面介绍的特性标注都是在"可变类型"上做精细控制。但现代 C# 中，我们越来越倾向于使用不可变的数据模型——这就轮到 record 出场了。

从 .NET 5 起，`System.Text.Json` 支持通过带参数的构造函数反序列化，这使 record 成为 JSON 数据模型的理想选择——不需要任何额外代码，就能同时拥有不可变性和完整的序列化支持。

{{< notice info >}}
默认的反序列化路径是先调用无参构造函数创建实例，再通过属性 setter 赋值。但 record 的属性通常是只读的（init setter），且 record 通常只暴露带参构造函数、没有无参构造函数，这条默认路径自然走不通。因此序列化器需要通过带参构造函数，在创建对象的同时把值注入进去。否则恐怕就只能借助反射了。
{{< /notice >}}

### 位置 Record

最简洁的形式是位置 record（positional record），声明即可直接使用：

```csharp
public record Person(string Name, int Age);
```

序列化与普通类型完全一致：

```csharp
var person = new Person("Alice", 30);
string json = JsonSerializer.Serialize(person);
// {"Name":"Alice","Age":30}
```

反序列化时，`System.Text.Json` 会自动定位主构造函数，将 JSON 中的键按名称注入对应参数：

```csharp
Person p = JsonSerializer.Deserialize<Person>("""{"Name":"Alice","Age":30}""")!;
```

### 选择构造函数：`[JsonConstructor]`

如果不使用上述最简单的 record 声明方式，那么就需要提供带参构造函数来实现反序列化了。当类型有多个构造函数时，必须用 `[JsonConstructor]` 明确指定反序列化使用哪一个：

```csharp
public record Point
{
    public int X { get; }
    public int Y { get; }

    [JsonConstructor]
    public Point(int x, int y) => (X, Y) = (x, y);

    public Point(int x) : this(x, 0) { }
}
```

只有单个构造函数时无需标注：有唯一的有参构造函数则自动选择它，只有无参构造函数则走属性赋值路径。

### 参数名匹配

反序列化时，JSON 键与构造函数参数名做**大小写不敏感**匹配，因此下面三种写法都能正确反序列化到 `Person(string Name, int Age)`：

```json
{ "Name": "Alice", "Age": 30 }
{ "name": "Alice", "age": 30 }
{ "NAME": "Alice", "AGE": 30 }
```

如需映射到不同的 JSON 键名，在位置 record 上使用 `[property: JsonPropertyName(...)]`（`property:` 前缀是为了将特性作用到自动生成的属性上，而非构造函数参数）：

```csharp
public record Person(
    [property: JsonPropertyName("full_name")] string Name,
    int Age
);
// 序列化 → {"full_name":"Alice","Age":30}
// 反序列化匹配键 "full_name"
```

非位置 record 或普通 class 则直接标注在属性上即可，无需 `property:` 前缀。

## JsonNode

到目前为止，我们都是在"提前知道 JSON 结构"的前提下做序列化。但实际开发中，经常会遇到结构不固定的 JSON——比如配置文件、第三方 API 返回的动态数据等。这种时候就需要 `JsonNode` 出场了。

`JsonNode` 是 .NET 6 引入的**可变 DOM**，适用于不方便预定义类型的场景：处理结构不固定的 JSON、只需读写其中几个字段、或者动态拼装 JSON 请求体等。

它由四个类型组成，与 Newtonsoft 的类型一一对应：

| System.Text.Json | Newtonsoft.Json | 说明 |
| --- | --- | --- |
| `JsonNode` | `JToken` | 所有节点的抽象基类 |
| `JsonObject` | `JObject` | JSON 对象 `{ }` |
| `JsonArray` | `JArray` | JSON 数组 `[ ]` |
| `JsonValue` | `JValue` | 标量值（字符串、数字、布尔等）|

### 解析与读取

```csharp
string json = """
    {
        "name": "Alice",
        "age": 30,
        "scores": [95, 87, 92],
        "address": { "city": "Beijing" }
    }
    """;

JsonNode root = JsonNode.Parse(json)!;

string name  = root["name"]!.GetValue<string>();              // "Alice"
string city  = root["address"]!["city"]!.GetValue<string>();  // "Beijing"
int    first = root["scores"]![0]!.GetValue<int>();           // 95
```

Newtonsoft 的等效写法几乎相同，仅取值方法有差异：

```csharp
JObject root = JObject.Parse(json);
string name  = root["name"]!.Value<string>();
string city  = root["address"]!["city"]!.Value<string>();
int    first = (int)root["scores"]![0]!;  // JToken 支持隐式转换
```

{{< notice tip >}}
`JsonNode` 的索引器返回 `JsonNode?`（可空），所以读取链中常见 `!`。Newtonsoft 的 `JToken` 在类型转换上更宽松，支持隐式转换运算符，但代价是运行时类型错误更难察觉。
{{< /notice >}}

### 构建 JSON

`JsonObject` 支持像 `Dictionary` 那样初始化，同时 `JsonArray` 支持集合初始化器语法：

```csharp
var node = new JsonObject
{
    ["name"]    = "Alice",
    ["age"]     = 30,
    ["scores"]  = new JsonArray(95, 87, 92),
    ["address"] = new JsonObject
    {
        ["city"] = "Beijing"
    }
};

string json = node.ToJsonString();
// {"name":"Alice","age":30,"scores":[95,87,92],"address":{"city":"Beijing"}}
// ToJsonString 方法支持传入 options
```

与 Newtonsoft 的 `new JObject { ["key"] = value }` 语法几乎相同，`ToJsonString()` 对应 Newtonsoft 的 `ToString()`。

### 修改 DOM

```csharp
JsonNode root = JsonNode.Parse(json)!;

// 添加 / 修改
root["email"] = "alice@example.com";
root["age"]   = 31;

// 删除属性
root.AsObject().Remove("address");

// 向数组追加元素
root["scores"]!.AsArray().Add(100);
```

Newtonsoft 可以直接将 `JToken` 强转为 `JObject` 或 `JArray`，而 `JsonNode` 需要调用 `.AsObject()` / `.AsArray()` 方法显式转换。

### 与强类型对象互转

```csharp
var person = new Person("Alice", 30);

// 强类型 → JsonNode
JsonNode node = JsonSerializer.SerializeToNode(person)!;

// JsonNode → 强类型
Person? p = node.Deserialize<Person>();
```

Newtonsoft 对应的是 `JObject.FromObject(person)` 和 `obj.ToObject<Person>()`。

### 遍历

```csharp
// 遍历对象的所有键值对
foreach (var (key, value) in root.AsObject())
{
    Console.WriteLine($"{key}: {value}");
}

// 遍历数组
foreach (JsonNode? item in root["scores"]!.AsArray())
{
    Console.WriteLine(item!.GetValue<int>());
}
```

### 只读场景：JsonDocument

如果只需要读取、不需要修改，可以使用更早引入（.NET Core 3.0）的 `JsonDocument` / `JsonElement`。它在解析时使用池化缓冲区（pooled buffer）来存储数据，读取性能更高，但节点不可修改，且需要手动 `Dispose` 以归还缓冲区：

```csharp
using JsonDocument doc = JsonDocument.Parse(json);
JsonElement root = doc.RootElement;

string name = root.GetProperty("name").GetString()!;
int age     = root.GetProperty("age").GetInt32();
```

{{< notice info >}}
需要修改或构建 JSON → 用 `JsonNode`；只需读取且追求极致性能 → 考虑 `JsonDocument`。
{{< /notice >}}

## 源生成器

无论是强类型的 `JsonSerializer`，还是动态的 `JsonNode`，它们在底层都依赖同一套机制——反射。而反射在性能和 NativeAOT 场景下都有隐患，源生成器就是为解决这个问题而生的。

默认情况下，`System.Text.Json` 依赖反射在运行时读取类型的属性和构造函数信息。这存在两个问题：

1. **首次调用时有预热开销**，序列化器需要通过多层反射逐一检查所有类型并缓存元数据
2. **阻碍裁剪（trimming）和 NativeAOT**，编译器无法静态分析哪些成员会被访问，只能保留全部代码

**源生成器**（Source Generator）在编译期分析类型并生成序列化代码，完全绕开反射。

### 基本配置

创建一个继承自 `JsonSerializerContext` 的 `partial` 类，用 `[JsonSerializable]` 注册需要处理的顶层类型：

```csharp
[JsonSerializable(typeof(Person))]
[JsonSerializable(typeof(List<Person>))]
internal partial class AppJsonContext : JsonSerializerContext { }
```

编译器会自动生成这个类的实现部分。

{{< notice tip >}}
只需注册**顶层类型**（即直接传入 `JsonSerializer` 的那个）。成员的类型会自动递归处理，无需单独注册。但集合类型必须明确注册，如 `List<Person>` 和 `Person` 需要分别注册。
{{< /notice >}}

### 使用方式

通过 `AppJsonContext.Default` 访问生成的上下文单例：

```csharp
// 传入 JsonTypeInfo<T>（推荐）
string json = JsonSerializer.Serialize(person, AppJsonContext.Default.Person);
Person? p   = JsonSerializer.Deserialize<Person>(json, AppJsonContext.Default.Person);

// 传入 JsonSerializerContext（适合泛型 / 运行时才知道类型的场景）
object obj  = person;
string json = JsonSerializer.Serialize(obj, person.GetType(), AppJsonContext.Default);
```

两种方式均不使用反射。第一种将类型信息完全确定在编译期，还能走序列化优化路径（见下文），是首选。

### 配置选项

序列化选项通过 `[JsonSourceGenerationOptions]` 在编译期指定，等效于运行时的 `JsonSerializerOptions`：

```csharp
[JsonSourceGenerationOptions(
    WriteIndented = true,
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull)]
[JsonSerializable(typeof(Person))]
internal partial class AppJsonContext : JsonSerializerContext { }
```

{{< notice info >}}
`PropertyNamingPolicy` 这里使用的是 `JsonKnownNamingPolicy`（枚举），而非运行时的 `JsonNamingPolicy`（类）。
{{< /notice >}}

### 两种生成模式

源生成器有两种工作模式，默认同时启用：

**元数据模式**（`JsonSourceGenerationMode.Metadata`）：生成 JSON 契约元数据，支持反序列化、循环引用、多态等复杂场景。

**序列化优化模式**（`JsonSourceGenerationMode.Serialization`）：直接生成调用 `Utf8JsonWriter` 的序列化代码（又称 fast-path），跳过运行时选项检查，序列化性能最高。**但它不支持反序列化。**

可以在单个类型上指定模式：

```csharp
[JsonSerializable(typeof(Person), GenerationMode = JsonSourceGenerationMode.Serialization)]
[JsonSerializable(typeof(Order),  GenerationMode = JsonSourceGenerationMode.Metadata)]
internal partial class AppJsonContext : JsonSerializerContext { }
```

### NativeAOT 与裁剪

发布 NativeAOT 时，由于反射 API 不可用，**必须**使用源生成器。建议同时显式关闭默认反射（`JsonSerializerIsReflectionEnabledByDefault=false`），这样在开发调试阶段就能提前发现仍走反射路径的代码，而不是等到发布时才报错：

```xml
<PropertyGroup>
    <PublishAot>true</PublishAot>
    <JsonSerializerIsReflectionEnabledByDefault>false</JsonSerializerIsReflectionEnabledByDefault>
</PropertyGroup>
```

{{< notice info >}}
如果你只是启用裁剪（`PublishTrimmed=true`）而非 NativeAOT，.NET 8 起会**自动**将 `JsonSerializerIsReflectionEnabledByDefault` 设为 `false`，无需手动配置。但显式设置仍然有助于在调试阶段尽早发现问题。
{{< /notice >}}

### 与 ASP.NET Core 集成

ASP.NET Core 内部的 JSON 序列化可以通过 `TypeInfoResolverChain` 接入源生成上下文：

```csharp
builder.Services.ConfigureHttpJsonOptions(options =>
{
    options.SerializerOptions.TypeInfoResolverChain.Insert(0, AppJsonContext.Default);
});
```

`TypeInfoResolverChain`（.NET 8+）支持链接多个上下文：当一个上下文找不到某个类型的信息时，会自动尝试链中的下一个。这在将多个库的上下文合并使用时尤为有用。

## 总结

System.Text.Json 是 .NET 平台上现代化的 JSON 序列化方案。相比 Newtonsoft.Json，它在性能、内存分配和 NativeAOT 支持上都有显著优势，并且自 .NET Core 3.0 起就作为框架内置库随附，无需额外引入第三方依赖。

如果你正在从 Newtonsoft.Json 迁移，本文梳理的 JsonNode、Record 支持和特性标注等内容应该能覆盖大多数日常场景。而对于追求极致性能或需要 NativeAOT 发布的项目，源生成器则是必选项。随着 .NET 的持续演进，System.Text.Json 的功能覆盖已经相当完善，完全可以在大多数项目中替代 Newtonsoft.Json。
