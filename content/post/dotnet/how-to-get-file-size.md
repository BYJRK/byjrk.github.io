---
title: "C# 获取文件大小的几种方式及它们的性能比较"
slug: "how-to-get-file-size"
description: "本文介绍了在 C# 中获取文件大小的几种方式，包括使用 FileInfo、RandomAccess、P/Invoke 调用 Windows API等，并对它们的性能进行了比较。"
image: https://s2.loli.net/2025/09/06/WBHdw1K6rio2hxP.jpg
date: 2025-09-06
tags:
    - dotnet
    - csharp
    - io
---

我们在操作文件时，经常需要获取文件的大小。相信大家都知道 `FileInfo` 类有一个 `Length` 属性可以获取文件大小，但实际上我们还有一些别的方式，并且其他方式可能比 `FileInfo` 有更好的性能。这篇文章我们就来盘点一下 C# 中获取文件大小的几种方式，并简单比较一下它们的性能。

## 使用 FileInfo.Length

这个是最常见的方式，`FileInfo` 类提供了一个 `Length` 属性，可以直接获取文件的大小，单位是字节（bytes）。

```csharp
using System.IO;

FileInfo fileInfo = new FileInfo(filename);
long fileSize = fileInfo.Length;
```

这种方式的优点是代码简洁易懂，并且几乎适用于所有场景，包括跨平台开发。它唯一美中不足的地方在于，`FileInfo` 在使用前需要实例化，这会带来一点 GC 开销。

另外，如果觉得返回的 `long` 类型不够直观，我们也可以将其转换为更常见的单位，比如 KB、MB、GB 等。对于这个需求，除了自己写转换代码，我们还可以使用 [Humanizer](https://github.com/Humanizr/Humanizer) 这个库，它提供了非常方便的文件大小格式化功能。

```csharp
using Humanizer;

FileInfo fileInfo = new FileInfo(filename);
string humanizedSize = fileInfo.Length.Bytes().Humanize("0.00"); // e.g. "1.23 MB"
```

## 使用 RandomAccess

`RandomAccess` 是一个在.NET 6中引入的静态类，旨在提供高性能、线程安全的文件随机访问I/O操作。它提供的 `GetLength` 方法可以直接获取文件的大小。但稍微有些可惜的是，虽然它的 `GetLength` 方法是静态且不需要创建对象的，但它需要传入一个文件句柄（file handle），而后者是一个 `SafeFileHandle` 对象，这就不可避免地引入了 `FileStream` 对象的创建开销。

```csharp
using System.IO;

using var handle = File.OpenHandle(filename, FileMode.Open, FileAccess.Read, FileShare.Read, FileOptions.RandomAccess);
long fileSize = RandomAccess.GetLength(handle);
```

那么实际上这个方式的效果怎么样呢？在后面的跑分环节会揭晓答案。

## 使用 P/Invoke 调用 Windows API

当程序运行的平台是 Windows 时，我们还可以通过 P/Invoke 调用 Windows API 来获取文件大小。这个方式的好处是它不需要创建任何托管对象，因此理论上它的性能应该是最好的。

```csharp
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;

[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
static extern bool GetFileAttributesEx(
    string lpFileName,
    int fInfoLevelId,
    out WIN32_FILE_ATTRIBUTE_DATA lpFileInformation);

public static long GetFileSizeWin32(string path)
{
    if (!GetFileAttributesEx(path, 0, out var data))
        throw new System.ComponentModel.Win32Exception();

    return ((long)data.nFileSizeHigh << 32) + data.nFileSizeLow;
}

[StructLayout(LayoutKind.Sequential)]
struct WIN32_FILE_ATTRIBUTE_DATA
{
    public uint dwFileAttributes;
    public FILETIME ftCreationTime,
                    ftLastAccessTime,
                    ftLastWriteTime;
    public uint nFileSizeHigh, nFileSizeLow;
}
```

然后我们就可以使用上面的 `GetFileSizeWin32` 方法来获取文件大小了。

{{< notice info >}}
如果是在 Linux 或 macOS 上运行的程序，那么虽然可以采用诸如引入 `Mono.Posix` 之类的库来调用系统 API，但这样做的复杂度和维护成本会比较高，所以推荐直接使用 `FileInfo`。
{{< /notice >}}

## 使用 VisualBasic.FileIO

最后这种方式可能有凑数的嫌疑，但是我们确实可以借助 `Microsoft.VisualBasic` 命名空间下的 `FileSystem` 类来获取文件大小。

```csharp
using Microsoft.VisualBasic.FileIO;

long fileSize = FileSystem.FileLen(filename).Length;
```

## 性能比较

以上就是四种可行的获取文件大小的方式。接下来我们来比较一下它们的性能。结果如下：

| Method          | Mean      | Error     | StdDev    | Allocated |
|---------------- |----------:|----------:|----------:|----------:|
| UseFileInfo     |  7.888 μs | 0.0522 μs | 0.0462 μs |      96 B |
| UseWin32Api     |  7.732 μs | 0.0740 μs | 0.0692 μs |         - |
| UseFileSystem   | 15.779 μs | 0.2104 μs | 0.1968 μs |      96 B |
| UseRandomAccess | 10.627 μs | 0.1137 μs | 0.1063 μs |      72 B |

从结果中我们不难得出以下几个结论：

1. 使用 Windows API 的方式性能最好，并且没有任何托管内存分配。但它只能在 Windows 平台使用。
2. 使用 `FileInfo` 的方式性能也不错，适用于绝大多数场景。
3. 使用 `RandomAccess` 的方式性能一般，虽然它不需要创建 `FileInfo` 对象，但它需要创建 `FileStream` 对象来获取文件句柄，这带来了无法避免的开销（虽然比 `FileInfo` 少了一点）。
4. 使用 `VisualBasic.FileIO` 的方式性能最差，并且还会有内存分配，基本上没有任何优势。

## 总结

综上所述，几乎在任何情况下，我们都可以优先考虑使用 `FileInfo.Length` 来获取文件大小。只有在对于性能有极致要求，并且程序运行的平台确定是 Windows 的情况下，才考虑使用 P/Invoke 调用 Windows API 的方式。
