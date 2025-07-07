---
title: ".NET 原生有哪些 Timer 以及它们分别是怎么用的？"
slug: "how-many-timers-are-there"
description: ".NET 标准库为我们提供了数个计时器（Timer），它们各自的功能和使用场景是什么？这篇文章我们就来盘点一下吧。"
date: 2025-07-07
tags:
    - dotnet
    - csharp
    - timer
    - threading
    - async
---

相信很多 .NET 新手（甚至有几年经验的老手）都会搞不清楚这个问题：.NET 原生有哪些计时器（Timer）？它们分别是做什么用的？该如何选择以及如何正确地使用？

这篇文章我们就来盘点一下吧。

## 一共有多少种 Timer？

首先我们来回答一下这个问题。在 [.NET 源代码](https://source.dot.net) 中搜索 `Timer`，我们可以找到答案。排除掉一些 `internal` 或 `abstract` 的类型（例如 `System.Net.Timer`、`Microsoft.ML.Trainers.FastTree.Timer` 等），我们可以找到以下几种计时器：

- `System.Threading.Timer`
- `System.Timers.Timer`
- `System.Threading.PeriodicTimer`
- `System.Windows.Threading.DispatcherTimer`
- `System.Windows.Forms.Timer`
- `System.Web.UI.Timer`
- `Windows.UI.Xaml.DispatcherTimer`

这里，后面四个可以从命名空间看出，它们适用于特定的 UI 框架（即 WPF、WinForms、ASP.NET Forms、Win UI 等），而前面三个则是更通用的计时器，适用于大多数场景。这篇文章我们主要介绍前三个，并且在后四个中选择适用于 WPF 的 `DispatcherTimer` 进行介绍。

## System.Threading.Timer

源代码：[System.Threading.Timer.cs](https://source.dot.net/#System.Private.CoreLib/src/libraries/System.Private.CoreLib/src/System/Threading/Timer.cs)

`System.Threading.Timer` 是 .NET 中最常用也是最轻量的计时器之一。它是基于线程池的，所以不与某个特定线程（如 UI 线程）关联，并且也不会阻塞调用线程。

它没有提供诸如 `Start` 和 `Stop` 方法，而是通过设置回调函数和周期来启动（还可以通过 `Change` 方法来调整周期）。当不需要使用时，可以通过调用 `Dispose` 方法来结束它并释放资源。

下面是一个简单的例子：

```csharp
using System;
using System.Threading;

// 第三个参数是初始延迟时间，第四个参数是周期时间（单位都是毫秒）
// 这里的传参意味着，计时器将会没有初始延迟，且每隔 1 秒执行一次回调函数
var timer = new Timer(TimerCallback, null, 0, 1000);
Console.WriteLine("Timer started. Press Enter to exit...");
Console.ReadLine();

timer.Dispose();
Console.WriteLine("Timer stopped and disposed.");

void TimerCallback(object? state)
{
    Console.WriteLine($"Timer callback executed at {DateTime.Now}, thread id: {Environment.CurrentManagedThreadId}");
}
```

输出结果形如：

```plaintext
Timer started. Press Enter to exit...
Timer callback executed at 2025/7/6 19:27:27, thread id: 11
Timer callback executed at 2025/7/6 19:27:28, thread id: 9
Timer callback executed at 2025/7/6 19:27:29, thread id: 9
Timer callback executed at 2025/7/6 19:27:30, thread id: 9
Timer stopped and disposed.
```

我们不难发现几个现象：

1. 计时器在创建后立刻就开始执行了，不需要调用类似 `Start` 的方法；
2. 计时器没有阻塞创建它的线程，它类似于启动了一个后台服务；
3. 计时器的回调函数是在不同的线程上执行的，而且每次执行的线程 ID 可能不同，这取决于线程池的调度；
4. 计时器可以通过 `Dispose` 方法来停止及释放资源。

因为它的一些局限性，这在实际开发中可能会让我们遇到一些困难，比如我们无法灵活地控制它的开始与结束，以及暂停和重启等。另外，因为它每次的回调可能都发生在不同的线程上，所以我们需要特别注意线程安全问题，尤其是在访问共享资源，或者需要某些操作发生在特定线程（如 UI 线程）时。

关于这些问题，我们会在后续介绍的其他计时器中看到更好的解决方案。

## System.Timers.Timer

源代码：[System.Timers.Timer.cs](https://source.dot.net/#System.ComponentModel.TypeConverter/System/Timers/Timer.cs)

`System.Timers.Timer` 是一个更高级的计时器，它基于（或者可以理解为封装了） `System.Threading.Timer`，并提供了更多的功能和更易用的 API。比如它提供了开始、停止、关闭等功能，还提供了一些属性来控制计时器的行为，比如：

- Interval：设置计时器的间隔时间（毫秒），不再需要使用 `Change` 方法了；
- Enabled：设置计时器是否启用（`Start` 和 `Stop` 方法其实就是在控制它）；
- AutoReset：设置计时器是否自动重置（即是否在回调函数执行完毕后立即重新开始计时，默认为 `true`）。或者换一种理解方式，有时候我们不希望计时器会每周期都触发一次，而是真的像一个简单的定时器那样，在开始后到达设定的周期就触发，然后停在那里，等待下一次启动。

下面是一个简单的例子：

```csharp
using System;
using System.Timers;

var timer = new Timer(); // 创建一个计时器（默认的周期为 100 毫秒）
timer.Elapsed += TimerElapsedHandler; // 订阅 Elapsed 事件
timer.Interval = 1000; // 设置间隔为 1 秒

timer.Start();
Console.WriteLine("Timer started. Press Enter to exit...");
Console.ReadLine();

timer.Stop();
Console.WriteLine("Timer stopped and disposed.");

timer.Dispose();

void TimerElapsedHandler(object? sender, ElapsedEventArgs e)
{
    Console.WriteLine($"Timer elapsed at {e.SignalTime}, thread id: {Environment.CurrentManagedThreadId}");
}
```

现在我们可以稍微探讨一下这个计时器的另外一个特性了：如果它的回调函数比较耗时，甚至超过了它的周期，会怎么样？

答案非常简单：计时器依旧会按照设定的周期继续触发回调函数，虽然看起来（比如从控制台的输出）可能会表现出延迟，甚至可能因为每次回调的延迟不同而使得输出顺序变得混乱。这也就是它使用线程池的原因之一：即便上一次回调还没有完成，导致它所在的线程仍处于阻塞状态，下一次回调依旧可以在其他线程上继续执行。

{{< notice note >}}
还有一个值得注意的点：当计时器停止（甚至释放）后，之前每次 `Elapsed` 触发的回调如果还没有执行完毕，那么将仍会处于执行状态，尤其是它们内部有耗时的操作时。这是因为计时器每次触发时，都会将回调函数放入线程池中执行，而线程池中的线程会继续执行这些任务，直到它们完成。
{{< /notice >}}

## System.Threading.PeriodicTimer

源代码：[System.Threading.PeriodicTimer.cs](https://source.dot.net/#System.Private.CoreLib/src/libraries/System.Private.CoreLib/src/System/Threading/PeriodicTimer.cs)

这是一个比较新的计时器（.NET 6+），它不仅现代，而且精确，还支持异步操作。正如它的名称所提示的，它旨在提供一个周期性的计时器，允许我们在每个周期结束时执行一个异步操作。它与传统的 `Timer` 类不同，不使用事件或回调，而是通过 `await` 一个异步方法来控制每次操作的发生。

它的使用方式也非常简单，下面是一个例子：

```csharp
using System;
using System.Threading;

var timer = new PeriodicTimer(TimeSpan.FromSeconds(1)); // 创建一个周期为 1 秒的计时器
var cts = new CancellationTokenSource();
var token = cts.Token;

try
{
    while (await timer.WaitForNextTickAsync(token))
    {
        token.ThrowIfCancellationRequested();

        Console.WriteLine($"Periodic timer tick at {DateTime.Now}, thread id: {Environment.CurrentManagedThreadId}");
    }
}
catch (OperationCanceledException)
{
    Console.WriteLine("Periodic timer canceled.");
}
finally
{
    timer.Dispose();
    cts.Dispose();
}
```

这个计时器还有一个常见的使用情形，就是在 ASP.NET Core 中借助它来创建一个后台的定时任务。因为它不仅准时，而且支持异步操作。比如：

```csharp
class MyService : BackgroundService
{
    private readonly ILogger<MyService> logger;

    private readonly PeriodicTimer timer;

    public MyService(ILogger<MyService> logger)
    {
        this.logger = logger;
        this.timer = new(TimeSpan.FromMilliseconds(1000));
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (await timer.WaitForNextTickAsync(stoppingToken) && !stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Hello, world!");
        }
    }
}
```

然后我们就可以在入口处注册这个服务了：

```csharp
builder.Services.AddHostedService<MyService>();
```

这样即便每次循环体中的操作比较耗时，它仍然可以保证每次触发的时间是准确的。它绝对比在循环中使用 `await Task.Delay()` 要准确得多。

## System.Windows.Threading.DispatcherTimer

源代码：[DispatcherTimer.cs](https://github.com/dotnet/wpf/blob/main/src/Microsoft.DotNet.Wpf/src/WindowsBase/System/Windows/Threading/DispatcherTimer.cs)

最后我们再来简单地看一下适用于 WPF 的 `DispatcherTimer`。看到 `Dispatcher` 这个词，我们很容易联想到诸如 `Application.Current.Dispatcher`，所以它主要用于在 UI 线程上执行操作。它的使用方式与 `System.Timers.Timer` 类似，也提供了 `Start`、`Stop` 等方法，以及 `Interval` 属性和 `Tick` 事件等。

下面是一个简单的例子：

```csharp
using System;
using System.Windows.Threading;

public partial class MainWindow : Window
{
    private readonly DispatcherTimer timer;

    public MainWindow()
    {
        InitializeComponent();

        timer = new DispatcherTimer();
        timer.Interval = TimeSpan.FromSeconds(1);
        timer.Tick += Timer_Tick;
        timer.Start();
    }

    private void Timer_Tick(object sender, EventArgs e)
    {
        listBox.Items.Add($"Dispatcher timer tick at {DateTime.Now}, thread id: {Environment.CurrentManagedThreadId}");
    }
}
```

`DispatcherTimer` 有几个构造函数，可以指定它的优先级以及所使用的 `Dispatcher`。默认情况下，它会使用 `DispatcherPriority.Background` 以及 `Dispatcher.Current`。只要你在 UI 线程上创建它，它就会在 UI 线程上执行回调函数。

## 总结

在这篇文章中，我们介绍了 .NET 中常用的几种计时器，包括它们各自的功能和特点，以及所适合的场景。简单来说：

- `System.Threading.Timer` 是最轻量的计时器，适用于大多数非 UI 线程的场景，但因为缺少灵活的控制方法和线程安全问题，可能需要一些额外的处理；
- `System.Timers.Timer` 提供了更易用的 API 和更多的功能，适用于大多数需要定时操作的场景；
- `System.Threading.PeriodicTimer` 是一个现代的计时器，支持异步操作，适用于需要精确控制周期性操作的场景，以及异步编程；
- `DispatcherTimer` 适用于 WPF，能够在 UI 线程上执行操作，适合需要与 UI 交互的场景。

希望这篇文章能帮助你更好地理解 .NET 中的计时器，并在实际开发中选择合适的计时器来满足你的需求。如果你有任何问题或建议，欢迎在评论区留言讨论！
