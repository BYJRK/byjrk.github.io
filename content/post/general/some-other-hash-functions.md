---
title: "常见与不常见哈希函数"
slug: "some-other-hash-functions"
description: "之前我们已经探讨了密码加盐哈希，这次我们围绕着哈希函数再做一些补充。本文将介绍一些常见和不常见的哈希函数，以及它们的特点和应用场景。"
date: 2025-06-30
tags:
    - hash
    - cryptography
    - security
---

在 [前面的文章](../why-password-hash-with-salt) 中，我们已经探讨了有关密码加盐哈希的话题。这次我们围绕着哈希函数再做一些补充。

哈希函数是计算机科学和密码学中非常重要的工具。它们用于数据完整性验证、数字签名、密码存储等多个领域。哈希函数的种类有很多，它们有的是常见的，有的则相对不那么常用。本文将介绍一些常见和不常见的哈希函数，以及它们的特点和应用场景。

## 早期哈希函数

说起早期的哈希函数，MD5 和 SHA-1 是最广为人知的。当然，在它们之前还有更早的，比如 MD4 和 SHA-0，但它们早已不再被广泛使用。MD5 和 SHA-1 在 1990 年代和本世纪初期非常流行，广泛应用于文件完整性校验、数字签名等场景。

它们虽然曾被广泛使用，但由于安全性问题，现在已不再推荐用于安全敏感的应用。尽管如此，它们仍然非常流行，比如许多软件下载等场景都会提供文件的 MD5 或 SHA-1 校验和，以方便用户验证下载的文件是否完整。所以，即便一个技术有缺点（甚至有严重漏洞），只要它足够流行，仍然会被广泛使用。就像 JPG 图片格式一样，虽然它有很多缺点（比如不支持透明度、不支持无损压缩、容易出现伪影等），但它仍然是最常用的图片格式之一。

那么它们到底有什么安全性问题呢？简单来说，MD5 和 SHA-1 都存在碰撞攻击的风险。碰撞攻击是指两个不同的输入数据经过哈希函数处理后，得到相同的哈希值。这意味着攻击者有可能构造一个恶意文件，使其哈希值与合法文件相同，从而绕过完整性验证。

就拿上面提到的验证下载文件的完整性来说。比如网站告诉你，该文件的哈希值是 `d41d`（这里为方便起见，仅使用前 4 位）。然后你下载了一个文件，计算出来的哈希值也是这个。一般来说，你可以确定这个文件没有被篡改，从而可以放心使用。但是黑客可以构造一个哈希值同样是 `d41d` 的恶意文件，并借助一些手段向你提供这个文件。你下载后，就会误以为这个文件是安全的，最终运行了病毒程序。除了病毒程序，还可能是伪造的证书文件等。这些都可能带来严重的后果。

即便如此，碰撞攻击依旧是成本巨大的。再加上 MD5 的广泛适配性以及高效的计算速度，使得它在很多场景下仍然被使用。比如在一些非安全敏感的应用中，MD5 仍然被用来快速计算文件的哈希值，以便进行完整性校验。

说起哈希碰撞，这里还有一个有趣的例子。在 2017 年，谷歌的研究人员制作了下面这张 GIF 动图。这张动图神奇的地方在于，它可以展示自己的 MD5 值！

![Hashquines: files containing their own checksums](https://www.bleepstatic.com/images/news/u/1164866/2022/sep-2022/md5-image/md5.gif)

更多有意思的例子可以看看 [这篇文章](https://www.bleepingcomputer.com/news/security/this-image-shows-its-own-md5-checksum-and-its-kind-of-a-big-deal/)。

## SHA-2 系列

因为 MD5 和 SHA-1 的安全性问题，SHA-2 系列（包括 SHA-256、SHA-384、SHA-512 等）成为了新的标准。SHA-2 系列的哈希函数在设计上更为复杂，提供了更高的安全性。它们被广泛应用于数字签名、证书颁发机构（CA）等领域。

一般来说，如果我们想要将它用于数据库中存储用户的密码，那么通常还会给它加上一个随机的盐值（salt），这样可以防止彩虹表攻击。彩虹表攻击是指攻击者预先计算出大量常见密码的哈希值，并存储在一个表中。当攻击者获取到哈希值后，可以通过查找这个表来快速破解密码。通过添加盐值，即使两个用户的密码相同，它们的哈希值也会不同，从而增加了破解的难度。

以 C# 为例，使用 SHA-256 哈希函数和盐值来存储密码的代码如下：

```csharp
using System;
using System.Text;
using System.Security.Cryptography;

static byte[] GenerateSalt()
{
    using (var rng = new RNGCryptoServiceProvider())
    {
        byte[] salt = new byte[16];
        rng.GetBytes(salt);
        return salt;
    }

    // 上面的方法会提示已过时，可以使用下面的方式
    // return RandomNumberGenerator.GetBytes(16);
}

static byte[] HashPassword(string password, byte[] salt)
{
    using (var sha256 = SHA256.Create())
    {
        byte[] passwordBytes = Encoding.UTF8.GetBytes(password);
        byte[] saltedPassword = new byte[passwordBytes.Length + salt.Length];
        Buffer.BlockCopy(passwordBytes, 0, saltedPassword, 0, passwordBytes.Length);
        Buffer.BlockCopy(salt, 0, saltedPassword, passwordBytes.Length, salt.Length);
        return sha256.ComputeHash(saltedPassword);
    }

    // 新版本还提供了更简便的静态方法，比如 SHA256.HashData
}
```

然后将加盐哈希后的密码与盐值一起存储到数据库中就可以了。需要验证密码时，先从数据库中获取盐值，然后使用相同的哈希函数和盐值对输入的密码进行哈希，再与存储的哈希值进行比较即可。

不必担心盐值泄露的问题，因为即使攻击者获取了盐值，也无法直接破解密码。盐值的作用是增加哈希值的唯一性和复杂性，使得攻击者无法使用预先计算的彩虹表来破解密码。

## SHA-3 系列

SHA-2 系列虽然解决了 MD5 和 SHA-1 的安全性问题，但它仍然是基于与前代相同的架构（Merkle-Damgård）。科学家担心之前的碰撞方式继续发展和研究下去有可能破解 SHA-2 系列，并且随着量子计算的发展，SHA-2 系列的安全性也可能受到威胁。因此，NIST（美国国家标准与技术研究院）在 2015 年发布了 SHA-3 系列。

SHA-3 系列采用了全新的设计理念，基于 Keccak 算法。它不仅提供了更高的安全性，还可以根据需要选择不同的输出长度（如 SHA3-224、SHA3-256、SHA3-384、SHA3-512 等）。

不过 SHA-3 系列目前的应用并不算广泛，它更多的是作为 SHA-2 的一个备选，以便未来在 SHA-2 系列被破解时可以迅速切换到更安全的哈希函数。此外，虽然它提供了更好的安全性和灵活性，但是在实际的场景下，我们通常会选择其他的一些更擅长某一方面的方法。

## PBKDF2

在 SHA-2 的基础上，为了进一步提高破解的难度，除了引入盐值外，通常还会引入迭代次数。PBKDF2（Password-Based Key Derivation Function 2）就是一个常用的密码哈希函数，它通过多次迭代哈希计算来增加破解的难度。

PBKDF2 的工作原理是将密码和盐值作为输入，经过多次迭代的哈希计算，生成一个固定长度的输出。迭代次数越多，破解的难度就越大。PBKDF2 通常用于密码存储和密钥派生。

在 C# 中，可以使用 `Rfc2898DeriveBytes` 类来实现：

```csharp
using System;
using System.Security.Cryptography;
using System.Text;

static byte[] HashPasswordWithPBKDF2(string password, byte[] salt, int iterations = 10000)
{
    using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, iterations, HashAlgorithmName.SHA256);
    return pbkdf2.GetBytes(32); // 生成 32 字节的哈希值
}
```

## bcrypt 与 Argon2

可惜的是，PBKDF2 在某些情况下可能不够安全，尤其是面对现代硬件的攻击（比如 GPU 超强的并行计算能力）。为了解决这个问题，出现了 bcrypt 和 Argon2 等更安全的密码哈希函数。

bcrypt 是基于 Blowfish 加密算法的密码哈希函数，它通过增加计算复杂度来提高破解难度。bcrypt 的一个重要特性是它可以调整工作因子（cost factor），从而控制哈希计算的时间和资源消耗。工作因子越高，破解的难度就越大。与迭代次数不同的是，这个工作因子是指数级增长的，这意味着每增加一个单位的工作因子，计算时间就会翻倍。在 C# 中，可以使用 `BCrypt.Net-Next` 等库来实现 bcrypt。

Argon2 是 2015 年密码学竞赛的获胜者，它被认为是目前最安全的密码哈希函数之一。Argon2 具有高度的可配置性，可以调整内存使用量、迭代次数和并行度等参数，从而提供更强的安全性。Argon2 分为三个变种：Argon2d、Argon2i 和 Argon2id，分别针对不同的攻击场景。在 C# 中，可以使用 `Konscious.Security.Cryptography.Argon2` 等库来使用 Argon2。

## BLAKE2

BLAKE2 是一个相对较新的哈希函数（2013 年发布），它在速度和安全性之间取得了很好的平衡。BLAKE2 的设计目标是提供比 MD5 和 SHA-1 更快的速度，同时比 SHA-2 更高的安全性。它非常适合用于文件完整性校验、密码哈希等场景。

它的高性能得益于它充分利用了现代 CPU 的 SIMD 指令集（如 SSE2/AVX 等），在多核处理器上表现尤为出色。不仅如此，它还提供了两个主要版本：BLAKE2b 和 BLAKE2s。BLAKE2b 适用于 64 位平台，输出长度可变，最大为 64 字节；而 BLAKE2s 适用于 8 到 32 位平台，输出长度可变，最大为 32 字节。

除此之外，它还提供了很多特性，比如内置密钥机制、可选盐值和个性化字符串等。这些特性使得 BLAKE2 在很多应用场景中都非常有用。

在 C# 中，可以使用 `BouncyCastle` 等库来实现 BLAKE2。以下是一个简单的示例：

```csharp
using Org.BouncyCastle.Crypto;
using Org.BouncyCastle.Crypto.Digests;

var digest = new Blake2bDigest(); // 默认 512，可以改为 8~512 的任意 8 的倍数
digest.BlockUpdate(data, 0, data.Length);
var hash = new byte[digest.GetDigestSize()];
digest.DoFinal(hash, 0);
```

## SM3

最后我们再来介绍一个国产的哈希函数：SM3。SM3 是中国国家密码管理局在 2010 年发布的哈希函数标准。它是中国独立设计和开发的哈希算法，不依赖于国外的标准。这对于国家安全和信息安全具有重要意义。

SM3 算法生成 256 位的哈希值，并且安全性及效率与 SHA-256 相当。它在设计上具有良好的抗碰撞性和单向性，旨在抵抗各种密码分析攻击。

作为中国的国家标准，SM3 在国内的应用越来越广泛，尤其是在金融、政府和军工等领域。

## 总结

哈希函数可谓是种类繁多、各有所长。从早期的 MD5 和 SHA-1，到现在的 SHA-2、SHA-3、PBKDF2、bcrypt、Argon2、BLAKE2 和 SM3，每种哈希函数都有其独特的设计理念和应用场景。

简单来说，一些常见需求及可以选择的哈希函数如下：

- **数据完整性校验**：MD5、SHA-1、SHA-2、BLAKE2
- **密码存储**：PBKDF2、bcrypt、Argon2
- **数字签名**：SHA-2、SHA-3
- **国产安全**：SM3
