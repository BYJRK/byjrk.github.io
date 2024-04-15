---
title: "{{ replace .Name "-" " " | humanize | title }}"
slug: "{{ .Name }}"
description: 
date: {{ .Date }}
draft: true
tags:
    - tag1
    - tag2
    - tag3
---

