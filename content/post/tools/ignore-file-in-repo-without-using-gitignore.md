---
title: "如何在不使用 .gitignore 的情况下忽略代码仓库中的文件或文件夹"
slug: "ignore-file-in-repo-without-using-gitignore"
description: "本文介绍了在不使用 .gitignore 文件的情况下，如何忽略代码仓库中的文件或文件夹的几种方法。这样就可以便捷地管理本地文件，而不影响其他协作者，也不用烦恼修改的提交与合并问题。"
date: 2025-11-06
tags:
    - git
    - cli
    - vscode
---

我们在管理代码仓库时，有时候会在项目中引入一些额外的文件或文件夹，常见的比如我们想临时测试效果的 `test` 文件，或 `.vscode`、`.idea`、`.github` 等配置文件夹。这些文件或文件夹可能不适合被提交到版本控制系统中，但我们又不想使用 `.gitignore` 文件来忽略它们，因为这样我们就需要将 `.gitignore` 文件也提交到仓库中，影响其他协作者（或者让其他人察觉到你可能在本地仓库做了什么 :)

有一个笨方法，就是修改本地的 .gitignore 文件，但是不提交它。这样虽然可以达到忽略文件的目的，但拉取代码时，如果其他协作者更新了 `.gitignore` 文件，你的本地修改就会被覆盖，导致忽略设置失效。或者者你需要频繁地手动合并 `.gitignore` 文件，增加了维护成本。

那么，有没有一种方法可以在不使用 `.gitignore` 的情况下，忽略这些文件或文件夹呢？答案是肯定的。下面我们就简单介绍几种方式。

## 使用 `git update-index --assume-unchanged`

Git 提供了一个命令 `git update-index --assume-unchanged <file>`，可以让 Git 忽略对指定文件的更改。这样，即使你在本地修改了该文件，Git 也不会将其标记为已更改状态。

例如，如果你有一个名为 `test.py` 的文件，你可以运行以下命令：

```bash
git update-index --assume-unchanged test.py
```

然后就会发现，它不会出现在 `git status` 的输出中了。

如果你想恢复对该文件的跟踪，可以使用以下命令：

```bash
git update-index --no-assume-unchanged test.py
```

但是这个方法有一个缺点，就是它不能使用通配符来忽略多个文件或文件夹，你需要对每个文件单独执行该命令。

此外，假如这个文件已经被提交到了仓库中，并且其他协作者修改了它后被拉取到了本地，那么你可能无法察觉到这些更改。

## 使用 `.git/info/exclude`

另一个方法是使用 Git 仓库中的 `.git/info/exclude` 文件。这个文件的作用类似于 `.gitignore`，但它是本地的，不会被提交到远程仓库。而且它的语法规则是和 `.gitignore` 一样的，支持使用通配符。

你可以在 `.git/info/exclude` 文件中添加你想忽略的文件或文件夹路径。例如：

```
test.*
.vscode/
.idea/
.github/
[Pp]ublish/
```

这个方式就比较适合忽略多个文件或文件夹，而且不会影响其他协作者。

另外，`.git` 文件夹通常是隐藏的，并且在 VS Code 等编辑器中默认也是隐藏的。如果你需要编辑 `.git/info/exclude` 文件，可以在编辑器中打开隐藏文件夹，或者使用命令行编辑器进行修改。以 VS Code 为例，可以打开终端，进入项目根目录，然后运行以下命令：

```bash
code .git/info/exclude
```

这样就可以直接在 VS Code 中编辑该文件了。
