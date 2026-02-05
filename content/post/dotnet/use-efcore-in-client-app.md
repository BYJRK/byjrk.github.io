---
title: "如何在本地客户端使用 EF Core"
slug: "use-efcore-in-client-app"
description: "将 EF Core 用于 WPF、WinForms 等本地客户端应用程序可能并不是一个非常简单的事情。我们尤其需要了解它的一些内部机制，以及如何有针对性地进行配置，从而避免一些常见的问题。"
date: 2026-02-02
tags:
    - dotnet
    - csharp
    - efcore
    - orm
    - wpf
---

Entity Framework Core (EF Core) 是一个强大的对象关系映射（ORM）框架，通常用于服务器端应用程序中与数据库交互。通常我们会将它用于 ASP.NET Core 应用程序，并且它的配置方式也绝对可以说是相当成熟了。但有时候我们在做本地客户端应用程序（例如 WPF、WinForms 或 Avalonia 应用程序）时，也希望利用 EF Core 来简化数据访问层的开发。那么我们需要注意些什么？最佳实践是怎样的？这篇文章我们就来探讨这个问题。

## 回顾 EF Core 在 ASP.NET Core 中的使用

首先我们来快速回顾一下在 ASP.NET Core 应用程序中使用 EF Core 的典型方式。以一个比较新（.NET 6+）的项目为例，通常我们会在程序入口进行如下的配置：

```c#
var builder = WebApplication.CreateBuilder(args);

// 配置 DbContext
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// 其他服务配置
// ...
```

这里其实有一个隐式的配置，就是我们将 `DbContext` 的生命周期设置为了作用域（Scoped）。在 ASP.NET Core 中，每个 HTTP 请求都会创建一个新的作用域，因此每个请求都会有一个独立的 `DbContext` 实例。这种方式有助于确保数据的一致性和隔离性。

这个方案在服务器端应用程序中可以说是非常标准且正确的，但是这个问题到了本地客户端，情况就不太相同了。对于客户端程序来说，通常并没有作用域这么一个概念。客户端程序一般是单用户的，整个应用程序的生命周期就是一个大的作用域。如果我们直接将 `DbContext` 注册为作用域生命周期，那么实际上它就会变成单例生命周期，这样就会带来一些问题：

1. **线程安全问题**：`DbContext` 不是线程安全的，如果在多线程环境下（例如 UI 线程和后台线程）共享同一个实例，可能会导致数据损坏或异常。
2. **内存泄漏**：长时间持有 `DbContext` 实例可能会导致内存泄漏，因为它会跟踪所有的实体状态，随着时间的推移，这些状态会不断累积。

因此，如何解决这两个问题就成了我们在客户端使用 EF Core 时需要重点考虑的内容。

## 方法一：注册为瞬态（Transient）生命周期

首先我们来看一种相对来说比较简单的方式。既然注册为作用域，实际上就相当于单例，那么我们可以直接将 `DbContext` 注册为瞬态生命周期。这样在每个被注入服务的类中，它都会获得一个新的 `DbContext` 实例，从而一定程度上避免了一些问题。

```c#
// 注册 DbContext 服务
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")),
    ServiceLifetime.Transient);

// 使用 DbContext 的服务
public class MyViewModel
{
    private readonly AppDbContext _dbContext;

    public MyViewModel(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }

    public void LoadData()
    {
        var items = _dbContext.Items.ToList();
        // 处理数据
    }
}
```

{{< notice info >}}
对于一个客户端程序，尤其是 MVVM 模式，一个典型的情况是我们将 `DbContext` 注入到 ViewModel 中使用。当然对于更复杂的场景，我们可能会将数据访问逻辑封装到一个 Repository 或 Service 层中，然后再将这些服务注入到 ViewModel 中。至于没有使用 MVVM 模式的情形，我们基本上也不会搞 DI 容器，所以也就不考虑这些问题了。
{{< /notice >}}

那么这有没有问题呢？答案是有的，而且这个方案并不理想。比如我们看下面这个例子。在这个例子中，我们使用了 CommunityToolkit.Mvvm 来简化 ViewModel 的编写：

```c#
public partial class MainViewModel : ViewModelBase
{
    private readonly AppDbContext _dbContext;

    [ObservableProperty]
    private ObservableCollection<Item> _loadedItems;

    public MainViewModel(AppDbContext dbContext)
    {
        _dbContext = dbContext;
    }
    
    [RelayCommand(AllowConcurrent = true)]
    private async Task LoadDataAsync()
    {
        var items = await _dbContext.Items.ToListAsync();
        LoadedItems = new(items);
    }
}
```

在这个例子中，我们将 `DbContext` 注入到了 `MainViewModel` 中，并且在 `LoadDataAsync` 方法中使用它来加载数据。这里其实就已经出现不少问题了：

1. `MainViewModel` 的实例通常生命周期非常长（可能与整个应用程序相同），而 `DbContext` 被注册为瞬态生命周期，这就意味着每次调用 `LoadDataAsync` 方法时，实际上都是在使用同一个 `DbContext` 实例。那这其实并没有比单例强多少，最多就是不用和其他服务共用同一个实例而已。长时间使用下去，`DbContext` 仍然会积累大量的状态，导致内存泄漏的问题。
2. 这里我故意将 `LoadDataAsync` 方法设置为允许并发执行（`AllowConcurrent = true`）。这就意味着如果用户快速多次点击加载按钮，就会导致多个线程同时访问同一个 `DbContext` 实例，从而引发线程安全问题。

所以说，虽然将 `DbContext` 注册为瞬态生命周期在某些情况下可以工作，但它并不是一个理想的解决方案。除非我们能保证使用它的代码绝对不会并发执行，并且生命周期比较短（比如一个表单的视图模型），否则我们还是需要寻找更好的方法。

## 方法二：为服务注入作用域

既然上面的思路走不通，我们恐怕就不能简单地给视图模型直接注入 `DbContext` 了。为了解决上面的问题，我们应该让视图模型操作数据库的方法有机会每次都创建一个新的实例。顺着这个思路，我们可以让 `DbContext` 继续注册为作用域生命周期，然后为视图模型注入一个 `IServiceScopeFactory`，每次需要访问数据库时，就创建一个新的作用域，从而获得一个新的 `DbContext` 实例。

```c#
public partial class MainViewModel : ViewModelBase
{
    private readonly IServiceScopeFactory _scopeFactory;

    [ObservableProperty]
    private ObservableCollection<Item> _loadedItems;

    public MainViewModel(IServiceScopeFactory scopeFactory)
    {
        _scopeFactory = scopeFactory;
    }
    
    [RelayCommand(AllowConcurrent = true)]
    private async Task LoadDataAsync()
    {
        using var scope = _scopeFactory.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        
        var items = await dbContext.Items.ToListAsync();
        LoadedItems = new(items);
    }
}
```

或者我们还可以更简单一些，我们直接将 `DbContext` 注册为瞬态生命周期，然后为视图模型注入一个 `IDbContextFactory<AppDbContext>`，每次需要访问数据库时，就通过工厂创建一个新的 `DbContext` 实例。

```c#
public partial class MainViewModel : ViewModelBase
{
    private readonly IDbContextFactory<AppDbContext> _dbContextFactory;

    [ObservableProperty]
    private ObservableCollection<Item> _loadedItems;

    public MainViewModel(IDbContextFactory<AppDbContext> dbContextFactory)
    {
        _dbContextFactory = dbContextFactory;
    }
    
    [RelayCommand(AllowConcurrent = true)]
    private async Task LoadDataAsync()
    {
        using var dbContext = _dbContextFactory.CreateDbContext();
        
        var items = await dbContext.Items.ToListAsync();
        LoadedItems = new(items);
    }
}
```

## 总结

总的来说，在本地客户端应用程序中使用 EF Core 时，我们需要特别注意 `DbContext` 的生命周期以及线程安全。只要解决了这两个问题，我们就可以放心地在客户端程序中使用 EF Core 来简化数据访问层的开发。
