---
title: "WPF 中的 Name 与 x:Name 究竟是什么区别？"
slug: "wpf-name-vs-xname"
description: 在 WPF 开发中，可以给控件添加 Name 或 x:Name 属性。那么这二者究竟是什么区别呢？本文就来简单探讨一下。
image: https://s2.loli.net/2024/10/11/jurJoLAN3aWBgZ6.png
date: 2024-10-10
tags:
    - dotnet
    - wpf
---

在 WPF 开发中，我们可以给控件添加 `Name` 或 `x:Name` 属性。这样做的目的通常是希望在代码后台能够访问这个控件，或者我们在写 `Binding` 表达式时，希望使用 `ElementName` 的方式绑定某个控件。那么这二者究竟是什么区别呢？本文就来简单探讨一下。

## 本质不同，但却又几乎相同

别的暂且不谈，我们只关注 XML 文档的命名空间，不难发现 `Name` 和 `x:Name` 的区别在于前者没有命名空间，而后者有一个 `x` 命名空间。具体来说，通常我们的一个 XAML 文件的根元素是这样的：

```xml
<Window x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MainWindow" Height="450" Width="800">
    <!-- 省略其他内容 -->
</Window>
```

其中，`xmlns` 是默认的命名空间，而 `xmlns:x` 是 `x` 命名空间。所以，`x:Name` 和 `Name` 分别出自哪个命名空间，就不言而喻了。

但是，虽然它们两个出身不同，但在 WPF 中，它们的作用几乎是一样的。具体来说，`Name` 是 [`FrameworkElement` 类](https://source.dot.net/#PresentationFramework/System/Windows/FrameworkElement.cs,3213)（以及 [`FrameworkContentElement` 类](https://source.dot.net/#PresentationFramework/System/Windows/FrameworkContentElement.cs,834)，下略）的一个依赖属性，形如（为便于阅读，代码略有删改）：

```c#
[CommonDependencyProperty]
public static readonly DependencyProperty NameProperty =
            DependencyProperty.Register(
                        "Name",
                        typeof(string),
                        typeof(FrameworkElement),
                        new FrameworkPropertyMetadata(/* ... */);

[Localizability(LocalizationCategory.NeverLocalize)]
[MergableProperty(false)]
[DesignerSerializationOptions(DesignerSerializationOptions.SerializeAsAttribute)]
public string Name
{
    get { return (string) GetValue(NameProperty); }
    set { SetValue(NameProperty, value);  }
}
```

而进一步观察 [`FrameworkElement` 类的声明](https://source.dot.net/#PresentationFramework/System/Windows/Generated/FrameworkElement.cs,30)，我们可以发现：

```c#
namespace System.Windows
{
    [RuntimeNamePropertyAttribute("Name")]
    public partial class FrameworkElement
    {
        // ...
    }
}
```

这里的 `RuntimeNamePropertyAttribute` 是一个特性，它告诉 WPF 运行时，`FrameworkElement` 类的 `Name` 属性将会被转为 `x:Name` 属性。所以，`Name` 和 `x:Name` 在 WPF 中几乎是一样的。

至于为什么要这样设计，我并没有找到官方的答案。唯一合理的猜测，就是想给开发者一个较为方便的方式去给控件命名。毕竟，`Name` 比 `x:Name` 看起来更简洁，更加直观（毕竟这看起来就是属于控件自己的名字一样），而且还不需要使用命名空间。

## x:Name 本质上意味着什么？

那么，既然二者并没有多少区别，我们现在就来看一看 `x:Name` 到底意味着什么。在 XAML 中，当我们给控件添加 `x:Name` 属性时，实际上是在告诉 XAML 解析器，这个控件的名字是什么。并且相信大家都知道，拥有了名字的控件，它就会变成类的字段，我们可以在代码后台通过这个名字来访问它。

具体来说，以 `Window` 为例，我们会发现后台代码是一个分部类。在我们看不到的地方，XAML 解析器会生成一个类。这个类中就有我们最熟悉的在构造函数中调用的 `InitializeComponent` 方法，以及我们在 XAML 中添加了 `Name` 的控件所对应的字段。例如，我们在 XAML 中这样写：

```xml
<Window x:Class="WpfApp1.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MainWindow" Height="450" Width="800">
    <Button x:Name="button1" Content="Click Me" />
    <Button x:Name="button2" x:FieldModifier="private" Content="Click Me" />
</Window>
```

那么，我们就能在后台生成的代码（文件名类似 `MainWindow.g.i.cs`）中找到这样的内容（我们可以在后台随便一个地方访问这个字段，然后用 IDE 的跳转到定义的方式找到后台生成的代码）：

```c#
public partial class MainWindow : // ...
{
    internal System.Windows.Controls.Button button1;
    private System.Windows.Controls.Button button2;
}
```

此外，如果 XAML 中的一个控件拥有了 `Name`，我们还可以实现一些别的事情。包括但不限于：

1. 在 `Binding` 表达式中使用 `ElementName` 来绑定这个控件；
2. 在 `Storyboard` 中使用 `TargetName` 来指定这个控件；
3. 在后台代码中使用 `FindName` 方法来查找这个控件。

## 总结

本文简单介绍了 WPF 中的 `Name` 和 `x:Name` 属性。虽然它们在本质上有一些区别，但在 WPF 中，它们的作用几乎是一样的。

围绕着 `Name` 这个概念，其实能聊的还有很多。比如：

1. `NameScope` 的概念；
2. 当持有 `Name` 的控件在 `ControlTemplate` 或 `DataTemplate` 中时会怎样；
3. 与之相关的其他来自 `x` 命名空间的属性，比如 `x:FieldModifier`、`x:Reference` 等。

这些内容，我们会在以后的文章中继续探讨。

## 参考

- [In WPF, what are the differences between the x:Name and Name attributes?](https://stackoverflow.com/questions/589874/in-wpf-what-are-the-differences-between-the-xname-and-name-attributes)
- [x:Name Directive | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/desktop/xaml-services/xname-directive)
