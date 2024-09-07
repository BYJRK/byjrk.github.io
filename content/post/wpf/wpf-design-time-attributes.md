---
title: "WPF 设计时特性的实用技巧"
slug: "wpf-design-time-attributes"
description: 
date: 2024-09-07
tags:
    - dotnet
    - csharp
    - wpf
---

相信无数 WPF 开发者在开发过程中，都会遭受过很多这样或那样的痛苦，比如：

- 在设计 `TextBlock` 控件时，因为无法预览字体、字号、颜色等属性，导致需要临时给 `Text` 属性赋一个值，查看效果后再删除；
- 有一个默认折叠的 `Expander` 控件，但是在设计时无法看到折叠后的效果，只能在运行时查看，或者临时修改 `IsExpanded` 属性；
- `Window` 的 `DataContext` 因为在后台代码中赋值，导致在设计时无法看到绑定的数据，也无法在书写绑定时获得智能提示。

如果你有过这样的困扰，那么这篇文章一定可以帮助到你。本文将介绍 WPF 中设计时特性的使用方法，让你在设计时就能看到更多的效果，提高开发效率。

{{<notice warning>}}
这篇文章是占坑用的，内容尚未完善。待相关视频发布后，会及时更新。
{{</notice>}}

## 基本概念

设计时特性（Design-Time Attributes）是 WPF 中的一种特性，用于在设计时为控件提供更多的信息，以便在设计时能够更好地预览控件的效果。这一功能其实默认一直都是开启的，只是我想可能很多开发者都没有注意过。比如我们在 WPF 中新建一个 `UserControl`，那么就会在 XAML 的开头看到类似这样的代码：

```xml
<UserControl x:Class="WpfApp1.MyUserControl"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" 
             xmlns:d="http://schemas.microsoft.com/expression/blend/2008" 
             mc:Ignorable="d" 
             d:DesignHeight="450" d:DesignWidth="800">
</UserControl>
```

在开头，模板自动为我们添加了很多 XML 命名空间（`xmlns`），但是很多开发者可能只了解 `xmlns` 与 `xmlns:x` 这两个，而往往忽略了另外的几个。但其实另外的几个（`xmlns:mc`、`xmlns:d`）就提供了设计时特性的支持。最典型的例子就比如上面的`d:DesignHeight`和`d:DesignWidth`，这两个属性就是用来在设计时指定控件的高度和宽度的。这些特性最大的特点就是，它们只在设计时起作用，不会影响运行时的效果。

了解了这些基本概念后，我们就可以开始介绍一些常用的设计时特性了。

## 常用设计时特性

比如 `TextBlock` 的 `Text` 在设计时并没有内容（比如是 `DynamicResource` 从运行时加载的语言文件中获取，或绑定了 `ViewModel` 中的属性，但是设计时这个属性没有值，却又想预览字体效果，这时候就可以使用 `d:Text` 来指定设计时的文本内容：

```xml
<TextBlock Text="{DynamicResource ResourceKey=HelloWorld}" d:Text="Hello, World!" />
```

这样在设计时就可以看到 `Hello, World!` 这个文本了。

如果 `TextBlock` 的内容是用多个 `Run` 组合而成，那么我们也可以用这样的方式来实现：

```xml
<TextBlock>
    <d:TextBlock.Inlines>
        <Run Text="Hello, " />
        <Run Text="World!" FontWeight="Bold" />
    </d:TextBlock.Inlines>
</TextBlock>
```

其他类似的例子还比如：

1. 有一个只在特殊情况下才会展示的进度条，希望查看它的效果：`d:Visibility="Visible"`
2. 有一个平时默认折叠的面板，想查看效果：`d:IsExpanded="True"`
3. 一个用户控件，想给它一个相对合理的默认大小：`d:DesignHeight="600"` 或 `d:Height`
4. 一个下拉框，想查看选中项的预览效果：`d:SelectedIndex="0"`

## 虚拟控件

我们不仅可以借助设计时特性来实现控件某些属性的虚拟，还可以虚拟整个控件出来：

```xml
<d:Button Content="Virtual Button" Style="{StaticResource MyButtonStyle}" />
```

这样就可以在设计时看到一个虚拟的按钮了，而不需要在运行时才能看到效果。这一技巧可以用来预览按钮的样式。

## 设计时数据

这段内容可以说是重中之重了。很多开发者苦恼于因为在 Window 的代码后台通过 `this.DataContext = new ViewModel();` 来添加 `ViewModel`，导致在设计时无法看到绑定的数据，也无法获得智能提示。这时候我们可以使用 `d:DataContext` 来指定设计时的数据：

```xml
<Window ...
        d:DataContext="{d:DesignInstance Type=vm:MainViewModel}">
</Window>
```

## 列表项

如果我们有一个 `ListBox`，并且想要查看列表项的效果，可以这样：

```xml
<ListBox d:ItemsSource="{d:SampleData Items=10}" />
```

## 更多功能

除了上面介绍的这些，还有很多其他的设计时特性，比如：

1. `d:DesignSource` 用于 `CollectionViewSource` 的设计时数据；
2. `DesignData` 生成操作；
3. 在其他程序集的自定义控件及附加属性上使用设计时特性。

## 参考

- [Design-Time Attributes](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2010/ee839627(v=vs.100))
- [Using Sample Data in the WPF Designer](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2010/ee823176(v=vs.100))
- [Use Design Time Data with the XAML Designer](https://learn.microsoft.com/en-us/visualstudio/xaml-tools/xaml-designtime-data?view=vs-2022)