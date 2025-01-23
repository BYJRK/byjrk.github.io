---
title: "为什么用户密码需要加盐哈希后再存储？"
slug: "why-password-hash-with-salt"
description: 密码的加盐哈希是一个老生常谈的话题，但是为什么要这样做呢？本文将会从不安全到安全，逐步探讨密码加盐哈希的必要性及实现方式。
date: 2025-01-23
image: https://s2.loli.net/2025/01/23/oNjelMu2p8TmiPw.jpg
math: true
tags:
    - dotnet
    - csharp
    - security
---

> 本文有对应的视频教程：[哔哩哔哩](https://www.bilibili.com/video/BV1F4wWehErP)

我们常说，密码不能明文存储在数据库中，而是应当哈希后存储。尤其我们还要对密码进行加盐处理。这样做的目的及必要性是什么呢？在 C# 中又该如何实现呢？这篇文章我们就来探讨一下。我们将从最不安全到最安全，逐步讲解为什么要这样做。

## 明文存储

首先我们就来看一看最不安全的方式吧：

```csharp
class User
{
    public int Id { get; set; } // 自增主键
    public string Username { get; set; }
    public string Password { get; set; } // 明文密码
}
```

然后我们去创建一个用户：

```csharp
var user = new User
{
    Username = "admin",
    Password = "123456"
};
```

那么现在，数据库中存储的就是用户的明文密码了。这样其实是非常危险的。

- 假如是本地的如 SQLite 数据库，那么只要有人能够访问到数据库文件，或通过反编译等方式获取到了连接字符串，那么就可以直接看到用户的密码；
- 假如是远程的数据库，那么黑客依旧有多种方式可以获取到数据库的数据，比如 SQL 注入、SSH 密钥泄露、数据库备份文件泄露、其他服务器漏洞等等。

明文的密码可以说是相当不应该被泄露的。它不仅可能包含了用户的私密信息以及使用习惯，还可以被黑客直接用来撞库（即通过泄露的密码尝试登录其他网站）。所以我们应当在任何情况下避免明文存储密码。

## 哈希存储（MD5 / SHA1）

下面我们稍微升级一下我们的代码，改为存储使用 MD5 或 SHA1 哈希后的密码：

```csharp
class User
{
    public int Id { get; set; } // 自增主键
    public string Username { get; set; }
    public string PasswordHash { get; set; } // 密码哈希
}
```

然后为了方便开发，我们再写一个密码辅助类，用来进行密码哈希及验证：

```csharp
class PasswordHelper
{
    public static string HashPassword(string password)
    {
        using var md5 = MD5.Create();
        var hash = md5.ComputeHash(Encoding.UTF8.GetBytes(password));
        return Convert.ToBase64String(hash);
    }

    public static bool VerifyPassword(string password, string passwordHash)
    {
        return HashPassword(password) == passwordHash;
    }
}
```

在这个方法中，我们使用 MD5 算法对密码进行哈希，并最终转换为 Base64 字符串。在验证密码时，我们只需要再次哈希输入的密码，然后与数据库中的密码哈希进行比较即可。

{{< notice info >}}
为什么我们通常会将密码转为 Base64 字符串再进行存储，而不是直接存为比如 BLOB 呢？这是因为 Base64 字符串是可读的，方便我们在数据库中查看。不仅如此，字符串的索引的效率也比 BLOB 更高。

在后面的方法中，我们还会看到一些哈希后的密码本身就是可读字符串的方法。所以通常我们会将密码哈希转为字符串进行存储。
{{< /notice >}}

此时我们保存的密码可能形如：

`ISMvKXpXpadDiUoOSoAfww==`

现在这个密码看起来显然比明文要安全多了。但很可惜，在黑客看来，这样的密码恐怕并没有安全太多，因为有一招叫做**彩虹表攻击**。简单来说，黑客可以提前生成一张巨大的彩虹表，里面包含了常见密码的哈希值。然后黑客只需要将数据库中的哈希值与彩虹表中的哈希值进行比对，就可以很快地找到密码。

比如上面的密码，对应的明文是 `admin`。黑客只需要在彩虹表中找到对应的哈希值，就可以轻松破解密码了。可不要小看这个彩虹表，它通常包含巨量的常见密码，甚至是所有可能的密码组合。所以，除非你的密码比较复杂（比如包含大小写、数字及符号），否则可能就会被彩虹表轻易破解。

不仅如此，MD5 和 SHA1 算法本身也是不安全的。它们已经被证明是可以被碰撞的。所谓碰撞，就是两个不同的输入可以生成相同的哈希值。这样的话，黑客就可以通过碰撞来破解密码了。以上述例子来说，虽然黑客可能无法通过彩虹表得知我们的明文是 `admin`，但是他通过计算发现，`qwerty` 同样可以生成相同的哈希值，那么他就可以用 `qwerty` 来登录了。毕竟服务器端的校验只会比对哈希值，而不会比对明文。

## 使用 SHA256 加盐

那么，我们只好进一步升级我们的算法了。这次我们使用能够防止碰撞的 SHA256（它是 SHA-2 系列中的一种，其他常见的还有 SHA-384、SHA-512 等）算法，并且加入一个随机的盐值：

```csharp
class User
{
    public int Id { get; set; } // 自增主键
    public string Username { get; set; }
    public string PasswordHash { get; set; } // 密码哈希
    public string Salt { get; set; } // 盐值
}
```

然后，我们修改一下 `PasswordHelper` 类：

```csharp
class PasswordHelper
{
    public static string HashPassword(string password, byte[] salt)
    {
        var passwordBytes = Encoding.UTF8.GetBytes(password);
        var combinedBytes = new byte[passwordBytes.Length + salt.Length];
        Array.Copy(passwordBytes, 0, combinedBytes, 0, passwordBytes.Length);
        Array.Copy(salt, 0, combinedBytes, passwordBytes.Length, salt.Length);
        var hash = SHA256.HashData(combinedBytes);
        return Convert.ToBase64String(hash);
    }

    public static bool VerifyPassword(string password, string passwordHash, byte[] salt)
    {
        return HashPassword(password, salt) == passwordHash;
    }
    
    public byte[] GenerateSalt()
    {
        return RandomNumberGenerator.GetBytes(16); // 一般 16 字节（256 位）的盐值即可
    }
}
```

{{< notice tip >}}
在较新版本的 .NET 中，我们可以使用很多便利的静态方法，比如 `SHA256.HashData`，`RandomNumberGenerator.GetBytes` 等，而不需要我们先创建实例。

在以前，大家可能会见过使用 `RNGCryptoServiceProvider` 来生成随机数的方法。但是该方法现在已经过时。
{{< /notice >}}

在这个方法中，我们将密码和盐值合并后再进行哈希。这样，即使两个用户的密码相同，由于盐值不同，最终的哈希值也会不同。这样就避免了碰撞的问题。

此外，盐值也是需要存储在数据库中的。这样，在进行密码校验时，会根据用户的 `Id` 或 `Username` 从数据库中取出盐值及加盐哈希后的密码，然后再将用户输入的密码使用相同的盐值进行哈希，最后与数据库中的密码进行比对，从而判断密码是否正确。

这样的密码存储方式，即使黑客拿到了数据库，也无法直接破解密码。因为彩虹表攻击现在已经不再有效，毕竟每个用户都有不同的盐值。

## 使用 PBKDF2

SHA256 加盐的方式已经相当安全了，但是我们还可以进一步提升安全性。因为黑客虽然无法使用彩虹表，但仍然可以尝试暴力破解密码。简单来说，黑客可以尝试使用各种密码组合，然后通过哈希后的密码与数据库中的密码进行比对，从而破解密码。

所以，为了提高密码被暴力破解的难度，之后我们要考虑的方案基本上就是围绕着提高计算的速度来展开。首先，我们可以考虑使用 PBKDF2 算法。这个算法在很多编程语言的标准库中均有提供。在 C# 中，我们可以使用 `Rfc2898DeriveBytes` 类来实现。我们只需要稍加修改我们的 `PasswordHelper` 类即可：

```csharp
class PasswordHelper
{
    public static string HashPassword(string password, byte[] salt)
    {
        using var pbkdf2 = new Rfc2898DeriveBytes(password, salt, 10000, HashAlgorithmName.SHA256); // 迭代 10000 次
        return Convert.ToBase64String(pbkdf2.GetBytes(32)); // 32 字节（256 位）的哈希值
    }

    // 其他方法不变
}
```

{{< notice info >}}
`Rfc2898` 是 `PBKDF2` 的一个实现，所以这里可以说是一回事，只是名字不同。另外，`Rfc2898DeriveBytes` 的构造函数中，我们需要给定使用的哈希算法，否则不包含这一传参的构造函数会提示已过时。
{{</ notice >}}

在这个方法中，我们使用 `Rfc2898DeriveBytes` 类来进行密码哈希。我们可以指定迭代次数，这样就可以提高计算的速度。一般来说，迭代次数越多，计算的速度就越慢，黑客破解密码的难度就越大。但是，迭代次数也不能太多，否则会影响用户登录的速度。一般来说，`10000` 次迭代是一个比较合适的值。

有了这一算法的加持，现在黑客想要暴力破解，需要付出的代价就会大大增加。

## 使用 BCrypt 和 Argon2

但可惜的是，道高一尺，魔高一丈。PBKDF2 算法虽然提高了黑客暴力破解密码的难度，但是仍然有一些问题。比如，黑客可以使用 GPU 或 FPGA 来加速计算，从而提高暴力破解的速度。所以，我们还有更加重量级的选手：BCrypt 及 Argon2。

我们先来看 BCrypt。在 C# 中，我们可以使用 [`BCrypt.Net-Next`](https://github.com/BcryptNet/bcrypt.net) 库来实现 BCrypt 算法。我们只需要稍加修改我们的 `PasswordHelper` 类即可：

```csharp
class PasswordHelper
{
    public static string HashPassword(string password)
    {
        return BCrypt.Net.BCrypt.HashPassword(password, 12); // 12 为工作因子
    }

    public static bool VerifyPassword(string password, string passwordHash)
    {
        return BCrypt.Net.BCrypt.Verify(password, passwordHash);
    }
}
```

并且我们的 `User` 类也可以去掉 `Salt` 属性了。这是为什么呢？因为 BCrypt 算法本身就包含了盐值，相当于替我们代劳了。这样，我们就不需要再自己生成盐值，也不需要专门去存储盐值了。

我们看一个 BCrypt 哈希后的密码：

`$2a$11$lraBT1/lH3RiFXjQbywREutDElnBFaolPOEsDAvo1sjK2iRjwCAUi`

这段文本中，`$2a$` 表示使用的是 BCrypt 算法，`11` 表示工作因子，而后面的内容则是由盐值和哈希后的密码组成。也就是说，这段文本中包含了全部用来验证密码的信息，我们只需要将其存储在数据库中即可。

{{< notice info >}}
工作因子是用来控制计算的速度的，它是 $2$ 的幂运算。比如，上面的密码就对应了 $2^{11}=2048$ 次计算。工作因子越大，计算的速度就越慢，黑客破解密码的难度就越大。通常 $10$ 到 $12$ 是一个比较合适的范围。
{{</ notice >}}

但黑客依旧不甘心，还是打算借助其强大的硬件来尝试破解。这样，我们就要请出我们的杀手锏：Argon2 算法了。

与 BCrypt 一样，Argon2 同样没有 .NET 标准库的实现。我们可以选择一些第三方的库，比如 [`Konscious.Security.Cryptography`](https://github.com/kmaragon/Konscious.Security.Cryptography)。

这里，我们不演示实际在 C# 中该如何使用 Argon2 算法，因为它与 BCrypt 在开发体验及数据模型和表的设计上是类似的。但是，Argon2 算法在安全性上要比 BCrypt 更胜一筹。它引入了更多防止黑客暴力破解的机制，比如内存硬化、并行计算等。它可以轻易调整破解的时间、内存成本以及并行度。

另外，Argon2 还提供了三种变体：Argon2d、Argon2i 和 Argon2id。其中，Argon2d 适用于对抗时间攻击，Argon2i 适用于对抗侧信道攻击，而 Argon2id 则是两者的结合。具体来说：

- Argon2d 更注重防止 GPU 并行计算的攻击。
- Argon2i 更注重抗侧信道攻击。
- Argon2id 是综合了这两种特性，适合一般用途。

相信有了这么“变态”的密码哈希算法，至少现阶段的黑客是彻底束手无策了。

## 总结

在这篇文章中，我们从最不安全的明文存储密码开始，逐步讲解了为什么我们需要对密码进行加盐哈希。我们看到了明文存储密码的危险性，哈希后的密码可能被彩虹表攻击的问题。以及老旧的哈希算法可能存在的被碰撞的问题。然后，我们介绍了 SHA256 加盐、PBKDF2、BCrypt 和 Argon2 等算法，以及它们的优缺点。

在实际开发中，我们应当根据自己的需求和安全性要求来选择适合的密码哈希算法。对于一般的小项目来说，SHA256 加盐已经足够安全了，而且它对于客户端及服务端开销的要求也很低。但是，如果我们对安全性要求很高，那么 BCrypt 或 Argon2 就是不二之选了。
