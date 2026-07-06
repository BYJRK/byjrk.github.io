---
title: "WPF TabControl 控件的子元素的加载事件该如何对待"
slug: "tabcontrol-children-loaded-events"
description: 在 WPF 中，TabControl 有一些可能不太符合预期的行为，特别是关于子元素的加载与卸载的时机。这篇文章我们就来探讨一下，并且思考相应的解决方案及最佳实践。
date: 2026-06-15
tags:
  - dotnet
  - csharp
  - wpf
  - tabcontrol
categories:
  - WPF
---

TabControl 是 WPF 中一个相当常用的控件。当我们需要设计一个多页面的界面时，借助 TabControl 可以很方便地实现页面的切换。然而，TabControl 的一些行为可能不太符合我们的预期，尤其是关于子元素的加载与卸载的时机。具体是怎么一回事呢？

## TabItem 的原理

在探讨后面的内容之前，我们先简单分析一下 TabControl 及 TabItem 的底层原理，或者说在切换 Tab 后，相应的 Content 是如何呈现出来的。

从实现上来看，`TabControl` 主要可以拆成两部分：

1. 上方用于切换的页签头，也就是每个 `TabItem` 的 `Header`
2. 下方用于承载当前页内容的内容展示区域

其中，页签头通常会全部生成出来，因为用户需要看到所有可以切换的标签；但内容展示区域在同一时刻通常只会显示当前选中的那一项。微软文档在 `TabControl` 的默认模板里明确给出了一个名为 `PART_SelectedContentHost` 的部件，它的类型是 `ContentPresenter`，并且通过 `ContentSource="SelectedContent"` 来展示当前选中项的内容。当选项卡切换时，这个属性会更新为当前活动 `TabItem` 的 `Content`。

所以当切换 Tab 后，并不是 `TabItem` 本身被加载到内容展示区域，而是它的 `Content` 被加载。`TabItem` 本身仍然是内容的拥有者，只是负责实际呈现的是内容区里的 `ContentPresenter`。

另外，如果应用了 MVVM 模式，那么通常还会跟视图模型打交道。如果 `Content` 没有单独显式设置 `DataContext`，它会继承 `TabItem` 的 `DataContext`。也就是说，切换时进入内容区的是 `Content` 这棵界面树，而它绑定时所使用的数据上下文，默认仍然往往来自对应的 `TabItem`。

## TabItem 的 Loaded 事件

然后我们来看一看 `TabItem` 的 `Loaded` 是什么时候触发的。稍加尝试后，我们会轻易地发现，`TabItem` 的 `Loaded` 事件只会在第一次被加载到界面树时触发一次。不仅如此，它们的加载顺序还有一些规律可循：它们会按照顺序加载，并且第一个被呈现的 Tab 的 `Loaded` 事件会在其他 `TabItem` 之后触发。

例如有 A、B、C 三个 TabItem，A 是默认选中的，那么它们的 `Loaded` 事件触发顺序是 B、C、A。如果此时将 B 设为默认选中，那么顺序就是 A、C、B。

不过这通常没有什么好关注的，因为 `TabItem` 的 `Loaded` 事件只会在第一次加载时触发一次，之后即使切换 Tab，也不会再触发。而且我们基本上也不会在它的 `Loaded` 事件里做什么事情。

## Content 的 Loaded 事件

当涉及到 `TabItem.Content` 时，问题就变得复杂了一些。首先我们尝试直接将 `Content` 声明在 `TabItem` 中，类似：

```xml
<TabControl>
    <TabItem Header="A">
        <StackPanel Loaded="Content_Loaded" Unloaded="Content_Unloaded">
            <TextBlock Text="Content A" Loaded="Content_Loaded" Unloaded="Content_Unloaded"/>
        </StackPanel>
    </TabItem>
    <TabItem Header="B">
        <StackPanel Loaded="Content_Loaded" Unloaded="Content_Unloaded">
            <TextBlock Text="Content B" Loaded="Content_Loaded" Unloaded="Content_Unloaded"/>
        </StackPanel>
    </TabItem>
    <TabItem Header="C">
        <StackPanel Loaded="Content_Loaded" Unloaded="Content_Unloaded">
            <TextBlock Text="Content C" Loaded="Content_Loaded" Unloaded="Content_Unloaded"/>
        </StackPanel>
    </TabItem>
</TabControl>
```

此时我们会观察到，`TabItem` 与 `Content` 是交替加载的，而 `Content` 又会先加载默认显示的页面的，然后再按顺序加载其他的。这就会产生一个很有意思的现象。还是以 A、B、C 三个页面举例子。我们如果默认显示 A，那么各控件的 Loaded 顺序将会是：

1. A 的 Content
2. B 的 TabItem
3. B 的 Content
4. C 的 TabItem
5. C 的 Content
6. A 的 TabItem

是不是感觉被绕晕了？其实只要把 Content 和 TabItem 分开看，就会看出规律：它们各自符合前面提到的规律，然后交替进行。感兴趣的话，也可以想象一下如果将 B 设为默认选中，那么顺序会是怎么样，然后可以写个小程序来验证一下。

<details>
<summary>答案</summary>
<ol>
<li>B 的 Content</li>
<li>A 的 TabItem</li>
<li>A 的 Content</li>
<li>C 的 TabItem</li>
<li>C 的 Content</li>
<li>B 的 TabItem</li>
</ol>
</details>

其实这个顺序并不是很重要（而且看起来就像是脑筋急转弯），真正重要的是：所有 `Content` 都会在刚一开始就被触发，即便它们并没有被显示出来。这恐怕并不符合我们的直觉，更不是我们期望的效果。我们通常期望的效果是，页面只有在被切换到时才会加载，而不是在一开始就全部加载。

## Content 的 Unloaded 事件

幸运的是，`Content` 的 `Unloaded` 事件是符合我们预期的。它会在切换到其他 Tab 时触发，并且只会触发当前显示的页面的 `Unloaded` 事件。所以当切换页面时，比如从 A 切换到 B，我们会观察到：

1. A 的 Content 的 Unloaded 事件触发
2. B 的 Content 的 Loaded 事件触发

所以关于这一部分，就没有太多可以赘述的内容了。

## 如何解决 Loaded 事件被多次触发的问题

现在我们很容易发现一个问题：`Content` 的 `Loaded` 事件在一开始就会被触发，并且在切换 Tab 时也会再次触发，这就导致了一个问题：如果我们在 `Loaded` 事件里做一些初始化操作，那么这些操作可能会被执行多次，甚至在页面还没有显示出来时就已经执行了，这显然不是我们想要的效果。

为了解决这个问题，我们通常的做法是引入一个局部变量，用来标记当前页面是否已经被加载过。这样在 `Loaded` 事件里，我们就可以先检查这个标记，如果已经加载过，就不再执行初始化操作。例如：

```csharp
private bool _isContentALoaded = false;

private void ContentLoaded(object sender, RoutedEventArgs e)
{
    if (_isContentALoaded) return;

    Initialize();

    _isContentALoaded = true;
}
```

如果是在视图模型中实现初始化的逻辑，也可以用相同的方式：

```csharp
class TabViewModel
{
    private bool _isInitialized = false;

    public void Loaded()
    {
        if (_isInitialized) return;

        Initialize();

        _isInitialized = true;
    }
}
```

如果借助行为库，通常我们会这样实现：

```xml
<TabControl>
    <TabItem Header="A" DataContext="{Binding TabViewModel}">
        <Grid>
            <i:Interaction.Triggers>
                <i:EventTrigger EventName="Loaded">
                    <i:InvokeCommandAction Command="{Binding LoadedCommand}" />
                </i:EventTrigger>
            </i:Interaction.Triggers>
            <TextBlock Text="Content A" />
        </Grid>
    </TabItem>
</TabControl>
```

## 如何解决 Loaded 事件在一开始就被触发的问题

现在我们来讨论另一个问题：`Content` 的 `Loaded` 事件在一开始就会被触发，这可能会导致一些不必要的初始化操作在页面还没有显示出来时就已经执行了。那么这个问题又该如何解决呢？

首先有一个方式，就是我们额外添加一个判断，即 Tab 只有在被选中，或者可见时，才会执行初始化操作。这样就可以避免在页面还没有显示出来时就执行初始化操作了。以判断是否可见为例，除了可以在 `Loaded` 事件里判断 `IsVisible` 属性外，还可以借助行为库的条件行为来实现。具体的实现方式如下：

```xml
<i:EventTrigger EventName="Loaded">
    <i:Interaction.Behaviors>
        <i:ConditionBehavior>
            <i:ConditionalExpression>
                <i:ComparisonCondition LeftOperand="{Binding RelativeSource={RelativeSource AncestorType=UserControl}, Path=IsVisible}" RightOperand="True" />
            </i:ConditionalExpression>
        </i:ConditionBehavior>
    </i:Interaction.Behaviors>
    <i:InvokeCommandAction Command="{Binding LoadedCommand}" />
</i:EventTrigger>
```

这个看起来很复杂的实现，其实就是在 `Loaded` 事件触发时，额外添加了一个条件。如果条件不满足，则不执行后面的 `Action`。这样就可以确保只有在页面可见时，才会执行初始化操作。

除此之外还有一种不太能想到的方式，就是借助 `TabItem.ContentTemplate` 来实现，也就是不借助 `Content` 属性。形如：

```xml
<TabControl>
    <TabItem Header="A">
        <TabItem.ContentTemplate>
            <DataTemplate>
                <TextBlock Text="Content A" />
            </DataTemplate>
        </TabItem.ContentTemplate>
    </TabItem>
</TabControl>
```

通过这样的方式，`Content` 的 `Loaded` 事件就不会在一开始就被触发了，而是只有在切换到该 Tab 时才会触发。这一方式的原理是，模板只是告诉控件如何生成界面元素，而并没有直接生成界面元素。只有在切换到该 Tab 时，控件才会根据模板生成界面元素，从而触发 `Loaded` 事件。

## 总结

`TabControl` 在切换页面时，真正进入和离开内容区的通常不是 `TabItem` 本身，而是当前选中项的 `Content`。也正因为如此，`TabItem` 自身的 `Loaded` 往往只在初次进入界面树时触发一次，而 `Content` 的 `Loaded` / `Unloaded` 则会随着切换被重复触发；如果是直接把内容内联写在 `TabItem` 里，甚至还可能在初始阶段就先触发。

所以在实际开发中，最好不要把 `Loaded` 直接等同于“用户第一次看到这个页面”。更稳妥的做法通常是：要么给初始化逻辑加上幂等保护，避免重复执行；要么结合选中状态、可见性，或者改用 `ContentTemplate`，让初始化发生在真正合适的时机。
