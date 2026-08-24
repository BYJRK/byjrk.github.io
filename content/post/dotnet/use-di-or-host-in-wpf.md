---
title: "在 WPF 等桌面应用中应该单纯使用 DI 还是引入 Generic Host？"
slug: "use-di-or-host-in-wpf"
description: "本文探讨了在 WPF 等桌面客户端中应用依赖注入时的两种典型方案：直接使用 Microsoft.Extensions.DependencyInjection 还是引入 Generic Host。对比了两者的实现方式、功能差异及依赖包开销，并给出了实际开发中的建议。"
date: 2026-08-24
tags:
  - wpf
  - dotnet
  - csharp
  - di
categories:
  - dotnet
---

在现代 .NET 开发中，依赖注入（Dependency Injection，简称 DI）因为其在解耦、可测试性和生命周期管理上的优势，已经成为了几乎所有项目的标配。无论是 ASP.NET Core、Blazor 还是桌面端的 WPF、Avalonia、WinUI 等，微软官方都提供了统一的依赖注入体系。

很多做客户端开发（WPF、Avalonia、WinUI 等）的开发者，在早期的项目中大多接触过各种第三方 IoC/DI 容器，例如 Autofac、旧时 Prism 标配的 Unity、Simple Injector 等。这些第三方库的角色往往非常纯粹，就是一个单纯的 DI 容器：在应用启动时构建一个容器（比如 `ContainerBuilder`），把服务、ViewModel 和 Window 注册进去，最后解析主窗口并显示。微软官方的 `Microsoft.Extensions.DependencyInjection` 也是如此。

然而，当大家查阅现代的官方文档、开源项目或者技术博客时，却会发现有大量的项目直接引入了 Generic Host（通用主机，`IHost` / `HostApplicationBuilder`）。这难免会让不少客户端开发者产生困惑：**在桌面端使用微软官方的依赖注入体系时，我们究竟应该只使用单纯的 DI 容器，还是把 Generic Host 整体引入进来？**

这两种做法在实际开发中都非常普遍。事实上，**微软官方的 DI 容器本身就是 Generic Host 的核心功能之一**，而 Host 则在此基础上额外打包了配置、日志、Options 模式和后台托管服务等一整套基础设施。

本文将对比这两种方案的具体用法与能力差异，聊聊它们各自的优缺点，以及我们在实际项目中该如何权衡取舍。

## 单纯使用 DI（ServiceCollection）

如果我们的桌面应用主要是为了解耦业务服务（Services）与视图模型（ViewModels）、方便进行单元测试以及管理对象的生命周期（单例、瞬态等），并不需要一套复杂的跨环境配置系统或后台服务，那么直接使用纯粹的 DI 容器就是最直接、最轻量的选择。

我们只需要安装一个包：

```shell
dotnet add package Microsoft.Extensions.DependencyInjection
```

这个包非常干净，只包含 `IServiceCollection`、`IServiceProvider` 以及官方的默认 IoC 容器实现，几乎没有多余的传递依赖。

{{< notice note >}}
如果想要在一个类库项目中使用 DI，那么只需要引用 `Microsoft.Extensions.DependencyInjection.Abstractions` 包即可，它只包含接口定义，不包含任何默认实现。然后就可以借助扩展方法来实现形如 `AddXXX(this IServiceCollection services)` 的注册方法，供入口项目调用。
{{< /notice >}}

### 在 WPF 中集成单纯 DI

在 WPF 中使用 DI 的经典做法是改造 `App.xaml` 和 `App.xaml.cs`。

首先，打开 `App.xaml`，**移除默认的 `StartupUri` 属性**，并在后台实现构造函数、重写 `OnStartup` 等方法来注册和配置服务、解析主窗口等：

```csharp
using System.Windows;
using Microsoft.Extensions.DependencyInjection;

namespace WpfDiApp;

public partial class App : Application
{
    // 提供全局静态访问点（可选，便于在某些特殊场景下获取服务）
    public new static App Current => (App)Application.Current;

    public IServiceProvider Services { get; }

    public App()
    {
        Services = ConfigureServices();
    }

    private static IServiceProvider ConfigureServices()
    {
        var services = new ServiceCollection();

        // 注册业务服务
        services.AddSingleton<IGreetingService, GreetingService>();

        // 注册 ViewModels
        services.AddTransient<MainWindowViewModel>();

        // 注册 Views/Windows
        services.AddTransient<MainWindow>();

        return services.BuildServiceProvider();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 从容器中获取主窗口并显示
        var mainWindow = Services.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        // 应用程序退出时妥善释放容器中所有 IDisposable 的单例资源
        if (Services is IDisposable disposable)
        {
            disposable.Dispose();
        }

        base.OnExit(e);
    }
}
```

在视图和 ViewModel 中，我们就可以通过标准的构造函数注入来使用所需的服务了：

```csharp
public class MainWindowViewModel(IGreetingService greetingService)
{
    public string Message => greetingService.GetGreeting();
}

public partial class MainWindow : Window
{
    public MainWindow(MainWindowViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
```

### 方案特点

- **极简且纯粹**：没有任何多余的抽象层，只专注于依赖的注册与解析。
- **贴合桌面生命周期**：桌面应用的生命周期本质上是由 UI 线程消息循环（`Dispatcher`）以及 `Application.Current` 控制的。单纯 DI 只作为一个普通服务容器挂在 `App` 下，完全不干扰 WPF 原有的运行逻辑。

## 引入 Generic Host

在 Generic Host 中，前面的 DI 并没有被替代，而是成为了 Host 的一部分。当我们使用 Host 时，注册和配置服务依然是通过 `builder.Services`（它本身就是一个 `IServiceCollection`）完成的，而构建出来的 `IHost.Services` 本质上也就是一个标准的 `IServiceProvider`。

如果想要在 WPF 中引入 Host，我们只需要安装一个包：

```shell
dotnet add package Microsoft.Extensions.Hosting
```

在现代 .NET 中，推荐使用 `HostApplicationBuilder`（通过 `Host.CreateApplicationBuilder()`）来搭建主机，它的语法与 ASP.NET Core 中的 `WebApplicationBuilder` 保持了一致。

同样在 `App.xaml` 中移除 `StartupUri`，并在 `App.xaml.cs` 中接入 Host：

```csharp
using System.Windows;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace WpfHostApp;

public partial class App : Application
{
    private readonly IHost _host;

    public App()
    {
        // 创建应用构建器（会自动载入命令行参数、环境变量及 appsettings 等）
        var builder = Host.CreateApplicationBuilder();

        // 1. 注册业务服务与后台服务
        builder.Services.AddSingleton<IGreetingService, GreetingService>();
        builder.Services.AddHostedService<HeartbeatBackgroundService>();

        // 2. 注册 Views 与 ViewModels
        builder.Services.AddTransient<MainWindowViewModel>();
        builder.Services.AddTransient<MainWindow>();

        _host = builder.Build();
    }

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // 启动 Host（会依次触发所有 IHostedService 的 StartAsync）
        await _host.StartAsync();

        // 解析并显示主窗口
        var mainWindow = _host.Services.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    protected override async void OnExit(ExitEventArgs e)
    {
        // 优雅停止 Host（触发所有 IHostedService 的 StopAsync 并给它们一定的停止宽限期）
        using (_host)
        {
            await _host.StopAsync();
        }

        base.OnExit(e);
    }
}
```

除了上面看到的 DI 容器之外，Generic Host 还额外提供了许多开箱即用的功能。

### 多源配置系统

`Host.CreateApplicationBuilder()` 默认会自动加载并按顺序合并多个配置源：

1. `appsettings.json`
2. `appsettings.{Environment}.json`（例如 `appsettings.Development.json`）
3. 环境变量
4. 命令行参数（如果有传入）
5. 本地开发阶段的用户机密（User Secrets）

在任何注入了 `IConfiguration` 的服务中，都可以直接读取合并后的配置项：

```csharp
public class GreetingService(IConfiguration configuration) : IGreetingService
{
    public string GetGreeting() =>
        configuration["GreetingMessage"] ?? "Hello from Generic Host!";
}
```

配合 `builder.Services.Configure<AppOptions>(builder.Configuration.GetSection("App"))`，还可以将配置绑定到强类型的 Options 类上，并在服务中注入 `IOptions<AppOptions>` 或 `IOptionsMonitor<AppOptions>`（支持配置文件修改时热重载）。

### 结构化日志与第三方日志集成

Host 默认配置了 `ILoggerFactory`，且日志级别、过滤规则天然与 `appsettings.json` 中的 `Logging` 配置节绑定。在任何服务或 ViewModel 中，直接声明 `ILogger<T>` 即可记录日志：

```csharp
public class MainWindowViewModel(
    IGreetingService greetingService,
    ILogger<MainWindowViewModel> logger)
{
    public void DoSomething()
    {
        logger.LogInformation("用户点击了操作按钮");
    }
}
```

使用 Host 的一大好处是**日志抽象层的标准化**。所有业务代码统一面向 `Microsoft.Extensions.Logging` 的 `ILogger<T>` 接口编写。如果后续想要替换为第三方日志框架，比如 Serilog，只需要引入 [serilog/serilog-aspnetcore](https://github.com/serilog/serilog-aspnetcore)，然后在构建 Host 时替换底层的日志提供程序即可：

```csharp
var builder = Host.CreateApplicationBuilder();

builder.Services.AddSerilog(); // 添加这一行即可替换内置的 Logger
```

### 后台托管服务（Hosted Services）

这也是 Host 独有的特性之一。通过继承 `BackgroundService` 或实现 `IHostedService`，我们可以定义伴随应用程序生命周期运行的后台任务：

```csharp
public class HeartbeatBackgroundService(ILogger<HeartbeatBackgroundService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("后台心跳检测正常运行中...");
            await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);
        }
    }
}

// 在 App.xaml.cs 中注册
builder.Services.AddHostedService<HeartbeatBackgroundService>();
```

当 `_host.StartAsync()` 被调用时，所有注册的 `BackgroundService` 会自动在后台线程中启动；当程序退出调用 `_host.StopAsync()` 时，Host 会触发取消通知并等待它们优雅退出。这对于需要常驻监听网络端口、定时同步数据或轮询任务的桌面端场景非常实用。

## 权衡与取舍

既然 Host 提供了这么多便利，是不是所有桌面项目都应该直接使用 Host？其实也不尽然。在实际选型时，有几个维度的权衡值得关注：

### 依赖包体积与依赖树深度

- **单纯 DI**：只有一个 `Microsoft.Extensions.DependencyInjection` 包及其抽象层，依赖极其清晰干净。
- **Generic Host**：`Microsoft.Extensions.Hosting` 相当于一个基础包，会自动拉入 Configuration、Logging、Options、FileProviders 等一整套依赖，不管你用不用。

![Hosting v10.0.11 版本的依赖](https://files.seeusercontent.com/2026/08/24/Zt5h/pasted-image-1787555821745.webp)

虽然在常见的桌面开发中这些程序集并不会带来明显的体积压力，但如果在做 Native AOT 编译、或者对发布产物体积和裁剪比较敏感，过多的间接依赖会增加构建分析和裁剪配置的成本。也因此，微软还专门为 ASP.NET 提供了 `WebApplication.CreateSlimBuilder` 来减少不必要的依赖。

### 生命周期模型的差异

- **桌面应用**的生命周期以 **UI 线程和窗口** 为核心，由 `Dispatcher` 消息循环驱动，通常绑定在主窗口关闭（`ShutdownMode`）或托盘图标交互上。
- **Generic Host** 最初是为 **服务端或控制台守护进程** 设计的，生命周期围绕 `StartAsync`、`StopAsync` 以及控制台退出信号展开。

在 WPF 中使用 Host，本质上是用代码把这两套生命周期桥接在一起（在 `OnStartup` 触发 `StartAsync`，在 `OnExit` 触发 `StopAsync`）。如果应用中并没有任何 `IHostedService` 需要管理，那么这套异步启动和停止流程就显得有些多余。

### 按需组装的折中方案

很多开发者之所以引入 Host，只是因为“想用 `appsettings.json`”或者“想用 `ILogger`”。

但实际上，**微软的这些扩展库大多是高度模块化的**。如果只需要其中某一项功能，完全可以在单纯 DI 的基础上单独按需引入：

- **只需读取 `appsettings.json`**：单独安装 `Microsoft.Extensions.Configuration.Json`，通过 `new ConfigurationBuilder().AddJsonFile(...).Build()` 构建配置，并以单例形式注册进 `ServiceCollection`；
- **只需使用 `ILogger`**：单独安装 `Microsoft.Extensions.Logging`，通过 `services.AddLogging()` 直接向 `ServiceCollection` 注册日志服务。

我们可以按需组合自己需要的组件，而不必为了使用一两项功能而引入完整的 Host。

## 总结

对于桌面应用的开发来说：

- **单纯使用 DI（ServiceCollection）**：适合轻量工具、单页面或架构相对简单的客户端。没有复杂的多环境配置和常驻后台任务，追求干净的依赖和最简单的启动流程。
- **引入 Generic Host**：适合中大型桌面应用，或者需要多源配置、Options 模式、结构化日志管理以及后台常驻任务（`IHostedService`）的场景。

两者并没有绝对的优劣之分，搞清楚它们的包含关系与优缺点，根据实际需求选择最合适的方案即可。
