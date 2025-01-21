---
title: "如何在 WPF 中高效布局多行多列的控件"
slug: "grid-of-controls"
description: "探讨一个 WPF 中的简单而又不简单的布局问题：如何高效地实现多行多列的控件布局？"
image: https://s2.loli.net/2024/12/26/kgGyXcYIlnMNpSr.jpg
date: 2024-12-26
tags:
    - dotnet
    - csharp
    - wpf
---

这次我们来探讨一个 WPF 中的简单而又不简单的布局问题：如何实现下图中的效果？

{{< figure src="https://s2.loli.net/2024/12/25/qlpQr1DJ4FBskKe.png" width="400px" >}}

为什么说这个问题简单而又不简单呢？是因为单纯只是实现这个效果的话，我们完全可以使用 `Grid` 控件来实现。~~甚至如果完全不在乎优雅的话，我们还可以用 `Canvas` 来实现~~（当然这几乎在任何情况下都是不推荐的）。但是，实际这样干过的开发者相信都很清楚，使用 `Grid` 的实现方式几乎可以说是毫无灵活性的。很快就会被后续的界面微调的需求整得焦头烂额。

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

说起“自动化布局”，相信很多人在使用 `Grid` 时都垂涎过 `UniformGrid` 的功能，因为它可以让所有子控件依次填充到每个单元格中。所以，我们或许可以借助它的这一效果。比如我们想要一个两列的网格，可以：

```xml
<UniformGrid Columns="2">
    <Label Content="1" />
    <TextBox />
    <Label Content="2" />
    <TextBox />
    <!-- ... -->
```

但这样的局限性在于，所有子控件的大小（或者它们所处的单元格）都是完全等大的。这可能会失去灵活性，并且看起来有些呆板。那么我们还可以部分借助 `UniformGrid` 的功能，比如下面这样：

```xml
<UniformGrid Columns="1">
    <UniformGrid.Resources>
        <Style TargetType="StackPanel">
            <Setter Property="Orientation" Value="Horizontal" />
        </Style>
        <Style TargetType="Label">
            <Setter Property="Width" Value="50" />
        </Style>
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

此时，我们可以请个“外援”。其实在 Win UI 3、Avalonia UI 等框架中，`StackPanel` 天生就比 WPF 多了一个属性：`Spacing`。这个属性可以让我们很方便地设置行间距。但是在 WPF 中，我们就没有这么幸运了。不过，我们可以借助自定义控件来实现这一功能。

代码也不用我们自己写，网上可以找到一些开源实现。比如这里我贴两个供大家参考：

- [Kinnara/ModernWpf - SimpleStackPanel](https://github.com/Kinnara/ModernWpf/blob/master/ModernWpf/Controls/SimpleStackPanel.cs)
- [OrgEleCho/WpfSuite - StackPanel](https://github.com/OrgEleCho/EleCho.WpfSuite/blob/master/EleCho.WpfSuite.Layouts/Layouts/StackPanel.cs)

假如我们搬运到了 `local` 命名空间下，那么我们就可以这样使用：

```xml
<local:StackPanel Spacing="10">
    <local:StackPanel.Resources>
        <Style TargetType="StackPanel">
            <Setter Property="Orientation" Value="Horizontal" />
        </Style>
    </local:StackPanel.Resources>
    <StackPanel>
        <Label Content="1" />
        <TextBox />
    </StackPanel>
    <StackPanel>
        <Label Content="2" />
        <TextBox />
    </StackPanel>
    <!-- ... -->
</local:StackPanel>
```

这样看起来就方便多了。此外，我们还有一些小技巧，来进一步提高布局的效率：

1. 为 `Label` 设置一个固定的宽度，这样可以让所有的 `Label` 对齐
2. 为 `Label` 设置 `VerticalAlignment` 或 `VerticalContentAlignment` 为 `Center`，这样可以让 `Label` 和 `TextBox` 垂直居中对齐
3. 为 `TextBox` 等控件（还比如 `CheckBox`、`ComboBox` 等）设置固定的宽度，这样可以让所有的 `TextBox` 对齐

## 使用更高级的 Grid

上面的方式其实已经相当灵活了，尤其是对于可能需要增删、调换顺序之类的情形。但是可能仍然会觉得不够爽，因为里面多出了一层 `StackPanel`，这写起来就还是会觉得不太爽。

所以，有没有办法让 `Grid` 更加智能一点，比如可以像是 `WrapPanel` 或者 `UniformGrid` 那样，自动填充控件呢？

答案当然是有的。这里给大家推荐一个 NuGet 包：`WpfAutoGrid`。这个 `AutoGrid` 就正是我们梦寐以求的控件。

{{< notice info >}}
NuGet 上有好多个叫这个名字的包。这里我贴一个自己试过的：[`WpfAutoGrid.Core`](https://github.com/budul100/WpfAutoGrid.Core)
{{< /notice >}}

它的使用也非常简单：

```xml
<local:AutoGrid Columns="100,150" RowCount="8" RowHeight="30">
    <Label Content="1" />
    <TextBox />
    <Label Content="2" />
    <TextBox />
    <!-- ... -->
</local:AutoGrid>
```

这样我们连内部的 `StackPanel` 都不需要了，直接将 `Label` 和 `TextBox` 放在 `AutoGrid` 中即可。此外，它提供了很多实用的属性，比如上面实用的 `Columns`、`RowCount`、`RowHeight`，还有 `ColumnSpacing`、`RowSpacing` 等。不仅如此，`AutoGrid` 还能正确响应子控件 `ColumnSpan` 等属性，可以让我们更加灵活地布局控件。

除此之外，这里我再贴一个我自己写的 `GridAssist`。它是一个附加属性，可以直接用于原生的 `Grid` 控件。使用这个附加属性，就能够自动为子控件添加 `Grid.Row` 和 `Grid.Column` 属性。

[BYJRK/GridAssist](https://gist.github.com/BYJRK/66aefb80c838634e0642ffed4f58e076)

使用方式也非常简单：

```xml
<Grid local:GridAssist.AutoRowColumn="_,2">
    <Label Content="1" />
    <TextBox />
    <Label Content="2" />
    <TextBox />
    <!-- ... -->
</Grid>
```

这个附加属性的 `AutoRowColumn` 填写的 `_,2` 意思是，行数自动增加，列数固定为 2（还可以写 `_,2,Auto`，从而将列宽设置为 `Auto`）。这样我们就不需要为每个控件指定 `Grid.Row` 和 `Grid.Column` 了。然后，我们只需要将子控件按照从上到下，从左到右的顺序放置即可，不需要再引入一层 `StackPanel` 了。此外，它也是可以正确响应 `Grid.ColumnSpan` 的。

## 总结

在 WPF 中，布局是一个非常重要的问题。而对于多行多列的控件布局，我们可以使用 `Grid`、`UniformGrid`、`StackPanel`、`AutoGrid` 等控件或者附加属性来实现。每一种方式都有它的优势和局限性，我们可以根据实际情况来选择最适合的方式。

另外，对于上面提到的几种自定义控件或附加属性，我们完全可以直接将代码复制到自己的项目中，然后根据实际需求进行修改。这样可以更好地适应自己的项目，也可以更好地理解这些控件或属性的实现原理，还可以省去引入第三方库的麻烦。
