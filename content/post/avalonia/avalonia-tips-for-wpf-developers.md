---
title: "分享一些针对 WPF 开发者的 Avalonia 开发技巧"
slug: "avalonia-tips-for-wpf-developers"
description: "Avalonia 在设计上借鉴了 WPF 的许多概念，开发体验来说也有很多相似之处。但 Avalonia 也有其独特之处和最佳实践。本文将分享一些针对 WPF 开发者在使用 Avalonia 时的实用建议，帮助大家更好地适应和利用 Avalonia 的特性，从而提升开发效率和应用性能。"
date: 2025-10-23
tags:
    - dotnet
    - wpf
    - avalonia
    - xaml
---

Avalonia 在设计上借鉴了 WPF 的许多概念，开发体验来说也有很多相似之处。比如 XAML 语法、数据绑定、样式与模板等等，这使得 WPF 开发者能够较快上手 Avalonia。然而，Avalonia 也有其独特之处和最佳实践。如果对这些不够了解，WPF 开发者可能会将一些 WPF 的习惯直接套用到 Avalonia 上，导致代码不够高效或难以维护。

本文将分享一些针对 WPF 开发者在使用 Avalonia 时的实用建议，帮助大家更好地适应和利用 Avalonia 的特性，从而提升开发效率和应用性能。

## 布局控件的改良

### 子控件间距

Avalonia 为一些常用的布局控件提供了方便好用的属性。其中最方便的就是与 `Spacing` 相关的一些属性。在 WPF 中，如果想让控件之间有间距，通常需要使用 `Margin` 属性，导致代码看起来非常冗长：

```xml
<StackPanel Orientation="Horizontal">
    <Button Content="Button 1" Margin="0,0,10,0"/>
    <Button Content="Button 2" Margin="0,0,10,0"/>
    <Button Content="Button 3"/>
</StackPanel>
```

但是在 Avalonia 中，可以直接使用 `Spacing` 属性来设置控件之间的间距，使代码更加简洁：

```xml
<StackPanel Orientation="Horizontal" Spacing="10">
    <Button Content="Button 1"/>
    <Button Content="Button 2"/>
    <Button Content="Button 3"/>
</StackPanel>
```

除了 `StackPanel`，`WrapPanel`、`Grid` 和 `UniformGrid` 也支持 `Spacing` 属性。具体来说：

- `StackPanel`：
  - `Spacing`：设置子项之间的间距
- `WrapPanel`：
  - `ItemSpacing`：设置子项之间的间距
  - `LineSpacing`：设置行之间的间距
  - `ItemsAlignment`：设置整行（或列，取决于方向）的对齐方式
- `Grid` 与 `UniformGrid`：
  - `RowSpacing`：设置行之间的间距
  - `ColumnSpacing`：设置列之间的间距

使用这些属性可以让布局代码更加简洁易读，避免了大量的 `Margin` 设置。

### `Grid` 控件

在 Avalonia 中，`Grid` 也迎来了一些开发体验的优化。除了上面提到的 `RowSpacing` 和 `ColumnSpacing` 属性外，`Grid` 还支持 `RowDefinitions` 和 `ColumnDefinitions` 的简化语法。我们现在可以用字符串的形式来快速定义行和列：

```xml
<Grid ColumnDefinitions="Auto,*,100">
    <!-- WPF 的做法 -->
    <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="100"/>
    </Grid.RowDefinitions>
</Grid>
```

{{< notice tip >}}
如果需要操作这些 `Definition`，比如在运行时动态调整它们的可见性、尺寸等，那我们仍然需要使用传统的方式来定义。
{{< /notice >}}

此外，如果我们的布局要求非常简单，比如并不会用到行与列，只是简单地将子控件堆叠在一起，最多是借助它们的 `Alignment` 属性来调整位置，那么我们可以使用更加轻量的 `Panel` 控件来替代 `Grid`，以提升性能。而 WPF 因为缺乏这样的轻量级容器，往往会过度使用 `Grid`，导致性能下降。也因此，不少第三方控件库提供了诸如 `SimplePanel` 之类的轻量级容器来弥补这一缺陷。

## 集合类型

在 WPF 中，我们都知道，如果想要让前台的 `ItemsControl`（及其子类，如 `ListBox`、`ComboBox` 等）能够响应集合的变化，我们需要使用 `ObservableCollection<T>` 作为数据源，因为它实现了 `INotifyCollectionChanged` 接口，能够在集合发生变化时通知 UI 更新。

而在 Avalonia 中，我们可以考虑使用它提供的 `AvaloniaList<T>` 作为集合类型。简单来说，`AvaloniaList<T>` 提供了以下几条额外的功能：

1. 可以设置 `ResetBehavior` 属性来控制集合被清空时触发的是 `NotifyCollectionChangedAction.Reset` 还是 `Remove`：`Reset` 仅通知，但事件参数不包含具体删除了哪些元素，而 `Remove` 则会包含被删除的元素列表
2. 提供了 `Validate` 方法，可以在添加元素时进行验证
3. 提供了 `AddRange` 和 `RemoveRange` 方法，可以一次性添加或移除多个元素

这些新功能可以说是显著提升了 `ObservableCollection<T>` 的使用体验。

Avalonia 还提供了 `AvaloniaDictionary<,>`，它是一个具备通知功能的字典类型。WPF 因为缺乏类似 `ObservableDictionary<,>` 的类型，往往需要开发者自行实现，而 Avalonia 则直接提供了现成的解决方案供我们使用。

此外，对于 `DataGrid` 控件，Avalonia 还提供了 `DataGridCollectionView`，它是一个支持排序、过滤、分组等功能的集合视图类型，可以大大提高数据展示的灵活性。在 11.3.x 版本的 Avalonia 中，它被迁移到了 `Avalonia.Controls.DataGrid` 包中，方便我们单独引用。

## 值转换器

在 WPF 中，我们常常需要与值转换器（`IValueConverter`）打交道，以便在数据绑定时对数据进行转换。WPF 原生几乎只提供了一个我们用得上的转换器——`BooleanToVisibilityConverter`。其他的转换器通常需要我们自己实现。这同时也因为 WPF 的绑定语法不够灵活，导致连一个简单的布尔值取反都需要我们自己写转换器。

而在 Avalonia 中，情况则大不相同。甚至可以说，在遇到看似需要我们写值转换器的场景时，我们应该先考虑是否可以通过 Avalonia 提供的内置功能来实现，并且很多时候都是可以的。

### 内置转换器

Avalonia 提供了丰富的内置值转换器，涵盖了常见的转换需求。比如：

- `BoolConverters`
  - 提供了一些多值转换器（`IMultiValueConverter`），如 `AndConverter`、`OrConverter` 等，可用于 `MultiBinding`
  - 提供了布尔值的取反转换器 `NotConverter`，但通常可以用绑定表达式的特殊语法来实现
- `StringConverters`
  - 提供了一些与字符串有关的转换器，如 `IsNullOrEmpty`、`IsNullOrWhiteSpace` 等
- `ObjectConverters`
  - 提供了一些与对象有关的转换器，如 `IsNull`、`IsNotNull`、`Equal`、`NotEqual` 等

运用这些内置的转换器，我们可以轻易实现很多常见的需求，比如：

```xml
<!-- 只有当所有开关都打开时，提交按钮才可用 -->
<ToggleSwitch x:Name="Toggle1" />
<ToggleSwitch x:Name="Toggle2" />
<ToggleSwitch x:Name="Toggle3" />
<Button Content="Submit">
    <Button.IsEnabled>
        <MultiBinding Converter="{x:Static BoolConverters.AndConverter}">
            <Binding ElementName="Toggle1" Path="IsChecked"/>
            <Binding ElementName="Toggle2" Path="IsChecked"/>
            <Binding ElementName="Toggle3" Path="IsChecked"/>
        </MultiBinding>
    </Button.IsEnabled>
</Button>

<ListBox x:Name="MyListBox" />
<TextBlock IsVisible="{Binding #MyListBox.SelectedItem, Converter={x:Static ObjectConverters.IsNotNull}}">
    An item is selected
</TextBlock>
```

### 绑定表达式

Avalonia 的绑定表达式语法也比 WPF 更加灵活强大。我们可以在绑定路径中直接使用一些特殊的语法来实现简单的转换需求，而无需借助值转换器。 

比如：

```xml
<!-- 布尔值取反 -->
<ToggleSwitch x:Name="MyToggle" />
<TextBlock IsVisible="{Binding #MyToggle.IsChecked, Path=!}">
    The toggle is off
</TextBlock>

<!-- 字符串不为空 -->
<TextBox x:Name="MyTextBox" />
<TextBlock IsVisible="{Binding !!#MyTextBox.Text}">
    Text is not empty
</TextBlock>
```

通过这些内置的转换器和灵活的绑定表达式语法，我们可以大大减少自定义值转换器的编写，从而简化代码，提高开发效率。

### 函数值转换器

如果上面的这些方式还不能满足，那么或许依然不必急于去写值转换器。Avalonia 还提供了函数值转换器（`FuncValueConverter`），它允许我们快速地在后台代码中定义一个转换函数，并将其直接用于绑定中，而无需创建一个完整的转换器类。

```csharp
public class MyViewModel
{
    public static FuncValueConverter<string, bool> StringToBoolConverter { get; }
        = new(str => !string.IsNullOrEmpty(str));
}
```

```xml
<TextBox x:Name="MyTextBox" />
<TextBlock IsVisible="{Binding #MyTextBox.Text, Converter={x:Static local:MyViewModel.StringToBoolConverter}}">
    Text is not empty
</TextBlock>
```

通过这种方式，我们可以快速地实现一些简单的转换逻辑，而无需编写冗长的转换器类，从而提高开发效率。如果希望传入参数（`ConverterParameter`），它还有一个 `FuncValueConverter<TIn, TParam, TOut>` 的重载版本，可以满足这一需求。此外，我们还有 `FuncMultiValueConverter` 可供使用，适用于多值绑定的场景。

但需要注意，这种方式存在一定局限性：它只支持正向转换（`Convert` 方法），不支持反向转换（`ConvertBack` 方法）。因此，如果需要更复杂的转换逻辑，仍然需要编写完整的值转换器类。

## xmlns 命名空间

在 WPF 中，如果我们想要引入一个程序集中的控件或类型，通常需要在 XAML 文件的开头使用 `xmlns` 声明一个命名空间，并指定程序集名称：

```xml
<Window xmlns:md="http://materialdesigninxaml.net/winfx/xaml/themes"
        xmlns:local="clr-namespace:MyApp.Controls"
        xmlns:classlib="clr-namespace:ClassLibrary.Controls;assembly=ClassLibrary" />
```

如果在当前程序集，那么我们只需要 `clr-namespace` 即可；如果是其他程序集，则需要加上 `assembly` 部分。

这样的方式在 Avalonia 中同样适用，但 Avalonia 还提供了更加简洁的 `using` 语法，允许我们直接使用程序集名称来引入命名空间：

```xml
<Window xmlns:md="http://materialdesigninxaml.net/winfx/xaml/themes"
        xmlns:local="using:MyApp.Controls"
        xmlns:classlib="using:ClassLibrary.Controls" />
```

另外，Avalonia 的默认 `x` 命名空间也为我们提供了不少便利。在 WPF 中，如果我们想在 XAML 中使用一些常见的类型，比如 `String`、`Int32`、`Boolean` 等，通常需要显式地引入 `System` 命名空间：

```xml
<Window xmlns:sys="clr-namespace:System;assembly=mscorlib">
    <Window.Resources>
        <sys:String x:Key="MyString">Hello, World!</sys:String>
        <sys:Int32 x:Key="MyInt">42</sys:Int32>
        <sys:Boolean x:Key="MyBool">True</sys:Boolean>
    </Window.Resources>
</Window>
```

{{< notice tip >}}
对于 .NET Framework 项目，我们必须引入 `mscorlib` 程序集；而对于 .NET 5+ 项目，我们还将多一些选择，比如：

- `System.Core`
- `System.Runtime`
- `netstandard`
{{< /notice >}}

而在 Avalonia 中，我们可以直接使用 `x` 命名空间来引用这些常见类型，无需额外的 `xmlns` 声明：

```xml
<Window>
    <Window.Resources>
        <x:String x:Key="MyString">Hello, World!</x:String>
        <x:Int32 x:Key="MyInt">42</x:Int32>
        <x:Boolean x:Key="MyBool">True</x:Boolean>
    </Window.Resources>
</Window>
```

## 结语

本文介绍了一些针对 WPF 开发者在使用 Avalonia 时的实用建议。通过了解和运用这些 Avalonia 的特性和最佳实践，WPF 开发者可以更好地适应 Avalonia 的开发环境，从而提升开发效率和应用性能。

我们在使用 Avalonia 时，应该充分利用其提供的丰富功能和灵活语法，避免简单地将 WPF 的习惯直接套用到 Avalonia 上。希望本文的内容能够帮助大家更好地理解和使用 Avalonia，打造出高质量的跨平台应用程序。
