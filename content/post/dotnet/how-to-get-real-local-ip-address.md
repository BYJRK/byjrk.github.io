---
title: "如何在 C# 中获取本机真实 IP 地址？"
slug: "how-to-get-real-local-ip-address"
description: "在 C# 中获取本机 IP 地址并不是一个简单的问题，因为我们几乎总是会获取到很多 IP 地址，而判断哪一个才是我们想要的真实局域网 IP 地址才是我们真正面对的问题。本文将介绍如何获取本机的真实局域网 IP 地址。"
date: 2026-01-15
tags:
    - dotnet
    - csharp
    - networking
---

获取本机 IP
地址听起来是一个非常简单的需求，但实际操作起来却并不容易。虚拟网卡、IPv6、APIPA
地址等因素会让我们获取到一大堆 IP，而如何从中筛选出真正想要的局域网 IP
才是我们要解决的问题。

## 常见的坑

### 1. 获取到一堆 IP 地址

最直接的想法可能是使用 `Dns.GetHostAddresses` 或 `Dns.GetHostEntry`
来获取本机所有的 IP 地址：

```csharp
var hostName = Dns.GetHostName();
var ipAddresses = Dns.GetHostEntry(hostName).AddressList;

foreach (var ip in ipAddresses)
{
    Console.WriteLine(ip);
}
```

运行后你可能会看到类似这样的输出：

```
192.168.1.100
169.254.123.45
172.17.0.1
10.0.75.1
192.168.56.1
fe80::1234:5678:abcd:ef01%12
::1
```

这么多 IP 地址，到底哪个才是我们想要的真实局域网 IP？

### 2. 虚拟网卡的干扰

现代计算机上通常会存在多种类型的网络适配器：

- **物理网卡**：真实的以太网卡或 Wi-Fi 适配器
- **虚拟网卡**：
  - VMware、VirtualBox、Hyper-V 等虚拟机软件创建的虚拟网卡
  - Docker Desktop 创建的虚拟网卡（如 vEthernet）
  - VPN 软件创建的虚拟适配器
  - WSL2 创建的虚拟网卡
  - 蓝牙适配器
  - 回环地址（Loopback）

这些虚拟网卡都会有自己的 IP 地址，导致我们获取到一大堆无用的地址。

### 3. IPv4 vs IPv6

除了虚拟网卡的问题，还有 IPv4 和 IPv6 的区别：

- **IPv4**：如 `192.168.1.100`（我们通常想要的）
- **IPv6**：如 `fe80::1234:5678:abcd:ef01%12`（链路本地地址）
- **IPv6 本地回环**：`::1`（相当于 IPv4 的 `127.0.0.1`）

在大多数局域网场景中，我们想要的是 IPv4 地址。

## 解决方案

### 方法一：使用 NetworkInterface 获取

这个方法通过 `NetworkInterface`
获取所有网络接口，过滤出正在运行的网卡，排除虚拟网卡，然后根据接口索引排序选择最佳
IP。下面的例子中排除了 VMware 虚拟网卡：

```csharp
static string? GetBestIPByMetric()
{
    var bestIp = NetworkInterface.GetAllNetworkInterfaces()
        .Where(n => n.OperationalStatus == OperationalStatus.Up)
        .Where(n => !n.Description.ToLower().Contains("vmware")) // 排除 VMware 虚拟网卡
        .SelectMany(n => n.GetIPProperties().UnicastAddresses
            .Where(a => a.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
            .Select(a => new
            {
                IP = a.Address.ToString(),
                Description = n.Description,
                // 获取网卡的 IPv4 接口指标
                Metric = n.GetIPProperties().GetIPv4Properties()?.Index
            }))
        .OrderBy(x => x.Metric) // 索引通常反映了绑定顺序
        .FirstOrDefault();

    return bestIp?.IP;
}
```

这个方法的优点是精确可控，可以根据需求添加过滤条件，且不依赖路由表。缺点是需要手动维护虚拟网卡的排除列表，不同虚拟网卡的名称和描述可能不同。

{{< notice tip >}}
接口索引（Index）通常反映了网卡的绑定顺序和优先级，索引越小优先级越高。通过
`GetIPv4Properties().Index` 可以获取这个值。 {{< /notice >}}

### 方法二：使用 Socket 连接外部地址

这是一个非常经典且巧妙的方法。通过创建一个 UDP Socket 并"连接"到外部地址（如
Google DNS 的 8.8.8.8），让操作系统根据路由表自动选择最合适的本地 IP。

```csharp
static string? GetLocalIp()
{
    using Socket socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, 0);

    try
    {
        // 这里使用一个伪造的外部地址。
        // 即使断网，系统也会根据路由表返回最匹配的物理网卡 IP
        socket.Connect("8.8.8.8", 65530);
        var endPoint = socket.LocalEndPoint as IPEndPoint;
        return endPoint?.Address.ToString();
    }
    catch
    {
        // 如果没有任何网卡连接，会进入这里
        return "127.0.0.1";
    }
}
```

{{< notice tip >}} 这里使用的是 UDP 协议（`SocketType.Dgram`），`Connect`
方法只是设置默认目标地址，**不会真正发送数据包**。因此即使断网也能正常工作，系统会根据路由表返回最匹配的本地
IP。 {{< /notice >}}

这个方法代码最简洁，能自动避开虚拟网卡。但如果局域网与外网完全隔离，路由表中没有相应路由时可能失效。

### 方法三：使用 WMI 查询物理网卡

这个方法利用 Windows Management Instrumentation (WMI)
来查询系统中标记为物理适配器的网卡，然后与 `NetworkInterface` 的 DeviceID
进行匹配，从而准确过滤出物理网卡的 IP。

```csharp
static void GetRealIP()
{
    // 使用 WMI 查询物理网卡
    var searcher = new ManagementObjectSearcher("SELECT * FROM Win32_NetworkAdapter WHERE PhysicalAdapter = True");
    var physicalIds = searcher.Get()
        .Cast<ManagementBaseObject>()
        .Select(x => x["DeviceID"].ToString())
        .ToList();
    var interfaces = NetworkInterface.GetAllNetworkInterfaces();
    foreach (var ni in interfaces)
    {
        // 匹配物理网卡 ID 并且状态为 Up
        if (physicalIds.Contains(ni.Id) && ni.OperationalStatus == OperationalStatus.Up)
        {
            var props = ni.GetIPProperties();
            var ipv4 = props.UnicastAddresses
                .FirstOrDefault(x => x.Address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork);
            if (ipv4 != null)
            {
                // 排除掉 169.254.x.x (自动配置地址)
                if (ipv4.Address.ToString().StartsWith("169.254")) continue;
                Console.WriteLine($"网卡名称: {ni.Description}");
                Console.WriteLine($"真实局域网 IP: {ipv4.Address}");
            }
        }
    }
}
```

这个方法从准确性来说是最可靠的，能从操作系统底层识别物理网卡。但它有明显的局限性：

- 需要引用 `System.Management` NuGet 包
- 只能在 Windows 平台使用，不支持跨平台
- WMI 查询相对较慢，性能敏感场景需要缓存结果

{{< notice tip >}} `169.254.x.x` 是 APIPA（Automatic Private IP
Addressing）地址段，当 DHCP 服务器不可用时，Windows
会自动分配这个范围的地址。这通常不是我们想要的真实局域网地址。 {{< /notice >}}

### 方法四：NetworkInterface 评分机制（终极方案）

兜兜转转尝试了各种方法后，发现还是回到 `NetworkInterface`
最简单且有效。下面这个方案相当于 [方法一](#方法一使用-networkinterface-获取)
的增强版，通过更全面的过滤条件和评分机制来选择最佳 IP 地址：

- 排除更多种类的虚拟网卡（Clash、ZeroTier、Tailscale、WireGuard、VMware、Docker
  等）
- 排除特殊 IP 段（Docker 的 172.16-31.x.x、网络基准测试的 198.18.x.x、APIPA 的
  169.254.x.x）
- 使用评分系统综合评估：有网关 +100 分，以太网/无线网卡 +50
  分，知名厂商（Intel、Realtek 等）+30 分

```csharp
static string GetRealLocalIP()
{
    var allInterfaces = NetworkInterface.GetAllNetworkInterfaces();
    var candidates = new List<(IPAddress Ip, int Score)>();
    foreach (var ni in allInterfaces)
    {
        if (ni.OperationalStatus != OperationalStatus.Up) continue;
        if (ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
        if (ni.NetworkInterfaceType == NetworkInterfaceType.Tunnel) continue;

        string desc = ni.Description.ToLower();
        string name = ni.Name.ToLower();
        if (desc.Contains("wintun") ||
            desc.Contains("clash") ||
            desc.Contains("virtual") ||
            desc.Contains("vmware") ||
            desc.Contains("vbox") ||
            desc.Contains("hyper-v") ||
            desc.Contains("zerotier") ||
            desc.Contains("tailscale") ||
            desc.Contains("wireguard") ||
            desc.Contains("docker") ||
            name.Contains("vethernet") ||
            name.Contains("wsl"))
            continue;

        var ipProps = ni.GetIPProperties();
        var ipv4Addrs = ipProps.UnicastAddresses
            .Where(a => a.Address.AddressFamily == AddressFamily.InterNetwork);

        foreach (var addr in ipv4Addrs)
        {
            string ipStr = addr.Address.ToString();
            if (ipStr.StartsWith("169.254")) continue;
            if (ipStr.StartsWith("198.18.")) continue;
            if (ipStr.StartsWith("172."))
            {
                var parts = ipStr.Split('.');
                if (parts.Length == 4 && int.TryParse(parts[1], out int secondOctet))
                {
                    if (secondOctet >= 16 && secondOctet <= 31) continue;
                }
            }

            int score = 0;
            if (ipProps.GatewayAddresses.Any(g => !g.Address.ToString().Equals("0.0.0.0")))
                score += 100;
            if (ni.NetworkInterfaceType == NetworkInterfaceType.Ethernet ||
                ni.NetworkInterfaceType == NetworkInterfaceType.Wireless80211)
                score += 50;
            if (desc.Contains("intel") || desc.Contains("realtek") || desc.Contains("atheros") || desc.Contains("broadcom"))
                score += 30;

            candidates.Add((addr.Address, score));
        }
    }

    if (candidates.Count == 0)
        return "192.168.1.100";

    return candidates.OrderByDescending(c => c.Score).First().Ip.ToString();
}
```

这个版本覆盖了几乎所有常见场景，通过多维度评分确保选择的是真正在使用的物理网卡
IP。评分机制比简单的索引排序或依赖路由表更智能，能适应各种复杂网络环境。

{{< notice warning >}}
虽然这个方法提供了最大的灵活性和准确性，但代码较长，维护成本相对较高。需要根据实际遇到的虚拟网卡类型持续更新过滤列表。
{{< /notice >}}

## 总结

获取本机真实 IP 地址看似简单，实则需要处理虚拟网卡、特殊 IP
段、多网卡等复杂情况。本文介绍了四种方法，各有优劣：

| 方法                            | 优点                   | 缺点                   | 适用场景     |
| ------------------------------- | ---------------------- | ---------------------- | ------------ |
| 方法一（基础 NetworkInterface） | 可控性强，代码相对简单 | 需要手动维护排除列表   | 一般场景     |
| 方法二（Socket 连接）           | 代码最简洁，自动选择   | 完全隔离网络可能失效   | 快速实现     |
| 方法三（WMI 查询）              | 最准确，系统层面识别   | 仅限 Windows，性能较慢 | Windows 专用 |
| 方法四（评分机制）              | 最灵活准确，覆盖全面   | 代码较长，维护成本高   | 复杂网络环境 |

大家可以根据自己的实际需求选择合适的方法，或者结合多种方法以获得最佳效果。
