---
title: "如何在 WPF 中实现可以显示密码的密码框"
slug: "reveal-password-box"
description: "密码框（PasswordBox）是一个 WPF 中常用的控件，但是默认情况下，密码框中输入的内容是隐藏的。有时候，我们需要在用户输入密码的时候，提供一个按钮，让用户可以查看输入的密码。本文将介绍如何在 WPF 中实现一个可以显示密码的密码框。"
draft: true
date: 2024-12-07
tags:
    - dotnet
    - csharp
    - wpf
---

WPF 中的密码框（PasswordBox）是一个常用的控件。它类似文本框（TextBox），但是输入的内容是隐藏的，并且内部也提供了一套安全的机制来保护用户输入的密码不被黑客获取到。但正是因为这一套安全机制，我们的开发常常会陷入困境。尤其是在 MVVM 模式下，想要绑定密码框的内容，或者最起码密码框中输入内容的长度，都是做不到的。

为了解决这一问题，通常我们的做法就是为密码框写一个附加属性，或者使用行为（Behavior）来实现。这里不做赘述，但大致思路就是通过订阅密码框的 `PasswordChanged` 事件，将密码框中的内容（或长度）同步到一个依赖属性中，然后在 ViewModel 中绑定这个依赖属性。

这样的行为并不需要我们写，在网上很多地方都能够看到它们的身影。比如 Livet 这个包中，就为我们提供了一个 [`PasswordBoxBindingSupportBehavior`](https://github.com/runceel/Livet/blob/master/LivetCask.Behaviors/ControlBinding/PasswordBoxBindingSupportBehavior.cs)，我们直接抄过来，然后适当做些减法，即可直接使用了。

{{< notice info >}}
为什么不使用依赖属性呢？答案很简单，因为密码框是一个 `sealed` 类，我们无法继承，也就无法写一个自定义类，从而添加依赖属性了。
{{< /notice >}}

有了绑定密码的能力，我们终于可以实现下面这些效果了：

1. 在 ViewModel 中对密码的强度进行判断
2. 让登录按钮的可用状态由密码框内容是否不为空来决定

## 实现思路

但现在，我们要实现一个更复杂一些的功能：在密码框中输入密码的时候，提供一个按钮（通常是一个眼睛形状的按钮，放在密码框右侧），让用户可以点击并查看输入的密码。这个功能非常实用且常见，但是在 WPF 中实现起来却并不简单。原因无他，WPF 的密码框并不提供这个功能。要想实现，我们除了自己写控件以外，基本上只能使用另外的一个文本框来辅助实现。大致思路如下：

1. 与密码框重叠放置一个外观相同的文本框，默认是隐藏的
2. 当用户点击查看密码按钮时，文本框将会显示，同时密码框将会隐藏
3. 将密码框的内容与文本框进行同步，从而使用户在任意模式下的输入都会反映到后台绑定的密码文本

有了这样的思路之后，我们就可以着手实现了。

## 具体实现

现在我们就可以来制作界面了：

```xml
<Border Padding="10"
        HorizontalAlignment="Center"
        VerticalAlignment="Center"
        BorderThickness="1"
        CornerRadius="5"
        BorderBrush="Gray">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="10" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="10" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="100" />
            <ColumnDefinition Width="200" />
            <ColumnDefinition Width="30" />
        </Grid.ColumnDefinitions>

        <TextBlock Text="Username" />
        <TextBox Grid.Column="1" />

        <TextBlock Grid.Row="2" Text="Password" />
        <PasswordBox x:Name="PasswordBox" Grid.Row="2" Grid.Column="1">
            <i:Interaction.Behaviors>
                <b:PasswordBoxBindingSupportBehavior Password="{Binding ElementName=RevealPasswordTextBox, Path=Text}" />
            </i:Interaction.Behaviors>
        </PasswordBox>
        <TextBox x:Name="RevealPasswordTextBox"
                    Grid.Row="2"
                    Grid.Column="1"
                    Visibility="{Binding ElementName=RevealPasswordToggleButton, Path=IsChecked, Converter={StaticResource BoolToVisibilityConverter}}" />
        <ToggleButton x:Name="RevealPasswordToggleButton"
                        Grid.Row="2"
                        Grid.Column="2"
                        Margin="5,0,0,0"
                        FontFamily="Segoe Fluent Icons"
                        Content="&#xf78d;" />

        <Button Grid.Row="4"
                Grid.ColumnSpan="3"
                Width="100"
                Content="Login" />
    </Grid>
</Border>
```

界面的大致效果如下：

![简易登录界面](https://s2.loli.net/2024/12/18/UfEh8Jd4Ss1NYkX.png)

{{< notice info >}}
这里的“眼睛”按钮使用了 Segoe Fluent Icons 字体，你可以在 [Microsoft Docs](https://docs.microsoft.com/en-us/windows/apps/design/style/segoe-fluent-icons-font) 上找到更多的图标。这个字体在 Windows 11 中是默认安装的，但是在 Windows 10 中需要手动安装。另外，Windows 10 自带的 Segoe MDL2 Assets 是这款字体的前身，也可以使用。
{{< /notice >}}

那么我们想要的功能其实就已经实现了：

1. 密码框借助行为，使其 `Password` 与文本框的 `Text` 绑定
2. 使用一个 `ToggleButton` 来控制文本框及密码框的显示与隐藏
3. 密码框与文本框拥有相同的外观及布局，从而实现无缝切换

## 其他主题库或框架的实现方式

虽然我们在 WPF 中实现了这一功能，但是它仍然有提升空间。比如，虽然我们将密码框的密码同步到了文本框，但是如果我们选中了文本框中的内容，那么密码框中的内容并不会被选中。这样的体验并不是很好。在其他的一些主题、控件库中，其实是有这一功能的实现的。我们这里举几个例子来学习一下。

### Material Design In Xaml Toolkit

Material Design In Xaml Toolkit（简称为 MDIX）是一个将谷歌的 Material Design 风格带入 WPF 的工具包。它提供了一套 Material Design 风格的控件，并且提供了丰富的密码框的风格。其中自然包括了我们这里想要的功能。

