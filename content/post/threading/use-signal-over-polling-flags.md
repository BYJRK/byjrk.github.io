---
title: "在多线程开发中用信号量代替轮询和标志位"
slug: "use-signal-over-polling-flags"
description: "我们在多线程开发中，经常会用到标志位和轮询。但是这样的方式并不优雅。这篇文章我们来看一看如何用信号量等机制来替代轮询标志位的方式，从而实现线程间的通信和控制。"
date: 2025-04-02
tags:
    - dotnet
    - csharp
    - threading
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1e7o2YTEpi)

我们在多线程开发中，经常会用到标志位和轮询，从而控制一个线程中的执行逻辑。但是这样的方式会导致代码的可读性和可维护性下降，并且也不够优雅。这篇文章我们来看一看如何用信号量等机制来替代轮询标志位的方式，从而实现线程间的通信和控制。

## 传统方式

首先我们来看一看传统的标志位和轮询是怎么一回事。这里我们用一个简单的例子来探讨：

```csharp
class MyService
{
    private volatile bool _shouldStop;

    private Thread? _workerThread;

    public void Start()
    {
        _workerThread = new Thread(Worker);
        _shouldStop = false;
        _workerThread.Start();
    }

    public void Stop()
    {
        _shouldStop = true;
        _workerThread?.Join();
    }

    private void Worker()
    {
        while (!_shouldStop)
        {
            // 执行一些工作
            Thread.Sleep(50); // 模拟工作
        }
    }
}
```

上面就是一个典型的例子。这里，`_shouldStop` 是一个标志位，表示线程是否需要停止。我们在 `Start` 和 `Stop` 方法中分别设置和读取这个标志位，并在 `Worker` 方法中，通过轮询它来判断线程是否需要继续执行。

{{< notice info >}}
上面的标志位 `_shouldStop` 是 `volatile` 的，这样做能够保证编译器不会对其进行优化，从而保证每次读取都是最新的值。其实一般情况下，如果我们的轮询中包含了 `Thread.Sleep` 等操作，那么即便不加 `volatile`，也依旧是可以读到最新的值的。
{{< /notice >}}

{{< notice warning >}}
注意，这里我们只是用简单的代码大概介绍思路，并没有提供一个稳健的实现。比如上面的例子中，我们并没有处理用户多次调用 `Start` 方法，也没有处理线程异常等情况。
{{< /notice >}}

如果我们想在上面的基础上再添加暂停和继续的功能，那么我们就需要添加更多的标志位和轮询逻辑。比如：

```csharp
class MyService
{
    private volatile bool _shouldStop;
    private volatile bool _isRunning;

    private Thread? _workerThread;

    public void Start()
    {
        _workerThread = new Thread(Worker);
        _shouldStop = false;
        _isRunning = true;
        _workerThread.Start();
    }

    public void Stop()
    {
        _shouldStop = true;
        _workerThread?.Join();
    }

    public void Pause()
    {
        _isRunning = false;
    }

    public void Resume()
    {
        _isRunning = true;
    }

    private void Worker()
    {
        while (!_shouldStop)
        {
            if (_isRunning)
            {
                // 执行一些工作
            }

            Thread.Sleep(50); // 暂停时也要休眠，避免 CPU 占用过高
            
        }
    }
}
```

## 经典的两个标志位

现在我们来看一看如何使用信号量来替代标志位。

### 用 `ManualResetEvent` 实现线程的暂停和继续

我们先来思考一下，上面的 `_isRunning` 的作用和效果是什么。我们想用它的值来控制线程是否要执行操作，但是我们不能在它发生变化时立刻得到通知，因此我们只能每隔一段时间去轮询一下。那么，如果有办法能够在它为 `false` 时不需要我们轮询，而是直接阻塞在某个地方，等到它变为 `true` 时再继续执行，是不是就好很多了？

根据这一需求，我们可以使用 `WaitHandle` 的两个子类——`ManualResetEvent` 及 `AutoResetEvent` 来实现。`ManualResetEvent` 是一个可以手动重置的信号量。当它 `Set` 后，将会保持放行状态，直到再次 `Reset` 才会关闭。与它相对的是 `AutoResetEvent`，它会在每次放行后自动重置。这里更符合我们的需求的是 `ManualResetEvent`，因为我们希望放行后能够连续执行多次，而不需要每次都 `Set` 后执行一次。

```csharp
class MyService
{
    private volatile bool _shouldStop;
    private ManualResetEvent _isRunningEvent = new ManualResetEvent(false); // 初始是关闭的

    private Thread? _workerThread;

    public void Start()
    {
        _workerThread = new Thread(Worker);
        _shouldStop = false;
        _isRunningEvent.Set(); // 线程开始时放行
        _workerThread.Start();
    }

    public void Stop()
    {
        _shouldStop = true;
        _workerThread?.Join();
    }

    public void Pause()
    {
        _isRunningEvent.Reset(); // 关闭信号量
    }

    public void Resume()
    {
        _isRunningEvent.Set(); // 放行信号量
    }

    private void Worker()
    {
        while (!_shouldStop)
        {
            _isRunningEvent.WaitOne(); // 等待信号量放行

            // 执行一些工作

            Thread.Sleep(50); // 适当休眠，避免 CPU 占用过高
        }
    }
}
```

### 用 `CancellationToken` 实现任务的停止

我们可以进一步优化上面的例子，比如我们可以使用 `CancellationToken` 来实现任务的停止。`CancellationToken` 是 .NET 中用于取消操作的机制，它可以在任务中传递一个取消请求，并且可以在任务中检查这个请求。它不仅可以用于异步编程，也可以用于多线程编程。这里，我们用它来取代 `_shouldStop` 标志位。

```csharp
class MyService
{
    private ManualResetEvent _isRunningEvent = new ManualResetEvent(false); // 初始是关闭的

    private Thread? _workerThread;
    private CancellationTokenSource _cancellationTokenSource = new CancellationTokenSource();

    public void Start()
    {
        _workerThread = new Thread(Worker);
        _isRunningEvent.Set(); // 线程开始时放行
        _workerThread.Start();
    }

    public void Stop()
    {
        _cancellationTokenSource.Cancel(); // 取消操作
        _workerThread?.Join();
    }

    public void Pause()
    {
        _isRunningEvent.Reset(); // 关闭信号量
    }

    public void Resume()
    {
        _isRunningEvent.Set(); // 放行信号量
    }

    private void Worker()
    {
        while (!_cancellationTokenSource.Token.IsCancellationRequested)
        {
            _isRunningEvent.WaitOne(); // 等待信号量放行

            // 执行一些工作

            Thread.Sleep(50); // 适当休眠，避免 CPU 占用过高
        }
    }
}
```

上面的例子因为比较简单，所以并没有体现出使用 `CancellationToken` 的优势。实际上，有很多方法都可以接收一个 `CancellationToken` 参数。这样我们还可以通过传递它来实现停止在 `Worker` 方法中调用的长时间运行的其他任务；否则我们可能就只能在取消后等待这些任务的结束了。

## 优化使用消息队列的情形

除了上面的例子，我们还经常会遇到需要使用一个队列来实现生产者消费者模式的情况。比如下面这个例子：

```csharp
class MyService
{
    private readonly Queue<int> _queue = new Queue<int>();
    private readonly object _lock = new object();

    private volatile bool _shouldStop;
    private volatile bool _isRunning;

    private Thread? _workerThread;

    public void Start()
    {
        _workerThread = new Thread(Worker);
        _shouldStop = false;
        _isRunning = true;
        _workerThread.Start();
    }

    public void Stop()
    {
        _shouldStop = true;
        _workerThread?.Join();
    }

    // 省略 Pause 和 Resume 方法的实现

    public void Enqueue(int item)
    {
        lock (_lock)
        {
            _queue.Enqueue(item);
        }
    }

    public void Worker()
    {
        while (!_shouldStop)
        {
            lock (_lock)
            {
                if (_queue.Count > 0 && _isRunning)  // 也可以使用 TryDequeue
                {
                    var item = _queue.Dequeue();
                    // 处理 item
                }
            }

            Thread.Sleep(50); // 暂停时也要休眠，避免 CPU 占用过高
        }
    }
}
```

在上面的例子中，我们具体做了这样几件事情：

1. 使用 `Queue` 来存储数据，并使用线程锁和 `lock` 语句来保证线程安全；
2. 使用 `_shouldStop` 和 `_isRunning` 来控制线程的执行；
3. 在 `Worker` 方法中使用 `lock` 来获取锁，并在队列不为空时获取传入的任务和进行处理；
4. 暴露一个 `Enqueue` 方法来让生产者添加任务到队列中。

那么我们该如何优化这个例子呢？

### 用线程安全的集合类型

实际上，.NET 标准库中已经提供了线程安全的集合类型，比如 `ConcurrentQueue<T>`。它们可以在多线程环境中安全地使用，而不需要我们手动加锁。我们可以直接用它来替代上面的 `Queue` 和 `lock` 语句。

```csharp
class MyService
{
    private readonly ConcurrentQueue<int> _queue = new ConcurrentQueue<int>();

    public void Enqueue(int item)
    {
        _queue.Enqueue(item);
    }

    public void Worker()
    {
        while (!_shouldStop)
        {
            if (_isRunning && _queue.TryDequeue(out var item)) // 也可以使用 TryDequeue
            {
                // 处理 item
            }

            Thread.Sleep(50); // 暂停时也要休眠，避免 CPU 占用过高
        }
    }
}
```

通过这样的方式，我们就不需要手动加锁了。`ConcurrentQueue<T>` 会自动处理线程安全的问题。

### 用信号量来取代标志位

上面的代码中，我们又用到了轮询。但是这个轮询本质上做的事情是等待队列中有数据可用。基于这一思路，我们可以考虑用一个只在有新数据到来时才放行一次的信号量——也就是 `AutoResetEvent` 来替代它。

```csharp
class MyService
{
    private readonly ConcurrentQueue<int> _queue = new ConcurrentQueue<int>();
    private readonly AutoResetEvent _queueEvent = new AutoResetEvent(false); // 初始是关闭的

    public void Enqueue(int item)
    {
        _queue.Enqueue(item);
        _queueEvent.Set(); // 放行信号量
    }

    public void Worker()
    {
        while (!_shouldStop)
        {
            _queueEvent.WaitOne(); // 等待信号量放行

            if (_isRunning && _queue.TryDequeue(out var item)) // 也可以使用 TryDequeue
            {
                // 处理 item
            }
        }
    }
}
```

但是这个例子并不好，因为如果同时来了多条数据，那么我们虽然会调用多次 `Set`，但是信号量只会放行一次。可就有可能出现数据处理不及时的情况。所以更好的方式是使用 `Semaphore`。它好比一扇宽度可变的大门。每次放行都会让门变宽一些，而不像是 `AutoResetEvent` 那样只有开和关这两种状态。不过这个例子我们就不演示了，因为我们有更好的方法。

### 用 `BlockingCollection` 来实现生产者消费者模式

实际上，.NET 中已经提供了一个现成的类来实现生产者消费者模式——`BlockingCollection<T>`。它是一个线程安全的集合类型，而且它还提供了阻塞和通知的功能。我们可以直接用它来替代上面的 `ConcurrentQueue<T>` 和 `AutoResetEvent`。

```csharp
class MyService
{
    private readonly BlockingCollection<int> _queue = new BlockingCollection<int>();

    public void Enqueue(int item)
    {
        _queue.Add(item); // 添加数据到队列中
    }

    public void Worker()
    {
        while (!_shouldStop)
        {
            if (_isRunning && _queue.TryTake(out var item, Timeout.Infinite)) // 等待数据可用
            {
                // 处理 item
            }
        }
    }
}
```

这样，如果队列为空时，`TryTake` 会阻塞当前线程，直到有数据可用。当调用 `Add` 方法时，`BlockingCollection<T>` 会自动放行等待的线程。这样我们就不需要手动处理信号量了。

{{< notice info >}}
其实通过观察 `BlockingCollection<T>` 的[源代码](https://source.dot.net/#System.Collections.Concurrent/System/Collections/Concurrent/BlockingCollection.cs,3fc8b6e4e28ee36c)，我们不难发现它在底层用到了 `ConcurrentQueue<T>` 和 `SemaphoreSlim`。此外，它底层使用的集合类型也是可变的，比如 `ConcurrentStack<T>` 和 `ConcurrentBag<T>` 等。我们可以通过传入不同的集合类型来实现不同的行为。
{{< /notice >}}

## 总结

在这篇文章中，我们探讨了如何用信号量等机制来替代轮询标志位的方式，从而实现线程间的通信和控制。我们使用了 `ManualResetEvent`、`AutoResetEvent`、`CancellationToken` 和 `BlockingCollection<T>` 等类来实现这些功能。通过这些类，我们可以更优雅地实现多线程编程，避免了轮询和标志位带来的问题。

大家在实际的开发中，也一定要多多关注这些现成的类和工具，而不是盲目地自己造轮子。
