---
title: "如何用 Rx.NET 来模拟情景短剧《恐惧症研讨会》"
slug: "phobia-workshop"
description: 这次我们来尝试使用响应式编程来模拟一个有趣的情景短剧《恐惧症研讨会》，并借助各种运算符来模拟剧中每个人的行为逻辑
image: https://s2.loli.net/2024/04/20/tAq5BvYJUkQgReP.png
date: 2024-04-20
tags:
    - csharp
    - reactive
---
不知道大家有没有看过这样一个视频：

{{<bilibili "BV1js411z7wf">}}

（或者也可以看油管上的 [原版视频](https://www.youtube.com/watch?v=koNwUeG-iKE)）

我们这次就来玩一玩，如何使用 Rx.NET 来模拟这个情景短剧。

## 简单分析每个人的特点

通过观看视频，我们发现一共有五个人，且这五个人各有特点，或者说各自会在特定情况下触发自己的恐惧症，进而发出尖叫。具体来说：

- Lee：对于“AAGH!”（也就是“啊！”）这个词很恐惧
  - 且这个词必须是别人发出的
- Jim：对于道歉（或者说“Sorry”这个词）很恐惧
  - 自己说的这个词也是可以触发自己的恐惧的
- Karen：对于重复的话很恐惧
  - 两句重复的话必须都是别人说的
  - （从视频中来看，两句重复的话甚至可以间隔很久，但这种情况难以概括，且视频中其他时候也有重复的话，但并未触发，所以存在 BUG，暂不考虑）
- Ronnie：对于“尴尬的沉默”很恐惧
  - 也就是说，如果有人说了一句话，然后没有人回应，那么就会触发
  - 前提是必须有人先说了什么，而不是打一开始就没有任何人说话
- Tim：对于别人因恐惧而发出尖叫这件事情感到恐惧，并且会吓出狗叫
  - 当其他有人发出了恐惧的尖叫，且之后不再会有人尖叫时，他会发出狗叫

大家可以多看几遍视频，尤其是靠近后面的地方，他们连续相继发出尖叫声的片段，看看我上面总结的是否正确。

那么现在，我们就来模拟这个情景短剧吧。

## 实现消息总线

在模拟每个人之前，我们首先需要有一个消息总线（Message Bus）。有了这个总线，我们才可以既让所有人都能够收听（或者说订阅）这个总线，又可以向总线中发送消息。

在 Rx.NET 中，`Subject` 这个类型就是典型的能够实现这一效果的类。我们可以使用它来实现一个消息总线。

```csharp
class MessageBus : IDisposable
{
    // 内部使用一个 Subject 对象
    private readonly Subject<Message> _subject = new();

    // 当用于订阅时，返回一个 IObservable<Message> 对象，从而封装类中其他功能
    public IObservable<Message> Messages => _subject.AsObservable();

    // 当向总线中发送消息时，底层会调用 Subject 的 OnNext 方法
    public void SendMessage(Message message)
    {
        if (message.Content == "exit")
            _subject.OnCompleted();
        else
            _subject.OnNext(message);
    }

    public void Dispose()
    {
        _subject.Dispose();
    }
}
```

同时，我们也需要一个 `Message` 类型，从而更好地让接下来的每一个人都能够判断自己是否应该发出尖叫。

```c#
record Message(string Sender, string Content);
```

是的，一个简单的记录类就可以满足我们的需求了。上面的每一个人，它们都只需要知道是谁说的，以及说了什么，就足够处理各自的逻辑了。

{{<notice info>}}
在 [ReactiveUI](https://github.com/reactiveui/ReactiveUI) 中也有一个消息总线类型，名叫 `MessageBus`。它底层其实就是借助了一个 `Subject` 来实现的。当然实际上更复杂一些，因为还有与 `Scheduler` 相关的一些额外的功能，所以它额外实现了一个名为 [`ScheduledSubject`](https://github.com/reactiveui/ReactiveUI/blob/main/src/ReactiveUI/Scheduler/ScheduledSubject.cs) 的类。
{{</notice>}}

## 模拟每一个人的行为

下面我们就根据出场顺序，来逐个模拟每个人的逻辑吧。这里为了简单起见，我们统一使用小写，并且为所有人设定了一个固定的延迟。此外，还需要给两个人额外的时间：

- 给 Ronnie 一个时间阈值，表示多久之后才会被她判定为长时间的“尴尬的沉默”
- 给 Tim 一个相对更长一点的延迟，从而让他能够在确保其他人都不再尖叫之后，才发出自己的狗叫

```c#
var reactionDelay = TimeSpan.FromSeconds(0.25);
var ronnieSilenceThreshold = TimeSpan.FromSeconds(3);
var timReactionDelay = TimeSpan.FromSeconds(0.3);
```

同时，我们还要声明前面定义好的消息总线：

```c#
var bus = new MessageBus();
```

这样，每个人都能够收听这个总线，并且自己发出的尖叫也要传递给这个总线。

### Lee

Lee 的逻辑很简单，只要听到了别人说的 “AAGH!”这个词，就会发出尖叫。

```c#
using var agent1 = bus.Messages
    .Where(m => m.Content == "aagh" && m.Sender != "agent1") // 别人说的 aagh
    .Delay(reactionDelay)
    .Subscribe(_ => bus.SendMessage(new("agent1", "aagh")));
```

### Jim

Jim 的逻辑也很简单，只要听到了 “Sorry” 这个词（不用管是谁发出的），就会发出尖叫。

```c#
using var agent2 = bus.Messages
    .Where(m => m.Content == "sorry") // 无论是谁说的 sorry
    .Delay(reactionDelay)
    .Subscribe(_ => bus.SendMessage(new("agent2", "aagh")));
```

### Karen

Karen 的逻辑稍微复杂一点，因为她需要判断两句话是否重复，且都是别人说的。

```c#
using var agent3 = bus.Messages
    .Buffer(2, 1)
    .Where(ms => ms.Count == 2
        && ms[0].Content == ms[1].Content
        && ms[0].Sender != "agent3"
        && ms[1].Sender != "agent3")
    .Delay(reactionDelay)
    .Subscribe(_ => bus.SendMessage(new("agent3", "aagh")));
```

### Ronnie

Ronnie 的逻辑也比较简单，只要有人说了话，然后没有人回应，就会发出尖叫。那么 Rx 中的 `Throttle` 方法简直就是为她量身打造的。

```c#
var agent4 = bus.Messages
   .Throttle(ronnieSilenceThreshold)
   // .Delay(reactionDelay) // 这句也可以不写
   .Subscribe(_ => bus.SendMessage(new("agent4", "aagh")));
```

### Tim

Tim 其实与 Ronnie 类似，只要有人发出了尖叫，然后之后没有人再发出尖叫，他就会发出狗叫。所以我们同样可以使用 `Throttle` 方法来实现。

```c#
var agent5 = bus.Messages
    .Where(m => m.Content == "aagh")
    .Throttle(timReactionDelay)
    .Subscribe(_ => bus.SendMessage(new("agent5", "woof")));
```

## 放在一起

最后，我们将上面的代码放在一起。为了能够便于观察效果，我们使用 LINQPad 来简单地搭建这段代码，并且额外添加一个 `agent`，代表用户的输入。这样，我们就可以通过输入来模拟每个人的发言了。

```c#
bool isCompleted = false;

bus.Messages
    .Subscribe(
        m => Console.WriteLine($"[{DateTime.Now: mm:ss.fff}] {m.Sender}: {m.Content}"),
        () => isCompleted = true
    );

while (!isCompleted)
{
    var input = Util.ReadLine();
    bus.SendMessage(new("user", input));
}
```

完整版代码可以查看[这个 Gist](https://gist.github.com/BYJRK/6912c2df1e6dd5b705400c006b6be627)。

运行看一下效果。输入“aagh”会看到：

```
[55:26.812] user: aagh
[55:27.112] agent1: aagh
[55:27.362] agent3: aagh
[55:27.625] agent1: aagh
[55:27.941] agent5: woof
```

输入“sorry”会看到：

```
[55:34.985] user: sorry
[55:35.236] agent2: aagh
[55:35.499] agent1: aagh
[55:35.763] agent3: aagh
[55:36.027] agent1: aagh
[55:36.339] agent5: woof
```

## 总结

通过这个简单的例子，我们可以看到，Rx.NET 的强大之处。我们可以通过简单的类似 LINQ 一样的查询，就能够实现复杂的逻辑。这种方式不仅简洁，而且易于理解，同时也能够很好地处理异步的情况。试想一下，如果我们使用传统的多线程或异步编程来实现相同的效果，那么代码会变得多么复杂。

之后我们还会继续探讨 Rx.NET 的更多用法，用更多实际且生动的例子，来帮助大家更好地理解这个库。
