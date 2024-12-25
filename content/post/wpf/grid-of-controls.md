---
title: "如何在 WPF 中高效布局多行多列的控件"
slug: "grid-of-controls"
description: 
date: 2024-12-25
draft: true
tags:
    - dotnet
    - csharp
    - wpf
---

这次我们来探讨一个 WPF 中的简单而又不简单的布局问题：如何实现下图中的效果？

{{< figure src="https://s2.loli.net/2024/12/25/qlpQr1DJ4FBskKe.png" width="400px" >}}

为什么说这个问题简单而又不简单呢？是因为单纯只是实现这个效果的话，我们完全可以使用 `Grid` 控件来实现。甚至如果完全不在乎优雅的话，我们还可以用 `Canvas` 来实现（当然这几乎在任何情况下都是不推荐的）。但是，实际这样干过的开发者相信都很清楚，这样的实现方式几乎可以说是毫无灵活性的。很快就会被后续的界面微调的需求整得焦头烂额。

那么我们今天就来看一看，这样的需求通常有哪些做法吧。希望这篇文章中提到的某些方式能够帮助到你。

## 最传统的方式：Grid

在介绍后面的更好的方式之前，我们有必要先来看一看最传统的方式：使用 `Grid` 控件。这样才能更好地分析这种方式的局限性，以及思考改进的方向。

这样的方式相信所有具备基本 WPF 基础的开发者都相当熟悉：

1. 在 XAML 中定义一个 `Grid` 控件
2. 在 `Grid` 中定义多个 `RowDefinition` 和 `ColumnDefinition`
3. 在 `Grid` 中定义多个控件，并通过 `Grid.Row` 和 `Grid.Column` 来指定控件的位置
4. （可选）通过 `Grid.RowSpan` 和 `Grid.ColumnSpan` 来指定控件的跨行和跨列

好，然后我们就开始写 XAML 吧：

```xml
<Grid>
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
        <RowDefinition Height="Auto" />
    </Grid.RowDefinitions>
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto" />
        <ColumnDefinition Width="Auto" />
    </Grid.ColumnDefinitions>

    <Label Grid.Row="0" Grid.Column="0" Content="1" />
    <TextBox Grid.Row="0" Grid.Column="1" />
    <Label Grid.Row="1" Grid.Column="0" Content="2" />
    <TextBox Grid.Row="1" Grid.Column="1" />
    <!-- ... -->
</Grid>
```

好的，马上痛苦面具就戴上了：为每个控件写 `Grid.Row` 和 `Grid.Column`，简直就是顶级折磨。如果你搞了十几行，结果被告知需要删掉前面某一行，或者在前面添加一行，那就更是欲哭无泪了。

{{< notice tip >}}
可能会有聪明的同学想到一些简化这一步骤的方式，比如使用 `Style` 来统一指定上面的 `TextBox` 控件的 `Grid.Column`，并省略 `Label` 的 `Grid.Column="0"`。但这样依旧存在相当多的局限性，毕竟它最怕的就是例外情况了。
{{< /notice >}}

所以，我们显然是不能满足于使用这样的方式的。那究竟有什么更好的方式呢？

## 外层使用 UniformGrid

说起“自动化布局”，相信很多人在使用 `Grid` 时都垂涎过 `UniformGrid` 的功能，因为它可以让所有子控件依次填充到每个单元格中。所以，我们或许可以借助它的这一效果，将最外层的 `Grid` 替换为列数为 1 的 `UniformGrid`，这样我们就可以不去声明 `Grid.Row` 属性了。

```xml
<UniformGrid Columns="1">
    <UniformGrid.Resources>
        <Style TargetType="StackPanel">
            <Setter Property="Orientation" Value="Horizontal" />
        </Style>
        <style TargetType="Label">
            <Setter Property="Width" Value="50" />
        </style>
    </UniformGrid.Resources>
    <StackPanel>
        <Label Content="1" />
        <TextBox />
    </StackPanel>
    <StackPanel>
        <Label Content="2" />
        <TextBox />
    </StackPanel>
    <!-- ... -->
</UniformGrid>
```

这里我们将每一行的内容放在了一个 `StackPanel` 中，从而让 `Label` 和 `TextBox` 出现在同一行（或者说 `UniformGrid` 的同一个单元格中）。这样我们就不需要再为每个控件指定 `Grid.Row` 和 `Grid.Column` 了。

为了更加简化代码，我们还声明了两个 `Style`，分别用于设置 `StackPanel` 的 `Orientation` 和 `Label` 的 `Width`。这样我们就可以在 `StackPanel` 中直接放置 `Label` 和 `TextBox`，而不需要再为 `Label` 设置宽度了。

但是这样做有一个明显的局限性：行高是一致的。如果我们需要不同行的高度不一致，那么这种方式就无法满足需求了。

## 外层使用 StackPanel

为了突破上一个方式的局限性，我们可以考虑使用 `StackPanel` 来替代 `UniformGrid`。这样我们就可以为每一行的 `StackPanel` 设置不同的高度了。

```xml
<StackPanel Orientation="Vertical">
    <StackPanel.Resources>
        <!-- Styles -->
    </StackPanel.Resources>
    <StackPanel Height="40">
        <Label Content="1" />
        <TextBox />
    </StackPanel>
    <StackPanel Height="50">
        <Label Content="2" />
        <TextBox />
    </StackPanel>
    <!-- ... -->
</StackPanel>
```

但很快，我们又会被别的问题所折磨：如何高效地设置行间距？

而且可能还有另外一个小折磨：因为内外都使用了 `StackPanel`，所以写的 `Style` 可能会被它们共同使用。

{{< notice info >}}
针对这一问题，可能有同学会将内部的 `StackPanel` 替换为 `WrapPanel`，但这样并不是一个好主意，因为 `WrapPanel` 会让每一行的控件都尽可能地靠左对齐，并且在宽度不够时会自动换行！或许现在看着还好，但调整了窗口或父控件的尺寸，甚至修改了分辨率及缩放后，都有可能让你的界面变得一团糟。
{{< /notice >}}

