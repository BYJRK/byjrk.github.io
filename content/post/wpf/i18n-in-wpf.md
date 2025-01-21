---
title: "如何在 WPF 中实现支持动态切换的双语界面"
slug: "i18n-in-wpf"
description: "软件界面的本地化一直是一个热门的话题，但同时也是一个非常容易一不小心就选错了实现方式，导致后来追悔莫及的问题。本文将介绍几种在 WPF 中实现双语界面的方式供大家参考。"
draft: true
date: 2025-01-21
tags:
    - dotnet
    - csharp
    - wpf
    - i18n
---

在 WPF 中实现双语界面，这个需求说简单也简单，因为你只需要采用一种方式去管理你的不同语言下的各种资源（尤其是字符串），然后再想办法去将它们套用到界面的控件上。但是，这个需求说难也难，因为你需要考虑到很多细节，比如如何实现动态切换、如何支持多种资源类型（比如图片、声音等）、如何高效地管理资源项、如何在开发时能够获得编译时的提示及运行时的检查等。

对于这一功能的实现，大家只要在网上随便一搜，相信就能够找到一些常见的解决方案，然后可能就会掉以轻心，立刻抄到自己的项目中。但是不久之后，很可能就会发现这些方案并不是那么完美，甚至可能还和一些第三方的库不怎么兼容，导致不得不引入更多手段来弥补。最终，自己的项目可能就会变得越来越臃肿，越来越难以维护。

所以，本文将介绍几种在 WPF 中实现双语界面的方式供大家参考。这些方式各有所长，并且也很难说哪个方法就是最好的，最能够胜任各种情形和需求的。大家可以根据自己的项目需求和团队技术水平来选择适合自己的方式。

## 使用资源词典

使用资源词典（`ResourceDictionary`）是最常见也最简单的一种方式。在 WPF 中，我们可以创建一些资源词典，然后将它们合并到程序的资源中，然后通过 `DynamicResource` 来将这些资源应用到界面的控件上。

假如我们现在创建了一个资源词典文件 `Langs/Strings.zh.xaml`，内容大致如下：

```xml
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
                    xmlsn:sys="clr-namespace:System;assembly=mscorlib">
    <sys:String x:Key="Hello">你好</sys:String>
    <sys:String x:Key="World">世界</sys:String>
</ResourceDictionary>
```

{{< notice tip>}}
这里我们引入了 `sys` 这个命名空间，从而可以使用 `sys:String` 来定义字符串资源。对于该命名空间实际引入的程序集，除了上面的 `mscorlib` 之外，还可以使用 `System.Core`、`netstandard` 等。但是这两个只能用于 .NET Core 以上的项目，不能用于 .NET Framework 项目。因为 WPF 并不能跨平台，所以我们不需要关注这方面的问题，因此任何情况下都可以使用 `mscorlib`。
{{< /notice >}}

然后我们可以在 `App.xaml` 中将这个资源词典合并到程序的资源中：

```xml
<Application ...>
    <Application.Resources>
        <ResourceDictionary>
            <ResourceDictionary.MergedDictionaries>
                <ResourceDictionary Source="Langs/Strings.zh.xaml" />
            </ResourceDictionary.MergedDictionaries>

            <!-- 其他资源 -->
        </ResourceDictionary>
    </Application.Resources>
</Application>
```

最后，我们可以在界面的控件上使用这些资源：

```xml
<TextBlock Text="{DynamicResource Hello}" />
<TextBlock Text="{DynamicResource World}" />
```

除了上面的合并方式，我们还可以在后台代码中进行合并，同时也可以用来实现语言的动态切换。比如：

```csharp
public partial class App : Application
{
    public void ChangeLanguage(string lang)
    {
        var dict = new ResourceDictionary
        {
            Source = new Uri($"Langs/Strings.{lang}.xaml", UriKind.Relative)
        };

        // 通常我们合并的资源词典可能有很多，因此清空现有的资源可能并不是个好主意
        // 并且这通常是不必要的，因为我们新引入的会基于 Key 覆盖原有的
        // Resources.MergedDictionaries.Clear();
        Resources.MergedDictionaries.Add(dict);
    }
}
```

{{< notice tip >}}
虽然我们的确可以在代码后台去合并，从而省去在 `App.xaml` 中声明的步骤，并且也可以实现程序在开启前并不拥有一个默认语言，而是通过开启后读取配置等方式确定想要的语言，进而去加载相应的资源。但是这样有一个明显的缺点：我们无法在设计时看到界面的效果，也无法获得任何代码提示。这一问题无疑是灾难性的。

因此，绝大多数情况下，推荐的方式是在 `App.xaml` 中引入一个默认语言（通常为英文），然后在程序启动后再根据配置等方式去加载其他语言的资源。
{{< /notice >}}

## 资源词典方式的变种

资源词典这种方式其实还是有一些“灵活性”的，主要就灵活在，我们不一定非要把它们写在 `.xaml` 文件中。比如，我们可以在后台代码中生成：

```csharp
public partial class App : Application
{
    public void ChangeLanguage(string lang)
    {
        var dict = new ResourceDictionary();
        dict.Add("Hello", "你好");
        dict.Add("World", "世界");

        Resources.MergedDictionaries.Add(dict);
    }
}
```

然后相信大家也发现了，我们甚至都没有必要把它们用硬编码的方式写在后台代码中，我们可以通过读取配置文件、数据库、CSV 文件等方式来加载这些资源。这样，我们就可以实现一个支持动态切换的双语界面了。毕竟，使用这些方式的体验应该是要比直接手写 `.xaml` 文件要好很多的。

## 使用 `Resx` 文件

下面我们终于要“步入正轨”，采用官方推荐的方式：使用 `Resx` 文件。这种方式是最为推荐的，而且也是最为灵活的。Visual Studio 2022 最新版本还为我们提供了内置的多语言管理工具。

要使用这种方式，我们首先需要创建一个 `Resx` 文件，然后在其中添加我们的资源项。比如，我们创建一个 `Resources/Strings.resx` 文件。此时我们可以在项目结构中看到它，并且还有一个 `Strings.Designer.cs` 文件，这个文件是由 Visual Studio 自动生成的。

现在，我们在 `Strings.resx` 文件中添加两个资源项：

- Name: `Hello`, Value: `你好`
- Name: `World`, Value: `世界`

