---
title: 常见图片相关的数据类型之间的转换
slug: "image-datatypes-conversion"
description: "本文总结了 .NET 开发中（尤其是 WPF）常见的图片数据类型之间的转换方法，希望能帮助大家理清思路，以及发现规律。"
image: https://s2.loli.net/2024/11/19/bqvEn9ipfu7DPem.jpg
date: 2024-11-19
tags:
    - dotnet
    - csharp
    - wpf
    - winforms
---

我们在做 .NET 开发时，经常要和各种图片的数据类型打交道。**这里指的“类型”并不是图片的文件类型，比如 jpg、png、bmp 等，而是图片数据在内存中的表示方式**。这些类型之间的转换，有时候会让人感到困惑。本文总结了常见的图片数据类型之间的转换方法，希望能帮助大家理清思路。

常见的图片数据类型有：

- `byte[]` 字节数组：可能有两种情况：
  - 将图片文件读取到内存后得到的字节数组，包括图片文件的文件头等
  - 图片的像素数据，比如 RGB 数据
- `Stream`：数据流，比如 `MemoryStream`、`FileStream` 等，一般和字节数组可以轻易地相互转换
- `Bitmap`：WinForms 中的图片数据类型（基于 GDI+），命名空间是 `System.Drawing`
- `BitmapImage`：WPF 中的图片数据类型，命名空间是 `System.Windows.Media.Imaging`，常用于 `Image` 控件的 `Source` 属性（是 `ImageSource` 类型）
- `BitmapSource`：WPF 中的图片数据类型，命名空间是 `System.Windows.Media`，是 `BitmapImage` 的基类
- 其他一些来自第三方库的图片类型

## 将图片文件路径转为 BitmapImage

如果我们知道图片的链接（可以是本地链接或网址），并且想让 `Image` 控件显示这个图片，最简单的方式如下：

```csharp
var image = new Image();
image.Source = new BitmapImage(new Uri(@"path\to\image.jpg", UriKind.RelativeOrAbsolute));
```

上述方式甚至都不需要指定图片的格式，因为 `BitmapImage` 和 `BitmapDecoder` 都会自动进行处理。**对于大多数常见的图片格式（如 JPG、PNG、BMP、GIF、TIFF、WebP、HEIC、AVIF 等），这几种方式都能正常工作**。但如果是一些不太常见的图片格式，则可能需要借助一些第三方库才行了。

另外，如果我们并没有图片的路径，只有它被读进内存后的数据类型，那么就需要下面的几种方式了。

## Bitmap 转为 BitmapImage

`System.Drawing.Bitmap` 和 `System.Windows.Media.Imaging.BitmapImage` 是两个常见的图片数据类型。前者是 WinForms 中的类型（GDI+），后者是 WPF 的类型。它们之间的转换方法如下：

```csharp
using System.Drawing;
using System.Windows.Media.Imaging;

static BitmapImage ConvertBitmapToBitmapImage(Bitmap bitmap)
{
    using var stream = new MemoryStream();

    bitmap.Save(stream, ImageFormat.Png);
    stream.Position = 0;
    
    var bitmapImage = new BitmapImage();
    bitmapImage.BeginInit();
    bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
    bitmapImage.StreamSource = stream;
    bitmapImage.EndInit();
    bitmapImage.Freeze(); // （可选）冻结图片，提高性能和线程安全性
    return bitmapImage;
}
```

## 字节数组转为 ImageSource

这里有两种情况。如果字节数组只是读进内存的图片文件数据，比如一个本地的 JPG、PNG、BMP 等格式的文件，那么非常简单：

```csharp
using System.IO;
using System.Windows.Media.Imaging;

static ImageSource ConvertByteArrayToImageSource(byte[] bytes)
{
    using var stream = new MemoryStream(bytes);
    var bitmapImage = new BitmapImage();
    bitmapImage.BeginInit();
    bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
    bitmapImage.StreamSource = stream;
    bitmapImage.EndInit();
    bitmapImage.Freeze();
    return bitmapImage;
}
```

还有一种更简单的方式，直接使用 `BitmapDecoder` 类：

```csharp
using System.Windows.Media.Imaging;

static ImageSource ConvertByteArrayToImageSource(byte[] bytes)
{
    using var stream = new MemoryStream(bytes);
    return BitmapDecoder
        .Create(stream, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad)
        .Frames[0];
}
```

如果字节数组是图片的像素数据，比如从左上到右下的逐行 RGB 数据，那么会麻烦一些，而且我们需要有办法知道图片的宽高等信息：

```csharp
using System.Windows.Media;
using System.Windows.Media.Imaging;

static ImageSource BgrByteArrayToImageSource(byte[] array, int width, int height, int channel = 3, int? stride = null)
{
    var bmp = new WriteableBitmap(width, height, 96, 96, PixelFormats.Bgr24, null);
    stride ??= ((width * channel + 3) / 4) * 4;
    bmp.WritePixels(new Int32Rect(0, 0, width, height), array, stride.Value, 0);
    bmp.Freeze();
    return bmp;
}
```

## BitmapSource 转为 BitmapImage

这两个类其实是有继承关系的，`BitmapImage` 继承自 `BitmapSource`。但一般我们仍然需要进行一个“转换”，因为通常的使用场景是，我们从 WPF 提供的剪贴板 API 中获取到一个 `BitmapSource`，但我们经过简单的处理，将它转为 `BitmapImage` 从而添加给 `Image` 控件。这时候可以这样转换：

```csharp
using System.Windows.Media.Imaging;

static BitmapImage ConvertBitmapSourceToBitmapImage(BitmapSource bitmapSource)
{
    var bitmapImage = new BitmapImage();
    using var stream = new MemoryStream();
    BitmapEncoder encoder = new BmpBitmapEncoder(); // 一般情况下，剪贴板中的图片数据是 BMP 格式的，而非 PNG 格式
    encoder.Frames.Add(BitmapFrame.Create(bitmapSource));
    encoder.Save(stream);
    stream.Position = 0;
    bitmapImage.BeginInit();
    bitmapImage.CacheOption = BitmapCacheOption.OnLoad;
    bitmapImage.StreamSource = stream;
    bitmapImage.EndInit();
    bitmapImage.Freeze();
    return bitmapImage;
}
```

## Emgu.CV.Image 转为 BitmapImage

前面我们提到，`BitmapImage` 支持绝大多数常见的图片格式。但如果现在我们有一个不常见的格式，比如 JP2（JPEG 2000）格式，那么 `BitmapImage` 就无法直接处理了。这时候我们可以使用 Emgu.CV 库，它是 OpenCV 的 .NET 封装，支持更多的图片格式。下面给出一种方式：

```csharp
var filename = @"path\to\image.jp2";

var mat = new Image<Bgr, Byte>(filename);
var bytes = mat.ToJpegData();
using var stream = new MemoryStream(bytes);

var bitmap = new BitmapImage();
bitmap.BeginInit();
bitmap.CacheOption = BitmapCacheOption.OnLoad;
bitmap.StreamSource = stream;
bitmap.EndInit();
bitmap.Freeze();

var control = new Image();
control.Source = bitmap;

control.Dump();
```

## 总结

看了这么多，大家相信已经看出规律了吧？是的，对于大多数情况，我们都要先将数据转为持有常见图像类型的 `Stream`，然后再创建 `BitmapImage`，最后将其赋给 `Image` 控件。这样的方式，可以保证我们的代码在大多数情况下都能正常工作。
