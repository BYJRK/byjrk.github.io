---
title: "如何在 C# 中模拟 Go 的 defer 关键字并用于客户端开发"
slug: "mimic-go-defer-in-csharp"
description: "Go 语言中的 defer 关键字非常好用，可以用来释放资源，关闭文件等。本文介绍了如何在 C# 中模拟 Go 的 defer 关键字，并将其用于 WPF 客户端开发。"
image: https://s2.loli.net/2024/05/28/WyuKtqiXZQ3pDEA.jpg
date: 2024-05-28
tags:
    - dotnet
    - csharp
    - wpf
    - syntax
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1Ym421T7CS/)

## Go 中的 defer 大概是怎么一回事

Go 语言中有一个非常好用的 `defer` 关键字。`defer` 会在函数返回之前执行，可以用来释放资源，关闭文件等。比如我们想打开并读取一个外部文件的内容，我们可以这样写：

```go
func ReadFile() {
    file, err := os.Open("file.txt")

    // 如果打开文件失败，直接返回
    if err != nil {
        log.Fatal(err)
    }

    // 在函数返回之前关闭文件
    defer file.Close()

    // 读取文件内容
    content := make([]byte, 1024)
    file.Read(content)
    fmt.Println(string(content))
}
```

在这个例子中，我们使用 `defer` 关键字来确保在函数返回之前关闭文件。这样我们就不用担心忘记关闭文件，导致资源泄漏。

其实在 C# 和 Python 中，我们也可以借助一些特殊的语法来实现类似的效果。比如在 C# 中，我们可以使用 `using` 关键字来确保资源在使用完之后被释放；在 Python 中，我们可以使用 `with` 关键字来确保资源在使用完之后被释放。

但有些时候，我们想要实现的功能只是希望在离开作用域之前执行一些代码，而不是释放资源。这种情况下，我们仍然可以借助 `using` 关键字来实现，可以为我们带来意想不到的便利。

## 在 C# 中模拟 Go 的 defer

前面已经提到，我们需要在 C# 中使用 `using` 关键字来模拟 Go 的 `defer`。但是 `using` 关键字只能用于“释放资源”，或者说需要对一个实现了 `IDisposable` 接口的对象进行操作。那么我们就必须实现 `Dispose` 相关的逻辑了。话虽如此，并没有人规定我们必须在 `Dispose` 方法中执行释放资源的逻辑。比如我们前面提到的，希望在离开作用域之前执行一些代码，就可以放在 `Dispose` 方法中去执行。

基于这个思路，我们可以写出这样的代码：

```csharp
public class MyDisposable : IDisposable
{
    private readonly Action _callback;

    public MyDisposable(Action callback)
    {
        _this._callback = callback;
    }

    public void Dispose() => _callback();
}
```

这样我们就可以在 `Dispose` 方法中执行我们想要执行的代码了。比如我们可以这样使用：

```csharp
void Foo()
{
    using var md = new MyDisposable(() => Console.WriteLine("Job is done."));

    // Do something
}
```

我们在上面的例子中还用到了 C# 8.0 的新特性：`using` 语法的改进。在 C# 8.0 中，我们可以省略 `using` 语句中的大括号，直接在 `using` 语句后面写一个表达式。这样我们就可以更加简洁地使用 `using` 语法了。

它实际对应的底层 C# 代码是这样的：

```csharp
void Foo()
{
    MyDisposable md = new MyDisposable(() => Console.WriteLine("Job is done."));
    try
    {
        // Do something
    }
    finally
    {
        if (md != null)
        {
            md.Dispose();
        }
    }
}
```

所以可以保证 `finally` 语句中的代码一定会被执行，即使在 `try` 语句中抛出了异常。

## 这一技巧在 WPF 开发中的妙用

其实这个小妙招并不是我的原创，而是油管上的 [Jason Williams](https://www.youtube.com/@jason-williams) 在他的[一期视频](https://www.youtube.com/watch?v=DOtS7IOtACI)中提到的。在他的视频中，他为我们提供了一个绝妙的点子。

我们在做 WPF（以及其他诸如 Win UI、Avalonia 等）的客户端开发时，经常会遇到一个问题，就是需要去管理一个进度条的可见状态。比如我们现在有一个异步任务，我们希望任务在执行期间能够显示一个进度条，任务执行完毕（不管成功与否）后进度条消失。通常我们的做法是：

```csharp
// 模拟搜索电影的异步任务
public bool IsBusy { get; set; } = false; // 控制进度条是否可见，且该属性具备通知功能

async Task SearchMovieAsync(string movieName)
{
    IsBusy = true;

    if (!CanSearch())
    {
        IsBusy = false;
        return;
    }

    var resList = await SearchMoviesFromInternetAsync(movieName);
    if (resList == null || resList.Count == 0)
    {
        IsBusy = false;
        return;
    }

    foreach (var res in resList)
    {
        // Do something
    }

    IsBusy = false;
}
```

可以看到，我们在方法中需要多次根据情况设置 `IsBusy` 属性。这样的代码看起来不太优雅。为了解决这个问题，我们就可以用上前面实现的类了。不过我们需要稍微修改一下，使它的回调函数可以接受一个参数：

```csharp
public class BusyDisposable : IDisposable
{
    private readonly Action<bool> _busySetter;

    public BusyDisposable(Action<bool> busySetter)
    {
        _busySetter = busySetter;
        _busySetter(true);
    }

    public void Dispose() => _busySetter(false);
}
```

然后我们就可以这样使用了：

```csharp
async Task SearchMovieAsync(string movieName)
{
    using var _ = new BusyDisposable(value => IsBusy = value);

    if (!CanSearch())
    {
        return;
    }

    var resList = await SearchMoviesFromInternetAsync(movieName);
    if (resList == null || resList.Count == 0)
    {
        return;
    }

    foreach (var res in resList)
    {
        // Do something
    }
}
```

{{<notice info>}}
这里有一个需要注意的点：我们是在 ViewModel 中对 `IsBusy` 进行的操作，并借助绑定来控制前台进度条的显示。**这无形中帮助我们解决了一个重要的隐患：线程安全**。即便我们在非 UI 线程中修改了 `IsBusy` 属性，由于 WPF 的数据绑定机制，我们也不用担心线程安全问题。

但如果是在 View 中去直接操作进度条的 `Visibility` 属性，那么就可能需要我们自己去处理线程安全问题了。常见的方式比如使用 `Dispatcher`，或参考我的这篇 [关于使用 IProgress 的文章](/posts/how-to-report-progress)。
{{</notice>}}

相信大家立刻就能够明白这个方式有多么简洁和优雅了。我们通过使用 `using` 关键字，保证了当前作用域中的代码不管是正常执行还是异常退出，都会在离开作用域之前执行 `IsBusy = false` 这一行代码。这样我们就不用在方法中多次设置 `IsBusy` 属性了。

甚至我们还能再稍微优化一下，比如使用一个自动属性来简化 `BusyDisposable` 的实例化：

```csharp
private BusyDisposable NewBusyDisposable 
    => new BusyDisposable(value => IsBusy = value);

async Task SearchMovieAsync(string movieName)
{
    using var _ = NewBusyDisposable;

    // ...
}
```

这样我们就可以进一步简化这一语法，从而使其更接近 Go 语言中的 `defer` 关键字的使用方式。

## 总结

本期内容主要介绍了 Go 语言中的 `defer` 关键字，以及如何在 C# 中模拟 `defer` 的实现。虽然我们似乎一定程度上“滥用”了 `using` 关键字以及 `IDisposable` 接口，但这种方式确实可以带来一些意想不到的便利。

油管上的这位 Jason Williams 也绝对是一位大神。虽然他视频非常少，粉丝也只有几百，但是每期内容都堪称精品。大家有机会的话也可以去关注一下他，相信一定会有所收获。