---
title: "C# 代码格式化工具 CSharpier 上手指南"
slug: csharpier
date: 2023-10-16
image: https://s2.loli.net/2024/04/14/qZeQzEnSDvWpPyL.png
tags:
    - csharp
    - tool
---

## 简介

[CSharpier](https://csharpier.com/) 是一个针对 C# 代码的格式化工具，它可以帮助开发者自动化地调整代码的格式，使其更加一致和易于阅读。CSharpier 提供了丰富的配置选项，可以根据项目的需求定制代码格式化的规则。

它的官方介绍是「CSharpier is an opinionated code formatter for C#」，其中的“opinionated”是一个英文词，意思是“有主见的”或“有偏见的”。它想表达的是，该工具对代码格式化有自己的偏好和主见，即它会按照自己的规则来格式化代码，而不是完全按照用户的意愿。在下面的内容中，大家不难看出，CSharpier 几乎没有提供多少可以配置的选项。

## 安装

在 VS 的扩展中安装了 CSharpier 后，重启 VS 后会在上方提示安装工具，但是也可以自行安装，方式如下：

```shell
dotnet tool install -g csharpier
```

如果希望更新，那么可以：

```shell
dotnet tool update -g csharpier
```

除了 VS，VS Code、Rider 中也都有同名的扩展。

## 配置

可以在项目的根目录（通常与 `.sln` 文件位置相同）创建一个配置文件，可以是下面三个的任意一种：

- `.csharpierrc`
- `.csharpierrc.json`
- `.csharpierrc.yaml`

支持的配置项非常少，常用的一些如下：

```json
{
    "printWidth": 100,
    "useTabs": false,
    "tabWidth": 4,
    "preprocessorSymbolSets": ["", "DEBUG", "DEBUG,CODE_STYLE"]
}
```

或者

```yaml
printWidth: 100
useTabs: false
tabWidth: 4
preprocessorSymbolSets:
    - ""
    - "DEBUG"
    - "DEBUG,CODE_STYLE"
```

其中最后一个配置项与代码中预编译器指令（如 `#if DEBUG`）有关，详见[官方的配置文档](https://csharpier.com/docs/Configuration)。

## 实用场景

这里我随便写了一大段 C# 代码，大家可以拷贝到自己常用的 C# 开发工具中，然后使用 CSharpier 格式化，从而查看效果。

CSharpier 还提供了一个[Playground](https://playground.csharpier.com/)，方便大家在线体验它的效果。

```csharp
class CSharpierDemo
{
    private readonly List<string> allowedExtensions = new List<string> { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".tif", ".webp", ".heic" };

    private int[,] map = new [,] { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } };

    public static readonly DependencyProperty MyPropertyProperty = DependencyProperty.Register("MyProperty", typeof(string), typeof(MyControl), new PropertyMetadata(""));

    [JsonIgnore] public string MyProperty1 { get; set; }
    [JsonIgnore] public string MyProperty2 { get; set; }
    [JsonIgnore] public string MyProperty3 { get; set; }

    private void Foo()
    {
        allowedExtensions.Select(x => x.Trim().ToLower()).Select(x => x.TrimLeft('.')).Where(x => x.Length == 3).ToList().ForEach(x => Console.WriteLine(x));

        var exts = from x in allowedExtensions select x.Trim().ToLower() into x select x.TrimLeft('.') into x where x.Length == 3 select x;
    }

    private void FooWithManyParameters([FromHeader(Name = "Id")] long id, [FromQuery(Name = "first_name")] string firstName, [FromQuery(Name = "last_name")] string lastName, string? middleName = null, Action? callback = null, Action? errorCallback = null)
    {
        // ...
    }
}
```
