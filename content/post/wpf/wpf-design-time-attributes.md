---
title: "WPF 设计时特性的实用技巧"
slug: "wpf-design-time-attributes"
description: "本文介绍 WPF 中设计时特性的使用方法，让我们在设计时就能看到更多的效果，显著提高开发效率和体验。"
image: 
date: 2024-09-07
tags:
    - dotnet
    - wpf
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV17kptetEQV/)

相信无数 WPF 开发者在开发过程中，都会遭受过很多这样或那样的痛苦，比如：

- 在设计 `TextBlock` 控件时，因为无法预览字体、字号、颜色等属性，导致需要临时给 `Text` 属性赋一个值，查看效果后再删除；
- 有一个默认折叠的 `Expander` 控件，但是在设计时无法看到折叠后的效果，只能在运行时查看，或者临时修改 `IsExpanded` 属性；
- `Window` 的 `DataContext` 因为在后台代码中赋值，导致在设计时无法看到绑定的数据，也无法在书写绑定时获得智能提示。

如果你有过这样的困扰，那么这篇文章一定可以帮助到你。本文将介绍 WPF 中设计时特性的使用方法，让你在设计时就能看到更多的效果，提高开发效率。

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
<!-- 或者也可以用下面将要介绍的虚拟控件 -->
<d:TextBlock>
    <Run Text="Hello, " />
    <d:Run Text="World!" FontWeight="Bold"/>
</d:TextBlock>
```

其他类似的例子还比如：

1. 有一个只在特殊情况下才会展示的进度条，希望查看它的效果：`d:Visibility="Visible"`
2. 有一个平时默认折叠的面板，想查看效果：`d:IsExpanded="True"`
3. 一个用户控件，想给它一个相对合理的默认大小：`d:DesignHeight="600"` 或 `d:Height`
4. 一个下拉框，想查看选中项的预览效果：`d:SelectedIndex="0"`
5. 一个导航用的 `ContentControl`，我们希望预览导航到某一页的效果，就可以写 `d:ContentControl.Content`

{{<notice info>}}
关于上面的第 5 个例子，为什么我们直接将想要导航的内容以下面要提到的虚拟控件的方式添加到 `ContentControl` 之中呢？因为通常来说，我们写的导航页面是借助 `UserControl` 实现的，而它的命名空间通常为 `xmlns:local` 等。对于这样的命名空间，我们没有办法使用 `d:` 技巧，所以这里我们选择为 `ContentControl` 的 `Content` 属性添加 `d:` 特性。
{{</notice>}}

## 虚拟控件

我们不仅可以借助设计时特性来实现控件某些属性的虚拟，还可以虚拟整个控件出来：

```xml
<d:Button Content="Virtual Button" Style="{StaticResource MyButtonStyle}" />
```

这样就可以在设计时看到一个虚拟的按钮了，而不需要在运行时才能看到效果。这一技巧可以用来预览按钮的样式。

还有一种常见情形是，我们设计的软件会让用户去手动添加一些项目，从而动态生成对应的控件。对于这样的情况，我们如果能在设计时就看到一些“生成”出来的控件，那么就能更好地开发样式了。此时，我们添加一些虚拟控件，就可以满足这个需求。

```xml
<ItemsControl>
    <d:ItemsControl.Items>
            <Button Content="Button 1" />
            <Button Content="Button 2" />
            <Button Content="Button 3" />
    </d:ItemsControl.Items>
</ItemsControl>
```

## 设计时数据

这段内容可以说是重中之重了。很多开发者苦恼于因为在 Window 的代码后台通过 `this.DataContext = new ViewModel();` 来添加 `ViewModel`，导致在设计时无法看到绑定的数据，也无法获得智能提示。这时候我们可以使用 `d:DataContext` 来指定设计时的数据：

```xml
<Window ...
        d:DataContext="{d:DesignInstance Type=vm:MainViewModel}">
</Window>
```

`DesignInstance` 还有一个 `IsDesignTimeCreatable` 属性，用于指定是否在设计时创建实例。如果设为 `True`，还将能够在设计时看到一些 ViewModel 中属性的默认值。

或者我们还可以这样写，并且还可以在 XAML 中定制一些 ViewModel 的属性的初始值，便于观察效果：

```xml
<Window ...>
    <d:DataContext>
        <vm:MainViewModel Message="Hello!" />
    </d:DataContext>
</Window>
```

## 列表项

如果我们有一个 `ListBox`，并且想要查看列表项的效果，可以这样：

```xml
<ListBox ItemsSource="{Binding Students}">
    <d:ListBox.ItemsSource>
        <x:Array Type="model:Student">
            <model:Student Name="Alice" Age="18" />
            <model:Student Name="Bob" Age="19" />
            <model:Student Name="Charlie" Age="20" />
        </x:Array>
    </d:ListBox.ItemsSource>
</ListBox>
```

如果不想写 `x:Array`，而是希望采用传统的为 `Items` 添加控件的方式添加预览项，也可以这样：

```xml
<ListBox ItemsSource="{Binding Students}" d:ItemsSource="{x:Null}">
    <ListBox.Items>
        <ListBoxItem>Student 1</ListBoxItem>
        <ListBoxItem>Student 2</ListBoxItem>
        <ListBoxItem>Student 3</ListBoxItem>
    </ListBox.Items>
</ListBox>
```

这里额外写一个 `d:ItemsSource="{x:Null}"` 是因为 `ItemsSource` 和 `Items` 两个属性不能同时使用，所以我们需要将 `ItemsSource` 设置为 `null`，就可以避免这个报错了。

除了这些，如果我们想要预览的是比较简单的数据，或者我们并不非常关心数据的内容及格式，只是希望生成几个项目从而查看样式或模板的书写是否有问题，那么还有一个更简单的方法：

```xml
<ListBox ItemsSource="{Binding Students}" d:ItemsSource="{d:SampleData ItemCount=5}" />
```

这样就可以生成 5 个虚拟的列表项了。

## 更多功能

除了上面介绍的这些，还有很多其他的设计时特性，比如：

1. `d:DesignSource` 用于 `CollectionViewSource` 的设计时数据；
2. `DesignData` 生成操作；
3. 在其他程序集的自定义控件及附加属性上使用设计时特性。

关于上面的这些内容，大家可以移步我的视频观看倒数两个章节。

## 参考

- [Design-Time Attributes](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2010/ee839627(v=vs.100))
- [Using Sample Data in the WPF Designer](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2010/ee823176(v=vs.100))
- [Use Design Time Data with the XAML Designer](https://learn.microsoft.com/en-us/visualstudio/xaml-tools/xaml-designtime-data?view=vs-2022)