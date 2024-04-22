---
title: "如何使用 appsettings.json 配置文件？"
slug: "how-to-use-appsettings"
description: appsettings.json 是一个相较于 App.config 更加灵活的配置文件，是 .NET Core 以来新增的一种配置方式，提供了更多的灵活性
image: https://s2.loli.net/2024/04/22/7ZhNX9B6CefQbuE.png
date: 2024-04-22
tags:
    - csharp
    - dotnet
---

在 .NET Core 项目中，我们可以使用 `appsettings.json` 配置文件来存储应用程序的配置信息。在这篇文章中，我们将学习如何使用 `appsettings.json` 配置文件。

`appsettings.json` 是一个相较于 `App.config` 更加灵活的配置文件，是 .NET Core 以来新增的一种配置方式，提供了更多的灵活性。

## 快速入门

我们可以在项目中创建一个 `appsettings.json` 文件，然并将其生成操作设置为「较新时复制」或「总是复制」，这样在项目构建时，`appsettings.json` 文件会被复制到输出目录中。

然后我们可以在其中添加如下内容：

```json
{
    "AppSettings": {		
        "LogLevel":"Warning",
        "ConnectionStrings": {
            "Default": "this is the connection string"
        }	
    }
}
```

这样我们就可以尝试读取了。我们使用 NuGet 包管理器安装 `Microsoft.Extensions.Configuration.Json` 包。它会隐式安装 `Microsoft.Extensions.Configuration` 等依赖项，这些我们不需要显式安装。

然后我们可以在代码中读取配置文件：

```c#
using Microsoft.Extensions.Configuration;

var configuration = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .Build();
```

这样我们就可以获取上面的配置信息了：

```c#
var logLevel = configuration["AppSettings:LogLevel"];
var connectionString = configuration["AppSettings:ConnectionStrings:Default"];
```

这里的形如 `AppSettings.LogLevel` 是一种特殊的写法，简单来说就是借助 `:` 来表示 JSON 中的层级关系。

如果要获取的配置项是一个数字，我们除了可以先通过上述方式获取到字符串，进而使用 `int.Parse` 或 `Convert.ToInt32` 等方法进行转换，还可以使用 `GetValue` 方法：

```c#
// 传统方法
var logLevel = int.Parse(configuration["AppSettings:LogLevel"]);
// 使用 GetValue 方法
var logLevel = configuration.GetValue<int>("AppSettings:LogLevel");
```

对于连接字符串，我们还可以使用 `GetConnectionString` 方法：

```c#
var connectionString = configuration.GetConnectionString("Default");
```

## 可选与自动重载

在上面的代码中，我们可以看到 `AddJsonFile` 方法有两个参数，`optional` 和 `reloadOnChange`：

- `optional` 参数表示是否允许配置文件不存在，如果设置为 `false`，则会抛出异常，否则会忽略。
- `reloadOnChange` 参数表示是否在配置文件发生变化时重新加载配置文件。如果设置为 `true`，则会在配置文件发生变化时重新加载配置文件。

比如我们可以用下面的例子测试自动重载的效果：

```c#
var configuration = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .Build();

while (true)
{
    Console.WriteLine(configuration["AppSettings:LogLevel"]);
    Thread.Sleep(1000);
}
```

在运行程序后，我们可以修改 `appsettings.json` 文件中的 `LogLevel` 配置，然后我们会发现程序会自动重新加载配置文件。注意这里我们修改的是输出目录（也就是 `.exe` 文件所在位置）下的 `appsettings.json` 文件，而不是项目中的 `appsettings.json` 文件。

## 添加多个 JSON 文件

如果只能添加一个 JSON 文件，那么配置文件的灵活性就大大降低了。事实上，我们可以通过多次调用 `AddJsonFile` 方法来添加多个 JSON 文件。一个典型的情形是添加一个 `appsettings.Development.json` 文件，用于存储开发环境的配置信息。

```c#
var configuration = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile("appsettings.Development.json", optional: true, reloadOnChange: true)
    .Build();
```

这样我们就可以在 `appsettings.Development.json` 文件中存储开发环境的配置信息，而在 `appsettings.json` 文件中存储通用的配置信息。

不仅如此，这二者之间存在优先级，或者说覆盖关系。具体来说：

- 如果 `appsettings.json` 和 `appsettings.Development.json` 中都有相同的配置项，那么 `appsettings.Development.json` 中的配置项会覆盖 `appsettings.json` 中的配置项
- 如果 `appsettings.Development.json` 中没有某个配置项，而 `appsettings.json` 中有，那么会使用 `appsettings.json` 中的配置项
- 如果 `appsettings.Development.json` 中有某个配置项，而 `appsettings.json` 中没有，那么会使用 `appsettings.Development.json` 中的配置项

## 使用强类型配置

在上面的例子中，我们使用 `configuration["AppSettings:LogLevel"]` 来获取配置信息，这种方式是一种弱类型的方式。我们也可以使用强类型的方式来获取配置信息。

我们修改一下 `appsettings.json` 文件中的配置项：

```json
{
    "UserSettings": {
        "Name": "Alice",
        "Age": 18,
        "IsActive": true
    }
}
```

然后我们定义一个强类型的配置类：

```c#
public class UserSettings
{
    public string Name { get; set; }
    public int Age { get; set; }
    public bool IsActive { get; set; }
}
```

在获取配置前，我们还需要安装一个 NuGet 包：`Microsoft.Extensions.Options.ConfigurationExtensions`。然后我们就可以这样获取配置信息：

```c#
var userSettings = configuration.GetSection("UserSettings").Get<UserSettings>();
```

这样我们就可以获取到 `UserSettings` 对象了，然后就可以使用 `userSettings.Name`、`userSettings.Age`、`userSettings.IsActive` 来获取配置信息了。

但是需要注意，因为这里的 `userSettings` 实例已经初始化，所以前面提到的自动重载功能不再生效。如果需要自动重载，我们需要重新获取 `userSettings` 对象。

## 添加环境变量和命令行参数

在 .NET Core 中，我们还可以通过环境变量和命令行参数来覆盖配置文件中的配置信息。我们需要再安装两个 NuGet 包：

- `Microsoft.Extensions.Configuration.EnvironmentVariables`
- `Microsoft.Extensions.Configuration.CommandLine`

然后我们可以这样添加环境变量和命令行参数：

```c#
var configuration = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddEnvironmentVariables()
    .AddCommandLine(args)
    .Build();
```

这样我们就可以通过环境变量和命令行参数来覆盖配置文件中的配置信息了。

比如我们可以创建一个 `.bat` 批处理文件：

```bat
@echo off
set UserSettings__Name=Bob
set UserSettings__Age=20

.\Demo.exe
```

或者还可以使用 PowerShell：

```powershell
$env:UserSettings__Name = "Bob"
$env:UserSettings__Age = 20

.\Demo.exe
```

## 总结

相信通过这篇文章，大家已经认识到了 `appsettings.json` 配置文件的强大之处。它不仅提供了一种灵活的配置方式，还提供了多种配置方式的组合，使得我们可以更加灵活地配置应用程序。

但是它也有一些局限性。最重要的一条就是它的配置项是“只读”的，也就是不能像 `App.config` 那样在运行时方便地修改配置项。毕竟，一个项目中可能存在多个配置项，而不是只有一个 `appsettings.json` 文件。此时如果修改了，该保存到哪个文件呢？

当然，如果只有一个配置文件，那么 `appsettings.json` 是一个不错的选择。比如我们可以使用 `Newtonsoft.Json` 来轻松地写入 JSON 文件，这样就可以实现配置项的修改了。

最后，其实通常情况下，我们并不会使用上面的方式读取配置项，而是会更进一步，使用 `Host` 作为整个程序的入口，并读取配置、注入服务等。在之后的文章中，我们会学习如何使用 `Host` 来构建一个 .NET 应用程序。