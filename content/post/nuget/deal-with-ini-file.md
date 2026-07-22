---
title: "如何读写 INI 配置文件？"
slug: "deal-with-ini-file"
description: INI 文件是一种相当古老的配置文件格式，但如今仍然被广泛使用。本文将会介绍几种在 C# 中读写 INI 文件的方法，并探讨它们的效率和适用场景。
image: https://s2.loli.net/2024/07/11/QyFiMdrfNPKpazT.jpg
date: 2024-07-11
tags:
    - csharp
    - dotnet
---

INI 文件是一种相当古老的配置文件格式，但很“可惜”的是，它如今依旧被广泛使用。正因为如此，即便现在已经出现了很多更加现代化的配置文件格式（比如 JSON、YAML、TOML 等），我们仍然可能会遇到读写 INI 文件的情形。那么这次我们就来看看如何在 C# 中读写 INI 文件。

## INI 文件格式概述

INI 文件是一种文本文件，它由一系列的节（Section）和键值对（Key-value pair）组成。每个键值对都位于某个节中，键和值位于等号（`=`）左右，而节则由方括号（`[]`）括起来。一个简单的 INI 文件看起来可能是这样的：

```ini
[Section1]
Key1=Value1
Key2=Value2

[Section2]
Key3=Value3
Key4=Value4
```

此外，INI 文件还支持注释，通常以分号（`;`）开头（有时也可以自定义为其他符号，比如 `#` 等），直到行尾为止：

```ini
[Section1]
Key1=Value1 ; 这是一个注释
```

INI 文件的格式要求基本就是这样了。其他可能还有一些诸如命名习惯，以及等号左右是否添加空格等细节，但这些通常都是没有具体约束的。

不难发现，INI 因为格式极其简单，所以它的解析也是相当容易的，我们稍加思考，通常就可以写出一个简单的解析器。但是，既然已经有现成的解析库，我们当然不必自己重复造轮子。接下来我们就来看看在 C# 中如何读写 INI 文件。

## 传统方法：使用 Win32 API

相信大家只要在网上搜索过这个问题，就一定会看到有人推荐使用 Win32 API 来读写 INI 文件。这种方法的优点是简单、高效，但缺点也很明显：它是不跨平台的。如果你的程序需要在 Linux 或 macOS 上运行，那么这种方法就不适用了。

INI 文件的读写操作在 Windows 平台上有专门的 API 支持，这些 API 位于 `kernel32.dll` 中。我们可以通过 P/Invoke 的方式调用这些 API，实现对 INI 文件的读写。

```c#
using System;
using System.Runtime.InteropServices;

[DllImport("kernel32")]
private static extern long WritePrivateProfileString(string section, string key, string val, string filePath);

[DllImport("kernel32")]
private static extern int GetPrivateProfileString(string section, string key, string def, StringBuilder retVal, int size, string filePath);

public string IniReadValue(string Section,string Key)
{
    StringBuilder temp = new StringBuilder(256);
    int i = GetPrivateProfileString(Section,Key,"",temp, 256, this.path);
    return temp.ToString();
}
```

我们只需要从 `kernel32.dll` 中导入 `WritePrivateProfileString` 和 `GetPrivateProfileString` 两个函数，就可以实现对于 INI 文件的读写操作了。通常情况下，我们还会额外写一个 `IniReadValue` 方法来包装 `GetPrivateProfileString` 函数，以便更加方便地读取键值。

{{<notice info>}}
除了上面的两个方法，`kernel32.dll` 中还有一些其他的函数，比如 `GetPrivateProfileSection`、`GetPrivateProfileSectionNames` 等，它们可以帮助我们更加方便地操作 INI 文件。有兴趣的读者可以自行查阅相关文档。
{{</notice>}}

但是大家在使用这个库的时候，不知道会不会有一种仿佛“高射炮打蚊子”一样的心情？毕竟 INI 这么简单的一种格式，居然要使用到 P/Invoke 来调用 Win32 API，这未免也太麻烦了。所以，这种传统方式存在以下问题：

1. 使用体验差：需要通过 P/Invoke 来调用 Win32 API，这对于 C# 开发者来说并不是一种友好的体验。
2. 不跨平台：这种方法只能在 Windows 平台上使用，无法在 Linux 或 macOS 上运行。
3. 线程不安全：由于这是一个全局函数，每次调用都会操作外部文件，所以在多线程环境下可能会出现问题。
4. 时间复杂度高：假如我们想要读取 INI 文件中的多个键值对，那么就需要多次调用 `GetPrivateProfileString` 函数，而每次调用都需要从文件开头开始读取，直到找到对应的键值对。这样的时间复杂度显然是不够理想的。
5. 文本编码：这种方法只会使用系统默认的文本编码（比如中文操作系统的 ANSI 对应 GBK 编码），无法指定其他编码，因此非 ASCII 字符可能会出现乱码。

所以下面我们再介绍几个别的库。但是大家也不要高兴太早，因为这些库虽然各有优点，但也有各自的问题。

## 第三方库：Ini-Parser

[ini-parser](https://github.com/rickyah/ini-parser) 是一款非常好用的 INI 文件解析库。它可以一次性将整个 INI 文件解析为一个 `IniData` 对象（可以想象成一个字典），从而方便我们像操作字典那样便捷又高效地进行高频率的读写操作，并在最后统一写回文件。

{{<notice tip>}}
大家在 NuGet 中搜索 `ini-parser` 时，还会发现 `ini-parser-netstandard` 这个库。这两个库的功能是一样的，只是前者是 .NET Framework的，而后者则是 .NET Standard 2.0 的，因此可以在 .NET Core、.NET 5+ 及跨平台环境中使用，甚至还可以用于 Unity 游戏开发。推荐大家在任何情况下都使用后者。
{{</notice>}}

```c#
using IniParser;

var parser = new FileIniDataParser();
IniData data = parser.ReadFile("config.ini");

// 读取键值对
string value1 = data["Section1"]["Key1"];
string value2 = data["Section1"]["Key2"];

// 修改键值对
data["Section1"]["Key1"] = "NewValue1";
data["Section1"]["Key2"] = "NewValue2";

// 写回文件
parser.WriteFile("config.ini", data);
```

除此之外，它还支持更多功能，比如合并多个 INI 文件等。大家可以查看官方文档来了解更多信息。

但是，这个库有一个非常明显的限制：虽然它一次性读取了整个 INI 文件，使得我们在需要频繁读写时更加高效。但是当文件较大时，一次性读取整个文件可能会导致占用更大的内存；不仅如此，如果我们的需求仅仅是临时读写某一项配置，那么这种一次性读取整个文件的方式显然是不够高效的。

所以这里再和大家推荐另外一个库。

## 第三方库：IniSharp

[IniSharp](https://github.com/kevinlae/IniSharp) 真是一个不错的名字。这个库提供了便捷的操作 INI 文件的方法，并且不依赖 Win32 API，因此可以在跨平台环境下使用。

```c#
using IniSharp;

var ini = new IniFile("config.ini", Encoding.UTF8);

var value1 = ini.GetValue("Section1", "Key1");
var value2 = ini.GetValue("Section1", "Key2", "Default");  // 如果该键不存在，则创建并返回默认值

ini.SetValue("Section1", "Key1", "NewValue1");

ini.DeleteKey("Section1", "Key2");

ini.DeleteSection("Section2");

List<string> sections = ini.GetSections();
List<string> keys = ini.GetKeys("Section1");
```

这个库并不会一次性读取整个 INI 文件，而是在每次操作时进行读取或写入操作，因此不会占用过多的内存。这在我们的需求是临时读写某一项配置时显得尤为重要。

但是我仍然要泼大家一盆冷水：这个库的性能并不高，因为它底层的代码存在一些值得优化的空间。以读取单个键值的方法为例（以下代码为节选，并不完整）：

```c#
// 它在底层声明了一个“碰巧”与 Win 32 API 一样的函数名
private string GetPrivateProfileString(string section, string key, string defaultValue = null)
{
    List<string> lines = File.ReadAllLines(filePath, FileEncoding).ToList();
    (int sectionNum, int keyNum) = FindSectionAndKey(section, key, lines);
    if (sectionNum != -1 && keyNum != -1)
    {
        int startIndex = lines[keyNum].IndexOf(key);
        int equalsIndex = lines[keyNum].IndexOf('=', startIndex + key.Length);
        string strLalue = lines[keyNum].Substring(equalsIndex + 1);
        int hashIndex = strLalue.IndexOf(commentChar);
        return (hashIndex != -1) ? strLalue.Substring(0, hashIndex) : strLalue;
    }
    if (defaultValue != null)
    {
        if (sectionNum != -1)
        {
            if (keyNum == -1)
            {
                lines.Insert(sectionNum + 1, $"{key}={defaultValue}");
                lock (lockObject)
                {
                    File.WriteAllLines(filePath, lines, FileEncoding);
                }
            }
        }
        else
        {
            lock (lockObject)
            {
                using (StreamWriter sw = File.AppendText(filePath))
                {
                    sw.WriteLine($"[{section}]");
                    sw.WriteLine($"{key}={defaultValue}");
                }
            }
        }
    }
    return defaultValue;
}
```

不难看出几个问题：

1. 它使用的是 `ReadAllLines()` 方法，而不是采用 `ReadLines()` 方法返回一个延迟加载的 `IEnumerable<string>`，或使用 `StreamReader` 逐行读取。这样会导致一次性读取整个文件，占用更多内存。尤其是即便我们要找的键就在文件的开头，它也会从头读取整个文件，这显然是不够高效的。
2. 它使用了 `File.WriteAllLines()` 方法，每次修改都会重写整个文件。
3. 在插入新键值对时，它使用了 `List.Insert()` 方法，这会导致整个列表的元素向后移动，时间复杂度为 O(n)。

除此之外，这个库还有其他一些提升空间，比如可以使用 `Span`、`ArrayPool` 等，来减少内存分配和 GC 压力。

## 总结

上面提到的几种方式可以说是各有千秋，总会存在一些缺憾，因此关于 INI 这么简单的一个文件格式，我们的故事并没有结束。在后续的文章中，我还会和大家分享更多关于 INI 文件的读写方法，以及一些优化技巧。欢迎大家继续关注我的博客。
