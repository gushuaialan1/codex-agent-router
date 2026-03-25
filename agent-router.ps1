param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("index", "suggest")]
    [string]$Command = "suggest",

    [Parameter(Mandatory = $false)]
    [string]$Query,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath,

    [Parameter(Mandatory = $false)]
    [string]$AgentsPath = "$HOME\.codex\agents",

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $PSScriptRoot "agent-catalog.json"),

    [Parameter(Mandatory = $false)]
    [string]$MarkdownPath = (Join-Path $PSScriptRoot "agent-catalog.md"),

    [Parameter(Mandatory = $false)]
    [int]$Top = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Text {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $normalized = $Text.ToLowerInvariant()
    $normalized = $normalized -replace "[^a-z0-9\-\s]", " "
    $normalized = $normalized -replace "\s+", " "
    return $normalized.Trim()
}

function Get-KeywordSet {
    param(
        [string]$Name,
        [string]$Category,
        [string]$Description
    )

    $raw = @($Name, $Category, $Description) -join " "
    $tokens = Normalize-Text $raw
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($token in ($tokens -split " ")) {
        if ($token.Length -ge 3 -and -not $list.Contains($token)) {
            $list.Add($token)
        }
    }

    $expansions = @{
        "reviewer" = @("review", "audit", "regression", "correctness", "security", "tests")
        "docs-researcher" = @("docs", "documentation", "api", "reference", "version")
        "search-specialist" = @("search", "locate", "find", "grep", "scan")
        "code-mapper" = @("trace", "ownership", "map", "path", "entrypoint")
        "frontend-developer" = @("frontend", "ui", "react", "vue", "angular", "browser")
        "backend-developer" = @("backend", "api", "server", "service", "database")
        "fullstack-developer" = @("fullstack", "end-to-end", "feature", "frontend", "backend")
        "browser-debugger" = @("browser", "reproduce", "dom", "client", "debug")
        "debugger" = @("debug", "bug", "root-cause", "failure", "stacktrace")
        "test-automator" = @("test", "automation", "coverage", "e2e", "unit")
        "performance-engineer" = @("performance", "latency", "throughput", "slow", "optimize")
        "security-auditor" = @("security", "vulnerability", "auth", "exploit", "hardening")
        "refactoring-specialist" = @("refactor", "cleanup", "simplify", "decompose")
        "agent-installer" = @("install", "agent", "setup", "catalog", "subagent")
        "multi-agent-coordinator" = @("parallel", "coordinate", "delegate", "orchestrate")
        "knowledge-synthesizer" = @("summarize", "synthesize", "merge", "combine")
    }

    if ($expansions.ContainsKey($Name)) {
        foreach ($token in $expansions[$Name]) {
            if (-not $list.Contains($token)) {
                $list.Add($token)
            }
        }
    }

    return $list.ToArray()
}

function Parse-AgentFile {
    param([string]$FilePath)

    $raw = Get-Content -Raw -LiteralPath $FilePath
    $nameMatch = [regex]::Match($raw, '(?m)^name\s*=\s*"([^"]+)"')
    $descriptionMatch = [regex]::Match($raw, '(?m)^description\s*=\s*"([^"]+)"')
    $modelMatch = [regex]::Match($raw, '(?m)^model\s*=\s*"([^"]+)"')
    $reasoningMatch = [regex]::Match($raw, '(?m)^model_reasoning_effort\s*=\s*"([^"]+)"')
    $sandboxMatch = [regex]::Match($raw, '(?m)^sandbox_mode\s*=\s*"([^"]+)"')

    $categoryFolder = Split-Path (Split-Path $FilePath -Parent) -Leaf
    $categoryName = if ($categoryFolder -eq "agents") { "installed-agents" } else { $categoryFolder -replace '^\d{2}-', '' }

    $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { [System.IO.Path]::GetFileNameWithoutExtension($FilePath) }
    $description = if ($descriptionMatch.Success) { $descriptionMatch.Groups[1].Value } else { "" }
    $model = if ($modelMatch.Success) { $modelMatch.Groups[1].Value } else { "" }
    $reasoning = if ($reasoningMatch.Success) { $reasoningMatch.Groups[1].Value } else { "" }
    $sandbox = if ($sandboxMatch.Success) { $sandboxMatch.Groups[1].Value } else { "" }

    [pscustomobject]@{
        name = $name
        category = $categoryName
        description = $description
        model = $model
        reasoning_effort = $reasoning
        sandbox_mode = $sandbox
        source_path = $FilePath
        keywords = Get-KeywordSet -Name $name -Category $categoryName -Description $description
    }
}

function Build-Catalog {
    param(
        [string]$RepoPath,
        [string]$AgentsPath
    )

    $files = @()
    if ($RepoPath -and (Test-Path $RepoPath)) {
        $files = Get-ChildItem -Path $RepoPath -Recurse -Filter *.toml | Sort-Object FullName
    } elseif ($AgentsPath -and (Test-Path $AgentsPath)) {
        $files = Get-ChildItem -Path $AgentsPath -Filter *.toml | Sort-Object FullName
    }

    if (-not $files) {
        throw "No .toml agent files found. Provide -RepoPath pointing to awesome-codex-subagents, or ensure -AgentsPath exists."
    }

    return $files | ForEach-Object { Parse-AgentFile -FilePath $_.FullName }
}

function Save-Catalog {
    param(
        [object[]]$Catalog,
        [string]$Path,
        [string]$MarkdownPath
    )

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $Catalog | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Path

    $markdownDir = Split-Path $MarkdownPath -Parent
    if ($markdownDir -and -not (Test-Path $markdownDir)) {
        New-Item -ItemType Directory -Force -Path $markdownDir | Out-Null
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("| Name | Category | Model | Sandbox | Description |")
    $lines.Add("| --- | --- | --- | --- | --- |")

    foreach ($agent in ($Catalog | Sort-Object category, name)) {
        $description = ($agent.description -replace "\|", "/" -replace "\r?\n", " ").Trim()
        $lines.Add("| $($agent.name) | $($agent.category) | $($agent.model) | $($agent.sandbox_mode) | $description |")
    }

    $lines | Set-Content -LiteralPath $MarkdownPath
}

function Load-Catalog {
    param(
        [string]$RepoPath,
        [string]$AgentsPath,
        [string]$Path,
        [string]$MarkdownPath
    )

    if (-not (Test-Path $Path)) {
        $catalog = Build-Catalog -RepoPath $RepoPath -AgentsPath $AgentsPath
        Save-Catalog -Catalog $catalog -Path $Path -MarkdownPath $MarkdownPath
        return $catalog
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-QueryKeywords {
    param([string]$Text)

    $normalized = Normalize-Text $Text
    $rawLower = if ($Text) { $Text.ToLowerInvariant() } else { "" }
    if (-not $normalized) {
        $tokens = @()
    } else {
        $tokens = $normalized -split " " | Where-Object { $_.Length -ge 3 }
    }

    $queryKeywords = New-Object System.Collections.Generic.List[string]

    foreach ($token in $tokens) {
        if (-not $queryKeywords.Contains($token)) {
            $queryKeywords.Add($token)
        }
    }

    $phraseExpansions = @{
        "review" = @("reviewer", "code-reviewer")
        "bug" = @("debugger", "browser-debugger", "error-detective")
        "ui" = @("frontend-developer", "ui-designer", "ui-fixer")
        "frontend" = @("frontend-developer", "react-specialist", "vue-expert")
        "backend" = @("backend-developer", "api-designer")
        "security" = @("security-auditor", "penetration-tester")
        "test" = @("test-automator", "qa-expert")
        "docs" = @("docs-researcher", "documentation-engineer")
        "agent" = @("agent-installer", "agent-organizer", "multi-agent-coordinator")
        "performance" = @("performance-engineer")
        "refactor" = @("refactoring-specialist", "legacy-modernizer")
        "search" = @("search-specialist", "research-analyst")
        "research" = @("research-analyst", "docs-researcher", "market-researcher")
        "react" = @("react-specialist", "frontend-developer")
        "python" = @("python-pro")
        "powershell" = @("powershell-7-expert", "powershell-5.1-expert", "powershell-module-architect")
        "infra" = @("devops-engineer", "platform-engineer", "cloud-architect")
        "docker" = @("docker-expert")
        "kubernetes" = @("kubernetes-specialist")
        "terraform" = @("terraform-engineer", "terragrunt-expert")
    }

    foreach ($token in $tokens) {
        if ($phraseExpansions.ContainsKey($token)) {
            foreach ($value in $phraseExpansions[$token]) {
                if (-not $queryKeywords.Contains($value)) {
                    $queryKeywords.Add($value)
                }
            }
        }
    }

    $rawIntentMap = @{
        "review|审查|评审|代码评审|pr" = @("review", "reviewer", "code-reviewer")
        "安全|漏洞|风控|攻击|鉴权|权限" = @("security", "security-auditor", "penetration-tester")
        "测试|漏测|覆盖率|单测|集成测试|e2e" = @("test", "test-automator", "qa-expert")
        "文档|官方文档|api 文档|接口文档|版本差异" = @("docs", "docs-researcher", "documentation-engineer")
        "查找|搜索|定位|搜一下|grep|find" = @("search", "search-specialist", "code-mapper")
        "报错|bug|故障|异常|崩溃|报异常" = @("bug", "debugger", "error-detective")
        "浏览器|页面|前端|ui|react|vue|angular" = @("frontend", "frontend-developer", "browser-debugger")
        "后端|接口|服务端|api|数据库" = @("backend", "backend-developer", "api-designer")
        "修复|实现|开发|改一下|写代码|新增" = @("fix", "implement", "build")
        "重构|整理代码|解耦|简化" = @("refactor", "refactoring-specialist", "legacy-modernizer")
        "agent|subagent|代理|智能体|安装 agent" = @("agent", "agent-installer", "agent-organizer")
        "并行|协调|拆任务|多 agent|多智能体" = @("parallel", "multi-agent-coordinator", "task-distributor")
        "性能|慢|卡|延迟|吞吐" = @("performance", "performance-engineer")
        "powershell" = @("powershell", "powershell-7-expert", "powershell-module-architect")
        "python" = @("python", "python-pro")
        "docker" = @("docker", "docker-expert")
        "kubernetes|k8s" = @("kubernetes", "kubernetes-specialist")
        "terraform|terragrunt" = @("terraform", "terraform-engineer", "terragrunt-expert")
    }

    foreach ($pattern in $rawIntentMap.Keys) {
        if ($rawLower -match $pattern) {
            foreach ($value in $rawIntentMap[$pattern]) {
                if (-not $queryKeywords.Contains($value)) {
                    $queryKeywords.Add($value)
                }
            }
        }
    }

    return $queryKeywords.ToArray()
}

function Score-Agent {
    param(
        [object]$Agent,
        [string[]]$QueryKeywords
    )

    $score = 0
    $matched = New-Object System.Collections.Generic.List[string]

    foreach ($keyword in $QueryKeywords) {
        if ($Agent.name -eq $keyword) {
            $score += 8
            $matched.Add($keyword)
            continue
        }

        if ($Agent.name -like "*$keyword*") {
            $score += 5
            $matched.Add($keyword)
            continue
        }

        if ($Agent.category -like "*$keyword*") {
            $score += 3
            $matched.Add($keyword)
            continue
        }

        if ($Agent.keywords -contains $keyword) {
            $score += 2
            $matched.Add($keyword)
        }
    }

    if ($Agent.sandbox_mode -eq "read-only" -and ($QueryKeywords -contains "review" -or $QueryKeywords -contains "docs" -or $QueryKeywords -contains "research")) {
        $score += 2
    }

    if ($Agent.sandbox_mode -eq "workspace-write" -and ($QueryKeywords -contains "fix" -or $QueryKeywords -contains "implement" -or $QueryKeywords -contains "build")) {
        $score += 2
    }

    if ($Agent.name -eq "reviewer" -and ($QueryKeywords -contains "review") -and ($QueryKeywords -contains "security" -or $QueryKeywords -contains "test")) {
        $score += 6
    }

    if ($Agent.name -eq "code-mapper" -and ($QueryKeywords -contains "search") -and ($QueryKeywords -contains "fix" -or $QueryKeywords -contains "bug")) {
        $score += 4
    }

    [pscustomobject]@{
        agent = $Agent
        score = $score
        matched_keywords = ($matched | Select-Object -Unique)
    }
}

function Suggest-Agents {
    param(
        [object[]]$Catalog,
        [string]$Text,
        [int]$Top
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw "Query is required for suggest mode."
    }

    $queryKeywords = Get-QueryKeywords -Text $Text
    $ranked = foreach ($agent in $Catalog) {
        Score-Agent -Agent $agent -QueryKeywords $queryKeywords
    }

    $topMatches = $ranked |
        Sort-Object -Property @{ Expression = "score"; Descending = $true }, @{ Expression = { $_.agent.name }; Descending = $false } |
        Where-Object { $_.score -gt 0 } |
        Select-Object -First $Top

    if (-not $topMatches) {
        return [pscustomobject]@{
            query = $Text
            query_keywords = $queryKeywords
            recommendation = $null
            alternates = @()
            confirmation_prompt = "我没有找到明显匹配的 agent。要不要我先按普通流程处理，或者你给我补充一下目标和技术栈？"
        }
    }

    $best = $topMatches[0]
    $reason = if ($best.matched_keywords.Count -gt 0) {
        "matched: " + ($best.matched_keywords -join ", ")
    } else {
        "matched by description/category"
    }

    return [pscustomobject]@{
        query = $Text
        query_keywords = $queryKeywords
        recommendation = [pscustomobject]@{
            name = $best.agent.name
            category = $best.agent.category
            description = $best.agent.description
            model = $best.agent.model
            sandbox_mode = $best.agent.sandbox_mode
            score = $best.score
            reason = $reason
            source_path = $best.agent.source_path
        }
        alternates = @(
            $topMatches |
                Select-Object -Skip 1 |
                ForEach-Object {
                    [pscustomobject]@{
                        name = $_.agent.name
                        category = $_.agent.category
                        description = $_.agent.description
                        score = $_.score
                    }
                }
        )
        confirmation_prompt = "这个任务更适合 ``$($best.agent.name)``。原因：$reason。要不要我改成先用这个 agent 来处理？"
    }
}

switch ($Command) {
    "index" {
        $catalog = Build-Catalog -RepoPath $RepoPath -AgentsPath $AgentsPath
        Save-Catalog -Catalog $catalog -Path $OutputPath -MarkdownPath $MarkdownPath
        $catalog | Sort-Object category, name | Format-Table name, category, model, sandbox_mode -AutoSize
    }
    "suggest" {
        $catalog = Load-Catalog -RepoPath $RepoPath -AgentsPath $AgentsPath -Path $OutputPath -MarkdownPath $MarkdownPath
        $result = Suggest-Agents -Catalog $catalog -Text $Query -Top $Top
        $result | ConvertTo-Json -Depth 6
    }
}
