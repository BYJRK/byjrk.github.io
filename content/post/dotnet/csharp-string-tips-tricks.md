---
title: "C# 字符串操作实用技巧及新手易犯错误"
slug: "csharp-string-tips-tricks"
description: 相信所有开发者每天都会和字符串打交道，但是你是否真的了解字符串，能够选择最合适的方式去解决实际问题呢？本文将带你了解 C# 字符串操作的一些实用技巧和易犯错误。
image: https://s2.loli.net/2024/07/29/nzM6Ya8AJDZNlhi.jpg
date: 2024-07-27
tags:
    - csharp
    - dotnet
    - string
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1mx4y1x7JR/)

C# 为字符串相关的操作提供了很多实用的类，比如：

- `string`
- `StringBuilder`
- `Encoding`
- `Regex`

它们的功能相当强大，但这也导致了我们可能并不足够了解它，导致我们可能并不熟悉某些方法的重载，或者不知道某些方法的性能问题，最终导致我们的代码效率低下（而且我们还常常察觉不到）。这篇文章我将为大家介绍一些 C# 字符串操作的实用技巧和易犯错误，希望能帮助大家更好地使用字符串。

## 在可以使用字符的时候不要使用字符串

在 C# 中，声明一个字符与字符串，有一个很典型的区别，就是使用单引号和双引号。除此之外，它们二者也是区别很大的。字符串变量实际上是在堆上分配了一块内存空间，这个空间用来存储字符串的内容。而字符则是值类型，它存储在栈上，所以它的性能要比字符串要好很多。所以绝对不能把字符简单理解为长度为 1 的字符串，它们是完全不同的两种类型，效率也是很不相同的。

在 C# 中使用 `string` 类型的某些方法时，我们就有机会使用字符而不是字符串，比如：

```csharp
string str = "Hello, World!";

str.StartsWith('H');
str.EndsWith('!');
str.Contains('o');
str.IndexOf('o');
str.Split(',');
```

这些方法都有重载，可以接受字符作为参数，这样我们就可以直接使用字符而不是字符串，这样可以提高代码的性能。

为什么要这么做呢？除了上面提到的引用类型和值类型的区别以外，它们还有其他一些区别。以 `Contains` 为例，大家可以想象一下这个方法在底层是如何实现的。比如底层可能会是一个二层循环，第一层循环遍历字符串的每一个字符，第二层循环则在匹配到第一个字符后，再遍历后面的字符，看是否和我们要查找的子字符串相同。

为了保证算法的通用性，即便我们传入的字符串长度为 1，底层也会把它当做一个字符串来处理。这对应到 JIT 编译后的机器码，就会有一些额外的开销，比如判断循环的跳出条件，以及跳转等。而如果我们传入的是字符，那么底层就可以直接比较单个字符的值，这样就可以减少一些额外的开销。

## 使用方法的重载，减少不必要的调用

字符串类的很多方法都包含了大量的重载。正确使用这些重载，有利于我们减少一些额外的调用，以及所造成的资源浪费。比如下面几个例子：

```csharp
string str = "  Hello, World,, Good, Morning ";

// 这里我们希望将上面的内容按照逗号分割，并去除空字符串
// 正确的做法是使用下面这个 Split 方法的重载
var slices = str.Split(',', StringSplitOptions.RemoveEmptyEntries);

//假如我们不知道这个重载，我们可能会写出下面这样的代码
var slices = str.Split(',').Where(s => !string.IsNullOrEmpty(s)).ToArray();

// 还比如我们希望去除每个字符串的前后空格
// 正确的做法是使用下面这个 Split 方法的重载
var slices = str.Split(',', StringSplitOptions.TrimEntries);

// 同样地，假如我们不知道这个重载，我们可能会写出下面这样的代码
var slices = str.Split(',').Select(s => s.Trim()).ToArray();
```

每一次对字符串类型调用它的常见方法，都会产生额外的开销。

我们再来看另外一个例子：比较两个字符串是否相同。如果我们想要忽略大小写进行比较，我们可能会写出这样的代码：

```c#
if (s1.ToLower() == s2.ToLower())
{
    // ...
}
```

但是实际上，我们有效率显著高于上面这种方式的方法 `Equals`：

```c#
if (s1.Equals(s2, StringComparison.OrdinalIgnoreCase))
{
    // ...
}
```

是的，这个方法也拥有一些重载。这样我们就可以避免创建两个新的字符串，以及额外的比较操作。

## string 类的构造函数

相信大多数新手可能声明字符串的方式都是直接使用双引号，或者对其他字符串调用一些方法而得到，比如：

```c#
string str = "Hello, World!";
string str2 = str.Substring(0, 5);
string str3 = str.Replace(",", " ");
```

但实际上，`string` 类还有一些构造函数，可以帮助我们更好地创建字符串。相信用过 Python 的都知道，如果我们想在控制台输出一个长度为 20 个等号的分隔符，通常我们的做法是：

```python
print('=' * 20)
```

其实在 C# 中，我们也可以实现类似的效果：

```c#
string sep = new string('=', 20);
Console.WriteLine(sep);
```

除此之外，如果我们有一个字符数组，我们也可以使用 `string` 类的构造函数来创建字符串。这个技巧一般用不到，可一旦我们有了一个需要转为字符串的字符数组，这个方法就会显得非常有用。一个典型的例子是，如果我们想翻转一个字符串，那么在不借助 `Span` 或 `unsafe` 的情况下，效率最高的方式为：

```c#
char[] chars = str.ToCharArray();
Array.Reverse(chars);
string reversed = new string(chars);
```

如果不知道字符串的构造函数的用法，可能就会写出下面的代码了：

```c#
string reversed = string.Join("", str.Reverse());
```

当然了，我们永远可以写出更加辣眼睛的代码，不是吗？

```c#
// string reversed = new string(str.Reverse().ToArray());
char[] chars = str.Select(c => c).ToArray();
chars = chars.Reverse().ToArray();
string reversed = string.Join("", chars);
```

## 与操作系统有关的一些方法

由于 Windows 与 Unix 系统的一些区别，导致了两个时不常会让我们感到痛苦的事情：换行符和路径分隔符。在 Windows 系统中，换行符为 `\r\n`（CRLF），而在 Unix 系统中，换行符为 `\n`（LF）。而路径分隔符在 Windows 系统中为 `\`，而在 Unix 系统中为 `/`。

在面对这些问题时，我们其实是有一些技巧的。比如处理路径时，我们可以使用 `Path` 类，它会根据当前操作系统的不同，返回不同的路径分隔符：

```c#
var folder = "MyFolder";
var subfolder = "MySubFolder/";
var filename = "MyFile.txt";

var path = Path.Combine(folder, subfolder, filename);
```

这个方法不仅可以帮助我们处理路径分隔符，还可以帮助我们处理路径的拼接，以及路径的规范化。比如上面的例子中，`subfolder` 末尾多了一个 `/`，但是 `Path.Combine` 方法会自动帮我们去除这个多余的 `/`。

类似地，面对换行符的问题，我们可以使用 `Environment.NewLine` 来获取当前操作系统的换行符。比如我们可以用下面的方式拼接一个多行字符串：

```c#
var lines = new string[]
{
    "Hello, World!",
    "Good, Morning!"
};

var text = string.Join(Environment.NewLine, lines);
```

{{<notice tip>}}
类似 `Environment.NewLine` 这样的属性，我们还有 `Path.DirectorySeparatorChar`、`Path.PathSeparator` 等，它们都可以帮助我们处理一些与操作系统有关的问题。
{{</notice>}}

不仅如此，.NET 6 还为我们提供了一个新方法：`ReplaceLineEndings`。这个方法可以帮助我们将字符串中的换行符统一为当前操作系统的换行符：

```c#
var text = "Hello, World!\r\nGood morning!\nGood night!";

// 如果不传参，则默认将换行符替换为当前操作系统的换行符
var normalized = text.ReplaceLineEndings();

// 如果传入参数，则将换行符替换为指定的换行符
var normalized = text.ReplaceLineEndings("\n");
var normalized = text.ReplaceLineEndings("\t");
```

其实很多时候，我们根本不需要显式地与换行符打交道。因为 .NET 的很多方法都会自动帮我们处理这些问题，比如：

```c#
var lines = File.ReadAllLines("file.txt");
File.WriteAllLines("file.txt", lines);

Console.WriteLine("..."); // 在控制台输出文本，并自动换行
Console.ReadLine(); // 读取用户输入，并自动处理换行符

var sb = new StringBuilder();
sb.AppendLine("Hello, World!");
```

等等。这些方法的名称中都会包含 `Line` 这个单词，大加可以多多留意。

## StringBuilder 的一些技巧

`StringBuilder` 可能是一个对于大家来说，既熟悉又陌生的类。熟悉是因为我们在处理大量字符串拼接时，都会用到它，陌生是因为我们可能并不了解它的所有功能。这里我就不多赘述了，我用一小段代码来展示 `StringBuilder` 的一些技巧：

```c#
var sb = new StringBuilder();

// 添加字符串
sb.Append("Hello, World!");
sb.AppendLine("Hello, World!");
sb.AppendFormat("Hello, {0}!", "World");
sb.Append('H', 5);  // 添加 5 个 'H'

sb.Insert(0, "Hello, "); // 在指定位置插入字符串
sb.Replace("Hello", "Good"); // 替换字符串
sb.Remove(0, 5); // 删除指定位置的字符串
sb.Clear(); // 清空 StringBuilder

sb.ToString(); // 将 StringBuilder 转为字符串
sb.ToString(0, 5); // 将 StringBuilder 的一部分转为字符串
```

没想到吧，连它的 `ToString` 方法都包含一个类似 `SubString` 的重载，方便我们减少一次不必要的内存开销。

## 拥抱语法糖，使用字符串内插

在 C# 6 中，我们迎来了字符串内插（String interpolation）这个语法糖。这个语法糖可以帮助我们更加方便地拼接字符串，而且还可以在字符串中插入表达式。比如：

```c#
var name = "World";
var age = 18;

var str = $"Hello, {name}! You are {age} years old.";

// 在以前，我们可能会写出下面这样的代码
var str = string.Format("Hello, {0}! You are {1} years old.", name, age);
```

实际上，这个语法糖的作用远不止于此，它的性能是高于 `string.Format` 的。甚至因为它性能的提升，我们在使用 `StringBuilder` 时，都可以考虑使用字符串内插来代替 `AppendFormat`。不过，对于这种情形，性能最高的方式是连续使用 `Append` 方法，形如：

```c#
var id = 123;
var name = "World";
var age = 18;

var sb = new StringBuilder();

// 使用 AppendFormat
sb.AppendFormat("ID: {0}, Name: {1}, Age: {2}", id, name, age);

// 使用字符串内插
sb.Append($"ID: {id}, Name: {name}, Age: {age}");

// 使用连续的 Append 方法
sb.Append("ID: ").Append(id).Append(", Name: ").Append(name).Append(", Age: ").Append(age);
```

## 总结

除此之外，字符串还有很多技巧，比如：

1. 原始字符串（Raw string）
2. `StringPool` 与 `string.Intern`
3. `Span<char>`
4. 文本编码（`Encoding`）
5. 一些与字符串有关的特性
   
但是因为篇幅的关系，我们这次就不展开了。希望大家能够通过这篇文章，了解到一些 C# 字符串操作的实用技巧和易犯错误。希望大家在以后的开发中，能够更加熟练地使用字符串，写出更加高效的代码。
