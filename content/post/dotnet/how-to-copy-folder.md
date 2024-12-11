---
title: "如何在 C# 中拷贝一个文件夹"
slug: "how-to-copy-folder"
description: "本文介绍了三种在 C# 中拷贝文件夹的方法，分别是使用递归、不使用递归、以及使用 VisualBasic 的内置方法。这三种方法各有优劣，读者可以根据自己的需求来选择适合的方法。"
image: https://s2.loli.net/2024/12/11/9swekVbJFzX3DfH.jpg
date: 2024-12-11
tags:
    - dotnet
    - csharp
    - io
---

拷贝文件夹听起来是一个非常简单的任务，但是在 C# 中实现起来却并不是那么容易，因为 .NET 并没有提供内置的方法，所以通常我们只能自己来实现。

本文提供了三种拷贝文件夹的方式供大家参考。

## 方法一：使用递归

使用递归是一个非常直观的方法，同时也是 [Microsoft Learn](https://learn.microsoft.com/en-us/dotnet/standard/io/how-to-copy-directories) 给出的示例。其原版的代码有些冗余和不必要的内存开销，所以这里贴一个相对简练且高效的版本：

```csharp
static void CopyDirectory(string sourceFolderPath, string targetFolderPath)
{
    Directory.CreateDirectory(targetFolderPath);

    foreach (string filePath in Directory.GetFiles(sourceFolderPath))
    {
        string fileName = Path.GetFileName(filePath);
        string destinationPath = Path.Combine(targetFolderPath, fileName);
        File.Copy(filePath, destinationPath, true);
    }

    foreach (string directoryPath in Directory.GetDirectories(sourceFolderPath))
    {
        string directoryName = Path.GetFileName(directoryPath);
        string destinationPath = Path.Combine(targetFolderPath, directoryName);
        CopyDirectory(directoryPath, destinationPath);
    }
}
```

简单来说，这个方法会递归地拷贝源文件夹下的所有文件和子文件夹到目标文件夹中。对于子文件夹，会递归调用该方法进行拷贝。

{{< notice tip >}}
`Directory.CreateDirectory` 是一个相当灵活的方法。如果目标文件夹不存在，它会自动创建；如果目标文件夹已经存在，它会忽略这个操作。同时，它还会沿途创建所有不存在的文件夹（类似 `mkdir` 的 `-p` 参数）。
{{< /notice >}}

## 方法二：不使用递归

如果不希望使用递归，那么也可以通过相对路径的方式来实现。这个方法会递归搜索源文件夹下的所有文件，通过计算它与源文件夹的相对路径来得到它的目标路径，进而生成目标路径所在的文件夹。

```csharp
static void CopyDirectory(string sourceFolderPath, string targetFolderPath)
{
    Directory.CreateDirectory(targetFolderPath);

    foreach (string filePath in Directory.GetFiles(sourceFolderPath, "*.*", SearchOption.AllDirectories))
    {
        var relativePath = Path.GetRelativePath(sourceFolderPath, filePath);
        var targetFilePath = Path.Combine(targetFolderPath, relativePath);
        var subTargetFolderPath = Path.GetDirectoryName(targetFilePath);
        if (subTargetFolderPath != null)
            Directory.CreateDirectory(subTargetFolderPath);
        File.Copy(filePath, targetFilePath);
    }
}
```

{{< notice tip >}}
`Path.GetDirectoryName` 方法有可能返回空。这一情况通常发生在文件位于根目录的情况（例如 Windows 的 `C:\`，或 Unix 的 `/`）。
{{< /notice >}}

## 使用 VisualBasic 的内置方法

其实 .NET 也不是完全没有提供内置的方法。比如我们可以使用 VisualBasic 的 `Microsoft.VisualBasic.Devices` 命名空间下的 `Computer` 类上的 `FileSystem` 成员的方法来实现拷贝文件夹的功能：

```csharp
using Microsoft.VisualBasic.Devices;
using Microsoft.VisualBasic.FileIO;

static void CopyDirectory(string sourceFolderPath, string targetFolderPath)
{
    fs = new Computer().FileSystem;
    fs.CopyDirectory(sourceFolderPath, targetFolderPath, UIOption.OnlyErrorDialogs);
}
```

可能有读者想说，作者你怎么不早点拿出这个方法呢？这方法多么地简单易用啊！

实际上，这个方法也是有显著缺点的：**需要使用 WinForms 相关的库**。也就是说，你的项目需要 `TargetFramework` 包含 `-windows`，并且还要 `UseWindowsForms`。

如果你在开发 WPF 或 WinForms 程序，那么这通常是可以接受的。但如果你是在开发控制台程序、ASP.NET 程序，又或者 Avalonia UI 等跨平台框架，那么这个方法显然就有些 unacceptable 了。

{{< notice tip >}}
其实 `VisualBasic` 还提供了一些别的实用功能，比如将文件移至回收站，就可以用 `FileSystem.DeleteFile` 方法，并添加 `RecycleOption.SendToRecycleBin` 参数来实现。这个方法会将文件移至回收站，而不是直接删除。
{{< /notice >}}

## 总结

本文介绍了三种拷贝文件夹的方法，分别是使用递归、不使用递归、以及使用 VisualBasic 的内置方法。这三种方法各有优劣，读者可以根据自己的需求来选择适合的方法。

{{< notice warning >}}
在拷贝文件夹时，一定要注意文件夹的权限问题。如果源文件夹或目标文件夹的权限不足，那么拷贝操作可能会失败。
{{< /notice >}}
