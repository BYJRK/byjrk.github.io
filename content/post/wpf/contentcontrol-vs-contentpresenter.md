---
title: "WPF 中的 ContentControl 及 ContentPresenter 有何异同？"
slug: "contentcontrol-vs-contentpresenter"
description: "WPF 中的 ContentControl 和 ContentPresenter 都是用于展示内容的控件，但它们之间有着不同的用途。本文将简单介绍一下这两个控件的异同，以及在具体情形下应该如何选择。"
date: 2025-03-05
tags:
    - dotnet
    - csharp
    - wpf
---

标题中提到的 `ContentControl` 和 `ContentPresenter` 都是 WPF 中较为常见的显示内容的控件，它们有各自的用途。但有的时候，开发者可能会搞不清楚它们之间的区别，导致选错了控件（却往往又因为效果实现了而忽视这一问题）。本文将简单介绍一下这两个控件的异同。

## 二者的共同点

首先，我们来看一下 `ContentControl` 和 `ContentPresenter` 之间的共同点：

1. 都包含一个 `Content` 属性；
2. 都可以用作一个将要展示内容的容器或占位符；
3. 默认情况下通常都没有什么样式，完全透明且空白，看起来十分轻量。

因此，当用于展示一个控件或内容时，它们看起来都可以胜任。比如：

```xml
<ContentControl>
    <Button Content="Hello, World!" />
</ContentControl>
```

或者我们还可以在资源词典中声明一个控件：

```xml
<Window.Resources>
    <Button x:Key="MyButton" Content="Hello, World!" x:Shared="False" />
</Window.Resources>

<ContentControl Content="{StaticResource MyButton}" />
```

{{< notice info >}}
这里我们使用了 `x:Shared="False"` 来确保每次使用这个资源时都会创建一个新的实例。否则，如果我们在多个地方使用这个资源，那么这些地方的控件都会指向同一个实例，导致一些问题（比如只有一个控件正确显示）。
{{< /notice >}}

当然了，我们还可以在代码后台去动态设置 `Content` 属性，这里我们就不演示了。

## 二者的区别

但正是因为它们有着这样的相同点，因此经常会有开发者误用了它们两个。那么，它们之间的区别又是什么呢？

### 它们的基类不同

`ContentControl` 是 `Control` 的子类，而 `ContentPresenter` 是 `FrameworkElement` 的子类。

首先我们来看 `FrameworkElement`。它提供了一些最基本的界面元素应该有的属性，比如宽高、样式、布局等。`Control` 是它的子类，额外添加了控件需要的边框、前背景色、字体等，还有一个相当重要的属性 `Template`，用于定义控件的外观。

然后，在这些的基础上，`ContentControl` 继承了 `Control`，并添加了一个 `Content` 属性，用于存放要展示的内容。不仅如此，因为它拥有模板（以及模板选择器等），因此它可以根据一些因素选择合适的模板从而去展示内容，并且非常适合在运行时动态改变内容。此外，它的 `Content` 不仅可以是一个具体的控件，还可以是一个数据模型等（通常还可以是绑定得到的）。

另一方面，`ContentPresenter` 并不拥有 `Control` 所提供的那些属性，可以说是一个相当轻量的界面元素。它的主要使用场景就是在模板中，用于展示模板的内容。比如我们可以在一个 `Button` 的模板中使用 `ContentPresenter` 来展示按钮的内容：

```xml
<ContentTemplate x:Key="MyButtonTemplate" TargetType="Button">
    <Border>
        <ContentPresenter />
    </Border>
</ContentTemplate>
```

不仅如此，因为它太适合用在这个场景了，所以通常我们根本不需要去操作它的 `Content` 属性，因为它会自动绑定到模板的 `Content` 属性上。也就是说，我们不需要写 `Content="{TemplateBinding Content}"` 这样的代码。

{{< notice info >}}
其实 `ContentPresenter` 的作用就是在模板中用来展示 `Content`，所以 `ContentControl` 及其子控件自然也都用到了它。如果你在一个模板中，错误地将 `ContentControl` 用在了应该用 `ContentPresenter` 的地方，并且手写了 `Content` 属性的绑定，那么你仍然有可能看到正确的效果。只是它底层依旧是借助了 `ContentPresenter`。
{{< /notice >}}

### 它们的功能不同

因为上面的原因，所以即便它们看起来（甚至简单使用起来）并没有什么区别，但是它们被设计出来的目的及作用是完全不一样的。

`ContentControl` 一般来说有这么几种用途：

1. 用于展示一个控件或内容（可以理解为容器或占位符）；
2. 用作控件的基类，可以被继承，从而实现一些自定义的控件；
3. 用于动态改变内容，比如在运行时改变 `Content` 属性；
4. 搭配 `DataTemplate` 使用，用于根据数据模型展示不同的内容（尤其适用于导航页面）。

对于第 4 点，这里有一个简单的例子：

```xml
<ContentControl Content="{Binding CurrentPageViewModel}">
    <ContentControl.Resources>
        <DataTemplate DataType="{x:Type local:HomePage}">
            <local:HomePage />
        </DataTemplate>
        <DataTemplate DataType="{x:Type local:AboutPage}">
            <local:AboutPage />
        </DataTemplate>
    </ContentControl.Resources>
</ContentControl>
```

此时，虽然它的 `Content` 属性的值并不是一个控件，而是一个模型（Model），但是它会根据这个模型的类型自动选择合适的模板来展示内容。这样的话，只要我们给它提供视图模型（ViewModel），它就可以自动选择相应的视图（View）来展示，并且还会自动将 `View` 的 `DataContext` 设置为 `Content` 的值。

而 `ContentPresenter` 一般来说只有一种用途，那就是用在 `ControlTemplate` 中。类似的，还有一个 `ItemsPresenter`，用于在 `ItemsControl` （及其子控件，如 `ListBox` 等）的模板中展示子项。如果你在一个需要使用 `ContentControl` 的地方使用了 `ContentPresenter`，那么你不仅没有办法操作 `Template` 或提供 `DataTemplate` 来展示数据，而且还将没有办法操作一些最基本的 `Control` 的属性，比如前景色、背景色、字体等。

## 总结

深入了解 `ContentControl` 和 `ContentPresenter` 的区别，可能显得有些繁琐。其实大家基本上只需要记住，`ContentPresenter` 几乎只用于模板中，其余情况下都可以使用 `ContentControl` 即可。

让合适的控件做合适的事情，这样才有助于我们开发出更加清晰、稳健、易维护的代码。
