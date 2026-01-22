---
title: "如何在类外移除类的事件订阅？"
slug: "how-to-remove-event-handler-outside-a-class.md"
description: "某些时候，我们可能需要在类外移除该类的事件订阅。然而事件本身只对外暴露了增加和移除方法，并且注册的方法可能也不是公共的，这些因素都会增加实现的难度。我们这次就来探讨如何通过反射机制实现这一目标。"
date: 2026-01-22
tags:
    - dotnet
    - csharp
    - reflection
    - delegate
    - event
---

某些时候，我们出于对第三方类库的定制需求，可能需要在类外移除该类的事件订阅。然而，事件本身就是一个封装良好的成员，直接访问和修改事件的订阅列表并不容易。不仅如此，为事件注册的方法可能还是私有的，这更是增加了难度。我们这次就来探讨如何通过反射机制实现这一目标。

## 简单情况

我们先来看一个最基本的例子。这里有一个 `Demo` 类，它定义了一个事件 `MyEvent`，并在构造函数中为该事件注册了一个事件处理器 `MyEventHandler`，并且也是这个类的私有方法。

```c#
class Demo
{

    public Demo()
    {
        MyEvent += MyEventHandler;
    }

    public event EventHandler? MyEvent;

    void MyEventHandler(object? sender, EventArgs e)
    {
        Console.WriteLine("MyEvent event triggered");
    }
}
```

在这个情况下，我们可以借助反射来拿到 `MyEvent` 事件的底层字段，然后将它置空，从而移除所有的事件订阅。

```c#
var demo = new Demo();
var eventField = typeof(Demo).GetField("MyEvent", BindingFlags.Instance | BindingFlags.NonPublic);
eventField.SetValue(demo, null);
```

这样一来，`MyEvent` 事件的所有订阅都被移除了。

## 事件声明在基类上

有时候，事件可能声明在类的基类上，比如：

```c#
class Base
{
    public event EventHandler? MyEvent;
}

class Demo : Base
{
    public Demo()
    {
        MyEvent += MyEventHandler;
    }

    void MyEventHandler(object? sender, EventArgs e)
    {
        Console.WriteLine("MyEvent event triggered");
    }
}
```

这时候上面的方法就不奏效了。我们需要在反射时指定正确的类型：

```c#
var eventField = typeof(Base).GetField("MyEvent", BindingFlags.Instance | BindingFlags.NonPublic);
eventField.SetValue(demo, null);
```

如果再复杂一点，我们甚至都不知道这个事件到底声明在哪个类上，这时候我们可以通过遍历继承链来查找：

```c#
Type? type = typeof(Demo);
FieldInfo? eventField = null;
while (type != null)
{
    eventField = type.GetField("MyEvent", BindingFlags.Instance | BindingFlags.NonPublic);
    if (eventField != null)
    {
        break;
    }
    type = type.BaseType;
}
eventField.SetValue(demo, null);
```

## 移除特定的事件处理方法

上面的方法都会移除所有的事件订阅。如果我们只想移除特定的方法怎么办？此时我们有两种方式。首先我们可以尝试获取事件的委托实例，然后从中移除特定的方法：

```c#
var eventField = typeof(Demo).GetField("MyEvent", BindingFlags.Instance | BindingFlags.NonPublic);
var eventDelegate = (MulticastDelegate?)eventField.GetValue(demo);
if (eventDelegate != null)
{
    foreach (var handler in eventDelegate.GetInvocationList())
    {
        if (handler.Method.Name == "MyEventHandler")
        {
            eventDelegate = (MulticastDelegate?)Delegate.Remove(eventDelegate, handler);
        }
    }
    eventField.SetValue(demo, eventDelegate);
}
```

{{< notice info>}}
C# 中事件是基于委托实现的。每个事件在底层都有一个与之关联的委托字段，这个字段保存了所有注册到该事件的处理方法。当事件被触发时，实际上是调用这个委托，从而依次调用所有注册的方法。具体来说，这个委托通常是一个多播委托（Multicast Delegate），它上面有一个方法列表，包含了所有注册的事件处理器。
{{< /notice >}}

另一种方式是直接通过反射获取特定的方法，然后借助 `Delegate` 创造这个方法的委托实例，再从事件中移除：

```c#
var methodInfo = typeof(Demo).GetMethod("MyEventHandler", BindingFlags.Instance | BindingFlags.NonPublic);
var eventInfo = typeof(Demo).GetEvent("MyEvent", BindingFlags.Instance | BindingFlags.Public);
var handlerDelegate = Delegate.CreateDelegate(eventInfo.EventHandlerType, demo, methodInfo!);
eventInfo.RemoveEventHandler(demo, handlerDelegate);
```

通过以上方法，我们就可以在类外成功地移除类的事件订阅了。

## 整理为通用方法

最后，结合上面的方法，我们可以得到两个通用的方法：

```c#
static void ClearEventHandler(object obj, string eventName, string handlerName)
{
    Type? type = obj.GetType();
    FieldInfo? eventField = null;
    while (type != null)
    {
        eventField = type.GetField(eventName, BindingFlags.Instance | BindingFlags.NonPublic);
        if (eventField != null) break;
        type = type.BaseType;
    }
    if (eventField is null)
        throw new InvalidOperationException($"Event field '{eventName}' not found.");
    var eventDelegate = eventField.GetValue(obj) as MulticastDelegate;
    if (eventDelegate != null)
    {
        foreach (var handler in eventDelegate.GetInvocationList())
        {
            if (handler.Method.Name == handlerName)
                eventDelegate = (MulticastDelegate?)Delegate.Remove(eventDelegate, handler);
        }
    }
    eventField.SetValue(obj, eventDelegate);
}

static void ClearAllEventHandlers(object obj, string eventName)
{
    Type? type = obj.GetType();
    FieldInfo? eventField = null;
    while (type != null)
    {
        eventField = type.GetField(eventName, BindingFlags.Instance | BindingFlags.NonPublic);
        if (eventField != null) break;
        type = type.BaseType;
    }
    if (eventField != null)
    {
        eventField.SetValue(obj, null);
    }
}
```

这两个方法分别用于移除特定的事件处理方法和移除所有的事件订阅。并且它们都能处理事件声明在任意基类上的情况。
