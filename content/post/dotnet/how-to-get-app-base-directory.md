---
title: "如何在 .NET 中获取程序的根目录？"
slug: "how-to-get-app-base-directory"
description: "本文介绍 .NET 中应用程序的根目录、当前工作目录与程序集位置的区别，解释了各种常见方式真实的逻辑，以及该如何正确选择。"
date: 2026-08-04
categories:
  - dotnet
tags:
  - dotnet
  - csharp
  - io
---

我们开发基于 C# 的客户端软件的时候，经常需要去获取应用程序的根目录，比如我们想要读取应用程序根目录下的配置文件，或者在根目录下创建日志文件等。这看起来应该是一个非常简单的需求，可是当我们想要去实现时，就会发现似乎存在很多能够达到目的的方法。比如：

- `AppContext.BaseDirectory`
- `AppDomain.CurrentDomain.BaseDirectory`
- `Environment.CurrentDirectory`
- `Assembly.Location`
  - `GetAssembly(typeof(Program))`
  - `GetEntryAssembly()`
  - `GetExecutingAssembly()`
  - `GetCallingAssembly()`

本文想要探讨的，就是在 .NET 中获取应用程序根目录的几种方法，它们的底层逻辑，以及它们的适用场景。相信在看完本文之后，你会对如何获取应用程序根目录有一个清晰的认识。

## BaseDirectory

咱们先不绕弯子，直接公布正确答案（因为后面的几乎都是误导项）。想要获取应用程序的根目录，最合适的方式就是使用 `BaseDirectory`；对于现代 .NET 应用，通常推荐 `AppContext.BaseDirectory`。

`AppContext.BaseDirectory` 表示**应用程序基目录**的绝对路径。这个目录也是 .NET 运行时进行程序集探测时的起点之一；在一般的桌面程序、控制台程序或 Windows 服务中，它通常就是启动程序所在的目录。例如，程序位于 `C:\Program Files\MyApp\MyApp.exe` 时，返回值通常为 `C:\Program Files\MyApp`。

{{< notice info >}}
`AppContext` 用于提供当前应用的上下文信息和开关，例如基目录、目标框架名称以及应用上下文开关。`AppDomain` 则是 .NET 中用于隔离程序集、配置和安全边界的运行时概念；在现代 .NET 中，一个进程通常只有默认的 `AppDomain`。`AppContext.BaseDirectory` 的值与 `AppDomain.CurrentDomain.BaseDirectory` 相对应，但新代码通常优先使用前者。
{{< /notice >}}

## Environment.CurrentDirectory

接下来我们就来看一些不那么正确，或者“有时候正确，有时候不正确”的做法吧。首先就是 `Environment.CurrentDirectory`。此外还有 `Directory.GetCurrentDirectory()`，它其实也是访问的前者。

一般情况下，如果你是双击一个 EXE 程序直接运行，或者是运行一个它的快捷方式，又或者是在 Visual Studio 等 IDE 中直接运行（或调试）程序，那么 `Environment.CurrentDirectory` 返回的值通常就是应用程序的根目录。然而，如果你在命令行中运行程序，并且没有 cd 到程序所在的目录，而是从其他目录去运行它，那么 `Environment.CurrentDirectory` 返回的值就会是你当前所在的目录，而不是应用程序的根目录。这也就是“当前工作目录”（current working directory，CWD）的概念，它是一个进程在运行时的上下文信息，而不是应用程序本身的路径。

还有一种情况是，你在使用 dotnet cli，并且在项目的根目录借助 `dotnet run` 的方式来启动程序，那么同样会观察到当前工作目录是你运行这句指令时的所在位置。

{{< notice info >}}
实际上是否选择使用 `CurrentDirectory` 也是一门技巧。并不是说任何时候都不应该选择这一路径。比如我们想要开发的是类似 FFmpeg 的控制台工具，那么你肯定希望用户在某个目录下通过你的工具转换了一个文件后，输出文件也出现在当前的目录下，而不是跑到了你的程序的根目录。否则用户就只能每次都繁琐地使用绝对路径了。
{{< /notice >}}

## Assembly

接下来我们看一看跟程序集有关的一些方法吧。这些方法有时候能行，有时候不太能行，而且还有几个干扰项。

### Assembly.Location

首先一个最容易想到的方式就是获取当前程序所属程序集的位置。通常我们的做法是：

- `Assembly.GetAssembly(typeof(Program))`
- `typeof(Program).Assembly`

这两种方式都是获取当前程序的程序集对象，然后通过 `Assembly.Location` 属性获取程序集的路径。这里我们选择了几乎所有程序都会有的 `Program` 类，从而确保它是来自入口项目的。虽然我们可以选择入口项目中的任何类型，但其他的看起来可能会很怪异，也不够直观。

这个方法如果成功，会直接返回对应程序集的 DLL 文件的绝对路径。然后我们再通过 `Path.GetDirectoryName()` 方法获取它的目录路径，即可获得应用程序的根目录。

不过，这种方式依赖程序集确实存在对应的物理文件。在 .NET 5 及更高版本的单文件发布中，打包进单文件的程序集并没有独立的 DLL 路径，`Assembly.Location` 会返回空字符串；另一方面，动态生成的程序集同样没有可供返回的程序集文件路径，访问 `Assembly.Location` 会抛出 `NotSupportedException`。

此外还有一个问题：如果当前代码不在入口项目中，我们没办法拿到诸如 `Program` 这样的属于入口项目的类型，那么我们就无法获取入口程序集对象了。虽然我们总是有 `BaseDirectory` 这样的正确方法，但这不妨碍我们就是想没事找事，用一用 `Assembly` 上面的其他方法对吧？🙃

### Assembly.GetXXXAssembly()

接下来我们看一看 `Assembly` 上的几个获取程序集对象的方法：

- `GetEntryAssembly()`：获取正在运行应用程序的入口程序集对象。对于大多数桌面应用程序和控制台应用程序，它通常就是包含 `Main` 方法的程序集。
- `GetExecutingAssembly()`：获取包含当前正在执行代码的程序集对象。
- `GetCallingAssembly()`：获取调用当前正在执行方法的那个方法所在的程序集对象。

假设解决方案中有一个控制台项目 `MyApp` 和一个被它引用的类库项目 `MyLibrary`。`MyApp` 的 `Program` 调用类库中的 `AssemblyHelper.Print()`：

```csharp
// MyApp/Program.cs
MyLibrary.AssemblyHelper.Print();

// MyLibrary/AssemblyHelper.cs
using System.Reflection;

namespace MyLibrary;

public static class AssemblyHelper
{
    public static void Print()
    {
        Console.WriteLine(Assembly.GetEntryAssembly()?.GetName().Name);
        Console.WriteLine(Assembly.GetExecutingAssembly().GetName().Name);
        Console.WriteLine(Assembly.GetCallingAssembly().GetName().Name);
    }
}
```

输出通常如下：

```text
MyApp
MyLibrary
MyApp
```

可以看到，`GetEntryAssembly()` 始终指向应用入口程序集，适合在类库中反向取得宿主应用的信息；`GetExecutingAssembly()` 指向定义 `Print` 方法的类库程序集；`GetCallingAssembly()` 则指向调用 `Print` 的程序集。若把对 `Print()` 的调用再封装到另一个类库中，最后一项也会随之变为那个中间类库，而不再是 `MyApp`。

不过，`GetCallingAssembly()` 的结果依赖调用栈，且可能受到 JIT 内联优化的影响。至于 `GetEntryAssembly()`，即便它获取了入口程序集，单文件发布时其 `Location` 仍可能为空字符串。此外，有一种比较少见的情况是，非托管程序（例如 C++ 开发的程序）调用托管程序集（例如借助 COM 互操作等方式）时，`GetEntryAssembly()` 可能返回 `null`，因为入口程序集并非托管程序集。

## 总结

“获取程序根目录”这个需求的关键，在于先区分自己真正需要的是哪一种路径：应用的部署目录、进程的当前工作目录，还是某个程序集文件的位置。这些路径在本地调试时经常相同，但它们的来源和稳定性并不相同。

- 若要定位与应用程序一同部署的配置、资源或其他文件，应使用 `AppContext.BaseDirectory`。这是获取应用程序基目录的首选方式，也能正确应对单文件发布。
- 若要按用户启动程序时所在的位置解析相对路径，应使用 `Environment.CurrentDirectory` 或 `Directory.GetCurrentDirectory()`；不要假定它始终等于应用程序根目录。
- 若要确认某个程序集实际从哪里加载，可以使用 `Assembly.Location`。但它描述的是程序集文件的位置，并不等同于应用程序根目录；单文件发布、动态程序集等场景下也不可靠。
- `GetEntryAssembly()`、`GetExecutingAssembly()` 和 `GetCallingAssembly()` 的职责是确定不同语义下的程序集对象，而不是解决目录定位问题。尤其是 `GetCallingAssembly()` 会受到调用栈和 JIT 优化的影响。

因此，如果问题确实是“应用程序根目录在哪里”，就不要折磨自己了，直接选择正确答案吧：

```csharp
string baseDirectory = AppContext.BaseDirectory;
```
