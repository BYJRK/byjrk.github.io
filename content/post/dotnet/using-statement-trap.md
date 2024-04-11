---
title: "Using 语句的陷阱"
slug: "using-statement-trap"
description: "using 语句的减少一层缩进的新用法在释放资源时可能会有意想不到的效果，不能无脑使用。"
image: https://s2.loli.net/2024/04/11/lbxw86NGjKJyqAv.jpg
date: 2024-04-11
tags:
    - dotnet
    - csharp
    - syntax
---

`using` 语句在 C# 中有很多种用法，比如引入命名空间，为类型起别名，或者释放资源等。这篇文章我们主要讨论 `using` 语句在释放资源时的陷阱。

## using 以前的使用方式

在很久很久以前，我们如果想要读取一个外部文本文件的内容，可能会这样写（不考虑更简洁易用的 `File.ReadAllText()` 等方法）：

```csharp
using (var stream = new FileStream(filename, FileMode.Open))
{
    using (var reader = new StreamReader(stream))
    {
        var content = reader.ReadToEnd();
        Console.WriteLine(content);
    }
}
```

其实上面的代码，是可以减少一层缩进的，并且这也是各种 IDE 推荐的写法，形如：

```csharp
using var stream = new FileStream(filename, FileMode.Open)
using var reader = new StreamReader(stream)
{
    var content = reader.ReadToEnd();
    Console.WriteLine(content);
}
```

这个其实很有意思，因为一般我们都认为，即便外层的语句省略了花括号，内层的语句依旧会保持缩进，就比如多层 `if` 语句：

```csharp
if (condition1)
    if (condition2)
    {
        // do something
    }
```

但是上面展示的 `using` 的省略外层花括号的新语法，内层的语句并不会额外添加缩进，而是会与外层保持同一层级。不信的话，可以使用任意一个格式化工具，比如 Visual Studio 的 `Ctrl+K, Ctrl+D`，格式化一下上面的代码，看看会是什么样子。

## using 的新语法

C# 8.0 为我们带来了一个新的 `using` 语句的用法，可以减少一层缩进，让代码看起来更简洁。同样是上面的代码，现在可以写成：

```csharp
string filename = "test.txt";
using var stream = new FileStream(filename, FileMode.Open);
using var reader = new StreamReader(stream);

var content = reader.ReadToEnd();
Console.WriteLine(content);
```

上面的代码实际上会被编译为这样的 low-level C# 代码：

```csharp
string path = "test.txt";
FileStream fileStream = new FileStream(path, FileMode.Open);
try
{
    StreamReader streamReader = new StreamReader(fileStream);
    try
    {
        string value = streamReader.ReadToEnd();
        Console.WriteLine(value);
    }
    finally
    {
        if (streamReader != null)
        {
            ((IDisposable)streamReader).Dispose();
        }
    }
}
finally
{
    if (fileStream != null)
    {
        ((IDisposable)fileStream).Dispose();
    }
}
```

不难看出，`using` 语句用于资源释放时，其实是通过 `try-finally` 语句来实现的。当存在多层的 `using` 语句时，每一层都会对应一个 `try-finally` 语句，也就变成了上面的样子。

新的语法会将 `using` 语句下面的内容（准确地说，是当前作用域中剩下的代码）包装在 `try-finally` 语句中，从而保证代码在离开作用域前，会释放资源。

{{<notice info>}}
仔细观察还可以发现，`Dispose` 的顺序是从内到外的，或者说先被 `using` 的对象会后被释放。
{{</notice>}}

## 新语法的陷阱

学了这个新语法之后，相信很多人都打算全面替代掉旧方法，毕竟少写了花括号，而且减少了缩进，效果还一模一样。但实际上，这种新语法并不是适用于所有情况的。也就是说，效果未必一模一样。比如之前我就踩了一个坑。

当时的情况是，我在使用 `System.IO.Compression` 命名空间下的 `GZipStream` 来压缩一个文本，并输出压缩后的内容。我使用的代码如下：

```csharp
using System.IO.Compression;
using System.Text;

string input = "text to be compressed.";

using var outputStream = new MemoryStream();
using var inputStream = new MemoryStream(Encoding.UTF8.GetBytes(input));
using var compressor = new GZipStream(outputStream, CompressionLevel.Optimal);

inputStream.CopyTo(compressor);
var compressed = outputStream.ToArray();
Console.WriteLine(compressed.Length);
```

运行后，输出了压缩后的内容长度为 `10`。

但是当我修改了 `input` 的字符串内容后，发现输出的长度依旧是 `10`，这显然是不可能的。我检查了一下代码，发现问题出在了 `using` 语句上。只要把上面的代码修改成这样，就能得到正确的结果：

```csharp
using var outputStream = new MemoryStream();
using (var inputStream = new MemoryStream(Encoding.UTF8.GetBytes(input)))
using (var compressor = new GZipStream(outputStream, CompressionLevel.Optimal))
{
    inputStream.CopyTo(compressor);
}
var compressed = outputStream.ToArray();
Console.WriteLine(compressed.Length);
```

造成这一现象的原因是，如果想要得到正确的压缩后的内容，需要保证 `GZipStream` 已经被释放。但是如果我们不加声明 `GZipStream` 这一行的花括号，会导致它直到离开作用域时才被释放，而不是在 `inputStream.CopyTo(compressor)` 之后立即释放。

所以，大家在使用新的 `using` 语句时，一定要根据实际情况来判断是否适用，不要无脑替换掉以前的旧写法。