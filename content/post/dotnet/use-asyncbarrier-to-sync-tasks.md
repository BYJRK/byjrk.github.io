---
title: "使用 AsyncBarrier 来等待并同步多个异步任务"
slug: "use-asyncbarrier-to-sync-tasks"
description: 如果在异步编程开发过程中遇到了多个异步任务需要在某一时刻全部完成后才能继续执行的情形，那么可以使用 AsyncBarrier 来帮助我们实现这一需求。这篇文章我们就来学习一下如何将它用在一个 WPF 项目中。
image: https://s2.loli.net/2024/08/11/15IEZJX7fCq4caS.jpg
date: 2024-08-11
tags:
    - dotnet
    - csharp
    - async
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1Gx4y1479f/)

大家在做异步编程开发的时候，不知道是否会遇到这样的一种情形：

有多个异步任务，这些任务之间没有依赖关系，但是我们需要等待所有任务都完成后再继续执行后续的操作。我们唯一知道的，就是这些任务的数量。

举个例子：我们现在有三个 IO 相关的异步任务。这些任务的先后顺序是不确定的，并且这些任务也不必同时发起，但是我们需要等待这三个任务都完成后再继续执行后续的操作。

对于最普通的等待多个异步任务，我们首先肯定会想到使用 `Task.WhenAll` 方法。但是 `Task.WhenAll` 现在并不能满足我们的需求，因为它需要能够立刻获取到所有任务的集合。并且因为我们希望在每个异步任务的中间某个环节去等待其他任务的完成，而并不是所有异步任务都会在同一时间点发起，所以这就产生了一个矛盾。

这时候大家可能会想到另外一种更加简单粗暴的方式：我们创建一个局部字段 `int count`，然后每个异步任务完成后，我们将 `count` 自增。当 `count` 的值等于我们预期的任务数量时，我们就可以继续执行后续的操作。这种方式虽然可以解决问题，但是实现起来比较繁琐，因为我们还需要考虑使用什么机制来控制这些异步任务在 `count` 达到预期值时进行后续操作。最简单的方式无疑是使用轮询，但这显然是不够好的。聪明一些的方式是使用信号量，如 `SemaphoreSlim`，或者其他库提供的 `AsyncAutoResetEvent` 等。当然，我们还可以采用更加轻量的 TCS（`TaskCompletionSource`）来实现。但即便思路已经有了，实际实现起来依旧非常复杂，因为我们还要考虑 `count` 变量的线程安全、异常处理、取消任务等。

## 引入 AsyncBarrier

这时候，`AsyncBarrier` 就派上用场了。`AsyncBarrier` 是一个非常轻量级的类，它可以帮助我们等待并同步多个异步任务。这个类是由 `Microsoft.VisualStudio.Threading` 提供的，我们可以轻易地找到[它的源代码](https://github.com/microsoft/vs-threading/blob/main/src/Microsoft.VisualStudio.Threading/AsyncBarrier.cs)。

实际在使用时，我并不推荐大家去直接将 `Microsoft.VisualStudio.Threading` 这个库引入到项目中，因为这个库本身是一个非常庞大的库，而且里面还包含了一些代码分析器（Code Analyzers），会给我们的项目添加一些恼人的“波浪线”。所以，一般情况下，我更推荐大家去使用 `Nito.AsyncEx` 这个库。但是它又不包含 `AsyncBarrier` 这个类，所以我们可以直接将 `AsyncBarrier` 的源代码复制到我们的项目中，然后稍作修改即可。如果你不想麻烦，我也提供了一个开箱即用的版本，在 [GitHub Gist](https://gist.github.com/BYJRK/b1b893bb5660cea32326025f49116609) 上。

我们来简单理解一下它的源代码。这里我节选了一部分：

```csharp
public class AsyncBarrier
{
    private readonly int participantCount;

    private readonly Stack<Waiter> waiters;

    public AsyncBarrier(int participants)
    {
        if (participants <= 0)
            throw new ArgumentOutOfRangeException(
                nameof(participants),
                $"Argument {nameof(participants)} must be a positive number."
            );
        this.participantCount = participants;

        this.waiters = new Stack<Waiter>(participants - 1);
    }

    public ValueTask SignalAndWait(CancellationToken cancellationToken)
    {
        lock (this.waiters)
        {
            if (this.waiters.Count + 1 == this.participantCount)
            {
                while (this.waiters.Count > 0)
                {
                    Waiter waiter = this.waiters.Pop();
                    waiter.CompletionSource.TrySetResult(default);
                    waiter.CancellationRegistration.Dispose();
                }

                return new ValueTask(
                    cancellationToken.IsCancellationRequested
                        ? Task.FromCanceled(cancellationToken)
                        : Task.CompletedTask
                );
            }
            else
            {
                TaskCompletionSource<EmptyStruct> tcs =
                    new(TaskCreationOptions.RunContinuationsAsynchronously);
                CancellationTokenRegistration ctr;
                if (cancellationToken.CanBeCanceled)
                {
                    ctr = cancellationToken.Register(
                        static (tcs, ct) =>
                            ((TaskCompletionSource<EmptyStruct>)tcs!).TrySetCanceled(ct),
                        tcs
                    );
                }
                else
                {
                    ctr = default;
                }

                this.waiters.Push(new Waiter(tcs, ctr));
                return new ValueTask(tcs.Task);
            }
        }
    }
}
```

这里还有另外两个类型 `Waiter` 和 `EmptyStruct`，这里由于篇幅的关系就不展示了。它们做的事情也非常简单，前者用于存储等待器的信息，后者则是一个空结构体，用于表示一个空的异步操作。它们并不是我们的重点，所以就不展开讨论了。

我们不难观察到这么几点：

1. 它内部有一个 `participantCount` 字段，表示参与者的数量；另外还有一个 `Stack`，用来存储所有等待的参与者；
2. 它只有一个公开的方法 `SignalAndWait`，表示调用者现在要进入等待状态。在这个方法中：
   - 首先，它会判断当前等待的参与者数量是否等于预期的参与者数量。如果是，那么就将等待器逐个从 `Stack` 中弹出并唤醒；
   - 如果不是，那么就创建一个新的 `TaskCompletionSource`，并将其存入 `Stack` 中，然后返回这个 `TaskCompletionSource` 的 `Task` 给参与者用于 `await`。
3. 当所有参与者都到齐后，`SignalAndWait` 方法会返回一个已完成的 `ValueTask`，这时候所有参与者都可以继续执行后续的操作。

{{<notice info>}}
这里其实还有一个小细节，就是 `Stack` 的容量是 `participantCount - 1`。这是因为我们并不需要将最后一个参与者也入栈。毕竟，当“倒数第一”到达终点时，我们就可以宣告比赛结束了。
{{</notice>}}

## 使用 AsyncBarrier

现在我们就可以来用一用它了。我们这里借助 `CommunityToolkit.Mvvm` 这个库来写一个视图模型（ViewModel），大致如下：

```csharp
partial class MainViewModel : ObservableObject
{
    public ObservableCollection<string> Results { get; } = new();

    private AsyncBarrier _asyncBarrier = new(3);

    [RelayCommand]
    async Task FirstJobAsync(CancellationToken token)
    {
        await Task.Delay(1500, token);
        Results.Add("First job completed. Waiting for async barrier...");
        await _asyncBarrier.SignalAndWait(token);
        Results.Add("First job completed.");
    }

    [RelayCommand]
    async Task SecondJobAsync(CancellationToken token)
    {
        await Task.Delay(1500, token);
        Results.Add("Second job completed. Waiting for async barrier...");
        await _asyncBarrier.SignalAndWait(token);
        Results.Add("Second job completed.");
    }

    [RelayCommand]
    async Task ThirdJobAsync(CancellationToken token)
    {
        await Task.Delay(1500, token);
        Results.Add("Third job completed. Waiting for async barrier...");
        await _asyncBarrier.SignalAndWait(token);
        Results.Add("Third job completed.");
    }
}
```

这里我们定义了三个异步方法 `FirstJobAsync`、`SecondJobAsync` 和 `ThirdJobAsync`，它们分别模拟了三个异步任务。这三个任务之间没有依赖关系，但是我们希望在它们都完成后再继续执行后续的操作。我们在类中声明了一个 `AsyncBarrier` 字段，然后让这三个任务都调用它的 `SignalAndWait` 方法，这样就可以保证这三个任务都完成后才会继续执行后续的操作。

实际运行代码，我们可以发现确实达到了我们想要实现的效果。这三个按钮可以让用户以任意的顺序及时间间隔进行点击，并且每个任务接近完成的时候，都会进入等待状态。只有当所有任务都完成后，我们才会看到所有任务都已完成的提示。

更棒的是，`AsyncBarrier` 还可以重复使用。毕竟它底层只是一个 `Stack`。我们在等待时会入栈，等待完成后会出栈，最终使它回归初始状态。这样我们就可以在界面中反复实验这一现象。

## 取消任务

现在我们希望更进一步，为这些异步任务添加取消功能。那么，首先我们可以添加 `InitAllJobs` 与 `FinishJobs` 两个方法：

```csharp
private AsyncBarrier? _asyncBarrier;

[MemberNotNull(nameof(_asyncBarrier))] // 提示编译器，这个方法会确保 _asyncBarrier 不为空
private void InitJobs()
{
    if (_asyncBarrier == null)
    {
        _asyncBarrier = new AsyncBarrier(3);
        Results.Clear();
    }
}

private void FinishJobs(bool success = true)
{
    if (_asyncBarrier != null)
    {
        _asyncBarrier = null;
        if (success)
            Results.Add("All jobs completed successfully.");
        else
            Results.Add("Jobs were canceled.");
    }
}
```

这两个方法分别用于初始化任务与结束任务。在初始化任务时，我们会创建一个新的 `AsyncBarrier` 实例，并清空 `Results` 集合。在结束任务时，我们会将 `AsyncBarrier` 实例置空，并根据是否成功完成任务来添加提示信息。

{{<notice tip>}}
这其实也是我比较推荐的使用 `AsyncBarrier` 的方式。虽然我们前面说了，它可以被重复使用。但是观察它的源代码会发现，它非常轻量，也不需要担心资源释放的问题，因为我们大可以每次使用的时候都实例化一个新的出来。毕竟这样还有一个好处，就是每次我们都可以根据实际情况去调整它的 `participantCount`。
{{</notice>}}

接下来我们就可以在每个异步任务中添加取消逻辑。以 `FirstJobAsync` 为例：

```csharp
[RelayCommand]
async Task FirstJobAsync(CancellationToken token)
{
    InitJobs();

    try
    {
        await Task.Delay(1200, token);
        Results.Add("First job completed. Waiting for async barrier...");

        await _asyncBarrier.SignalAndWait(token);

        FinishJobs();
    }
    catch (TaskCanceledException)
    {
        Results.Add("First job was canceled.");
        FinishJobs(false);
    }
}
```

这里的大致思路是：

1. 首先会调用 `InitJobs` 方法，初始化任务。这里每个异步方法都会尝试去初始化，但只有第一个（即 `AsyncBarrier` 字段为空时）是有效的；
2. 在异步任务中使用 `try-catch` 块，捕获 `TaskCanceledException` 异常。因为如果我们想要取消任务，那么这个异步任务中的 `Task.Delay` 以及 `AsyncBarrier.SignalAndWait` 都会抛出这个异常；
3. 当异步任务完成时，会调用 `FinishJobs` 方法，结束任务。并且这里类似 `InitJobs`，只有第一个异步任务会有效调用。

然后，我们还需要一个 `RelayCommand`，用来实现取消功能：

```csharp
[RelayCommand]
private void CancelAllJobs()
{
    if (FirstJobCommand.IsRunning) FirstJobCommand.Cancel();
    if (SecondJobCommand.IsRunning) SecondJobCommand.Cancel();
    if (ThirdJobCommand.IsRunning) ThirdJobCommand.Cancel();
}
```

这样我们就实现了想要的效果了。此时，我们在 XAML 中的代码如下：

```xml
<Window ...>
    <Window.DataContext>
        <local:MainViewModel />
    </Window.DataContext>
    <DockPanel >
        <DockPanel DockPanel.Dock="Bottom" LastChildFill="False">
            <Button Content="Job1" Command="{Binding FirstJobCommand}" />
            <Button Content="Job2" Command="{Binding SecondJobCommand}" />
            <Button Content="Job3" Command="{Binding ThirdJobCommand}" />
            <Button Content="Cancel" Command="{Binding CancelAllJobsCommand}" DockPanel.Dock="Right" />
        </DockPanel>
        <ListBox ItemsSource="{Binding Results}" />
    </DockPanel>
</Window>
```

其实上面的故事还没有结束，因为实际运行后会发现，`Cancel` 按钮在任何时候都是可用的。这是因为我们没有正确处理它的 ICommand 的 `CanExecute` 方法。这里我就不展开讲了，我在视频中有详细讲解，大家可以在文章开头找到相应的视频链接。

## 总结

`AsyncBarrier` 是一个非常轻量级的类，它可以帮助我们等待并同步多个异步任务。它的实现非常简单，但是却非常实用。我们可以在异步任务中使用它，来保证多个异步任务都完成后再继续执行后续的操作。同时，我们还可以在异步任务中添加取消逻辑，来保证任务的可靠性。

大家如果有这样的需求，不妨去试一下这个类，相信一定可以帮上忙。不仅如此，我们还可以借此学习微软官方的源代码，了解一下它的实现细节。这对我们提升编程能力也是非常有帮助的。