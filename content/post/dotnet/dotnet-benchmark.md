---
title: 'Benchmark.NET 简易指南'
description: 这篇文章是凑数的
slug: benchmark-dotnet
date: 2024-03-05T10:52:37+08:00
tags: 
    - csharp
    - dotnet
---

[Benchmark.NET](https://benchmarkdotnet.org/) 是一个用于 .NET 应用程序的强大的基准测试库。它可以帮助开发人员评估他们的代码的性能，找出潜在的性能问题，并且比较不同的实现方式。Benchmark.NET 提供了丰富的特性，包括内存诊断、全局初始化、迭代初始化等，可以满足各种性能测试的需求。

这篇文章将介绍 Benchmark.NET 的基础知识和一些常用的特性。你也可以观看[我的 B 站教学视频](https://b23.tv/9rMsBmF)进行学习。

## 常用特性

一些常用的特性：

- Class
  - `MemoryDiagnoser`：查看内存分配情况（有一个 bool 参数，表示是否显示 GC 的情况）
  - `SimpleJob`：可以设置 .NET 版本，如 `RuntimeMoniker.Net60`
  - `Orderer(SummaryOrderPolicy.SlowestToFastest)`：输出结果的排序
  - `RankColumn`：为结果表格添加一列 Rank，表示当前行的方法的排名
- Method
  - `Benchmark`：表示这个方法需要被测试（另有一个 `Baseline` 参数，同时会给结果添加一列 Ratio，表示和 Baseline 的比率）
  - `Arguments`：类似于 `Params`，表示该方法的传参，可以有多个，并且会和 `Params` 联动，充分考虑各种组合
  - `GlobalSetup`：全局初始化，常用于初始化一个要用来测试的变量、集合等。可以和 `Params` 联动，比如数组的容量由某个字段决定
  - `IterationSetup`：用于在每次迭代前的初始化，每次迭代都会调用一次
- Field
  - `Params`：某个字段可能有不同的值（如果多个字段被标记该特性，则会充分考虑所有参数的组合）

## 实际例子

### 测试排序的效率

```C#
[MemoryDiagnoser]
public class SortTester
{
    private List<int> testList;

    [GlobalSetup]
    public void Setup()
    {
        testList = Enumerable.Range(1, 100).Shuffle(new Random(1334)).ToList();
    }

    [Benchmark]
    public List<int> ListSort()
    {
        var lst = new List<int>(testList);
        lst.Sort();
        return lst;
    }

    [Benchmark]
    public List<int> LinqOrder()
    {
        return testList.Order().ToList();
    }
}
```

### 测试初始化数组的效率

```C#
public class ListInit
{
    [Params(16, 128, 1060)]
    public int count;

    [Benchmark(Baseline = true)]
    public List<int> WithoutInit()
    {
        var res = new List<int>();
        for (int i = 0; i < count; i++)
            res.Add(i);
        return res;
    }

    [Benchmark]
    public List<int> WithInit()
    {
        var res = new List<int>(count);
        for (int i = 0; i < count; i++)
            res.Add(i);
        return res;
    }

    [Benchmark]
    public List<int> WithLinq()
    {
        return Enumerable.Range(0, count).ToList();
    }
}
```

### .NET 6 vs. .NET 7

```C#
[MemoryDiagnoser(false)]
[SimpleJob(RuntimeMoniker.Net60)]
[SimpleJob(RuntimeMoniker.Net70)]
public class SortTester
{
    private IEnumerable<int> testList;

    [GlobalSetup]
    public void Setup()
    {
        testList = Enumerable.Range(1, 10).ToArray();
    }

    [Benchmark]
    public int CalcMin()
    {
        return testList.Min();
    }
}
```

## 注意事项

1. 要使用有编译器优化的 Release 模式
2. 被测试的类、使用了特性的方法与字段均需要为 `public`
3. 在要测试的方法中尽量避免会被 JIT 优化掉的情况，比如有一个不会被使用的变量等
4. 除非还想要测试内存读取的速度等，否则一般没有必要创建过大的数组

## 参考链接

[Rules of benchmarking - BenchmarkDotNet Documentation](https://fransbouma.github.io/BenchmarkDotNet/RulesOfBenchmarking.htm)
