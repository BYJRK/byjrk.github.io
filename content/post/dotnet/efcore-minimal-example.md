---
title: EntityFrameworkCore 最小入门指南
slug: efcore-minimal-example
date: 2024-03-13
tags:
    - ef
    - csharp
    - dotnet
---

## 安装 EntityFrameworkCore

以 Sql Server 为例，可以在 NuGet 包管理器中搜索并安装以下包：

- `Microsoft.EntityFrameworkCore`
- `Microsoft.EntityFrameworkCore.SqlServer`

## 实现 Model

假定现在有这样一张表：

```sql
CREATE TABLE [dbo].[Blog] (
    [BlogId] INT IDENTITY (1, 1) NOT NULL,
    [Title] NVARCHAR (100) NULL,
    [Author] NVARCHAR (50) NULL,
    [Content] NVARCHAR (MAX) NULL,
);
```

可以创建一个对应的 Model：

```csharp
public class Blog
{
    public int BlogId { get; set; }
    public string Title { get; set; }
    public string Author { get; set; }
    public string Content { get; set; }
}
```

## 创建 DbContext

创建一个继承自 `DbContext` 的类：

```csharp
public class BloggingContext : DbContext
{
    public DbSet<Blog> Blogs { get; set; }
}
```

这里其实幕后发生了一些基于 EF 命名习惯的自动配置，比如：

- `Blog` 类对应的表名为其复数形式 `Blogs`
- `BlogId` 字段会被自动识别为主键

## 配置连接字符串

最简单的方法是直接重写 `OnConfiguring` 方法：

```csharp
class BloggingContext : DbContext
{
    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseSqlServer(@"Data Source=(localdb)\MSSQLLocalDB;Initial Catalog=Blogging;");
    }
}
```

## 使用 DbContext

获取 `Blog` 数据：

```csharp
using (var db = new BloggingContext())
{
    var blogs = db.Blogs.ToList();
}
```

添加新的 `Blog`：

```csharp
using (var db = new BloggingContext())
{
    db.Blogs.Add(new Blog { Title = "Hello World", Author = "Alice", Content = "Hello World!" });
    db.SaveChanges();
}
```

## 总结

在本文中，我们通过一个最小化的示例介绍了如何使用 Entity Framework Core 进行数据访问。我们创建了一个 `BloggingContext` 类来表示数据库上下文，并定义了一个 `DbSet<Blog>` 来操作 `Blog` 实体。我们还展示了如何配置连接字符串，以及如何使用 `DbContext` 来添加和获取数据。

这个简单的例子虽然只涉及到了基本的操作，但它为理解 EF Core 的工作原理和进一步探索其功能提供了基础。

感谢阅读，欢迎在评论区分享你的想法和问题。
