---
title: "在 C# 中使用 IComparer 实现自定义排序"
slug: "customize-order-with-icomparer"
description: "本文介绍了在 C# 中如何借助 IComparer 等接口来实现自定义排序逻辑，从而满足复杂的业务需求。"
date: 2025-10-09
tags:
    - dotnet
    - csharp
---

在 C# 中处理数据时，我们有时候会想给某种数据一种特殊的排列顺序。比如对于公司员工排序时，我们希望按照员工所属的部门进行排序，并且希望按照一定的优先级，比如“行政、财务、人力资源、市场、销售、运营、研发”这样的顺序。这种情况下，如果我们使用默认的排序（即字典序），就无法满足我们的需求。

幸运的是，C# 提供了一个非常强大的接口 `IComparer`，它允许我们自定义排序逻辑。通过实现这个接口，我们可以定义任何我们想要的排序规则。

## IComparer 接口的定义

`IComparer<T>` 接口定义了一个方法 `Compare`，它接受两个参数，并返回一个整数值。这个整数值的含义就是我们熟知的 `CompareTo` 方法的返回值：

- -1：表示第一个参数小于第二个参数
- 0：表示两个参数相等
- 1：表示第一个参数大于第二个参数

所以，如果想要在使用各种常见排序方法（如 `Array.Sort`、`List<T>.Sort` 以及 LINQ 的 `OrderBy` 等）时使用自定义的排序逻辑，我们需要有一个实现了这个接口的类，并且将一个实例传给这些方法。

{{< notice tip >}}
这个接口还有一个非泛型版本 `IComparer`，它的 `Compare` 方法接受两个 `object` 类型的参数。虽然非泛型版本在某些情况下可能会用到，但通常我们更倾向于使用泛型版本，因为它提供了类型安全性，并且也减少了很多我们在实现过程中可能遇到的类型转换问题。
{{< /notice >}}

## 一个简单的例子

以我们前面提到的员工排序为例，假设我们有一个 `Employee` 类：

```csharp
public class Employee
{
    public string Name { get; set; }
    public string Department { get; set; }
}
```

我们可以创建一个 `EmployeeComparer` 类来实现 `IComparer<Employee>` 接口：

```csharp
class EmployeeComparer : IComparer<Employee>
{
    private static readonly List<string> DepartmentOrder = new List<string>
    {
        "行政", "财务", "人力资源", "市场", "销售", "运营", "研发"
    };

    public int Compare(Employee? x, Employee? y)
    {
        if (x is null || y is null)
            throw new ArgumentNullException();

        int xIndex = DepartmentOrder.IndexOf(x.Department);
        int yIndex = DepartmentOrder.IndexOf(y.Department);

        if (xIndex == -1) xIndex = int.MaxValue;
        if (yIndex == -1) yIndex = int.MaxValue;

        int deptComparison = xIndex.CompareTo(yIndex);
        if (deptComparison != 0)
            return deptComparison;

        return string.Compare(x.Name, y.Name, StringComparison.Ordinal);
    }
}
```

非泛型版本与上面类似，只是参数类型变成了 `object`，并且需要进行类型转换。这里不再赘述。

接下来，我们可以使用这个比较器来排序一个员工列表：

```csharp
List<Employee> employees = await GetEmployeesAsync();
var comparer = new EmployeeComparer();
employees.Sort(comparer);

// 或者使用 LINQ
var sortedEmployees = employees
    .OrderBy(e => e, comparer)
    .ThenBy(e => e.Name)
    .ToList();
```

## 一个更通用的例子

如果在我们的项目中，时常会遇到这样的情形，也就是我们希望手动指定一种数据类型的排序方式。那么上面的方式可能就不够灵活了，因为我们需要为每一种数据类型都创建一个比较器类。

此时，我们可以写一个更加通用的比较器类 `CustomComparer<T>`，它接受一个排序规则列表：

```csharp
sealed class CustomComparer<T> : IComparer<T>
{
    private readonly Dictionary<T, int> _customOrder;

    public CustomComparer(params T[] customOrder)
    {
        _customOrder = customOrder.Index().ToDictionary(x => x.Item, x => x.Index);
    }

    public int Compare(T? x, T? y)
    {
        if (x == null && y == null) return 0;
        if (x == null) return -1;
        if (y == null) return 1;

        var i = _customOrder[x];
        var j = _customOrder[y];
        return i.CompareTo(j);
    }
}
```

使用这个通用比较器，我们可以很方便地为任何类型指定排序规则：

```csharp
var departments = new[] { "行政", "财务", "人力资源", "市场", "销售", "运营", "研发" };
var departmentComparer = new CustomComparer<string>(departments);
var sortedEmployees = employees
    .OrderBy(e => e.Department, departmentComparer)
    .ThenBy(e => e.Name)
    .ToList();
```

{{< notice tip >}}
和前面的例子略有不同的是，这里我们只针对 `string` 这个类型定制了比较器。因此在使用时，我们需要指定 `OrderBy` 的第一个参数为 `e => e.Department`，而不是直接传入 `e`。而在前面的例子中，我们直接针对的比较对象就是 `Employee` 类型，然后我们在 `Compare` 方法中处理了 `Department` 属性。
{{< /notice >}}

通过实现 `IComparer` 接口，我们可以轻松地为任何数据类型定制排序逻辑。这不仅提升了代码的灵活性，也使得我们能够更好地控制数据的展示顺序，从而满足各种业务需求。

## 其他方式

除了使用 `IComparer` 接口，我们还有一些别的方法。比如 `Sort`、`OrderBy` 等方法允许我们传入一个 `Comparison<T>` 委托。它的声明如下：

```csharp
public delegate int Comparison<in T>(T x, T y);
```

所以我们可以使用 lambda 表达式来定义排序逻辑：

```csharp
List<Employee> employees = GetEmployees();
Comparison<Employee> comparison = (x, y) =>
{
    var departmentOrder = new List<string> { "行政", "财务", "人力资源", "市场", "销售", "运营", "研发" };
    int xIndex = departmentOrder.IndexOf(x.Department);
    int yIndex = departmentOrder.IndexOf(y.Department);
    if (xIndex == -1) xIndex = int.MaxValue;
    if (yIndex == -1) yIndex = int.MaxValue;
    int deptComparison = xIndex.CompareTo(yIndex);
    if (deptComparison != 0)
        return deptComparison;
    return string.Compare(x.Name, y.Name, StringComparison.Ordinal);
};
employees.Sort(comparison);
```

另外，我们还可以直接修改类型本身，来实现 `IComparable` 接口，从而定义默认的排序逻辑。这种方法我们就不再做具体介绍了，因为它存在显著的局限性：每个类型只能有一种默认排序方式。如果我们将 `Employee` 类型的比较方式硬性定义为了“先部门，后姓名”的方式，那么此后如果我们想在使用 LINQ 时采用别的排序方式，就会变得非常麻烦。这种方式只适合非常简单的数据类型及场景，比如我们定义了一种包装类，它实际排序依靠的是内部的某个数值属性。

## 总结

通过实现 `IComparer` 接口，我们可以为任何数据类型定制排序逻辑，从而满足各种复杂的业务需求。无论是为特定类型创建专用的比较器，还是使用通用的比较器类，我们都能够灵活地控制数据的排序方式。此外，使用 `Comparison<T>` 委托也是一种简便的方法，适用于简单的排序需求。总之，掌握这些技术，可以让我们在处理数据时更加得心应手。
