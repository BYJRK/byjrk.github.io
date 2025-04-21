---
title: "是不是所有 C# 中实现了 Dispose 方法的类我们都要用完即释放？"
slug: "no-need-to-always-call-dispose"
description: "在 C# 中，是否所有实现了 IDisposable 接口的类都需要在用后立刻调用 Dispose 方法？本文将通过几个典型的例子，来看看在什么情况下可以不调用 Dispose 方法，并从底层的原理出发，给大家提供一个判断是否有必要调用 Dispose 方法的思路。"
date: 2025-04-21
tags:
    - dotnet
    - csharp
    - gc
---

C# 作为一个有 GC（垃圾回收）的语言，在使用托管资源时，通常不需要开发者关注资源的释放问题。但如果使用了非托管资源（常见的如文件句柄、数据库连接等），就需要手动释放资源了。为了方便管理资源，并形成一种统一的规范，C# 提供了 `IDisposable` 接口（后来还提供了 `IAsyncDisposable` 接口），开发者可以通过这个接口提供的 `Dispose` 方法来释放资源，还可以借助 C# 的 `using` 语句来简化资源的释放过程。

那么问题来了：是否所有实现了 `IDisposable` 接口的类都需要在用后立刻调用 `Dispose` 方法？答案是：不一定。

这篇文章我们就借助几个典型的例子，来看看在什么情况下可以不调用 `Dispose` 方法，并从底层的原理出发，给大家提供一个判断是否有必要调用 `Dispose` 方法的思路。

## 实现 IDisposable 接口但不涉及资源释放的类

首先我们看第一种情况：有些类实现了 `IDisposable` 接口，但并不涉及资源的释放。这时候相信有的读者就会问了：这种情况有点太强行凑数了吧？而且这难道不是在滥用 `IDisposable` 吗，毕竟它本来是用来释放资源的啊？

其实未必。因为 C# 的 `using` 关键字提供了一个非常方便的语法糖，可以让我们在使用完一个对象后，自动调用它的 `Dispose` 方法中的逻辑（即便它可能与资源释放无关）。这样我们就可以实现延迟执行，以及在任何情况下（包括抛异常）都能够确保会执行的逻辑了。

首先我们简单回顾一下 `using` 关键字在幕后做的事情。我们这里看一个简单例子：

```csharp
using var fs = new FileStream("test.txt", FileMode.Open);
// 其他逻辑
```

上面的代码在编译后会变成下面的代码：

```csharp
var fs = new FileStream("test.txt", FileMode.Open);
try
{
    // 其他逻辑
}
finally
{
    if (fs != null)
    {
        ((IDisposable)fs).Dispose();
    }
}
```

{{< notice tip >}}
在上面的例子中，`using` 关键字并没有搭配花括号进行使用。这是 C# 8.0 中新增的语法糖，可以让我们减少一层缩进。它相当于花括号涵盖了从 `using` 关键字到作用域的结束这个范围。
{{< /notice >}}

我们可以看到，`using` 语句在编译后会变成一个 `try...finally` 语句块，确保了在 `try` 块中的代码执行完后，无论是否出现异常，最终都会执行 `finally` 块中的代码。

于是我们就可以借助这个语法来实现一些延迟执行的逻辑了，尤其是类似 Go 语言中的 `defer` 语句。Go 语言中，`defer` 语句会在函数返回时执行，比如下面这个例子：

```go
func main() {
    defer fmt.Println("defer")
    fmt.Println("hello")
}
```

于是我们可以仿照这个思路，在 C# 中实现一个类似的功能：

```csharp
class Defer : IDisposable
{
    private readonly Action _action;

    public Defer(Action action)
    {
        _action = action;
    }

    public void Dispose()
    {
        _action?.Invoke();
    }
}
```

它在构建时会传入一个 `Action` 委托，表示需要延迟执行的逻辑。然后我们就可以像下面这样使用它了：

```csharp
using var defer = new Defer(() => Console.WriteLine("defer"));
Console.WriteLine("hello");
```

所以对于这样的一个类，即便它实现了 `IDisposable` 接口，我们也不必须在使用完后，手动调用它的 `Dispose` 方法。因为它的 `Dispose` 方法并不涉及资源的释放，而只是执行一些延迟逻辑而已。

## 因为基类或接口的约束而实现 IDisposable 接口的类

除了上面提到的为了借助 `using` 语句来实现延迟执行的逻辑外，还有一些类实现了 `IDisposable` 接口，但并不涉及资源的释放。

我们都知道，C# 中有一些原生的数据流，比如 `FileStream`、`MemoryStream`、`GZipStream` 等等。它们的基类 `Stream` 实现了 `IDisposable` 接口，并且它们根据自己的实际情况，也各自提供了具体的 `Dispose` 方法的实现，比如 `FileStream` 会关闭文件句柄，从而释放文件资源，避免文件被占用。

但这其中的 `MemoryStream` 就有些非同寻常了。它虽然是一个数据流，但它并不涉及资源的释放。因为它的底层数据是存储在内存中的一个字节数组（`byte[]`）中，而这个字节数组是一个托管资源。在它的源代码中我们可以看到：

```csharp
public class MemoryStream : Stream
{
    private byte[] _buffer;    // Either allocated internally or externally.
    private readonly int _origin;       // For user-provided arrays, start at this origin
    private int _position;     // read/write head.
    private int _length;       // Number of bytes within the memory stream
    private int _capacity;     // length of usable portion of buffer for stream

    private bool _expandable;  // User-provided buffers aren't expandable.
    private bool _writable;    // Can user write to this stream?
    private readonly bool _exposable;   // Whether the array can be returned to the user.
    private bool _isOpen;      // Is this stream open or closed?

    // ...

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _isOpen = false;
            _writable = false;
            _expandable = false;
            // Don't set buffer to null - allow TryGetBuffer, GetBuffer & ToArray to work.
            _lastReadTask = default;
        }
    }
}
```

所以对于 `MemoryStream` 这样的 `Dispose` 方法并不涉及资源释放的类型，即便我们不调用它的 `Dispose` 方法，也不会造成资源泄漏。当然了，这并不意味着我们就不需要甚至不应该去做这件事情，因为规范的开发习惯仍旧是可以为我们的代码带来更好的可读性和可维护性的。

## 在特定情况下可以不调用 Dispose 方法的类

有些类提供了 `Dispose` 方法，但是在某些情况下，对这一方法的调用并不是至关重要的。这里有一个典型的例子就是我们在异步编程中常见的 `CancellationTokenSource`（下面简称为 CTS）。

首先我们来写一个简单的代码，并观察它在运行时的内存占用：

```csharp
for (int i = 0; i < 100000000; i++)
{
    var cts = new CancellationTokenSource();
}
```

运行后我们会发现，内存几乎没有任何变化。这是否意味着，CTS 的 `Dispose` 方法并不重要呢？其实并不是，但是在上面的这个用法中，调用与否确实没有太大的区别。这是怎么回事呢？

我们来观察 CTS 的 `Dispose` 方法的实现：

```csharp
protected virtual void Dispose(bool disposing)
{
    if (disposing && !_disposed)
    {
        ITimer? timer = _timer;
        if (timer != null)
        {
            _timer = null;
            timer.Dispose();
        }

        _registrations = null;

        if (_kernelEvent != null)
        {
            ManualResetEvent? mre = Interlocked.Exchange<ManualResetEvent?>(ref _kernelEvent!, null);
            if (mre != null && _state != States.NotifyingState)
            {
                mre.Dispose();
            }
        }

        _disposed = true;
    }
}
```

可以发现，这里它对两个“可有可无”的对象进行了回收，分别是：

- `_timer`：一个 `ITimer` 对象，表示一个定时器
- `_kernelEvent`：一个 `ManualResetEvent` 对象，是一个信号量

它们分别是做什么用的呢？首先我们来看定时器。我们知道，CTS 提供了延时自动取消的功能。比如我们希望在 5 秒后自动取消，那么实现方法可以是：

```csharp
var delay = TimeSpan.FromSeconds(5);
var cts = new CancellationTokenSource(delay);
// 或者也可以在创建后调用 CancelAfter 方法
```

此时，CTS 内部就会创建这个定时器，从而实现这个功能。在这一情况下，就会产生需要我们去释放的资源了。

另外一个信号量又是怎么回事呢？

我们都知道，CTS 现在常用于异步编程。它的 `CancellationToken` 可以传给标准库提供的 `Async` 结尾的方法，从而实现任务的取消。但是一些老的库函数可能并不支持 `CancellationToken`，这时候我们就可以借助 `token` 上的这个 `WaitHandle` 来实现任务的取消了。下面是 CTS 中关于 `WaitHandle` 属性的实现：

```csharp
internal WaitHandle WaitHandle
{
    get
    {
        ThrowIfDisposed();

        // Return the handle if it was already allocated.
        if (_kernelEvent != null)
        {
            return _kernelEvent;
        }

        // Lazily-initialize the handle.
        var mre = new ManualResetEvent(false);
        if (Interlocked.CompareExchange(ref _kernelEvent, mre, null) != null)
        {
            mre.Dispose();
        }

        if (IsCancellationRequested)
        {
            _kernelEvent.Set();
        }

        return _kernelEvent;
    }
}
```

可以发现，它默认是没有值的；当我们第一次访问它时，它便会创建一个新的，并返回它。这样的操作就会产生一个需要我们去释放资源的对象。我们可以做这样的一个实验：

```csharp
for (int i = 0; i < 100000000; i++)
{
    var cts = new CancellationTokenSource();
    var handle = cts.Token.WaitHandle;
}
```

{{< notice tip >}}
`WaitHandle` 在 CTS 上是 `internal` 的，我们只能也应当在 `CancellationToken` 上去访问，因为通常情况下，我们传给方法的参数并不是 CTS 对象本身，而是它的 `Token`。
{{< /notice >}}

然后运行程序，就会发现内存在不断增加。只要我们调用了 `CTS` 的 `Dispose` 方法，内存便会不再上升。

所以我们可以得出结论：如果我们在使用 CTS 时，既不使用延时自动取消的功能，也不使用 `WaitHandle` 属性，那么我们不调用 `Dispose` 方法也不会造成资源的泄漏。

## 虽然提供了 Dispose 方法，但不应该用完立即释放的类

还有一种情况是，虽然类实现了 `IDisposable` 接口，但我们并不应该在用完后立即释放它。它被设计出来就是希望我们能够复用的。典型的例子就是 `HttpClient`。

比如下面这个错误例子：

```csharp
List<string> urls = new List<string>()
{
    "https://www.baidu.com",
    "https://www.sogou.com",
    "https://www.sohu.com",
};

foreach (var url in urls)
{
    using var client = new HttpClient();
    await client.GetAsync(url);
}
```

这个例子就是一个错误的用法。正确的做法应该是将 `HttpClient` 的声明移动到循环外部，或者还可以声明为一个静态对象等。这是为什么呢？

简单来说，`HttpClient` 底层会使用 `HttpClientHandler` 去处理涉及到连接池、Socket、TCP 连接等资源的管理。TCP 连接因为比较昂贵（比如有三次握手、四次挥手等），所以它通常会被复用。当我们使用 `HttpClient` 去访问一个链接时，访问结束后这个 TCP 连接并不会立即关闭，而是会被放入连接池中，等待下次的复用。

但是，如果我们在每次请求时都创建一个新的 `HttpClient` 对象，那么这个 TCP 连接就会占据连接池中的一个位置，还有本地端口等资源，最终可能会导致连接池或本地端口的耗尽，进而抛出 `SocketException` 等异常。

因为 `HttpClient` 是一个包装好的功能相当灵活的类，因此我们完全可以只创建一个，并且多次使用。不管我们访问的链接是否可以复用，怎么复用，保持连接状态多久，都会被它妥善处理。所以对于一个本地项目（如控制台应用、WPF 应用等），我们完全可以创建一个单例并处处使用它。

如果我们在项目中还使用了 DI 容器（比如微软官方提供的 `Microsoft.Extensions.DependencyInjection`），那么我们可以将 `HttpClient` 注册为一个单例的服务。这样我们就可以在整个项目中复用它了。

```csharp
var services = new ServiceCollection();
services.AddSingleton<HttpClient>();
var serviceProvider = services.BuildServiceProvider();

var client = serviceProvider.GetService<HttpClient>();
```

当然了，这个方式并不是最推荐的方式（不过对于简单的本地项目来说是可取的）。对于复杂些的项目，我们更应该考虑的方式是使用 `HttpClientFactory`。要使用它，我们还要引入一个包：`Microsoft.Extentions.Http`（控制台或 WPF 等本地程序通常需要，而 `ASP.NET Core` 项目会自动引入它，因此就不需要额外安装包了），然后就可以使用了：

```csharp
var services = new ServiceCollection();
services.AddHttpClient();
var serviceProvider = services.BuildServiceProvider();

var factory = serviceProvider.GetService<IHttpClientFactory>();
var client = factory.CreateClient();
```

对于更加复杂的情况，比如我们希望为不同的服务类注入配置不同的 `HttpClient`（比如不同的 BaseAddress、Header、Timeout 等），我们可以使用 `AddHttpClient` 的“命名客户端”的方法来实现：

```csharp
var services = new ServiceCollection();
services.AddHttpClient("baidu", c =>
{
    c.BaseAddress = new Uri("https://www.baidu.com");
    c.Timeout = TimeSpan.FromSeconds(30);
});
services.AddHttpClient("sogou", c =>
{
    c.BaseAddress = new Uri("https://www.sogou.com");
    c.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3");
});
var serviceProvider = services.BuildServiceProvider();

var factory = serviceProvider.GetService<IHttpClientFactory>();
var baiduClient = factory.CreateClient("baidu");
var sogouClient = factory.CreateClient("sogou");
```

这样我们就可以为不同的服务类注入不同的 `HttpClient` 了。关于 `HttpClientFactory` 的更多用法，可以参考[官方的教程](https://learn.microsoft.com/zh-cn/aspnet/core/fundamentals/http-requests?view=aspnetcore-9.0)。

## 总结

在这篇文章中，我们讨论了在 C# 中是否需要总是调用 `Dispose` 方法的问题。我们通过几个典型的例子，来看看在什么情况下可以不调用 `Dispose` 方法，并从底层的原理出发，给大家提供一个判断是否有必要调用 `Dispose` 方法的思路。

在实际的开发中，与其说我们需要分辨出哪些对象是可以不用释放的，不如说我们应当明白如何对这一操作的必要性进行正确的判断，并养成统一且规范的开发习惯。这样不管是对团队的其他开发者，还是未来的自己，都是有好处的。
