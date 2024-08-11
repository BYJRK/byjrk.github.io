---
title: "为什么我们一般不使用公共字段，而是选择自动属性？"
slug: "why-we-prefer-property-over-field"
description: "为什么我们不直接把自动属性（也就是那种只写了“get;set;”的属性）直接写成公共字段？"
image: https://s2.loli.net/2024/06/13/6rLfG3dzciJpjvO.jpg
date: 2024-06-13
tags:
    - csharp
    - dotnet
    - syntax
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1ci421v7Uc/)

在写 C# 代码的时候，我们经常会写诸如此类的自动属性：

```c#
public Person
{
    public int Age { get; set; }
}
```

这时候相信很多人都会有疑问：为什么我们要费劲写成这样的自动属性？为什么不能直接简单地把它写成一个公共字段呢？就比如这样：

```c#
public Person
{
    public int Age;
}
```

其实这是有一些原因的。我们这次就来探讨一下。

## 看待属性与字段的方式不同

首先最重要的，就是我们看待属性与字段的方式，或者对于它们所扮演的角色的理解是不一样的。

当我们看到一个属性时，通常我们都会期望它拥有一个公共的读权限，同时拥有一个可能不公开的写权限还可能在初始化上存在一些限制。**通常我们写一个属性时，都是希望它存在被外界访问的价值，并且我们也充分考虑了后果**（比如我们可以在 setter 中添加逻辑，或干脆不开放 setter）。

也就是说，通常情况下我们希望一个属性它是一个：

1. （一般情况下）可以在类外被访问到，并且具有一定的意义，是开发者故意暴露出来的成员
2. 它的初始化可能包含一些逻辑，比如可以在什么时候被初始化，是否必须被初始化，初始化后还能否更改等
3. 它后台未必一定对应一个字段，而是会通过一些方式来得到它的值

{{<notice info>}}
对于第 3 条，我可以举出一些例子：

1. `List.Count` 实际与底层的 `Array` 的长度有关
2. `AsyncRelayCommand.IsRunning` 与底层的 `Task` 的状态有关
3. `ObservableValidator.HasErrors` 与底层用于存放错误信息的列表有关
4. `CheckBox.IsChecked` 与底层的依赖属性有关
{{</notice>}}

但是当我们看到字段时，通常会怎么考虑呢？我们先来看一段简单的代码：

```c#
class Manager
{
    private readonly int _uniqueId;             // 一个可能有特殊作用的唯一 ID
    private readonly IConfiguration _config;    // 一个通过依赖注入的方式在构造中初始化的接口对象
    private bool _flag = false;                 // 一个只用于内部方法间传递状态的标志位
    private readonly object _syncRoot = new();  // 一个只用于类内部的线程锁
}
```

大家对于字段的印象是否一般都是这样的呢？如果是的话，那么相信在看到下面的代码时，一定会有点恍惚和不知所措吧：

```c#
class Manager
{
    protected readonly int UniqueId;
    public bool Flag = false;
    public string ErrorMessage = "Oops!";
}
```

所以这里面的道理相信大家应该已经有一定感觉了。是的，我们通常对于字段所扮演角色的理解是：

1. 它通常只用于类内，作为其他属性或方法的辅助角色（比如线程锁、标志位、依赖注入的对象等）
2. 它通常不包含太多的逻辑，只是一个简单的值，而且也不如属性那样具有多种初始化的方式
3. 它通常不太“安全”，或者说开发者在不了解的情况下不太敢轻易去操作它

基于这样不同的看待方式，相信大家应该都能理解为什么我们一般不直接使用公共字段了。

当然了，例外情况肯定也是有的。比如说我们在开发一个简单的 Unity 游戏，那么通常我们会写出这样的代码：

```c#
public class Player : MonoBehaviour
{
    [SerializeField]
    private int health; // Unity 官方推荐的命名习惯是首字母小写
    public int attack;
    public int defense;
}
```

或者当我们想要与 C/C++ 写的 DLL 交互时，我们可能会写出这样的代码：

```c#
[StructLayout(LayoutKind.Sequential)]
public struct MyData
{
    public ushort Index;
    public uint Value;
    public byte[] Data;
}
```

这些情况下，我们可能会直接使用公共字段，而不是属性。

## 长期的约定俗成

既然我们有这样不同的看待方式，所以就出现了相当多类似的开发习惯，甚至连标准库及第三方库也在有意无意贯彻着这样的习惯。

{{<notice info>}}
当然了，这里面其实还有一个“先有鸡还是先有蛋”的问题。也就是说，我们是因为有了这样的习惯，所以才会有这样的标准库设计，还是因为标准库设计的如此，所以我们才会有这样的习惯呢？不过这个问题就不在我们的讨论范围内了。
{{</notice>}}

这里我可以举很多例子：

1. 在 WPF 开发中，如果你想在 XAML 中绑定一个类（通常为 Model 或 ViewModel）的变量，那么这个变量必须是一个属性，而不能是一个字段。此外，WPF 中另一个相当重要的功能——依赖属性——也会充分和属性打交道。
2. 在进行类的序列化与反序列化时，Json.NET、System.Text.Json 等库默认只会序列化属性，而不会序列化字段。
3. `DataGrid`、`PropertyGrid` 等会根据数据类型来自动生成界面的控件都是关注属性而非字段。
4. 在 EntityFramework Core 中，如果你想要使用代码优先（Code-First）的方式，那么你的实体类中的属性必须是属性，而不能是字段；而使用数据库优先（Database-First）的方式时，工具自动生成的也是属性。
5. C# 的接口可以包含属性，但不能包含字段。
6. C# 的记录类（record）底层也是使用属性来实现的。

其他还有一些别的例子，比如我们在使用数据映射的工具（如 Mapster、AutoMapper 等）时，可能也会发现属性和字段的一些不同之处。

所以，既然这样的习惯广泛存在，我们为什么要选择做一个另类的开发者呢？

## 灵活性与封装性

属性具有无与伦比的灵活性。我们可以在属性的 getter 和 setter 中添加任意的逻辑，比如数据校验：

```c#
public class Person
{
    private int _age;

    public int Age
    {
        get => _age;
        set
        {
            if (value < 0)
            {
                throw new ArgumentOutOfRangeException(nameof(value), "Age must be greater than 0.");
            }

            _age = value;
        }
    }
}
```

再比如通知功能：

```c#
class ViewModel : INotifyPropertyChanged
{
    private string _name;

    public string Name
    {
        get => _name;
        set
        {
            if (_name != value)
            {
                _name = value;
                OnPropertyChanged(nameof(Name)); // 事件与方法的实现略
            }
        }
    }
}
```

但更重要的是它的封装性。比如常见的 setter 就有这么几种：

1. `public`：公共的 setter，任何人都可以修改这个属性
2. `protected`：受保护的 setter，只有继承这个类的子类才能修改这个属性
3. `private`：私有的 setter，只有这个类内部的方法才能修改这个属性
4. `internal`：内部的 setter，只有同一个程序集内的方法才能修改这个属性
5. `init`：初始化 setter，只能在构造函数中初始化这个属性
6. 空：只读属性，只能在构造函数中初始化这个属性

不仅如此，还可以配合诸如 `required`、`virtual` 等关键字，使得属性的灵活性和封装性更上一层楼。这些都是字段完全无法比拟的（我知道上面的一些关键字也可以用于字段，但效果都很有限，比如会同时限制读写的权限等）。

## 性能方面的考虑

这时候可能有同学又要说了：我知道自动属性其实是个语法糖，最终还是会被编译器转换成字段和方法，形如：

```c#
class Person
{
    [CompilerGenerated]
    private int <Age>k__BackingField;

    public int Age
    {
        [CompilerGenerated]
        get
        {
            return <Age>k__BackingField;
        }
        [CompilerGenerated]
        set
        {
            <Age>k__BackingField = value;
        }
    }
}
```

那么调用方法去读写字段的值，效率上理应比直接读写字段要低对吧？如果是这样的话，把 `{ get; set; }` 这样的自动属性直接写成公共字段，不是更好吗？

这是个好问题，我们来看这样一个例子。下面的 `Person` 类中，我们定义了两个属性，一个是自动属性，一个是字段：

```c#
var p = new Person();

p.Age1 = 10;
p.Age2 = 20;

public class Person
{
    public int Age1 { get; set; }
    public int Age2;    
}
```

如果我们观察 IL 代码，会发现：

```
IL_0000: newobj instance void Person::.ctor()
IL_0005: dup
IL_0006: ldc.i4.s 10
IL_0008: callvirt instance void Person::set_Age1(int32)
IL_000d: ldc.i4.s 20
IL_000f: stfld int32 Person::Age2
IL_0014: ret
```

好像确实不大对劲啊。`Age1` 就是使用了 `Person::set_Age1` 方法，而 `Age2` 却直接使用了 `stfld` 指令。那是不是说明修改属性的速度就是会略微慢于直接修改字段呢？先别急，我们再来看一看 JIT 编译后的代码：

```
Program.<Main>$(System.String[])
    L0000: mov ecx, 0x33a4ca1c
    L0005: call 0x066f300c
    L000a: mov dword ptr [eax+4], 0xa
    L0011: mov dword ptr [eax+8], 0x14
    L0018: ret
```

这里我们可以看到，自动属性的 setter 其实会被 JIT 编译器优化成直接的内存写入操作。这就意味着，实际上在运行时，修改属性和直接修改字段的速度是一样的。所以，自动属性的性能和公共字段是完全一样的。大家大可以打消这个顾虑了。

## .NET 9 即将到来的新语法特性

如果你还在犹豫的话，我还可以再告诉你一个好消息：.NET 9（C# 13）即将引入一个新语法特性：`field` 关键字（这个关键字曾经在 C# 11 的时候就释放过信号，但因为一些原因姗姗来迟）。这个新特性可以让你更加方便地声明一个属性。

我们都知道，以前我们写完整属性（`propfull`）时，需要写成这样：

```c#
private int _age;

public int Age
{
    get => _age / 2;
    set => _age = value * 2;
}
```

但是现在，有了 `field` 关键字，我们可以这样写：

```c#
public int Age
{
    get => field / 2;
    set => field = value * 2;
}
```

这里的 `field` 就相当于那个 `_age` 字段。这样一来，我们就可以更加方便地声明一个属性了。

## 总结

通过上面的讨论，相信大家对于为什么我们一般不使用公共字段，而是选择自动属性有了更深的理解。当然了，这并不是说我们就不能使用公共字段了。在一些特殊的场景下，我们还是可以使用公共字段的。但是在大多数情况下，我们还是应该选择自动属性。

C# 后面不断新增的语法特性，一直在优化我们使用属性的体验。在比较旧的 C# 版本中，我们甚至不能给自动属性直接赋值，而是需要通过构造函数来初始化。但是随着 C# 版本的不断更新，我们可以看到，自动属性的使用变得越来越方便了。除了上面提到的即将到来地 `field` 关键字，我们在 C# 9 还迎来了记录类型，在 C# 12 又迎来了主构造函数。这些都是为了让我们更加方便地使用属性。

相信大家今后可以更加无忧无虑地使用属性。