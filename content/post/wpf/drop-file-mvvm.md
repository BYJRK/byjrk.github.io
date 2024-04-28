---
title: "如何在 WPF 中实现符合 MVVM 模式的文件拖入功能"
slug: "drop-file-mvvm"
description: 在 WPF 中，实现文件拖入功能并不难，但是想要遵守 MVVM 模式，恐怕需要稍微多花费一点心思。
date: 2024-04-28
draft: true
tags:
    - wpf
    - mvvm
    - csharp
    - dotnet
---

## 原始方式

在 WPF 中，实现文件拖入功能并不难。稍微在网上搜索一下，就能够得到答案。比如现在有一个窗口，我们只需要设置它的 `AllowDrop` 属性为 `True`，然后在 `Drop` 事件中处理即可。形如：

```xml
<Window ...
        AllowDrop="True"
        Drop="Window_Drop">
```

```c#
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            var files = (string[])e.Data.GetData(DataFormats.FileDrop);
            // 处理拖入的文件
        }
    }
}
```

## 添加视图模型

但问题是，如果现在 `Window` 拥有一个视图模型（ViewModel），形如：

```c#
public class MainViewModel : ViewModelBase
{
    private string? _fileName;
    public string? FileName
    {
        get => _fileName;
        set
        {
            _fileName = value;
            OnPropertyChanged(this, nameof(FileName));
        }
    }
}
```

{{<notice info>}}
这里我们假定已经实现了 `ViewModelBase` 类，它实现了 `INotifyPropertyChanged` 接口，并提供了 `OnPropertyChanged` 方法以便于通知属性发生了变化。
{{</notice>}}

然后 `Window` 上面有一个 `TextBox` 绑定了这个属性，这又该怎么办呢？

这里有两种比较简单粗暴的方式：

1. 为 `TextBox` 添加一个 `Name`，然后在 `Window` 的 `Drop` 事件中直接修改 `TextBox` 的 `Text` 属性，进而使用依赖属性的一些方法来通知绑定的 ViewModel 属性发生了变化
2. 在 `Window` 的 `Drop` 事件中直接修改 `ViewModel` 的属性（获取 `Window.DataContext`，并将其转为 `MainViewModel` 类型），然后在 `ViewModel` 中实现 `INotifyPropertyChanged` 接口，进而通知 `TextBox` 的 `Text` 属性发生了变化

这两种方式都很直接，而且其实都不违背 MVVM 模式。但是这两种方式并不优雅，所以这里我们借助行为（Behaviors）来实现一个更加优雅且通用的方式。

## 使用行为

首先，我们需要安装 `Microsoft.Xaml.Behaviors.Wpf` 包。然后我们可以创建一个 `DropFileBehavior` 类，形如：

```c#
public class DropFileBehavior : Behavior<FrameworkElement>
{
    public string[]? Data
    {
        get => (string[]?)GetValue(FilesProperty);
        set => SetValue(FilesProperty, value);
    }

    public static readonly DependencyProperty FilesProperty = DependencyProperty.Register(
        nameof(Data),
        typeof(string[]),
        typeof(DropFileBehavior),
        new UIPropertyMetadata(null)
    );

    protected override void OnAttached()
    {
        AssociatedObject.AllowDrop = true;
        AssociatedObject.Drop += DropHandler;
    }

    protected override void OnDetaching()
    {
        AssociatedObject.Drop -= DropHandler;
    }

    private void DropHandler(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            Data = (string[])e.Data.GetData(DataFormats.FileDrop);
        }
    }
}
```

这个行为大致实现的功能是：

1. 当附加到一个 `FrameworkElement` 上时，将其 `AllowDrop` 属性设置为 `True`，并注册 `Drop` 事件
2. 当拖入文件时，将文件路径保存到 `Data` 依赖属性中

然后我们就可以在 XAML 中使用这个行为了（因为这里我们声明的 `Data` 属性是一个数组，所以我们稍微修改 `MainViewModel` 中相关属性的名称及类型，从而实现绑定功能）：

```xml
<Window ...
        xmlns:i="http://schemas.microsoft.com/xaml/behaviors"
        xmlns:local="clr-namespace:YourNamespace">

    <i:Interaction.Behaviors>
        <local:DropFileBehavior Data="{Binding FileNames, Mode=OneWayToSource}" />
    </i:Interaction.Behaviors>

    <TextBox Text="{Binding FileNames[0]}" />
</Window>
```

注意这里，我们在书写行为的 `Data` 属性的绑定时，使用了 `Mode=OneWayToSource`，这是因为我们只需要将数据从视图传递到视图模型，而不需要反向传递。并且如果不写 `Mode`，它默认将会是 `OneWay`，导致可能无法正确通知到 `ViewModel`。
