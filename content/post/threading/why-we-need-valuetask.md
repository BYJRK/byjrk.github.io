---
title: "为什么我们需要 ValueTask？"
description: "明明已经有 Task 了，为什么我们还需要 ValueTask？什么情况下应该使用它？"
slug: "why-we-need-valuetask"
date: 2024-04-12
image: https://s2.loli.net/2024/04/14/P4HJMlIpSxY6CDn.jpg
tags:
    - csharp
    - dotnet
    - async
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1dm421j72Y/)

自从 C# 5.0 引入了 `async` 和 `await` 语法以后，异步编程变得非常简单，而 Task 类型也在开发中扮演着相当重要的角色，存在感极高。但是在 .NET Core 2.0 这个版本，微软引入了一个新的类型 `ValueTask`，那么这个类型是什么？为什么我们需要它？什么情况下应该使用它？我们今天就来探讨一下。

## 简单回顾 `Task` 类型

在异步编程中，我们经常会使用 `Task` 类型来表示一个异步操作或者说异步任务。相较于其他一些主流编程语言，C# 中的异步任务其实开销很小。比如知乎上的大佬 hez2010 在他的[这个回答](https://www.zhihu.com/question/509501955/answer/3225113571)中提到，C# 的 Task 类型通常只占用 64~136 B 的内存，而 Go 语言的一个 goroutine 至少占用 2 KB 的内存。

不仅如此，Task 还有许多优化技巧，比如：

1. 如果想直接返回一个结果，可以使用 `Task.FromResult` 方法
2. 如果想直接返回一个已经完成的任务，可以使用 `Task.CompletedTask`
3. 如果想直接返回一个已经取消的任务，可以使用 `Task.FromCanceled`
4. 如果想直接返回一个已经失败的任务，可以使用 `Task.FromException`

等等。所以从 C# 5.0（大概是 .NET Framework 4 时代）开始，直到 .NET Core 2.0 之前，一直相安无事。

## 传统 `Task` 类型的问题

但是，随着 .NET 开始跨平台，能使用 C# 的场景越来越多，微软的“野心”也越来越大，开始从各种角度优化 C# 的性能，从而使 .NET 能够胜任各种任务场景。除了引入 `Span`、`Memory`、`ref struct` 等新特性外，还引入了 `ValueTask`。那么，传统的 `Task` 类型有什么问题呢？

首先我们要知道，`Task` 包含泛型版本和非泛型版本，分别对应有无返回值的异步任务。而 `ValueTask` 在诞生之初，只有一个泛型版本。换句话说，设计者认为，`ValueTask` 应当只适用于有返回值的异步任务。所以这里我们来看一个典型的例子：

```csharp
private readonly ConcurrentDictionary<int, string> _cache = new ();

public async Task<string> GetMessageAsync(int id)
{
    if (_cache.TryGetValue(id, out var message))
    {
        return message;
    }

    message = await GetMessageFromDatabaseAsync(id);
    _cache.TryAdd(id, message);

    return message;
}
```

在上面的 `GetMessageAsync` 方法中，我们首先尝试从缓存中获取消息，如果没有找到，就再尝试从数据库中获取。但这里有一个问题，如果缓存中有数据，那么虽然我们好像会直接返回一个值。但是，由于 `GetMessageAsync` 方法是一个异步方法，所以实际上会返回一个 `Task<string>` 类型的对象。这就意味着，即便我们本可以只返回一个值，我们依旧会多创建一个 `Task` 对象，这就导致了无端的内存开销。

{{<notice info>}}

这种在异步任务中直接返回一个值的情况，我们称之为“同步完成”，或者“返回同步结果”。线程进入这个异步任务后，并没有碰到 `await` 关键字，而是直接返回。也就是说，这个异步任务自始至终都是在同一个线程上执行的。

{{</notice>}}

## `ValueTask` 简介

所以，`ValueTask` 的主要作用就是解决这个问题。它在 .NET Core 2.0 被正式引入，并在 .NET Core 2.1 得到了增强（新增了 `IValueTaskSource<T>` 接口，从而使它可以拥有诸如 `IsCompleted` 等属性），并且还添加了非泛型的 `ValueTask` 类型（这个我们稍后再说）。

`ValueTask` 我们先不要去思考它是否为值类型，而是可以这么理解：**它适用于可能返回一个 `Value`，也可能返回一个 `Task` 的情形**。也就是说，它非常适合上面的“缓存命中”的典型场景。我们可以把上面的代码修改为：

```csharp
public async ValueTask<string> GetMessageAsync(int id)
{
    if (_cache.TryGetValue(id, out var message))
    {
        return message;
    }

    message = await GetMessageFromDatabaseAsync(id);
    _cache.TryAdd(id, message);

    return message;
}
```

此时，如果缓存中有数据，那么我们可以直接返回一个 `ValueTask<T>` 对象，而不需要再创建一个 `Task<T>` 对象。这样就避免了无端的堆内存开销；否则，我们才会创建 `Task<T>` 对象。或者说，在这种情况下，`ValueTask` 的性能会退化为 `Task`（甚至可能还稍微低一丁点，因为涉及到更多的字段，以及值拷贝等）。

{{<notice info>}}
至于非泛型版本的 `ValueTask`，它的使用情形就更少了。它只有在即使异步完成也可以无需分配内存的情况下才会派上用场。`ValueTask` 的“发明者”Stephen Toub 在[他的文章](https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/)中提到，除非你借助 profiling 工具确认 `Task` 的这一丁点开销会成为瓶颈，否则不需要考虑使用 `ValueTask`。
{{</notice>}}

这时候我们再来思考它的性能究竟如何：

顾名思义，`ValueTask` 是一个值类型，可以在栈上分配，而不需要在堆上分配。不仅如此，它因为实现了一些接口，从而使它可以像 `Task` 一样被用于异步编程。所以，照理说，`ValueTask` 的性能要比 `Task` 更好很多（就如同 `ValueTuple` 之于 `Tuple`、`Span` 之于 `Array` 一样）。

但是，`ValueTask` 真的这么美好吗？它是不是可以完全替代 `Task` 呢？事情恐怕并没有这么简单。

## `ValueTask` 的注意事项

现在，我们该谈一谈 `ValueTask` 在使用时需要注意的地方了。

### `ValueTask` 不能被多次等待（`await`）

`ValueTask` 底层会使用一个对象存储异步操作的状态，而它在被 `await` 后（可以认为此时异步操作已经结束），这个对象可能已经被回收，甚至有可能已经被用在别处（或者说，`ValueTask` 可能会从已完成状态变成未完成状态）。而 `Task` 是绝对不可能发生这种情况的，所以可以被多次等待。

### 不要阻塞 `ValueTask`

`ValueTask` 所对应的 `IValueTaskSource` 并不需要支持在任务未完成时阻塞的功能，并且通常也不会这样做。这意味着，你无法像使用 `Task` 那样在 `ValueTask` 上调用 `Wait`、`Result`、`GetAwaiter().GetResult()` 等方法。

但换句话说，如果你可以确定一个 `ValueTask` 已经完成（通过判断 `IsCompleted` 等属性的值），那么你可以通过 `Result` 属性来安全地获取 `ValueTask` 的结果。

{{<notice info>}}
微软专门添加了一个与这个有关的警告：[CA2012](https://learn.microsoft.com/zh-cn/dotnet/fundamentals/code-analysis/quality-rules/ca2012)
{{</notice>}}

### 不要在多个线程上同时等待一个 `ValueTask`

`ValueTask` 在设计之初就只是用来解决 `Task` 在个别情况下的开销问题，而不是打算全面取代 `Task`。因此，`Task` 的很多优秀且便捷的特性它都不用有。其中一个就是线程安全的等待。

也就是说，`ValueTask` 底层的对象被设计为只希望被一个消费者（或线程）等待，因此并没有引入线程安全等机制。尝试同时等待它可能很容易引入竞态条件和微妙的程序错误。而 `Task` 支持任意数量的并发等待。

## 如何克服 `ValueTask` 的局限性

在实际使用过程中，难免遇到需要突破它的上述限制的情况。那么我们该怎么办呢？这里给出几种常见情况的对应方式：

1. 如果希望用阻塞的方式（`Result` 与 `.GetAwaiter().GetResult()`）获取 `ValueTask<T>` 的结果，可以先判断 `IsCompleted` 或 `IsCompletedSuccessfully` 等属性的值，确认它已经完成，然后再获取结果
2. 如果希望等待多次，或在多个线程中等待等，那么可以使用 `AsTask()` 方法将其转为一个普通的 `Task`，进而再进行各种 `Task` 的常用操作

基于 `ValueTask` 的原理及限制，一个普遍认同的推荐用法是：

{{<notice tip>}}
绝大多数情况下，都推荐直接使用 `await` 关键字来等待一个返回值为 `ValueTask<T>` 的异步任务并获取结果，**而不是试图将其返回值赋值给一个变量**（最多是搭配 `ConfigureAwait()` 进行使用）；否则，建议使用 `AsTask()` 方法将其转为传统的 `Task`，再进行常规操作。
{{</notice>}}

## 总结

总的来说，`ValueTask` 确实有很多闪光点，比如在栈上分配来避免堆分配的性能开销，但它也有一些让人头疼的限制，比如不能被多次等待。使用它就像是在走钢丝，一不小心就可能掉进性能优化的陷阱里。但别担心，大多数情况下，我们还是可以安全地使用 `await` 来等待 `ValueTask<T>` 的，只要我们不试图把它当作 `Task` 的替代品来用就好。

希望看了这篇文章之后，大家能够正确使用 `ValueTask`。

## 参考链接

- [ValueTask Source Code](https://source.dot.net/#System.Private.CoreLib/src/libraries/System.Private.CoreLib/src/System/Threading/Tasks/ValueTask.cs,77a292425839ae85)
- [Understanding the Whys, Whats, and Whens of ValueTask | .NET Blog](https://devblogs.microsoft.com/dotnet/understanding-the-whys-whats-and-whens-of-valuetask/)
- [Working with ValueTask in C# | CodeGuru.com](https://www.codeguru.com/csharp/c-sharp-valuetask/)
- [Task vs ValueTask: When Should I use ValueTask? | YouTube.com](https://www.youtube.com/watch?v=dCj7-KvaIJ0)
- [Understanding how to use Task and ValueTask | YouTube.com](https://www.youtube.com/watch?v=fj-LVS8hqIE)