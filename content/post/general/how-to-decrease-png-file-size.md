---
title: "如何减少 PNG 文件大小"
slug: "how-to-decrease-png-file-size"
image: https://files.seeusercontent.com/2026/09/01/fOh7/pasted-image-1788255990527.webp
description: "当要求 PNG 图片的分辨率不能太低，同时文件大小不能太高时，我们该怎么做？"
date: 2026-09-01
tags:
  - image
  - imagemagick
  - pngquant
  - oxipng
---

今天在推特上看到了一个有意思的帖子：

![用户@Jaidcel于2026年9月1日发的帖子](https://files.seeusercontent.com/2026/09/01/H6lp/pasted-image-1788254262737.webp)

大致是说，他在尝试发布 ChatGPT Plugin 时，发现需要提交一个指定要求的图标文件：

- PNG 格式
- 分辨率最好不小于 256x256
- 文件大小不超过 10 KB

这看似平平无奇的要求，其实可能还真没有那么简单，尤其是对于不熟悉图像处理的用户来说。不信的话，我这里有一张之前用 AI 生成的图标：

![](https://files.seeusercontent.com/2026/09/01/6yEu/pasted-image-1788254491243.webp)

我将它用 ImageMagick 以默认的参数转为 PNG 格式，256x256 的尺寸后，发现它的大小是 64.6 KB，距离要求的 10 KB 还差得远。

虽然官方没有要求必须不小于 256x256，但如果我们确实想达到这个分辨率，这该怎么办呢？

## 尝试使用不复杂的图片

上面那张图片之所以体积比较大，是因为它的内容比较复杂，包含了很多颜色和细节。对于 PNG 文件来说，复杂的图像通常会导致文件大小增加。所以，如果我们反其道而行之，尝试使用一些不复杂的图片，可能会更容易满足文件大小的要求。

这里我从网上随便找了一个 GitHub 给用户默认生成的头像，即 Identicon，它的内容相对简单，颜色也不多：

![](https://files.seeusercontent.com/2026/09/01/R6ej/pasted-image-1788254909629.webp)

此时图片的大小瞬间来到了只有 2 KB 不到。

这确实满足了要求，但是难道说我们就只能用这么简单的图片作为图标了吗？

## 尝试压缩 PNG 图片

我们当然不甘心只能用这么简单的图片了。所以回到刚开始的图标，我们来想想办法如何降低它的体积。首先我们来试试用 ImageMagick 将它以最高的压缩质量进行编码，即：

```shell
magick input.png -quality 100 output.png
```

但很遗憾，它的体积也只是从刚刚的 64.6 KB 降低到了 62.6 KB。看来这条路行不通。

{{<notice tip>}}
这里我们还可以添加 `-strip` 参数来去掉图片的元数据，从而进一步降低体积。但通常只会降低大约零点几 KB，基本可以忽略不计。
{{</notice>}}

那我们再尝试一个笨方法：先将它适当缩小，再放大，也就是人为制造了马赛克，降低了图片质量。为了更有马赛克的感觉，我们采用最近邻插值法（`-filter point`），命令如下：

```shell
magick input.png -resize 64x64 -filter point -resize 256x256 output.png
```

![](https://files.seeusercontent.com/2026/09/01/8cuH/pasted-image-1788255519450.webp)

这次文件体积是 8.64 KB，终于满足了要求。但我们仍不满足，因为这太模糊了。

## 量化 PNG 图片到 256 色

如果我们想要在保持图片清晰度的同时降低文件体积，那么量化图片到 256 色可能是一个不错的选择。PNG 格式支持调色板模式（Indexed Color），这意味着我们可以将图片的颜色数量限制在 256 种，从而显著减少文件大小。

我们仍然可以借助 ImageMagick 来实现这一点，命令如下：

```shell
magick input.png -colors 256 output.png
```

这里将原图、256 色、192 色并排放在了一起：

![](https://files.seeusercontent.com/2026/09/01/fOh7/pasted-image-1788255990527.webp)

是不是乍一看起来差别不大？但实际上，放大之后不难发现，256 色的图像在细节上已经有所损失，而 192 色的图像则更为明显。而且遗憾的是，降低到 192 色之后，文件大小依然有 15.1 KB，虽然我们好像已经离成功不远了。

但遗憾的是，继续降低颜色数量到 128 色甚至 64 色之后，文件大小仍然有 11.7 KB。后续降低颜色数量的收效甚微，但图片质量已经越来越惨不忍睹了。

## 用 pngquant + oxipng

pngquant 跟上面我们用的 ImageMagick 做的事情类似，都是做颜色上的量化，但是它还能通过智能量化、抖动（dithering）等方式减少肉眼可见的损失，所以通常会得到更好的结果。

但是光使用它还不够，因为它只负责颜色量化。我们还可以搭配 oxipng 这个无损 PNG 优化器来进一步压缩。

为了达到 10 KB 以内的大小，我也是尝试了多次，最后得到了这样的方案：

```shell
# 先用 pngquant 将颜色量化到 24 色，并设置质量为 30
pngquant 24 --quality=30 tmp.png
# 再用 oxipng 进行无损压缩
oxipng -o 4 --strip safe output.png
```

终于，我们达到了 9.47 KB 的大小，也算是完成了任务。这里贴一张结果图：

![](https://files.seeusercontent.com/2026/09/01/o5Un/pasted-image-1788256823971.webp)

但这个结果也是经不起细看的。所以，ChatGPT 对于图标的要求，可真是没那么容易满足啊。

## 总结

经过这一番折腾，我们不难得出结论：在尺寸与格式固定时，将复杂图像极限压缩至 10 KB 内，必须依赖**强力颜色量化**搭配**专业无损二次压缩**，且不可避免需要在细节与画质上做出一定妥协。
