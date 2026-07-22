---
title: "Jab：基于源生成器的编译时依赖注入容器"
slug: "introduce-di-tool-jab"
description: "源生成器诞生以来，越来越多曾经需要大量借助反射来实现的功能，都可以通过源生成器来实现，而无需再依赖反射。这阵风终于刮到了 DI 容器，也就是我们今天要介绍的 Jab。"
date: 2026-05-15
tags:
    - dotnet
    - csharp
    - source-generator
    - dependency-injection
    - nuget
categories:
    - nuget
---

最近在研究 Avalonia 的一款名为 [ShadUI](https://github.com/accntech/shad-ui) 的主题库时，发现它的示例项目使用了 [Jab](https://github.com/pakrym/jab) 这款 DI 容器来注册各种服务。

源生成器诞生以来，越来越多曾经需要大量借助反射来实现的功能，都可以通过源生成器来实现，而无需再依赖反射。从 .NET 内置的 JSON 序列化和正则表达式，到 Mapperly 这款基于源生成器的映射库，他们每一个都跑分喜人。那么 Jab 会让我们失望吗？

## 基本用法

Jab 的使用非常简单。安装它的 NuGet 包，或者在 .csproj 中添加以下内容即可：

```xml
<ItemGroup>
    <PackageReference Include="Jab" Version="0.12.0" PrivateAssets="all" />
</ItemGroup>
```

{{<notice info>}}
这里的 `PrivateAssets="all"` 是为了防止 Jab 被打包到最终的 NuGet 包中。这个包本身的作用是为基于源生成器来生成 `ServiceProvider` 以及注册各种服务的代码提供具体的实现。但是在生成后，我们直接使用这些生成出来的类即可，就不再需要 `Jab` 本身了。
{{</notice>}}

然后就可以使用了。我们可以这样注册服务：

```csharp
[ServiceProvider]
[Transient(typeof(IService), typeof(ServiceImpl))]
internal partial class MyServiceProvider { }
```

对于上面的代码，还有一点点“改进空间”：

```csharp
[ServiceProvider]
// C# 11 为我们带来了泛型特性
[Transient<IService, ServiceImpl>]
// 在有了主构造函数之后，我们声明一个空的类现在可以把花括号给省掉
internal partial class MyServiceProvider;
```

注册好服务之后，直接实例化容器，然后调用 `GetService<T>()` 获取服务即可：

```csharp
var provider = new MyServiceProvider();
IService service = provider.GetService<IService>();
```

{{< notice info >}}
Jab 没有类似 `Microsoft.Extensions.DependencyInjection` 中 `GetRequiredService<T>()` 的方法，但这并不是缺失——Jab 的 `GetService<T>()` 返回的就是非空的 `T` 而非可空的 `T?`。如果你请求了一个未注册的服务，编译器会在编译期直接报错，而不是等到运行时才抛出异常。这正是编译时 DI 的核心优势之一。
{{< /notice >}}

## 特殊用法

它的使用总体上来说是非常直观且符合直觉的。这里我再简单列举一些写法上稍微复杂一点的典型场景供大家快速参考。更多边界场景推荐直接阅读源代码仓库的 README。

## 将某个对象作为单例服务的实例

有时候，某个服务的实例需要通过特定的构建过程来创建，而不能简单地交给 DI 容器来实例化。典型的例子是 Serilog 的 `ILogger`——它通常需要通过 `LoggerConfiguration` 来配置和构建：

```csharp
ILogger logger = new LoggerConfiguration()
    .WriteTo.Console()
    .WriteTo.File("logs/app.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();
```

对于这种情况，Jab 提供了工厂方法的注册方式，让我们可以将这个已经构建好的实例作为单例注入：

```csharp
[ServiceProvider]
[Singleton<ILogger>(Factory = nameof(CreateLogger))]
internal partial class MyServiceProvider
{
    private ILogger CreateLogger() =>
        new LoggerConfiguration()
            .WriteTo.Console()
            .WriteTo.File("logs/app.log", rollingInterval: RollingInterval.Day)
            .CreateLogger();
}
```

这样，每次从容器中请求 `ILogger` 时，都会返回同一个由工厂方法创建的实例。

如果 logger 实例已经在容器外部创建好了，也可以直接通过实例属性的方式注册：

```csharp
[ServiceProvider]
[Singleton<ILogger>(Instance = nameof(LoggerInstance))]
internal partial class MyServiceProvider
{
    public ILogger LoggerInstance { get; set; }
}
```

使用时，在容器创建后再将实例赋给该属性：

```csharp
ILogger logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateLogger();

var provider = new MyServiceProvider();
provider.LoggerInstance = logger;

ILogger resolved = provider.GetService<ILogger>();
```

## 命名服务

当同一个接口有多个不同的实现需要同时注册时，可以通过 `Name` 属性为每个注册取一个名字，然后在构造函数参数上用 `[FromNamedServices("...")]` 来指定要注入哪一个：

```csharp
[ServiceProvider]
[Singleton<INotificationService, EmailNotificationService>(Name = "email")]
[Singleton<INotificationService, SmsNotificationService>(Name = "sms")]
[Singleton<Notifier>]
internal partial class MyServiceProvider;

class Notifier
{
    public Notifier(
        [FromNamedServices("email")] INotificationService email,
        [FromNamedServices("sms")] INotificationService sms)
    { }
}
```

{{< notice info >}}
Jab 同样支持 `Microsoft.Extensions.DependencyInjection` 中的 `[FromKeyedServices]` 特性，两者可以互换使用。
{{< /notice >}}

## 模块

如果你用过 Autofac，对它的 `Module` 机制一定不陌生。模块可以将一组相关的服务注册封装成一个独立单元，然后在不同的容器中复用，这样可以实现批量注册一些相关的服务的效果，从而更好地管理服务。Jab 也提供了类似的能力，同样叫做 Module。

定义模块时，创建一个接口并标注 `[ServiceProviderModule]`，然后在接口上声明服务注册：

```csharp
[ServiceProviderModule]
[Singleton<IService, ServiceImplementation>]
public interface IMyModule;
```

在服务容器中用 `[Import]` 引入模块即可：

```csharp
[ServiceProvider]
[Import<IMyModule>]
internal partial class MyServiceProvider;
```

模块之间也可以互相引入，便于将大型应用的注册拆分成多个职责清晰的模块来管理。

{{< notice info >}}
`Microsoft.Extensions.DependencyInjection` 本身没有 Module 的概念，通常的做法是为 `IServiceCollection` 编写扩展方法（如 `AddMyFeature(this IServiceCollection services)`）来实现类似的分组注册。Jab 将这一能力内置进来，写法上更加统一。
{{< /notice >}}

## 局限性

Jab 虽然在性能和编译期安全性上表现亮眼，但在实际项目中引入之前，有几点局限性值得考量：

1. **生态兼容性**：绝大多数第三方库（如 EF Core、Serilog、MediatR 等）都只针对 MEDI 提供 `IServiceCollection` 扩展方法，无法直接用于 Jab，需要手动桥接或改用工厂方式注册。
2. **没有 `ServiceCollection`**：Jab 没有运行时动态添加注册的能力，所有注册必须在编译期通过特性声明。这也导致所有针对 `IServiceCollection` 的扩展方法及中间件（如 Scrutor 的扫描注册）均无法使用。
3. **缺乏 Host 生态支持**：`Microsoft.Extensions.Hosting` 体系中的 `IConfiguration`、`IOptions<T>`、`DbContext` 等基础设施与 Jab 并无原生集成，若项目依赖这些能力，引入成本会较高。
4. **不适合动态插件系统**：插件通常需要在运行时发现并注册服务，而 Jab 的注册完全发生在编译期，无法支持这类场景。
5. **特性数量随项目增长**：服务全部通过特性在容器类上声明，项目规模较大时，容器类顶部可能会堆积大量特性，可读性有所下降。不过借助 Module 可以在一定程度上缓解这个问题。

## 总结

Jab 是一个思路清晰的编译时 DI 容器。如果你的项目对启动性能敏感（如桌面应用、命令行工具、AOT 场景），或者希望在编译期就捕获依赖配置错误，Jab 是一个值得尝试的选择。

但如果项目重度依赖 MEDI 生态（EF Core、ASP.NET Core 中间件、Generic Host 等），或者需要运行时动态注册，那么 Jab 并不适合作为主容器，继续使用 MEDI 会是更务实的选择。
