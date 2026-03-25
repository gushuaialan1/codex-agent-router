# Codex Agent Router

[![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?logo=powershell&logoColor=white)](#quick-start)
[![Platform](https://img.shields.io/badge/platform-Windows-informational)](#prerequisites)
[![License](https://img.shields.io/badge/license-unlicensed-lightgrey)](#limitations)

中文 | [English](#english)

`codex-agent-router` 是一个本地 PowerShell 工具，用来在开始执行任务前，为 Codex 自定义 agents 做路由推荐。

它主要做两件事：

1. 扫描 agent 定义文件，生成目录索引。
2. 根据用户请求，推荐更合适的 agent，并生成一段确认话术。

它适合放在你的日常 Codex 工作流前面，作为一个轻量的 agent selector。

## 前提

你至少需要满足下面二选一：

1. 已经安装过 Codex custom agents 到 `~/.codex/agents`
2. 本地有一份 `awesome-codex-subagents` 仓库，并通过 `-RepoPath` 指向它

如果你已经像下面这样安装过 agents：

```text
~/.codex/agents/*.toml
```

那默认直接可用，不需要额外指定路径。

## 文件

- `agent-router.ps1`: 主脚本
- `agent-catalog.json`: 机器可读索引
- `agent-catalog.md`: 人工浏览表
- `skill/agent-router`: 可直接安装的 Codex skill 版本

## 快速开始

在当前目录生成索引：

```powershell
pwsh -File .\agent-router.ps1 -Command index
```

如果你要直接从 `awesome-codex-subagents` 仓库生成：

```powershell
pwsh -File .\agent-router.ps1 -Command index -RepoPath "E:\path\to\awesome-codex-subagents"
```

根据用户请求做推荐：

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "帮我 review 这个 PR，看有没有安全问题和漏测"
```

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "这个 React 页面有个表单 bug，先帮我定位代码路径再修"
```

## 安装 Skill

如果你希望把它作为 Codex skill 使用，可以把仓库里的 `skill/agent-router` 复制到你的全局 skills 目录：

```powershell
New-Item -ItemType Directory -Force "$HOME\.codex\skills\agent-router" | Out-Null
Copy-Item .\skill\agent-router\* "$HOME\.codex\skills\agent-router" -Recurse -Force
```

复制后，重启或刷新 Codex 会话。

## 输出

`suggest` 会输出 JSON，关键字段包括：

- `recommendation`: 最推荐的 agent
- `alternates`: 备选 agent
- `confirmation_prompt`: 可以直接拿去问用户的确认话术

## 在项目里怎么用

这个工具本身不依赖某个固定业务项目，但它的典型使用场景是：你准备处理某个项目任务之前，先决定要不要交给某个专门 agent。

建议工作流：

1. 进入你的目标项目目录。
2. 拿 issue、PR 描述、报错说明或用户原话作为 `-Query` 输入。
3. 运行 `agent-router.ps1 -Command suggest`。
4. 读取 `recommendation.name` 和 `confirmation_prompt`。
5. 问用户是否先用推荐 agent。
6. 用户同意后，再进入实际实现、排查或 review。

例如：

```text
项目：一个 React Web 应用
任务：设置页表单提交失败，用户说“点保存没反应”
```

可以先运行：

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "React 设置页表单提交失败，先定位代码路径再修"
```

这类请求通常会把 `browser-debugger`、`frontend-developer`、`code-mapper` 排到前面。

## 示例

示例 1，PR review：

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "帮我 review 这个 PR，看有没有安全问题和漏测"
```

典型结果：

- `reviewer`
- `code-reviewer`
- `security-auditor`

示例 2，文档核对：

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "帮我查一下 Next.js 这个 API 的官方文档和版本差异"
```

典型结果：

- `docs-researcher`
- `api-designer`
- `documentation-engineer`

示例 3，前端故障排查：

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "这个 React 页面有 bug，先定位代码路径再修"
```

典型结果：

- `browser-debugger`
- `frontend-developer`
- `code-mapper`

## 设计说明

- 不是硬编码一个大 `if/else`
- 会读取 `.toml` agent 定义来建索引
- 匹配分由 `query keywords`、`agent name`、`category`、`description` 和一层启发式扩展共同决定
- 当 agent 列表更新后，重新运行 `index` 即可刷新目录

## 适合的任务

- PR review
- 安全审查
- 文档核对
- UI / 前端 bug 排查
- 测试补齐
- 重构建议
- 多 agent 任务拆分

## 限制

- 这是启发式推荐，不是严格分类器
- 如果你的 `~/.codex/agents` 里是扁平安装，分类会显示为 `installed-agents`
- 如果请求非常短或非常模糊，推荐质量会下降

---

## English

`codex-agent-router` is a local PowerShell tool that recommends the most suitable Codex custom agent before you start working on a task.

It does two main things:

1. Scans agent definition files and builds an index.
2. Recommends a better-fitting agent for a user request and generates a confirmation prompt.

It is intended to sit in front of your normal Codex workflow as a lightweight agent selector.

## Prerequisites

You need at least one of the following:

1. Codex custom agents already installed in `~/.codex/agents`
2. A local copy of `awesome-codex-subagents`, provided through `-RepoPath`

If your agents are already installed like this:

```text
~/.codex/agents/*.toml
```

the tool works out of the box with no extra path configuration.

## Files

- `agent-router.ps1`: main script
- `agent-catalog.json`: machine-readable index
- `agent-catalog.md`: human-readable catalog
- `skill/agent-router`: a Codex skill version you can install directly

## Quick Start

Generate an index in the current directory:

```powershell
pwsh -File .\agent-router.ps1 -Command index
```

Generate an index directly from `awesome-codex-subagents`:

```powershell
pwsh -File .\agent-router.ps1 -Command index -RepoPath "E:\path\to\awesome-codex-subagents"
```

Get an agent recommendation for a user request:

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "Review this PR for security issues and missing tests"
```

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "This React page has a form bug, first locate the code path and then fix it"
```

## Install The Skill

If you want to use this as a Codex skill, copy `skill/agent-router` into your global skills directory:

```powershell
New-Item -ItemType Directory -Force "$HOME\.codex\skills\agent-router" | Out-Null
Copy-Item .\skill\agent-router\* "$HOME\.codex\skills\agent-router" -Recurse -Force
```

After copying, restart or refresh your Codex session.

## Output

`suggest` returns JSON with these main fields:

- `recommendation`: the top recommended agent
- `alternates`: fallback agent options
- `confirmation_prompt`: a prompt you can directly use with the user

## How To Use It In A Project

The tool itself is not tied to any single business project. Its main purpose is to help you decide whether a task in a real project should first be delegated to a specialized agent.

Suggested workflow:

1. Open your target project.
2. Use the issue, PR description, bug report, or raw user request as `-Query`.
3. Run `agent-router.ps1 -Command suggest`.
4. Read `recommendation.name` and `confirmation_prompt`.
5. Ask the user whether to use the recommended agent first.
6. If the user agrees, proceed with the actual implementation, debugging, or review.

Example:

```text
Project: a React web app
Task: settings form submission is broken, the user says "clicking save does nothing"
```

You can run:

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "React settings form submission is broken, first locate the code path and then fix it"
```

This kind of request will usually rank `browser-debugger`, `frontend-developer`, and `code-mapper` near the top.

## Examples

Example 1, PR review:

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "Review this PR for security issues and missing tests"
```

Typical top results:

- `reviewer`
- `code-reviewer`
- `security-auditor`

Example 2, documentation lookup:

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "Check the official docs and version differences for this Next.js API"
```

Typical top results:

- `docs-researcher`
- `api-designer`
- `documentation-engineer`

Example 3, frontend bug investigation:

```powershell
pwsh -File .\agent-router.ps1 -Command suggest -Query "This React page has a bug, first locate the code path and then fix it"
```

Typical top results:

- `browser-debugger`
- `frontend-developer`
- `code-mapper`

## Design Notes

- It is not a giant hard-coded `if/else`
- It reads `.toml` agent definitions and builds an index from them
- Matching is based on `query keywords`, `agent name`, `category`, `description`, and heuristic expansions
- When your agent list changes, rerun `index` to refresh the catalog

## Good Fit For

- PR reviews
- Security reviews
- Documentation checks
- UI / frontend bug investigation
- Test coverage follow-up
- Refactoring suggestions
- Multi-agent task routing

## Limitations

- This is a heuristic recommender, not a strict classifier
- If your `~/.codex/agents` installation is flat, category will appear as `installed-agents`
- Recommendation quality drops when the request is too short or too vague
