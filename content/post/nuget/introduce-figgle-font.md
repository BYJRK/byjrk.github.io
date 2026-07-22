---
title: "Figgle：在控制台中打印 ASCII 艺术字"
slug: "introduce-figgle-font"
image: https://files.seeusercontent.com/2026/07/22/3Xpn/Snipaste_2026-07-22_16-29-00.png
description: "本文介绍 Figgle 的用途，以及在 .NET 控制台程序中生成 ASCII 艺术字的方法。"
date: 2026-07-22
categories:
    - nuget
tags:
    - dotnet
    - csharp
    - nuget
    - console
---

我的一些 C# 的教学视频里经常会用到一种看起来很华丽的 ASCII 艺术字，形如：

```
  _____  _____ _                     
 / ____|/ ____| |                    
| |    | (___ | |__   __ _ _ __ _ __ 
| |     \___ \| '_ \ / _` | '__| '_ \
| |____ ____) | | | | (_| | |  | |_) |
 \_____|_____/|_| |_|\__,_|_|  | .__/
                               | |   
                               |_|
```

或者

```
 ____     ____    __                                
/\  _`\  /\  _`\ /\ \                               
\ \ \/\_\\ \,\L\_\ \ \___      __     _ __   _____  
 \ \ \/_/_\/_\__ \\ \  _ `\  /'__`\  /\`'__\/\ '__`\
  \ \ \L\ \ /\ \L\ \ \ \ \ \/\ \L\.\_\ \ \/ \ \ \L\ \
   \ \____/ \ `\____\ \_\ \_\ \__/.\_\\ \_\  \ \ ,__/
    \/___/   \/_____/\/_/\/_/\/__/\/_/ \/_/   \ \ \/
                                               \ \_\
                                                \/_/
```

经常会有观众问我这样的文字是怎么生成的。其实很简单，我用了 [Figgle](https://github.com/drewnoakes/figgle) 这个 NuGet 库。

Figgle 是一个用于在 .NET 程序中生成 ASCII 艺术字横幅的开源库。给它一段普通文本和一种字体，它就能将文本渲染成上面那样由普通字符组成的“大字”。它很适合用在命令行工具的启动 Banner、示例程序的标题，或者需要在终端里突出显示某些信息的场景。

Figgle 的名字和能力都来自更早的 [FIGlet](https://www.figlet.org/) 项目。FIGlet 是一个经典的命令行程序，最早由 Glenn Chappell 在 1991 年编写；它使用 `.flf` 字体文件，将文本转换为 ASCII 艺术字。此后，社区积累了大量不同风格的 FIGlet 字体。

Figgle 将这种成熟的字体格式和渲染方式带到了 .NET 生态中。它并不是自己定义一套新的艺术字格式，而是负责解析 FIGlet 字体并输出渲染结果。因此，Figgle 既可以使用它提供的现成字体，也可以使用自己找到或制作的 `.flf` 字体文件。

## Figgle 的几个 NuGet 包

Figgle 项目目前主要发布了三个 NuGet 包，它们分别面向不同的使用方式。

### `Figgle`

[`Figgle`](https://www.nuget.org/packages/Figgle/) 是核心包，负责解析 FIGlet 字体和渲染文本。它不包含完整的字体集合，因此包本身比较轻量。

如果项目中使用的是自定义 `.flf` 文件，或者通过源生成器把字体嵌入到了自己的程序集里，运行时通常只需要引用这个包。

### `Figgle.Fonts`

[`Figgle.Fonts`](https://www.nuget.org/packages/Figgle.Fonts/) 是字体包，内置了 250 多种 FIGlet 字体（截止到写这篇文章时的 0.6.6 版本，共有 265 种字体）。最简单的使用方式就是同时安装 `Figgle` 和它，然后通过 `FiggleFonts` 类取得某一种预置字体。

```shell
dotnet add package Figgle
dotnet add package Figgle.Fonts
```

后面会看到，诸如 `Standard`、`Slant`、`Graffiti` 等常用字体，都是由这个包提供的。它适合快速尝试不同的效果；代价是应用会携带完整字体集。

### `Figgle.Generator`

[`Figgle.Generator`](https://www.nuget.org/packages/Figgle.Generator/) 是一个 C# 源生成器包，主要用来优化发布体积和运行时开销。

它有两种典型用法：对于编译期就确定的文本，直接在编译时生成最终的 ASCII 字符串；对于运行时才确定的文本，则只将实际会用到的字体嵌入程序集。这样就无需在最终应用中携带完整的 `Figgle.Fonts` 字体包。

{{< notice note >}}
如果只是想在小型控制台项目里快速打印一个标题，直接使用 `Figgle` 和 `Figgle.Fonts` 就足够了。`Figgle.Generator` 更适合在意应用体积，或只需要少数几个固定字体的场景。
{{< /notice >}}

## 使用 Figgle 和 Figgle.Fonts

对于大多数控制台程序而言，直接引用 `Figgle` 与 `Figgle.Fonts` 是最简单的方式。前者提供渲染能力，后者提供预置字体；安装命令在上文已经列出。

安装完成后，在代码中引入 `Figgle` 命名空间，即可通过 `FiggleFonts` 访问字体。下面的示例使用默认的 `Standard` 字体，将普通字符串渲染为 ASCII 艺术字：

```csharp
using Figgle;

Console.WriteLine(FiggleFonts.Standard.Render("Hello, World!"));
```

`Render` 方法接收需要显示的文本，返回一个包含换行符的字符串。

`Figgle.Fonts` 内置了 250 多种字体。不同字体的高度、宽度和风格差异很大，只要更换 `FiggleFonts` 上的字体属性，就能得到完全不同的效果。

例如，`Slant` 字体会让字符呈现倾斜效果，而 `ThreePoint` 字体非常紧凑，适合控制台宽度有限，或者不希望 Banner 占用太多行的场景。

```csharp
using Figgle;

Console.WriteLine(FiggleFonts.Slant.Render("Figgle"));
Console.WriteLine(FiggleFonts.ThreePoint.Render("Figgle"));
```

{{< notice tip >}}
在选择字体时，建议同时考虑终端窗口的宽度和文本长度，并务必使用等宽字体（常见的有 Consolas、Courier New、Monaco 等），否则 ASCII 艺术字的对齐会被破坏。另外，Figgle 只支持 ASCII 字符，也就是英文字母、数字和常用符号；中文或其他非 ASCII 字符无法渲染。
{{< /notice >}}

## 使用 Figgle.Generator

直接引用 `Figgle.Fonts` 很方便，但它会将全部 265 种字体一并带入应用。对于只使用一个固定 Banner 的程序，这显然有些浪费。`Figgle.Generator` 是一个 C# 源生成器：它会在编译时读取字体并生成 C# 代码，让最终程序只保留真正需要的内容。

根据文本是否在编译时确定，源生成器有两种用法。

### 在编译期生成固定文本

如果 Banner 的内容固定，例如程序名称或版本标题，可以让源生成器直接将最终的 ASCII 字符串写入程序集。此时运行时不需要 `Figgle` 或 `Figgle.Fonts`。

先安装源生成器。`PrivateAssets="all"` 表示该包只在编译期使用，不会作为依赖传递给引用当前项目的其他项目：

```xml
<ItemGroup>
  <PackageReference Include="Figgle.Generator" Version="0.6.6" PrivateAssets="all" />
</ItemGroup>
```

然后为一个 `partial` 类添加 `GenerateFiggleText` 特性：

```csharp
using Figgle;

[GenerateFiggleText(
    memberName: "Title",
    fontName: "slant",
    sourceText: "My Application")]
internal static partial class AsciiBanners;
```

编译时，源生成器会在 `AsciiBanners` 中生成名为 `Title` 的静态成员。使用时直接读取它即可：

```csharp
Console.WriteLine(AsciiBanners.Title);
```

这里的 `fontName` 使用的是 FIGlet 字体名称，而不是 `FiggleFonts.Slant` 这样的 C# 属性名。字体名不区分大小写。

### 嵌入字体并在运行时渲染

如果需要渲染的文本直到运行时才能确定，例如将用户输入、服务器名称或当前环境名称输出为艺术字，就不能预先生成最终字符串。不过仍然可以只嵌入一个需要的字体。

这种方式需要在运行时引用核心包，并在编译期引用源生成器：

```xml
<ItemGroup>
  <PackageReference Include="Figgle" Version="0.6.6" />
  <PackageReference Include="Figgle.Generator" Version="0.6.6" PrivateAssets="all" />
</ItemGroup>
```

使用 `EmbedFiggleFont` 特性声明要嵌入的字体：

```csharp
using Figgle;

[EmbedFiggleFont(
    memberName: "Slant",
    fontName: "slant")]
internal static partial class EmbeddedFonts;
```

编译后会得到一个 `FiggleFont` 对象，因此可以像普通字体一样在运行时调用 `Render`：

```csharp
string environmentName = Environment.MachineName;
Console.WriteLine(EmbeddedFonts.Slant.Render(environmentName));
```

最终应用只会包含 `Figgle` 核心库和 `slant` 字体，不再依赖完整的 `Figgle.Fonts` 包。

{{< notice tip >}}
固定文本优先使用 `GenerateFiggleText`，因为它连运行时渲染和核心库都不需要；只有在文本动态变化时，才选择 `EmbedFiggleFont`。
{{< /notice >}}

## 常用字体推荐

虽然 FiggleFonts 里面包含了大量的字体，但其实个人觉得 90% 以上的都完全用不上，或者可读性非常差。所以这里我挑选了一些个人向的常用字体，供大家参考。下面的例子都以“Figgle”为例。

### Big

```
 ______ _             _     
|  ____(_)           | |    
| |__   _  __ _  __ _| | ___
|  __| | |/ _` |/ _` | |/ _ \
| |    | | (_| | (_| | |  __/
|_|    |_|\__, |\__, |_|\___|
           __/ | __/ |      
          |___/ |___/ 
```

此外，Standard、Doom、IVrit 都与此类似，只是细节和大小上略有差异。

### Slant

```

     _______             __   
    / ____(_)___ _____ _/ /__ 
   / /_  / / __ `/ __ `/ / _ \
  / __/ / / /_/ / /_/ / /  __/
 /_/   /_/\__, /\__, /_/\___/ 
         /____//____/         

```

### Ogre

```
   ___ _             _      
  / __(_) __ _  __ _| | ___ 
 / _\ | |/ _` |/ _` | |/ _ \
/ /   | | (_| | (_| | |  __/
\/    |_|\__, |\__, |_|\___|
         |___/ |___/        
```

### Larry3d

```
____                         ___             
/\  _`\   __                 /\_ \            
\ \ \L\_\/\_\     __      __ \//\ \      __   
 \ \  _\/\/\ \  /'_ `\  /'_ `\ \ \ \   /'__`\ 
  \ \ \/  \ \ \/\ \L\ \/\ \L\ \ \_\ \_/\  __/ 
   \ \_\   \ \_\ \____ \ \____ \/\____\ \____\
    \/_/    \/_/\/___L\ \/___L\ \/____/\/____/
                  /\____/ /\____/             
                  \_/__/  \_/__/              
```

## 预览全部字体

如果大家还拿不定主意，那么可以用下面这个 C# 脚本来快速预览所有字体。使用 .NET 10 新增的 `dotnet run app.cs` 即可。如果版本比较低，只需要把它改成一个传统的 C# 控制台项目即可。

```csharp
#:package Figgle.Fonts@0.6.6 // 它依赖 Figgle，会自动引入

using System.Reflection;
using Figgle;
using Figgle.Fonts;

var fonts = typeof(FiggleFonts)
    .GetProperties(BindingFlags.Public | BindingFlags.Static)
    .Where(p => p.PropertyType == typeof(FiggleFont))
    .Select(p => new { p.Name, Font = (FiggleFont)p.GetValue(null)! })
    .ToArray();

Console.Write("Enter text to render: ");
var input = Console.ReadLine();

foreach (var font in fonts)
{
    Console.WriteLine($"Font: {font.Name}");
    Console.WriteLine(font.Font.Render(input));
    Console.WriteLine();
}
```
