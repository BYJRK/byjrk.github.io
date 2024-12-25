---
title: "WPF 值转换器（ValueConverter）的一些实用技巧"
slug: "valueconverter-tips-and-tricks"
description: "在这篇文章中，我们会介绍 WPF 的值转换器的一些实用技巧，相信一定可以帮助大家更好地使用值转换器，提高开发效率。"
image: https://s2.loli.net/2024/12/18/dRbx2KJsHOmaPG7.webp
date: 2024-12-18
tags:
    - dotnet
    - csharp
    - wpf
---

本篇文章对应的教学视频链接：[WPF中值转换器（ValueConverter）的一些实用技巧](https://www.bilibili.com/video/BV1ThkHYnEgi)

在 WPF 中，值转换器（`ValueConverter`）是一个非常重要的概念。它可以帮助我们在绑定数据时，将数据转换成我们需要的格式。在这篇文章中，我们将介绍一些值转换器的实用技巧。

## 使用 WPF 内置的值转换器

WPF 内置了几个常用的值转换器，我们可以直接使用。例如，我们可以使用 `BooleanToVisibilityConverter` 将布尔值转换成 `Visibility` 枚举值。

```xml
<Window.Resources>
    <BooleanToVisibilityConverter x:Key="BooleanToVisibilityConverter"/>
</Window.Resources>

<StackPanel>
    <CheckBox x:Name="checkBox" Content="Show Text" IsChecked="True"/>
    <TextBlock Text="Hello, World!" Visibility="{Binding ElementName=checkBox, Path=IsChecked, Converter={StaticResource BooleanToVisibilityConverter}}"/>
</StackPanel>
```

遗憾的是，WPF 内置的值转换器并不是很多，基本上我们能直接用上的就是上面提到的这个 `BooleanToVisibilityConverter`。其他虽然有一些照理说用得上的值转换器，但它们很多都是 `internal` 的，我们无法直接使用。即便如此，通过阅读它们的源代码，我们仍然可以学习一下它们的实现方式。比如：

- [`EnumBoolConverter`](https://source.dot.net/#Microsoft.VisualStudio.LanguageServices/Utilities/EnumBoolConverter.cs)
- [`BooleanReverseConverter`](https://source.dot.net/#Microsoft.VisualStudio.LanguageServices/Utilities/BooleanReverseConverter.cs)

## 将值转换器声明为单例

使用值转换器有些是否会让人觉得繁琐，因为通常这意味着我们需要在某个控件的 `Resources` 中声明一个值转换器，并在需要的地方通过 `StaticResource` 来引用它。但实际上，我们可以将值转换器声明为单例，这样就可以在任何地方直接使用它。比如：

```csharp
public class BooleanToVisibilityConverter : IValueConverter
{
    // 单例模式
    public static BooleanToVisibilityConverter Instance { get; } = new();

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        // ...
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        // ...
    }
}
```

然后我们就可以在 XAML 中借助 `x:Static` 来直接使用这个单例：

```xml
<StackPanel>
    <CheckBox x:Name="checkBox" Content="Show Text" IsChecked="True"/>
    <TextBlock Text="Hello, World!" Visibility="{Binding ElementName=checkBox, Path=IsChecked, Converter={x:Static local:BooleanToVisibilityConverter.Instance}}"/>
</StackPanel>
```

{{< notice warning >}}
这样确实可以一定程度上简化我们的代码，但也要注意，这样做可能会导致值转换器的状态被共享，从而引发一些问题。所以在使用这种方式时，一定要确保值转换器是无状态的。
{{< /notice >}}

## 将值转换器声明在 App.xaml 中

如果我们有一些相当**通用且无状态**的值转换器，就比如 `BooleanToVisibilityConverter`、`BoolReverseConverter`、`NotNullConverter` 等，我们可以将它们声明在 `App.xaml` 中，这样就可以在整个应用程序中直接使用这些值转换器，而不需要在每个用到它们的 `Window`、`UserControl` 等地方都进行声明。

```xml
<Application ...>
    <Application.Resources>
        <BooleanToVisibilityConverter x:Key="BooleanToVisibilityConverter"/>
        <BoolReverseConverter x:Key="BoolReverseConverter"/>
        <NotNullConverter x:Key="NotNullConverter"/>
    </Application.Resources>
</Application>
```

如果觉得这样的方式会“污染”`App.xaml`，我们也可以新建一个 `ResourceDictionary`，并将这些值转换器声明在这个 `ResourceDictionary` 中，然后在 `App.xaml` 中引用这个 `ResourceDictionary`。例如，我们可以新建一个 `CommonConverters.xaml`：

```xml
<ResourceDictionary ...>
    <BooleanToVisibilityConverter x:Key="BooleanToVisibilityConverter"/>
    <BoolReverseConverter x:Key="BoolReverseConverter"/>
    <NotNullConverter x:Key="NotNullConverter"/>
</ResourceDictionary>
```

然后在 `App.xaml` 中引用这个 `ResourceDictionary`：

```xml
<Application ...>
    <Application.Resources>
        <ResourceDictionary>
            <ResourceDictionary.MergedDictionaries>
                <ResourceDictionary Source="CommonConverters.xaml"/>
            </ResourceDictionary.MergedDictionaries>
        </ResourceDictionary>
    </Application.Resources>
</Application>
```

## 使用 `MarkupExtension` 简化值转换器的使用

`Markup` 语法也就是我们经常在 XAML 中看到的“花括号”语法，例如：

- `{Binding ...}`
- `{StaticResource ...}`
- `{x:Static ...}`

只要我们让值转换器继承 `MarkupExtension`，我们就可以在 XAML 中直接使用 `Markup` 语法来引用这个值转换器。比如：

```csharp
public class BooleanToVisibilityConverter : MarkupExtension, IValueConverter
{
    public bool IsReversed { get; set; }

    public bool UseHidden { get; set; }

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is bool b)
        {
            b = IsReversed ? !b : b;
            return b ? Visibility.Visible : (UseHidden ? Visibility.Hidden : Visibility.Collapsed);
        }
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is Visibility visibility)
        {
            return visibility == Visibility.Visible;
        }
    }

    public override object ProvideValue(IServiceProvider serviceProvider)
    {
        return this;
    }
}
```

上面是一个“高级版”的 `BooleanToVisibilityConverter`，它支持 `IsReversed` 和 `UseHidden` 两个属性，也就为这一值转换器提供了定制性。我们可以在 XAML 中这样使用它：

```xml
<StackPanel>
    <CheckBox x:Name="checkBox" Content="Show Text" IsChecked="True"/>
    <TextBlock Text="Hello, World!" Visibility="{Binding ElementName=checkBox, Path=IsChecked, Converter={local:BooleanToVisibilityConverter IsReversed=True, UseHidden=True}}"/>
</StackPanel>
```

这一技巧尤其适用于某个定制功能强大，且使用频率较高的值转换器。但也要注意，这样声明就会导致值转换器每次都会实例化一个新的出来。如果一个值转换器是无状态的，那么我们最好将其声明为单例，或者将其声明在 `App.xaml` 中，从而避免重复实例化。

如果还觉得不过瘾，我们可以为值转换器写一个抽象基类，从而进一步简化值转换器的实现。比如：

```csharp
public abstract class BaseValueConverter : MarkupExtension, IValueConverter
{
    public override object ProvideValue(IServiceProvider serviceProvider)
    {
        return this;
    }

    public abstract object Convert(object value, Type targetType, object parameter, CultureInfo culture);

    public virtual object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return Binding.DoNothing;
    }
}
```

另外还有一种版本，就是希望基类还顺便提供单例模式，那么我们可以这样：

```csharp
public abstract class BaseValueConverter<T> : MarkupExtension, IValueConverter
    where T : class, new()
{
    public static T Instance { get; } = new();

    // ...
}
```

然后我们就可以使用它了。比如说我们希望实现一个单向的值转换器，将字符串转换成大写，可以这样：

```csharp
public class StringToUpperConverter : BaseValueConverter<StringToUpperConverter>
{
    public override object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is string s)
        {
            return s.ToUpper();
        }

        return Binding.DoNothing;
    }
}
```

是不是瞬间变得简单了很多呢？

## 返回 DoNothing 与 UnsetValue

在 WPF 中，有两个特殊的返回类型，分别是 `Binding.DoNothing` 和 `DependencyProperty.UnsetValue`。在某些情况下，让值转换器的方法返回这两个值是非常有用的。

这两个都表示“不做任何事情”，但它们的使用场景是不同的。具体来说，`Binding.DoNothing` 单纯意味着“不做任何事情”，不去通知任何绑定源或目标，也不会更新界面；而 `DependencyProperty.UnsetValue` 则暗示绑定是失败的，或者值是无效的。此时，它会触发 `Binding` 的 `FallbackValue`，也就是俗称的“缺省值”。

比如我们有一个可以让用户输入文件路径的文本框，并且我们会让另一个 `TextBlock` 展示这个文件的名称。但是如果用户输入的路径是无效的，我们就不希望展示这个文件的名称，而是展示一个缺省值，这时我们就可以使用 `DependencyProperty.UnsetValue`：

```csharp
public class FilePathToFileNameConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is string path &&n File.Exists(path))
        {
            return Path.GetFileName(path);
        }
        return DependencyProperty.UnsetValue;
    }
}
```

然后我们可以在 XAML 中这样使用：

```xml
<StackPanel>
    <TextBox x:Name="textBox" Text="C:\Users\Public\Documents\file.txt"/>
    <TextBlock Text="{Binding ElementName=textBox, Path=Text, Converter={local:FilePathToFileNameConverter}, FallbackValue='Invalid File Path'}"/>
</StackPanel>
```

这样，当用户输入的文件路径无效时，`TextBlock` 就会展示“Invalid File Path”。

类似地，如果我们希望用户在输入无效的文件路径时，不做任何事情（比如保留上次有效的文件名城），我们就可以返回 `Binding.DoNothing`。然后就可以实现相应的效果了。

这两个特殊的返回值看似不起眼，但是如果上述功能让我们在 ViewModel 中去实现，就会变得非常繁琐。所以在这种情况下，值转换器就显得非常有用了。

## 借助 CultureInfo 实现多语言支持

值转换器中的两个方法都有一个 `CultureInfo` 类型的参数，我们可以利用这个参数来实现多语言支持。比如我们有一个值转换器，将数字转换成各国语言的数字。此时我们就可以在值转换器中根据 `CultureInfo` 所包含的地区码来选择合适的语言。

```csharp
public class NumberToLocalizedNumberConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is int number)
        {
            switch (culture.TwoLetterISOLanguageName)
            {
                case "zh":
                    return number switch
                    {
                        0 => "零",
                        1 => "一",
                        2 => "二",
                        3 => "三",
                        4 => "四",
                        5 => "五"
                    };
                case "en":
                    return number switch
                    {
                        0 => "Zero",
                        1 => "One",
                        2 => "Two",
                        3 => "Three",
                        4 => "Four",
                        5 => "Five"
                    };
                default:
                    return number.ToString();
            }
        }

        return Binding.DoNothing;
    }
}
```

然后我们可以在 XAML 中这样使用：

```xml
<StackPanel>
    <TextBlock Text="{Binding Number, Converter={local:NumberToLocalizedNumberConverter}, ConverterCulture=zh-CN}"/>
</StackPanel>
```

或者我们也可以在程序中动态地设置 `CultureInfo`：

```csharp
var culture = new CultureInfo("zh-CN");

Thread.CurrentThread.CurrentCulture = culture;
Thread.CurrentThread.CurrentUICulture = culture;
```

但是这样还不够，因为值转换器的这一入参是从控件的 `Language` 属性中继承而来的。所以我们还需要修改全局的 `Language` 属性。例如，我们想在一个 `UserControl` 中使用中文，可以这样：

```xml
<UserControl Language="zh-CN">
    <!-- 也可以这样写 -->
    <UserControl.Language>
        <XmlLanguage>zh-CN</XmlLanguage>
    </UserControl.Language>
</UserControl>
```

或者，我们还可以用 `OverrideMetadata` 的方式来修改全局的 `Language` 属性：

```csharp
FrameworkElement.LanguageProperty
    .OverrideMetadata(
        typeof(FrameworkElement),
        new FrameworkPropertyMetadata(
            XmlLanguage.GetLanguage(CultureInfo.CurrentCulture.IetfLanguageTag)
        )
    );
```

这样就可以让值转换器获取到当前的 `CultureInfo`，从而实现多语言支持。

## 仿照 Avalonia UI 实现一个 FuncValueConverter

Avalonia UI 中有一个有趣的 `FuncValueConverter`，它允许我们直接在代码后台简单地声明一个值转换器，而不需要额外写一个类。它地源代码可以在 [GitHub](https://github.com/AvaloniaUI/Avalonia/blob/38e839997d2c204548e6fad396c178780a010cb1/src/Avalonia.Base/Data/Converters/FuncValueConverter.cs) 上看到。我们可以仿照这个实现一个类似的值转换器。

```csharp
public sealed class FuncValueConverter<TIn, TOut> : IValueConverter
{
    private readonly Func<TIn, TOut> _convert;

    public FuncValueConverter(Func<TIn, TOut> convert)
    {
        _convert = convert;
    }

    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is TIn t)
        {
            return _convert(t);
        }

        return Binding.DoNothing;
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        return Binding.DoNothing;
    }
}
```

对于 `Convert` 方法的实现，这里还有一种更好的方式。我们都知道，在 XAML 书写的很多资源，WPF 都会在底层帮我们进行合适的类型转换。比如我们将 `"1"` 字符串赋值给一个 `int` 类型的属性，WPF 会自动将其转换成 `1`；我们将 `"Visible"` 字符串赋值给一个 `Visibility` 枚举类型的属性，WPF 也会进行相应的转换。如果我们不提供这个功能，那么我们写的这个 `FuncValueConverter` 就会变得不够灵活。因此，我们可以借助 .NET 原生的 `TypeDescriptor` 类来实现这个功能。

```csharp
public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
{
    if (value is not TIn t)
    {
        if (value is null)
        {
            return default(TOut);
        }

        if (TypeDescriptor.GetConverter(typeof(TIn)).CanConvertFrom(value.GetType()))
        {
            t = (TIn)TypeDescriptor.GetConverter(typeof(TIn)).ConvertFrom(value);
        }
        else
        {
            return Binding.DoNothing;
        }
    }

    return _convert(t);
}
```

这样我们就可以声明并使用了。我们需要将它声明为静态属性：

```csharp
public class MainViewModel : ViewModelBase
{
    public static FuncValueConverter<string, int> StringToIntConverter { get; } = new(s => int.Parse(s));
}
```

然后我们就可以在 XAML 中这样使用：

```xml
<StackPanel>
    <TextBox x:Name="textBox" Text="123"/>
    <TextBlock Text="{Binding ElementName=textBox, Path=Text, Converter={x:Static local:MainViewModel.StringToIntConverter}}"/>
</StackPanel>
```

这样，我们就能够轻易地在代码后台声明一个值转换器了。

## 其他第三方库

除了上面提到的这些方法，我们还可以使用一些第三方库来简化值转换器及绑定的使用。比如：

- [ValueConverters.NET](https://github.com/thomasgalliker/ValueConverters.NET)
- [CalcBinding](https://github.com/Alex141/CalcBinding)
- [CompiledBindings](https://github.com/levitali/CompiledBindings)

这些库有的提供了丰富的内置值转换器，包括组合多种值转换器的功能（例如先将字符串根据 `IsNullOrEmpty` 转为 `bool` 类型，再转为 `Visibility` 类型），有的提供了更加强大的绑定功能，例如可以调用函数，进行数学运算等等。大家有兴趣的话可以去了解一下。

## 总结

值转换器是 WPF 中非常重要的一个概念，它可以帮助我们将数据转换成我们需要的格式。在这篇文章中，我们介绍了一些值转换器的实用技巧。希望这些技巧能够帮助大家更好地使用值转换器。

只有充分发挥 WPF 中各个功能的优势，我们才能更好地提高我们的开发效率，实现更加复杂的功能。希望大家能够在实际的开发中多多尝试，多多实践。
