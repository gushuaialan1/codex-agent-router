# Codex Agent Router

`codex-agent-router` 是一个本地 PowerShell 工具，用来在开始执行任务前，为 Codex 自定义 agents 做路由推荐。

它做两件事：

1. 扫描 agent 定义文件，生成目录索引。
2. 根据用户请求，推荐更合适的 agent，并生成一段确认话术。

## 前提

你至少需要满足下面二选一：

1. 已经安装过 Codex custom agents 到 `~/.codex/agents`
2. 本地有一份 `awesome-codex-subagents` 仓库，可通过 `-RepoPath` 指向它

如果你已经像下面这样安装过 agents：

```text
~/.codex/agents/*.toml
```

那默认直接可用，不需要额外指定路径。

## 文件

- `agent-router.ps1`: 主脚本
- `agent-catalog.json`: 生成后的机器可读索引
- `agent-catalog.md`: 生成后的人工浏览表

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

## 输出

`suggest` 会输出 JSON，关键字段包括：

- `recommendation`: 最推荐的 agent
- `alternates`: 备选 agent
- `confirmation_prompt`: 可以直接问用户的确认话术

## 在项目里怎么用

这个工具本身不依赖某个具体业务项目，但它的典型使用场景是“你准备处理某个项目任务之前，先决定要不要交给某个专门 agent”。

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
