---
title: "如何正确使用 WPF 中 Application 的 MainWindow 及 ShutdownMode 属性"
slug: "correct-way-to-use-mainwindow"
description: "本文介绍了在 WPF 中如何正确使用 Application 的 MainWindow 属性及 ShutdownMode 属性，确保应用程序在主窗口关闭时能够正确退出。并且还介绍了如果有登录窗口时，该如何正确配置这两个属性。"
date: 2026-05-26
tags:
  - wpf
  - csharp
  - dotnet
  - window
---

提起 `MainWindow`，很多人的第一反应都是在创建 WPF 项目后，默认生成的那个 `MainWindow` 类。但其实我们这次要讨论的，是 `Application` 类中的 `MainWindow` 属性，或者大家更熟悉的访问方式是 `Application.Current.MainWindow`。可能有些人还不太清楚，但实际上它也是有一点使用技巧的，尤其是在与 `ShutDownMode` 配合使用时。

## 单例模式

首先，这个 `MainWindow` 属性是一个单例模式的实现，所以我们可以在项目中的任何地方通过 `Application.Current.MainWindow` 来访问它。这个功能非常方便，尤其是在需要在多个地方访问主窗口的情况下，比如在视图模型中或者其他服务类中。我们可以直接通过 `Application.Current.MainWindow` 来获取主窗口的引用，而不需要想尽办法来获取或传递它的引用。这样的需求常见于需要在主界面展示消息、弹窗、导航等操作时。

不过这里有一个稍微需要注意的地方，就是虽然它与我们的 `MainWindow` 类同名，但它本身是一个 `Window` 类型的属性，所以我们在使用时需要进行类型转换，这样才能拿到我们定义的 `MainWindow` 类中的特定方法和属性，或者有名字的界面控件。

## 配合 ShutDownMode 使用

这部分才是我们今天讨论的重点。WPF 开发者在刚入门的时候，可能会理所当然地认为，`MainWindow` 就一定是 `Application.Current.MainWindow` 的实例，并且主窗口关闭了，程序就应该退出了，这是天经地义的。但实际上这个事情恐怕没这么简单。

### 为什么 MainWindow 属性通常就是 MainWindow？

一个简单的 WPF 程序中，我们通常可以在 `App.xaml` 中看到类似这样的代码：

```xml
<Application x:Class="WpfApp.App"
             ...
             StartupUri="MainWindow.xaml">
    ...
</Application>
```

这段代码的意思是，当应用程序启动时，自动创建一个 `MainWindow` 的实例，并将它设置为 `Application.Current.MainWindow`。所以在这种情况下，`MainWindow` 属性确实就是我们定义的 `MainWindow` 类的实例。

或者如果我们不希望 `App` 自动帮我们创建主窗口，比如我们希望在程序刚开始的时候读取配置，为 DI 容器注册服务，或者做一些其他的初始化工作，我们可能会删掉 `App.xaml` 中的 `StartupUri`，并在 `App.xaml.cs` 的 `OnStartup` 方法中手动创建主窗口：

```csharp
protected override void OnStartup(StartupEventArgs e)
{
    base.OnStartup(e);

    // 这里我们手动创建 MainWindow 实例
    var mainWindow = new MainWindow();
    mainWindow.Show();
}
```

在这种情况下，我们同样可以通过 `Application.Current.MainWindow` 来访问这个主窗口，因为 WPF 默认会自动将第一个显示的窗口设置为 `MainWindow` 属性的值。

### ShutdownMode 是什么？

`ShutdownMode` 是 `Application` 类中的一个属性，它决定了当应用程序应该退出的条件。它有三个选项：

- `OnLastWindowClose`：当最后一个窗口关闭时，应用程序退出。这是默认值。
- `OnMainWindowClose`：当主窗口关闭时，应用程序退出。
- `OnExplicitShutdown`：只有当调用 `Shutdown()` 方法时，应用程序才会退出。

虽然它的默认值是 `OnLastWindowClose`，但实际上往往 `OnMainWindowClose` 更加符合我们的预期，因为我们通常希望当主窗口关闭时，整个应用程序就退出了，而不需要担心其他窗口是否还在。因此主窗口本身还常常承载着很多善后工作，例如在 `Closed` 事件中进行资源清理、保存数据和配置等操作。

如果我们在主窗口的 `Closed` 事件中再去额外调用 `Application.Current.Shutdown()` 来保证其他窗口也会被关闭，这显然是不高明的。所以更好的做法是，直接将 `ShutdownMode` 设置为 `OnMainWindowClose`，这样当主窗口关闭时，整个应用程序就会自动退出了。我们只需要在 `App.xaml` 或 `App.xaml.cs` 中显式设置即可。

{{<notice info>}}
关于 `Application.Current.Shutdown()` 方法，还有一些值得提及的细节：

1. 通过调用它来关闭所有窗口，正常情况下是可以触发每个窗口的 `Closing` 及 `Closed` 事件的。
2. 如果窗口还订阅了 `Closing` 事件，那么即便里面有 `e.Cancel = true` 的代码逻辑，也不会阻止窗口的关闭。
3. 如果在 `Closing` 事件中抛出了未经捕获的异常，可能会干扰事件链，导致 `Closed` 事件不被触发。
{{</notice>}}

### 第一个窗口不是 `MainWindow` 该怎么办？

有时候，主窗口可能并不是第一个弹出的窗口。一个典型的例子是，我们在应用程序启动时，先弹出一个登录窗口，用户登录成功后才显示主窗口。在这种情况下，`Application.Current.MainWindow` 可能会指向登录窗口，而不是我们真正的主窗口。那么此时我们该如何使用 `OnMainWindowClose` 来确保主窗口关闭时应用程序退出呢？

一个并不十分优雅，但也足够应付这个问题的方案是，我们先设置 `ShutdownMode` 为 `OnExplicitShutdown`，然后在登录窗口关闭后，再将 `ShutdownMode` 设置为 `OnMainWindowClose`，并且在登录窗口关闭时手动将主窗口设置为 `Application.Current.MainWindow`。这样就能保证当主窗口关闭时，应用程序能够正确退出了。比如在 `App.xaml.cs` 中：

```csharp
protected override void OnStartup(StartupEventArgs e)
{
    base.OnStartup(e);

    // 先设置 ShutdownMode 为 OnExplicitShutdown
    this.ShutdownMode = ShutdownMode.OnExplicitShutdown;

    // 显示登录窗口
    var loginWindow = new LoginWindow();
    var result = loginWindow.ShowDialog();

    if (result == true)
    {
        // 登录成功，创建主窗口
        var mainWindow = new MainWindow();
        mainWindow.Show();

        // 将主窗口设置为 MainWindow 属性
        this.MainWindow = mainWindow;

        // 设置 ShutdownMode 为 OnMainWindowClose
        this.ShutdownMode = ShutdownMode.OnMainWindowClose;
    }
    else
    {
        // 登录失败，直接退出应用程序
        this.Shutdown();
    }
}
```

这个方法不够优雅的地方在于，我们需要在登录窗口关闭后，手动设置 `MainWindow` 属性，并且多次切换 `ShutdownMode` 的值，从而让它们两个正确配合。

### 更优雅的方式

一个更优雅的方式为，我们可以先创建 `MainWindow` 的实例，并且赋值给 `Application.Current.MainWindow`，但不立即显示它。然后我们先显示登录窗口，等用户登录成功后，再显示主窗口。这样就能保证 `MainWindow` 属性始终指向我们真正的主窗口了，同时也不需要频繁切换 `ShutdownMode` 的值了。比如：

```csharp
protected override void OnStartup(StartupEventArgs e)
{
    base.OnStartup(e);

    // 先创建 MainWindow 实例，但不显示
    this.MainWindow = new MainWindow();
    this.ShutdownMode = ShutdownMode.OnMainWindowClose;

    // 显示登录窗口（省略判断登录成功的逻辑）
    var loginWindow = new LoginWindow();
    loginWindow.ShowDialog();

    // 登录成功后显示主窗口
    this.MainWindow.Show();
}
```

但这时候肯定会有人会问：如果登录失败，那么 `MainWindow` 不就白创建了？尤其是如果 `MainWindow` 中包含巨量的初始化逻辑，会不会导致很大的开销，甚至让登录窗口都出现不流畅的情况？

如果你有这样的担忧，那么很有可能是因为你的 `MainWindow` 的实现方式并不合理，尤其是你将初始化逻辑直接放在了构造函数中。一般来说，我们应该将初始化逻辑放在 `Loaded` 事件中，或者通过一些惰性加载的方式来实现，这样就能避免在创建 `MainWindow` 实例时就进行大量的初始化工作了。

或者，如果我们的项目采用了 MVVM 模式，那么我们可以将初始化逻辑放在 `MainViewModel` 中，并在合适的时机（通常仍然是主窗口的 `Loaded` 事件）调用它。这样同样可以避免上面的担忧。具体的做法可以是：

```csharp
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        this.Loaded += MainWindow_Loaded;
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        // 在这里进行初始化逻辑
        var viewModel = (MainViewModel)this.DataContext;
        viewModel.Initialize();
    }
}
```

或者如果你不想在 `.xaml.cs` 文件里面写太多逻辑，还可以用行为库：

```xml
<Window ...
        xmlns:i="http://schemas.microsoft.com/xaml/behaviors">
    <i:Interaction.Triggers>
        <i:EventTrigger EventName="Loaded">
            <i:InvokeCommandAction Command="{Binding InitializeCommand}" />
        </i:EventTrigger>
    </i:Interaction.Triggers>
    ...
</Window>
```

{{<notice tip>}}
除了将视图模型中的 `Initialize` 方法包装为 `ICommand` 来调用，还可以使用行为库中的 `CallMethodAction` 来直接调用视图模型中的方法。不过不太推荐这样做，因为 `ICommand`，尤其是 CommunityToolkit MVVM 中的 `AsyncRelayCommand`，可以更好地处理异步操作、错误处理和命令状态管理等问题，而直接调用方法则需要我们自己来处理这些细节了。
{{</notice>}}

## 总结

总的来说，`Application.Current.MainWindow` 是一个非常方便的属性，可以让我们在项目中的任何地方访问主窗口的实例。但我们需要注意它与 `ShutDownMode` 的配合使用，尤其是在一些特殊的场景下，比如登录窗口和主窗口的关系。通过合理地设置 `ShutdownMode` 和正确地初始化主窗口，我们就能确保当主窗口关闭时，整个应用程序能够正确退出了。
