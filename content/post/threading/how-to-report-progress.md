---
title: "如何在异步任务中汇报进度"
slug: "how-to-report-progress"
description: "在多线程情形下，有时候我们会希望有办法汇报进度，却常常会遇到线程不安全之类的问题。那么官方给出的实践方式是什么呢？"
image: https://s2.loli.net/2024/05/09/RJYeMSKs5q6UdQn.jpg
date: 2024-05-09
tags:
    - csharp
    - dotnet
    - async
    - wpf
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1SD421P76s/)

在执行异步任务时，有时候我们会希望有办法汇报进度。比如在一个 WPF 程序中，我们在界面上放了一个进度条，从而展示当前任务的进度。那么该如何汇报异步任务的进度呢？

其实 .NET 标准库就为我们提供了实现这一功能的接口和类：`IProgress<T>` 与 `Progress<T>`，其中 `T` 是一个泛型类型，表示要汇报的内容。如果我们希望汇报一个百分比进度，那么使用 `double` 类型即可；类似地，如果我们希望汇报一些更加复杂的内容，还可以使用 `string` 甚至一些自定义类与结构体。

下面我们就来看看该如何使用吧。

## 搭建项目

首先我们创建一个简易的 WPF 项目。因为这次的任务比较简单，所以我们就不遵循 MVVM 模式了，而是使用最传统的 WPF 事件注册的方式。

它的 `MainWindow` 形如：

```xml
<Window ...>
    <StackPanel VerticalAlignment="Center">
        <Button Width="100"
                Margin="0,0,0,10"
                Content="Run"
                Click="Button_Click" />
        <ProgressBar Height="20"
                     d:Value="10"
                     Name="progressBar" />
    </StackPanel>
</Window>
```

然后在 `MainWindow.xaml.cs` 中实现一些简单的逻辑：

```c#
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private async void Button_Click(object sender, RoutedEventArgs e)
    {
        await DoJobAsync(CancellationToken.None);
    }

    async Task DoJobAsync(CancellationToken token)
    {
        if (token.IsCancellationRequested)
            return;
        for (int i = 0; i < 100; i++)
        {
            await Task.Delay(50, token);
            progressBar.Value = i + 1;
            if (token.IsCancellationRequested)
            {
                break;
            }
        }
    }
}
```

我们将按钮注册的 `Button_Click` 方法修改为 `async void`，这样我们就可以在里面等待一个异步任务了。

{{<notice info>}}
虽然 `async void` 是一种非常危险的方式，但因为 `Button` 控件的 `Click` 事件对应委托对于函数传参及返回值的限制，这里我们不得不这样做。
{{</notice>}}

然后，我们在 `DoJobAsync` 中实现后台的异步任务。这里我们简单地使用一个 `for` 循环，并在其中使用 `Task.Delay`，从而实现一个拥有进度的异步任务。然后，我们在每次循环中直接修改 `progressBar` 控件的值。运行程序，就可以直接看到效果了：

![动画](https://s2.loli.net/2024/05/09/F6o97PzSaO4kiDc.gif)

这个问题难道就这么轻松地就解决了吗？其实不是的，因为在异步任务中，很可能会出现在别的线程中操作 UI 线程的资源（也就是控件及其属性），这种情况下程序会报错。所以如果使用这样的方式，通常我们还需要使用老套的 `Dispatcher.Invoke` 的方式来规避这个问题。但这样就显得不够优雅了。

那么同样的功能，我们该如何使用 `Progress` 类来实现呢？

## 使用 Progress 类

首先我们需要稍稍修改一下 `DoJobAsync` 方法：

```c#
async Task DoJobAsync(IProgress<double> reporter, CancellationToken token)
{
   for (int i = 0; i < 100; i++)
   {
        if (token.IsCancellationRequested)
            return;
       await Task.Delay(50, token).ConfigureAwait(false);
       reporter.Report(i + 1);
       if (token.IsCancellationRequested)
       {
           break;
       }
   }
}
```

然后，这个 `Progress` 类的实例来自哪儿呢？我们再修改一下 `Button_Click` 方法：

```c#
private async void Button_Click(object sender, RoutedEventArgs e)
{
    var reporter = new Progress<double>(value => progressBar.Value = value);
    await DoJobAsync(reporter, CancellationToken.None);
}
```

就这样，我们只需要在使用的时候实例化一个新的即可。它除了我们前面提到的泛型，还传入了一个回调函数，表示每次 `Report` 时需要执行的逻辑。这里的逻辑非常简单，只需要将传入的 `double` 类型的数字赋值给进度条的 `Value` 属性即可。

那么问题来了：它是如何规避了前面提到的线程问题的呢？我们观察 `Progress` 类的[源代码](https://source.dot.net/#System.Private.CoreLib/src/libraries/System.Private.CoreLib/src/System/Progress.cs,d23df0450d3fd0d6)，可以发现：

```c#
public Progress()
{
    // Capture the current synchronization context.
    // If there is no current context, we use a default instance targeting the ThreadPool.
    _synchronizationContext = SynchronizationContext.Current ?? ProgressStatics.DefaultContext;
    Debug.Assert(_synchronizationContext != null);
    _invokeHandlers = new SendOrPostCallback(InvokeHandlers);
}
```

在它的构造函数中，拥有一个 `SynchronizationContext` 对象，它持有了当前的同步上下文。当我们在 `Button_Click` 方法中声明它时，因为还在 UI 线程，所以它就保存了这个上下文。然后在它的 `Report` 方法被调用时，就会在正确的同步上下文（也就是 UI 线程）中执行相关逻辑了。

{{<notice info>}}
除了给构造函数传回调，`Progress` 类还为我们提供了一个 `ProgressChanged` 事件。注册这个事件可以实现相同的效果，并且也是在相同的同步上下文执行的。
{{</notice>}}

## 实现自定义 Progress 类

如果我们还有其他额外的需求，那么我们还可以自己实现接口，或者继承 `Progress` 类。官方特意没有将这个类设为 `sealed`，并且将 `OnReport` 方法设为 `virtual`，就是为了满足我们的这些需求。

{{<notice note>}}
但是如果我们去继承这个 `Progress` 类，会发现其实我们能自由发挥的空间并不大，因为它其中的很多字段（尤其是同步上下文）都是 `private` 的，所以我们能做的事情基本上也只有重写 `OnReport` 方法了。
{{</notice>}}

比如这里我写了一个子类，从而可以在进度完成后执行一个回调方法。

```c#
class MyProgress<T> : Progress<T> where T : notnull
{
    private readonly Action? _complete;
    private readonly T _maximum;
    private bool _isCompleted;

    public MyProgress(Action<T> handler, Action? complete, T maximum)
        : base(handler)
    {
        _complete = complete;
        _maximum = maximum;

        ProgressChanged += CheckCompletion;
    }

    protected override void OnReport(T value)
    {
        if (_isCompleted)
            return;
        base.OnReport(value);
    }

    private void CheckCompletion(object? sender, T e)
    {
        if (e.Equals(_maximum) && !_isCompleted)
        {
            _isCompleted = true;
            _complete?.Invoke();
        }
    }
}
```

然后我们就可以这样使用了：

``` c#
private async void Button_Click(object sender, RoutedEventArgs e)
{
    var reporter = new MyProgress<double>(
        value => progressBar.Value = value,
        () => progressBar.Visibility = Visibility.Hidden,
        100
    );
    await DoJobAsync(reporter, CancellationToken.None);
}
```

这里实现的效果是，当异步任务完成后，将会隐藏进度条。

## 总结

不知道大家看完这篇文章的感受如何。其实我在最开始了解文中提到的 `IProgress` 接口以及 `Progress` 类时，最大的感受是：微软究竟为我们提前准备好了多少接口和类啊🤣！

.NET 类中有太多这样的标准库了，但我们也没有什么办法去系统地挖掘与总结。所以只能仰仗大家今后持续不断的交流与学习了。

## 参考

[How to Report Progress with Async/Await in .NET Core 3 - YouTube](https://www.youtube.com/watch?v=zQMNFEz5IVU)

[C# Advanced Async - Getting progress reports, cancelling tasks, and more - YouTube](https://www.youtube.com/watch?v=ZTKGRJy5P2M)
