---
title: "关于 .NET 单文件应用我的一些看法"
slug: "my-thoughts-on-dotnet-file-based-app"
description: ".NET 10 引入了单文件应用，看起来像是 C# 的脚本化革命。但用得越多，我越觉得它处在一个很尴尬的位置。"
date: 2026-09-14
tags:
    - dotnet
    - csharp
categories:
    - dotnet
    - csharp
---

.NET 的单文件应用（File-based apps）在 .NET 10 中正式登场，吸引了不少关注。许多人憧憬它能像 Python 或 Node.js 一样，只需单个文件即可直接运行，告别创建项目的繁琐步骤。

但剥开这层美好的愿景，它的实际体验与定位却处处充满矛盾。

## 它是什么

简单来说，单文件应用允许用一个单独的 `.cs` 文件来编写、构建和运行 C# 程序，不再需要显式的 `.csproj` 项目文件。

最基础的写法如下：

```csharp
// hello.cs
Console.WriteLine("Hello, World!");
```

可以直接运行：

```shell
dotnet run hello.cs
# 甚至更简短：
dotnet hello.cs
```

在 Unix 平台上，还可以加上 shebang 将其设为可执行脚本：

```csharp
#!/usr/bin/env -S dotnet --

Console.WriteLine("Hello, World!");
```

对于依赖与配置，它通过文件顶部的 `#:` 指令来替代 csproj 中的 XML 配置：

```csharp
#:package Spectre.Console@0.49.1
#:property TargetFramework=net10.0

using Spectre.Console;
AnsiConsole.MarkupLine("[green]Hello![/]");
```

从表面上看，单文件、声明依赖、即写即跑，非常符合轻量脚本的形态。官方还为其赋予了 `dotnet pack` 打包、`dotnet publish` 本机发布，以及 `dotnet project convert` 转换回完整项目等进阶能力。

## 社区的美好设想

功能初发时，社区与官方畅想了许多诱人的应用场景：

- **脚本化开发**：摆脱 `dotnet new console` 和 csproj 的理解负担，随手写脚本。
- **仓库内的工程自动化脚本**：放在项目的 `scripts/` 目录下，用熟悉的 C# 编写构建、发布、数据迁移等辅助任务。
- **AI Agent 的理想载体**：AI 仅需生成一个 `.cs` 文件即可执行，无需维护工程目录。
- **命令行小工具**：配合 shebang 丢进 `$PATH`，成为日常系统工具。
- **降低入门门槛**：让新手接触 C# 的第一课回归纯粹的代码本身。

这些愿景听起来很美好，但随着功能逐步完备，这套设计中最核心的矛盾也逐渐暴露出来。

## 指令系统的膨胀与心智负担

为了让单文件应用不只是玩具，而是真正具备生产力，官方为其设计了一整套完备的 `#:` 指令系统。

从基础的引入 NuGet 包（`#:package`）、切换 SDK 类型（`#:sdk`）、设置 MSBuild 属性（`#:property`），到引用外部项目（`#:project`），甚至后续还新增了用于引入其他源码文件的 `#:include`。官方试图通过这些指令，将一个完整工程所具备的能力全数塞进一个 `.cs` 文件中。

但正是这种“追求完备”的努力，带来了巨大的潜在心智负担，也让它的定位变得越来越矛盾。诚然它的功能性得到了显著的提升，但是它在轻量脚本与完整工程之间的身份始终模糊不清。

同样是使用 `dotnet cli` 工具，我们创建项目、添加依赖、编译运行和发布等操作都是行云流水的：

```shell
dotnet new console -f net10.0 -n MyApp
dotnet add package Spectre.Console
dotnet build
dotnet run
dotnet publish
```

而在单文件应用中，我们只能在文件开头手写各种指令与配置，并且这通常意味着我们也得不到什么代码提示：

```csharp
#:package Spectre.Console@0.49.1
#:sdk Microsoft.NET.Sdk.Web
#:property TargetFramework=net10.0
```

不仅要手动书写指令，还得记忆具体的语法细节。这并没有真正减负，而是把原本 CLI 或 IDE 工具完成的工作，重新转嫁给了人工。

{{< notice note >}}
其实这样的 `#:` 指令系统并不新鲜，比如我们可以在 `csharprepl` 中使用 `#r` 引入 NuGet 包，或在 LINQPad 中使用 `#load` 引入外部脚本文件等。
{{< /notice >}}

而 `#:include` 的加入更是将这种矛盾推向了极致。当代码量逐渐膨胀、必须拆分成多个 `.cs` 文件时，单文件应用的初衷就已经不复存在了。

随着 `#:` 语法的使用，开发者不得不面临一个现实问题：既然已经需要管理多文件依赖、手写配置指令，为什么还要固执地坚守单文件形式，而不是直接建立一个标准项目？继续留在单文件形态下，不仅无法享受目录约定与完善的 IDE 重构支持，反而是在为“不用 csproj”这个形式承担额外的管理成本。

## 隐藏在底层的 MSBuild 项目

造成上述矛盾的根本原因在于：**单文件应用并不是真正意义上的轻量脚本引擎，它本质上依然是一个完整的 MSBuild 项目。**

它的运行机制是为 `.cs` 文件在系统临时目录生成一个隐藏的项目文件，并走完整的构建管线，将构建产物缓存在临时目录中。

这一底层实现带来了诸多无法回避的现实问题：

- **隐式缓存与构建黑盒**：构建产物依据文件哈希隐藏在系统缓存中。开发者可以使用 `dotnet clean hello.cs` 或 `dotnet clean file-based-apps` 来清理缓存。
- **语义边界泄漏**：它会静默继承所在目录链上的 `Directory.Build.props`、`Directory.Packages.props`、`nuget.config` 甚至父级目录中的 `.csproj`。一个号称单文件即可运行的脚本，其行为却能被几层目录之外的全局配置文件改变。
- **预设的“逃跑”通道**：官方提供了 `dotnet project convert` 命令，用于一键将单文件还原为标准的 csproj 项目。

{{< notice note >}}
`dotnet project convert` 命令的存在本身就是最直白的技术诚实：单文件只是暂时的试验品，正规项目才是最终的归途。但遗憾的是，即便是一个小项目，直接从单文件入手，也几乎不会比直接创建项目要更加简单。
{{< /notice >}}

## 割裂的受众与定位

功能与机制的复杂化，最终导致了受众定位上的全面脱节。

在发布环节，官方为单文件应用赋予了一个特殊的默认行为：执行 `dotnet publish` 时默认启用 Native AOT。

从设计理念来看，官方的初衷十分明确：希望让单文件编写的命令行小工具在分发时，直接打包为免装 .NET 运行时、秒级冷启动的原生二进制文件，像 Go 或 Rust 编写的 CLI 一样便于独立分发与部署。

然而，Native AOT 本身就是 .NET 中技术门槛极高的一环，与单文件主打的“轻量易用”产生了剧烈冲突：

- **高昂的认知门槛**：Native AOT 绝非新手能迅速理解的概念。它涉及提前编译、无 JIT 运行环境、静态代码分析以及激进的代码裁剪机制。
- **反射与代码标记的沉重心智负担**：在日常开发中，许多代码和第三方库高度依赖反射、动态序列化或依赖注入。一旦遇到 Native AOT 不支持的场景，开发者就需要引入 `[DynamicallyAccessedMembers]` 等特性进行显式标注，或者配置繁琐的裁剪警告抑制规则。这对于本想“随手写个脚本”的开发者而言，无疑是巨大的心智负担。
- **复杂的发布与编译参数**：严肃的 AOT 发布往往需要搭配一系列 MSBuild 属性进行精细化调优（如 `TrimMode`、`InvariantGlobalization`、优化级别等）。在单文件顶部靠 `#:property` 一行行手写这些参数，体验极其别扭。
- **反直觉的配置倒逼与漫长构建**：AOT 编译耗时显著长于 JIT 托管构建，彻底破坏了脚本“改完即跑”的敏捷反馈。而新手遭遇 AOT 报错后，为了回退到常规托管模式，反而被迫去理解并声明 `#:property PublishAot=false` 这种更晦涩的开关。

{{< notice warning >}}
凡是需要用到 Native AOT、复杂反射标注和精细发布参数的场景，本质上都已经是严肃的项目。这些配置本就应该依托标准的项目文件（`.csproj`）或其他更多的配置文件（例如 `Directory.Build.props`、`Directory.Packages.props`、`nuget.config`、`PublishProfiles` 等）进行系统化管理，而不是硬塞进单文件的开头。
{{< /notice >}}

这种定位割裂贯穿始终：

一方面，官方将“降低新手门槛”作为卖点，但新手不仅要面对 `#:package`、`#:property`、SDK 类型等概念，还要在发布时直面 Native AOT 的心智负担；另一方面，即便是对于资深开发者与工程化团队而言，单文件应用同样缺乏吸引力，毕竟 csproj 的地位完全无法撼动，而围绕它形成的一整套项目结构、单元测试、CI/CD 流程和开发规范，都是无比成熟的。

## 用作仓库脚本的价值

官方对单文件应用还有另一个构想：将其作为项目工程内置的脚本，统一存放在仓库的 `scripts/` 目录下，用 .NET 开发者最熟悉的 C# 语言来编写诸如构建后处理、数据迁移、打包分发等复杂的自动化任务。

这个想法初衷很好，但在工程落地时，面临着多方面的现实挤压。首先，在工程脚本与自动化任务领域，现有的成熟替代方案非常丰富且高效：

- 跨平台的 **PowerShell (pwsh)** 与 **Bash** 天然贴近操作系统进程、管道和环境变量，几乎没有冷启动开销。
- 经典的 **Makefile**，或是更现代的 **Taskfile (Task)**、**Just** 等工具，声明依赖清晰、语义明确，专为工程任务编排而生。
- 即便需要编写复杂的控制逻辑，**Python** 等脚本语言也拥有无与伦比的启动速度与生态便利。

相比之下，C# 单文件在脚本场景下显得相当厚重：调用系统命令和进程管道时代码繁琐，每次运行还可能要承受 MSBuild 的解析与编译开销。

更尴尬的是它的上下文冲突：官方一边鼓励在工程的 `scripts/` 目录下存放单文件脚本，另一边又因为前文提到的“边界泄漏”，警告开发者避免将单文件放在现有的项目目录树中，以防被全局 `Directory.Build.props` 污染。

这使得 C# 单文件在项目自动化场景中的价值也被挑战：**简单的任务用 PowerShell 或 Taskfile 更快更轻；复杂的任务最终又需要拆分模块和依赖，不如直接建立一个正规的控制台项目（甚至这个项目可能都不是用 C#，而是用诸如 C++、Rust、Go、Zig 等语言开发）。**

## 结语

单文件应用并非全无价值。在快速验证某个 API、编写一次性 Demo 或让 AI 快速生成一段可执行代码时，它确实能免去创建项目的步骤。但实际上，如果想快速测试某段代码，我仍然会选择 LINQPad（以及 RoslynPad、NetPad 等平替）、csharprepl、Polyglot Notebooks 等工具。

它的每一次“功能强化”，都是在向传统项目靠拢；而每一次靠拢，都在削弱它作为单文件存在的意义。**当你真正需要它提供的那些强大功能时，你其实已经需要一个真正的项目了**。不知道单文件应用未来会走向何方，是否会变得更加值得被尝试。

## 参考

- [File-based apps - .NET | Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/core/sdk/file-based-apps)
