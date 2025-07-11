---
title: "借助 ObservableCollections 获得更多具有通知功能的集合类型"
slug: "more-observable-collections"
description: "相信很多人在做 WPF、Avalonia 等开发时，都会遇到 ObservableCollection 没有批量操作的功能、缺少 ObservableDictionary 等集合类型等问题。本文介绍了一个 NuGet 包 ObservableCollections，它提供了多种实用的具有通知功能的集合类型。"
date: 2025-07-11
math: true
tags:
    - dotnet
    - csharp
    - wpf
    - avalonia
    - collection
    - observable
    - notification
---

如果大家在做基于 C# 的 WPF、Avalonia、Win UI 等开发，尤其是遵循 MVVM 模式时，遇到过下面的这些烦恼：

1. `ObservableCollection` 没有批量操作的功能（例如 `AddRange`）
2. 缺少 `ObservableDictionary`、`ObservableSet`、`ObservableQueue` 等集合类型
3. 难以实现诸如过滤、映射等功能

那么，`ObservableCollections` 这个 NuGet 包一定可以帮到你。没错，它就提供了一系列实用的具有通知功能的集合类型，使我们在 WPF、Avalonia、甚至 Unity 开发中都能够用得上。

## 安装

它的源代码链接在 [GitHub](https://github.com/Cysharp/ObservableCollections) 上。

如果想要安装它，我们只需要在 NuGet 包管理器中搜索 `ObservableCollections`，或者直接在项目中运行以下命令：

```bash
dotnet add package ObservableCollections
```

安装之后即可使用。注意它还有一个结尾包含 `R3` 的版本，是为它开发的 R3 库而准备的，通常我们不需要使用。这个 R3 库简单来说，就是一个更加高性能的 Rx.NET。

{{< notice info >}}
说起它的开发者 [Cysharp](https://github.com/Cysharp)，那可真的可以说是如雷贯耳。比如他们开发的 `Unitask`，就是一个非常流行的适用于 Unity 的异步编程库；而他们开发的 `ZLinq`，最近也是非常有名。油管上的 Nick Chapsas 也 [曾经介绍过这个库](https://www.youtube.com/watch?v=pUBc9uutSZM)。
{{< /notice >}}

## 支持批量操作的可观测集合

我们先来看一看它最简单的 `ObservableList`。它是一个具有通知功能的列表，并且支持批量操作。我们只需要实例化，然后就可以使用它了：

```csharp
class MainViewModel
{
    private readonly ObservableList<string> _items = new();

    public MainViewModel()
    {
        // 添加单个元素
        _items.Add("Item 1");
        
        // 批量添加元素
        _items.AddRange(GetItems());
    }

    private IEnumerable<string> GetItems()
    {
        // 假定这个方法可以从某个数据源获取一些数据
    }
}
```

通过观察可以发现，这个集合类型提供了 `CollectionChanged` 事件，我们可以通过订阅它来监听集合的变化。但是先不要想当然地认为它和 `ObservableCollection` 一样。实际上，它的 `CollectionChanged` 事件并不是来自我们熟悉的那个 `INotifyCollectionChanged` 接口，而是这个库自带的一个接口。所以我们在上面的代码中，并没有直接将这个集合声明为 `public` 的属性，从而在 XAML 中绑定。

那么它为什么要这样做，让我们不能方便地使用呢？其实原因很简单：这个库不单单适用于 WPF，它还可以用于 Avalonia、Unity 等框架。为了兼容更多的框架，它就没有使用 `INotifyCollectionChanged` 接口，而是提供了一个更通用的接口。

但不必担心，它并没有止步于此，而是专门提供了方便我们在 WPF、Avalonia 等框架中使用的额外类型。简单来说，我们只需要调用它的下面这个方法，即可将它转为可以用于 XAML 绑定的集合对象：

```csharp
class MainViewModel
{
    private readonly ObservableList<string> _items = new();

    public INotifyCollectionChangedSynchronizedViewList<string> Items { get; }

    public MainViewModel()
    {
        Items = _items.ToNotifyCollectionChanged();
    }
}
```

这里的 `INotifyCollectionChangedSynchronizedViewList` 就继承了 `INotifyCollectionChanged` 接口，因此实现了该接口的对象就可以直接在 XAML 中绑定使用，例如：

```xml
<ListBox ItemsSource="{Binding Items}" />
```

接下来，我们只需要在后台操作 `_items` 集合，它的变化即可同步到 `Items` 集合中，从而在 UI 上自动更新。

## 创建集合视图

实际上，对于 `ObservableList`，我们除了可以使用 `ToNotifyCollectionChanged` 方法将其转换为可以用于 XAML 绑定的集合类型外，还可以使用 `ToNotifyCollectionChangedSlim` 方法，将它转为一个更加轻量级的集合类型。这个类型同样实现了 `INotifyCollectionChanged` 接口，但它的性能更高，适用于需要频繁更新的场景。代价是，它将不提供 `AddRange` 等批量操作方法。

这时候可能有同学就会问了：我用 `ObservableList` 而不是原生的 `ObservableCollection`，不就是为了它提供的批量操作方法吗？如果我不需要批量操作，直接用 `ObservableCollection` 不就行了吗？

这就引出了我们即将介绍的下一个功能，同时也是这个库相当重要的功能：`View`。这个 `View` 不是我们常说的 MVVM 中的视图，而是指对集合的视图。它可以让我们在不改变原始集合的情况下，对集合进行过滤、映射等操作。我们不需要关注视图的实现细节，只需要操作后台的集合，即可将更改同步到界面中。

```csharp
class MainViewModel
{
    private readonly ObservableList<string> _items = new();

    private readonly ISynchronizedView<string, string> _syncView;

    public INotifyCollectionChangedSynchronizedViewList<string> Items { get; }

    public MainViewModel()
    {
        _syncView = _items.CreateView(s => s.ToUpper());
        Items = _syncView.ToNotifyCollectionChanged();
    }

    public void ToggleFilter(bool useFilter)
    {
        if (useFilter)
        {
            _syncView.AttachFilter(s => s.StartsWith("A")); // 过滤以 "A" 开头的元素
        }
        else
        {
            _syncView.ResetFilter(); // 清除过滤器
        }
    }
}
```

{{< notice tip>}}
如果我们只是想使用映射功能，那么使用 `ToNotifyCollectionChanged` 方法即可。它有一个重载，可以传入一个表示映射方式的 `Func`。另外，它还支持传入一个类似 `Dispatcher` 的参数，用于在 UI 线程上执行映射操作。至于为什么不是 WPF 中的 `Dispatcher`，而是一个它自己声明的类型，这也是为了兼容更多的框架。
{{< /notice >}}

在上面的代码中，我们创建了一个视图 `_syncView`。在创建时，我们就指定了一个映射函数，将集合中的每个元素转换为大写形式。然后在 `ToggleFilter` 方法中，我们可以通过 `AttachFilter` 及 `ResetFilter` 方法来添加或移除过滤器。就这样，我们轻松地实现了对集合的过滤和映射功能。

简单想象一下，这些功能在 WPF、Avalonia 等框架中原本实现起来会多么麻烦。对于映射，我们可以借助 `DataTemplate` 以及 `ValueConverter` 来实现；而对于过滤，我们可能需要使用 `CollectionView` 或者  `ICollectionView` 等。这些都需要我们编写大量的样板代码。

## 可观测的字典

WPF 中其实有一个 [`ObservableDictionary`](https://source.dot.net/#PresentationFramework/MS/Internal/Annotations/ObservableDictionary.cs)，但它并不是 `public` 的，只是标准库内部使用。或许我们可以使用一个 `ObservableCollection<KeyValuePair<TKey, TValue>>` 来模拟一个字典，但这效率并不高，因为字典的添加、删除、查找等操作都是 $O(1)$ 的，而 `ObservableCollection` 的这些操作都是 $O(n)$ 的。

至于 Avalonia，我们就比较幸运了，它直接提供了 `AvaloniaList` 和 `AvaloniaDictionary`，这两个集合类型，前者支持批量操作，后者则是一个可观测的字典。

下面我们用一个简单的例子来演示如何使用这个 `ObservableDictionary`。它的使用方式和 `ObservableList` 类似，我们只需要实例化它，然后就可以使用了：

```csharp
class MainViewModel
{
    private readonly ObservableDictionary<string, string> _items = new();

    public INotifyCollectionChangedSynchronizedViewList<string> Items { get; }

    public MainViewModel()
    {
        Items = _items.ToNotifyCollectionChanged(pair => pair.Value);

        _items.Add("Key1", "Value1");
    }
}
```

## 可观测的队列

队列有时候也是一个我们用得上的集合类型。它的特点是先进先出（FIFO），适用于需要按照顺序处理元素的场景。比如我们希望存储一些实时的消息，并且希望仅展示最新的几十条，而当超过这个数量时，自动删除最旧的消息。这就要求我们需要能够高效地删除队列头部的元素。这对于传统的列表来说是比较麻烦的，因为这会引入 $O(n)$ 的时间复杂度。

`ObservableCollections` 库提供了一个 `ObservableQueue<T>`，不过我不打算详细介绍它，因为我们上面提到的需求有一个更加合适的集合类型，等下就会介绍到。但这里我们还是用一个简单的例子来演示它的用法：

```csharp
class MainViewModel
{
    private readonly ObservableQueue<LogMessage> _logQueue = new();

    public INotifyCollectionChangedSynchronizedViewList<LogMessage> LogMessages { get; }

    public MainViewModel()
    {
        LogMessages = _logQueue.ToNotifyCollectionChanged();

        // 添加日志消息
        AddLogMessage("Application started");
    }

    public void AddLogMessage(string content)
    {
        var logMessage = new LogMessage(DateTime.Now.ToString("o"), content);

        // 如果队列超过 100 条，则删除最旧的消息
        if (_logQueue.Count >= 100)
        {
            _logQueue.Dequeue();
        }
        _logQueue.Enqueue(logMessage);        
    }
}

record LogMessage(string Timestamp, string Content);
```

{{< notice tip >}}
事实上，如果我们的需求只是比如说保留最近的几十到一百条消息，那么直接使用传统的 `ObservableCollection` 也是完全可以接受的。虽然有点性能损失，但对于现在的 CPU 来说，这点复杂度完全是微不足道的。通过简单的 Benchmark，我们可以看到，`List` 可能只比 `Queue` 慢 50% 左右；甚至当数据量比较小（例如十几条）时，`List` 更是能在性能上超过 `Queue`。另外，`List` 的使用显然比 `Queue` 简单了不少。
{{< /notice >}}

## 可观测的环形缓冲区

下面我们要介绍的这个集合类型，正是这个包最推荐我们用来实现这个保留最近的一些消息的集合类型：`RingBuffer`。它是一个环形缓冲区，具有固定的大小。当添加新元素时，如果缓冲区已满，则会覆盖最旧的元素。这使得它非常适合用于存储最近的消息或数据。

这个包提供了两种环形缓冲区：`ObservableRingBuffer` 和 `ObservableFixedSizeRingBuffer`。前者支持动态调整大小，而后者则是一个固定大小的环形缓冲区。借助后者，我们前面的例子可以简化为：

```csharp
class MainViewModel
{
    private readonly ObservableFixedSizeRingBuffer<LogMessage> _logBuffer = new(100);

    public INotifyCollectionChangedSynchronizedViewList<LogMessage> LogMessages { get; }

    public MainViewModel()
    {
        LogMessages = _logBuffer.ToNotifyCollectionChanged();

        // 添加日志消息
        AddLogMessage("Application started");
    }

    public void AddLogMessage(string content)
    {
        var logMessage = new LogMessage(DateTime.Now.ToString("o"), content);
        _logBuffer.Add(logMessage); // 添加新消息，自动覆盖最旧的消息
    }
}
```

就这样，我们轻松地实现了一个保留最近 100 条日志消息的集合。

## 线程安全

接下来这个部分相当重要，也是大家在使用这个包时需要尤其注意的，就是关于线程安全的问题。首先，这个包提供的每个集合都是线程安全的。它们内部会用一个线程锁，保证它的添加、删除等操作是线程安全的。但这并不意味着我们就可以高枕无忧了，因为虽然这些集合线程安全，但是从它们创建出的视图在同步它们的修改时，可能出现线程安全问题。那么，我们该怎么办呢？

首先，在使用 `ToNotifyCollectionChanged` 方法时，我们可以传入一个 `Dispatcher` 参数。前面提到，这个参数是该类库自己声明的类型。但是它提供了一个方便我们使用的单例：`SynchronizationContextCollectionEventDispatcher.Current`。借助它，我们就可以确保该方法创建出的视图在 UI 线程上执行修改操作，从而避免线程安全问题。

但是这还不够。实测发现，虽然背后的集合本身线程安全，但是它创建出来的视图在操作时仍面临着线程安全问题。尤其是数据不一致。比如我们在删除元素之后立刻添加了元素，那么这两次动作在同步到视图的过程中就可能会出现问题。对于这个问题，如果我们确实有在多线程上操作背后集合的需求，那么我们可以考虑让这些操作都发生在主线程上。以 WPF 为例，我们可以这样：

```csharp
class MainViewModel
{
    private readonly ObservableList<string> _items = new();

    public INotifyCollectionChangedSynchronizedViewList<string> Items { get; }

    public MainViewModel()
    {
        Items = _items.ToNotifyCollectionChanged(SynchronizationContextCollectionEventDispatcher.Current);
    }

    public void AddItem(string item)
    {
        // 确保在 UI 线程上执行添加操作
        Application.Current.Dispatcher.InvokeAsync(() => _items.Add(item));
    }

    public void RemoveItem(string item)
    {
        // 确保在 UI 线程上执行删除操作
        Application.Current.Dispatcher.InvokeAsync(() => _items.Remove(item));
    }
}
```

当然，在 `ViewModel` 中访问 `Application.Current` 可能并不是一个十分遵守 MVVM 模式的好习惯。因此在更加严谨的项目中，我们可以考虑将 `Dispatcher` 作为参数传入 `ViewModel`，或者使用依赖注入的方式来获取它。这样可以更好地遵循 MVVM 模式，同时也能确保在 UI 线程上执行操作。

## 总结

`ObservableCollections` 是一个非常实用的 NuGet 包，它提供了多种具有通知功能的集合类型，适用于 WPF、Avalonia、Win UI 等框架。它不仅支持批量操作，还提供了过滤、映射等功能，使得我们在开发中可以更加高效地处理集合数据。

在使用时，我们需要注意线程安全问题，尤其是在多线程环境下操作集合时。通过合理地使用 `Dispatcher`，我们可以确保集合的操作在 UI 线程上执行，从而避免数据不一致的问题。
