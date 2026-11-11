<div align="center">

<img src="assets/banner.png" width="760" alt="tern-omp-usage：通过 omp 在 Tern 状态栏中显示 Claude 和 Codex 额度">

[![check](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml/badge.svg)](https://github.com/joaodutra88/tern-omp-usage/actions/workflows/check.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/joaodutra88/tern-omp-usage?style=flat)](https://github.com/joaodutra88/tern-omp-usage/stargazers)
[![Latest release](https://img.shields.io/github/v/release/joaodutra88/tern-omp-usage)](https://github.com/joaodutra88/tern-omp-usage/releases/latest)

一个面向 [omp](https://omp.sh) 用户的 [Tern](https://stencil.so/tern) 状态栏插件。它在一行之内显示你的 Claude 和 Codex 订阅额度、本周的消费预算，以及今天的 token 用量和费用。点击今天的费用即可打开最近 7 天的仪表盘。

**[安装](#安装)** · **[每一部分的含义](#每一部分的含义)** · **[配置](#配置)** · **[FAQ](#faq)** · **[贡献](#贡献)**

[English](README.md) | [Português](README.pt-BR.md) | [Español](README.es.md) | **简体中文** | [日本語](README.ja.md)

英文版 README.md 是参考版本，如两者有出入，以英文版为准。

<img src="assets/statusline.png" alt="Tern 状态栏中的 Claude 和 Codex 用量">

</div>

## 它能告诉你什么

所有信息都在状态栏里，工作时一眼就能看到：

- **今天能不能承受一次高负载运行？** 工作周预算：周一到周五每个工作日解锁每周额度的 20%，节假日的份额顺延到之后。
- **今天花了多少？** 自当地午夜起的 token 数和按 API 价格计算的费用，覆盖 omp 追踪的所有提供商。仪表盘还会显示最近 7 天和本月的数据。
- **有没有已保存的额度重置？** Claude 和 Codex 已保存的用量限制重置次数。
- **什么时候会用完？** 按当前速度，5 小时或每周窗口还要多久会锁定（如果锁定会早于其重置）。窗口达到 80%、被锁定或重新释放时会弹出通知。
- **Claude 和 Codex 并排显示**，两者都通过 omp 读取，无需再登录任何新账户。

## 每一部分的含义

| 外观 | 含义 |
|---|---|
| <img src="assets/seg-window.png" height="28" alt="5h 窗口"> | 单个窗口的用量：5 小时（5h）、一周（`wk`），以及套餐包含时的 Fable。每个圆点保留自己的颜色，从绿色到红色，百分比采用最后一个被点亮的圆点的颜色。达到 80%（可以修改）时，百分比变为闪烁的红色徽章。 |
| <img src="assets/seg-reset.png" height="28" alt="重置倒计时"> | 距离 Claude 5 小时窗口重置的时间。剩余不到 30 分钟且 5 小时窗口用量达到 80% 或以上时变为绿色，表示即将缓解。 |
| `⏳23m` | 紧跟在 Claude 5h 或 `wk` 条之后：按该窗口开启以来的平均速度，它将在这段时间后用完，早于其重置。用量达到 50% 起显示。提醒以弹出通知的形式出现：窗口达到红色徽章阈值、被锁定或重新释放时。 |
| <img src="assets/seg-credits.png" height="28" alt="已保存的重置"> | 你已保存的用量限制重置次数。 |
| <img src="assets/seg-budget.png" height="28" alt="工作周预算"> | 工作周预算。当前 7 天窗口中，每个工作日（默认周一至周五，可以修改）解锁相同份额的每周额度，五个工作日时每天 20%。`left` 表示已解锁但尚未花费的额度。`over`（闪烁红色）表示你的消费超前于本周进度。 |
| <img src="assets/seg-codex.png" height="28" alt="Codex"> | Codex。`×2` 表示已关联的账户数量，窗口显示已用完的账户所占的比例。 |
| <img src="assets/seg-today.png" height="28" alt="今日 token 和费用"> | 自当地午夜起的 token 数和 API 价格费用，覆盖所有提供商，数据来自 `omp stats`。缓存读取也计入 token，因此这个数字的大部分来自缓存。点击即可打开仪表盘。 |
| <img src="assets/seg-refresh.png" height="28" alt="刷新"> | 立即刷新。点击其他任意用量片段也会执行相同操作。 |

### 仪表盘

**OMP usage: dashboard**（或点击今天的 token 数或费用）会在当前窗格旁边打开一个窗格。它根据 `omp usage --history` 按小时显示最近 7 天 Claude 和 Codex 的 5 小时及每周用量，并显示今天、最近 7 天和本月按 API 价格计算的费用，每天一根柱条。按 `r` 可重新读取历史记录。

`omp stats` 只能回溯约一天，因此插件会自行保存每天的总量。一周和一个月的数据从你安装 0.4.0 的那天开始累积。

## 一周中的状态变化

以下画面由预设的 `omp` 回复渲染而成，因此可以看到并非每天都会出现的状态。

**平静的早晨。** 一切为绿色，预算充足。

<p align="center"><img src="assets/state-calm.png" alt="平静"></p>

**用量上升。** 当某个窗口相比 5 分钟前的读数上升了 3 个百分点或以上时，会出现 `↑`。

<p align="center"><img src="assets/state-rising.png" alt="上升"></p>

**5 小时窗口过热。** 达到 86% 时，百分比变为红色徽章，而重置倒计时变为绿色，因为距离缓解只剩 21 分钟。

<p align="center"><img src="assets/state-hot.png" alt="过热"></p>

**超前于本周进度。** 本周已用 65%，但只解锁了 40%：`over 25%` 会闪烁，直到下一个工作日赶上进度。

<p align="center"><img src="assets/state-over.png" alt="超出预算"></p>

**锁定。** 某个窗口达到 100% 时，会显示一个闪烁徽章，附带距离释放的时间以及你已保存的重置次数。

<p align="center"><img src="assets/state-locked.gif" alt="锁定"></p>

## 安装

```sh
tern plugin install https://github.com/joaodutra88/tern-omp-usage
```

你需要在 `omp` 中登录 Anthropic 和/或 OpenAI Codex，以便 `omp usage` 能在终端中正常运行。插件使用 Tern 管理的 omp（Windows 上为 `%LOCALAPPDATA%\Tern\omp\bin\omp.exe`，macOS 上为 `~/Library/Application Support/Tern/omp/bin/omp`），如果找不到，则回退到 `PATH` 中的 `omp`。如果 Tern 的守护进程找不到它，请将 `OMP_USAGE_BIN` 设置为完整路径。

### 更新

插件每天在 GitHub 上检查一次是否有新版本。如果有，其片段开头会出现蓝色的 `⬆ 0.5.0`，并弹出一次通知。点击它，或运行 **OMP usage: update to the latest version**，插件就会从本仓库重新安装自己（`tern plugin install … --force`）。你的设置和 `extras.luau` 会保留下来。更新完成后，通知会显示新版本号，**OMP usage: what's new** 会打开其发布说明。

通过链接方式检出的插件（`tern plugin link`）则用 `git pull` 更新。要停止检查，请隐藏 `updates` 部分（见[配置](#配置)），或设置 `OMP_USAGE_NO_UPDATE_CHECK=1`。

**还在用 0.3.x？** 这些版本没有更新检查。请用 `--force` 运行一次上面的安装命令，从 0.4.0 起插件会自己提醒你。

如果也想通过电子邮件获取发布通知，请在本仓库顶部使用 **Watch → Custom → Releases**。

### 使用 AI 代理安装

将以下内容粘贴到 omp、Claude Code、Codex 或任何能运行命令的代理中：

```text
Install the Tern plugin https://github.com/joaodutra88/tern-omp-usage for me.
1. Check `omp usage --json -p anthropic` (or `-p openai-codex`) works. If it doesn't, help me sign in with omp first.
2. Run `tern plugin install https://github.com/joaodutra88/tern-omp-usage`.
3. Run `tern plugin list --json` and confirm `omp-usage` has status "ready".
4. If it isn't ready, read the lines containing `omp-usage` in Tern's log
   (`%LOCALAPPDATA%\Tern\Logs\tern.log` on Windows) and the repo's AGENTS.md, then tell me what is wrong.
5. Explain what each part of the status line means, using the README.
```

## 它运行什么，会触及什么

该插件不读取任何凭据。它运行 omp，并自行发起一个网络请求：

| 命令 | 运行时机 |
|---|---|
| `omp usage --json -p anthropic` | 每 5 分钟。Anthropic 的用量接口在约 5 分钟以内会返回 429。 |
| `omp usage --json -p openai-codex` | 每 5 分钟 |
| `omp stats --json` | 每 5 分钟 |
| `omp usage --history --json --days 7` | 打开仪表盘时，以及在其中按 `r` 时 |
| `omp usage invalidate` | 点击某个片段时，用于跳过 omp 的缓存 |
| `GET api.github.com/repos/joaodutra88/tern-omp-usage/releases/latest` | 每台机器每天一次，不使用 token；可通过隐藏 `updates` 部分或设置 `OMP_USAGE_NO_UPDATE_CHECK=1` 关闭 |
| `tern plugin install https://github.com/joaodutra88/tern-omp-usage --force` | 仅在你点击 `⬆` 或运行更新命令时 |

设置、每天的 token 数和费用（供仪表盘使用）、最近看到的版本，以及 `extras.luau` 的一份副本（在更新前创建）会保存到插件的数据文件夹（`tern.kv`），不会写到其他地方。状态格式化器只读取上述调用缓存的值，因为 Tern 只给格式化器 4 毫秒的时间。

## 配置

打开命令面板并输入 `OMP usage`。设置保存在插件的数据文件夹中，因此更新或重新安装都会保留它们。

| 命令 | 作用 |
|---|---|
| **OMP usage: show or hide a part…** | 输入一个部分名称来开启或关闭它：`claude`、`codex`、`today`、`cost`、`budget`、`reset`、`credits`、`fable`、`forecast`（即 `⏳`）、`alerts`（即弹出通知）、`updates`。 |
| **OMP usage: language…** | `en`、`pt-BR`、`es`、`zh-CN`、`ja`、`de` 或 `fr`。 |
| **OMP usage: work days per week…** | 从周一算起，有多少天解锁每周额度。默认值 `5` 表示周一至周五，每天 20%。 |
| **OMP usage: red badge threshold…** | 窗口变为闪烁红色徽章的百分比（默认 80）。 |
| **OMP usage: reset settings** | 恢复默认设置。 |
| **OMP usage: check for updates** | 立即向 GitHub 查询，即使 `updates` 已隐藏。 |
| **OMP usage: dashboard** | 打开仪表盘；如果当前窗口已有仪表盘，则切换到它。 |
| **OMP usage: what's new** | 打开你正在运行的版本的发布说明。 |

如果 Tern 的守护进程找不到 `omp`，请将 `OMP_USAGE_BIN` 环境变量设置为其完整路径。颜色是 `window.luau` 底部的普通 CSS。每个片段对应 `#statusline .sl-plugin[title="plugin.omp-usage.<name>"]`。

### 使用你的语言

插件显示的每个文字都位于 `labels.luau` 中，每种语言一张表。要添加一种语言，请复制 `en`，翻译其中的值，然后提交 Pull Request。某种语言缺少的键会回退到英文。

### 你自己的片段

如果 `window.luau` 旁边存在 `extras.luau` 文件，插件会加载它。Git 会忽略该文件，因此个人片段不会进入代码仓库。更新时会先把它复制到插件的数据文件夹，当 `window.luau` 旁边的文件不存在时，插件会加载这份副本：

```luau
local M = {}
function M.init(hidden, every) end -- register commands, timers, CSS
function M.segments(out, pane) end -- insert segments before the usage ones
return M
```

## FAQ

**`tern plugin list` 将插件显示为 `disabled`。**
Tern 会禁用出错的插件，或状态格式化器超出时间预算的插件。运行 `tern plugin reload`，然后在 Tern 的日志（Windows 上为 `%LOCALAPPDATA%\Tern\Logs\tern.log`）中查找包含 `omp-usage` 的行，并附上这些行提交 Issue。

**状态栏显示 `✻ Claude ?` 或 `⬢ Codex ?`。**
上一次 `omp usage` 调用失败了。请在终端中检查 `omp usage --json -p anthropic`（或 `-p openai-codex`）是否能正常运行；如果不能，请先用 omp 登录。点击任意片段即可重试。

**完全没有显示任何内容。**
请确认状态栏已开启（Tern 设置中的 `"status_bar": true`）。如果已开启，Tern 的守护进程可能找不到 `omp`：请将 `OMP_USAGE_BIN` 设置为其完整路径，然后重启 Tern。

**数字比 claude.ai 慢。**
它们来自同一个用量接口，通过 omp 每 5 分钟读取一次，因为 Anthropic 会对更频繁的轮询进行限速。点击某个片段即可强制刷新。

**为什么今天的 token 数这么高？**
其中包含缓存读取，它们占了智能体输入的大部分。费用是这些 token 按 API 价格计算的结果，而不是你的订阅实际收取的金额。

**如何更新？**
出现蓝色 `⬆` 时点击它，或运行 **OMP usage: update to the latest version**。手动更新：`tern plugin install https://github.com/joaodutra88/tern-omp-usage --force`。0.4.0 之前的版本没有更新检查，而在 Windows 上 0.4.0 的更新会报错 "The process cannot access the file"，因此这些版本需要手动更新一次。

**如何卸载？**
`tern plugin remove omp-usage`。

## 贡献

本项目采用 MIT 开源许可：可以使用、分叉、修改、发布。任何人都可以提交 Issue 和 Pull Request。

- `python scripts/check.py` 会运行语法检查、单元测试以及 CSS 和 manifest 检查；`--integration` 会在模拟的 Tern 中运行整个插件，使用录制好的 `omp` 和 GitHub 响应。CI 会在每个 pull request 上于 Linux、Windows 和 macOS 运行这两项。添加 `--tern` 还会在你的 Tern 中重新加载插件并读取其日志。
- 使用 AI 代理？请让它参考 [AGENTS.md](AGENTS.md)。其中说明了容易出错的规则，以及如何为你提交规范的 Bug 报告。
- 计划中的内容，以及改动需要遵守的规则：[ROADMAP.md](ROADMAP.md)（英文）。想法请发到 [Discussions](https://github.com/joaodutra88/tern-omp-usage/discussions)；标记为 **good first issue** 的 issue 适合入手。
- 更多内容见 [CONTRIBUTING.md](CONTRIBUTING.md)。参与者需遵守 [行为准则](CODE_OF_CONDUCT.md)；安全问题请通过 [SECURITY.md](SECURITY.md) 上报。

## Star 历史

[![Star History Chart](https://api.star-history.com/svg?repos=joaodutra88/tern-omp-usage&type=Date)](https://star-history.com/#joaodutra88/tern-omp-usage&Date)
