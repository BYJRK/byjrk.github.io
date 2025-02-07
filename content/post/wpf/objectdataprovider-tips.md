---
title: "WPF 中 ObjectDataProvider 的一些有趣用法"
slug: "objectdataprovider-tips"
description: "WPF 中的 ObjectDataProvider 是一个很有用的类。如果运用得当，我们可以实现很多传统方法无法实现的功能。本文将介绍一些 ObjectDataProvider 的实用而有趣的用法。"
date: 2025-02-07
tags:
    - dotnet
    - wpf
    - csharp
---

WPF 中的 `ObjectDataProvider` 是一个很有用的类。与常见的直接绑定到属性（包括控件的依赖属性、类的实例的属性、静态属性或字段等）不同的是，它可以通过调用构造函数的方式来创建对象，或调用对象的方法来获取数据，进而将其用作绑定的数据源。

这篇文章我们就来探讨一下它的一些实用而有趣的用法。

## 基本用法

### 创建对象

首先，我们来看一下最基本的用法：通过 `ObjectDataProvider` 来创建一个对象。比如我们有一个 `Person` 类：

```csharp
public class Person
{
    public string Name { get; set; }
    public int Age { get; set; }

    public Person(string name, int age)
    {
        Name = name;
        Age = age;
    }
}
```

如果 `Person` 提供了无参构造函数，那么我们可以用传统的方式直接实例化一个对象：

```xml
<Window.Resources>
    <local:Person x:Key="PersonObject" Name="Tom" Age="25" />
</Window.Resources>
```

但现在我们假设 `Person` 类只提供了有参构造函数，那么我们就无法直接实例化一个对象了。这时，我们可以通过 `ObjectDataProvider` 来实现：

```xml
<Window ...>
    <Window.Resources>
        <ObjectDataProvider x:Key="PersonObject" ObjectType="{x:Type local:Person}">
            <ObjectDataProvider.ConstructorParameters>
                <sys:String>John</sys:String>
                <sys:Int32>25</sys:Int32>
            </ObjectDataProvider.ConstructorParameters>
        </ObjectDataProvider>
    </Window.Resources>
    <Grid>
        <TextBlock Text="{Binding Name, Source={StaticResource PersonObject}}" />
        <TextBlock Text="{Binding Age, Source={StaticResource PersonObject}}" />
    </Grid>
</Window>
```

这里我们通过 `ObjectType` 属性指定了 `Person` 类型，通过 `ConstructorParameters` 属性传入了构造函数的参数。这样我们就成功地创建了一个 `Person` 对象，并将其绑定到了两个 `TextBlock` 控件上。

### 调用方法

除了创建对象，`ObjectDataProvider` 还可以调用对象的方法。比如我们有一个 `Calculator` 类：

```csharp
public class Calculator
{
    public int Add(int a, int b)
    {
        return a + b;
    }
}
```

我们可以通过如下方式调用 `Add` 方法：

```xml
<Window ...>
    <Window.Resources>
        <ObjectDataProvider x:Key="CalculatorObject" ObjectType="{x:Type local:Calculator}" MethodName="Add">
            <ObjectDataProvider.MethodParameters>
                <sys:Int32>10</sys:Int32>
                <sys:Int32>20</sys:Int32>
            </ObjectDataProvider.MethodParameters>
        </ObjectDataProvider>
    </Window.Resources>
    <Grid>
        <TextBlock Text="{Binding Source={StaticResource CalculatorObject}}" />
    </Grid>
</Window>
```

上面的方式会自动创建一个 `Calculator` 对象，并调用其 `Add` 方法，传入了两个参数。我们还可以将 `Calculator` 类及其成员声明为静态的，这样就可以避免创建对象了。

{{< notice info >}}
如果 `ObjectType` 指定的类型不是静态的，那么即便我们要访问的属性或方法是静态的，`ObjectDataProvider` 也会自动创建一个对象。这一现象可以在运行时通过观察该资源的 `ObjectInstance` 属性来验证。
{{< /notice >}}

### 给定实例

除了指定 `ObjectType` 属性外，我们还可以通过 `ObjectInstance` 属性来指定一个实例。比如我们上面的 `Calculator` 类提供了单例模式的实现：

```csharp
public class Calculator
{
    public static Calculator Instance { get; } = new();

    // ...
}
```

那么我们可以通过如下方式调用 `Add` 方法：

```xml
<Window ...>
    <Window.Resources>
        <ObjectDataProvider x:Key="CalculatorObject" ObjectInstance="{x:Static local:Calculator.Instance}" MethodName="Add">
            <ObjectDataProvider.MethodParameters>
                <sys:Int32>10</sys:Int32>
                <sys:Int32>20</sys:Int32>
            </ObjectDataProvider.MethodParameters>
        </ObjectDataProvider>
    </Window.Resources>
    <Grid>
        <TextBlock Text="{Binding Source={StaticResource CalculatorObject}}" />
    </Grid>
</Window>
```

当我们指定了 `ObjectInstance` 属性后，就不需要再指定 `ObjectType` 属性了。

### 工厂模式

还有一个经典用法是，我们可以结合工厂模式来在 XAML 中创建对象。比如我们有一个 `PersonFactory` 类：

```csharp
public class PersonFactory
{
    public Person CreatePerson(string name, int age)
    {
        return new Person(name, age);
    }
}
```

我们可以通过如下方式创建一个 `Person` 对象：

```xml
<Window ...>
    <Window.Resources>
        <ObjectDataProvider x:Key="PersonFactory" ObjectType="{x:Type local:PersonFactory}" MethodName="CreatePerson">
            <ObjectDataProvider.MethodParameters>
                <sys:String>John</sys:String>
                <sys:Int32>25</sys:Int32>
            </ObjectDataProvider.MethodParameters>
        </ObjectDataProvider>
    </Window.Resources>
</Window>
```

这样便为 XAML 注入了更多的活力与灵活性。

## 经典用法

### 绑定枚举类型到下拉选单

相信所有和 `ComboBox` 控件打过交道的开发者都知道，如果我们希望将一个枚举类型的值绑定到 `ComboBox` 控件上，我们可以通过 `ObjectDataProvider` 来实现。

比如我们有一个 `Fruit` 枚举类型：

```csharp
public enum Fruit
{
    Apple,
    Banana,
    Orange,
    Pear
}
```

我们可以通过如下方式将其绑定到 `ComboBox` 控件上：

```xml
<Window ...>
    <Window.Resources>
        <ObjectDataProvider x:Key="FruitEnumValues" MethodName="GetValues" ObjectType="{x:Type sys:Enum}">
            <ObjectDataProvider.MethodParameters>
                <x:Type TypeName="local:Fruit"/>
            </ObjectDataProvider.MethodParameters>
        </ObjectDataProvider>
    </Window.Resources>
    <Grid>
        <ComboBox ItemsSource="{Binding Source={StaticResource FruitEnumValues}}" />
    </Grid>
</Window>
```

这里其实就体现了对于类型方法的调用。首先，我们知道在 C# 中，可以通过这样的方式来获取枚举类型的所有值：

```csharp
var values = Enum.GetValues(typeof(Fruit));
```

也就是我们调用了 `Enum` 类型的 `GetValues` 静态方法，并传入了 `Fruit` 类型（`Type`），从而获取所有的枚举值。而在 XAML 中，我们就是借助 `ObjectDataProvider` 来实现了相同的操作。我们通过 `ObjectType` 属性指定了 `Enum` 类型，通过 `MethodName` 属性指定了 `GetValues` 方法，再通过 `MethodParameters` 属性传入了 `Fruit` 类型。

### 为下拉选单提供整数数据源

借鉴上面的思路，我们很容易产生更多的想法：既然它可以调用任何类型的方法，那么 LINQ 的 `Enumerable` 上面的一些静态方法岂不也能为我们所用了？

那么我们就赶快来试一试吧。我们假如我们想给一个 `ComboBox` 添加几个连续的数字作为它的选项（比如 1~5），在代码后台我们会这样调用：

```csharp
var numbers = Enumerable.Range(1, 5);
```

那么在 XAML 中，我们可以这样实现：

```xml
<Window xmlns:linq="clr-namespace:System.Linq;assembly=netstandard">
    <Window.Resources>
        <ObjectDataProvider x:Key="Numbers" MethodName="Range" ObjectType="{x:Type linq:Enumerable}">
            <ObjectDataProvider.MethodParameters>
                <sys:Int32>1</sys:Int32>
                <sys:Int32>5</sys:Int32>
            </ObjectDataProvider.MethodParameters>
        </ObjectDataProvider>
    </Window.Resources>
    <Grid>
        <ComboBox ItemsSource="{Binding Source={StaticResource Numbers}}" />
    </Grid>
</Window>
```

是不是很有意思呢？

## 总结

`ObjectDataProvider` 是一个非常有用的类，它可以帮助我们在 XAML 中实现更多的功能。通过调用构造函数或对象的方法，我们可以实现更多的数据绑定操作。在实际开发中，我们可以根据具体的需求，灵活地使用 `ObjectDataProvider`，从而提高开发效率。

不过，好用归好用，它或许并不总是最优解。如果我们可以借助 `ViewModel` 中的成员，或 `MarkupExtension` 等方式来实现，那么我们一般就可以不考虑使用 `ObjectDataProvider` 了。毕竟，`ObjectDataProvider` 声明起来还是显得有些繁琐，而且因为借助反射，我们在编译时也可能无法发现一些潜在的问题。
