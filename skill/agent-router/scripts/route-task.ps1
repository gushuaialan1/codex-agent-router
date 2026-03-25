param(
    [Parameter(Mandatory = $true)]
    [string]$Query,

    [Parameter(Mandatory = $false)]
    [string]$AgentsPath = "$HOME\.codex\agents",

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
        [string]$Description
    )

    $tokens = Normalize-Text "$Name $Description"
    $list = New-Object System.Collections.Generic.List[string]

    foreach ($token in ($tokens -split " ")) {
        if ($token.Length -ge 3 -and -not $list.Contains($token)) {
            $list.Add($token)
        }
    }

    $seed = @{
        "reviewer" = @("review", "correctness", "security", "tests")
        "code-reviewer" = @("review", "maintainability", "quality")
        "docs-researcher" = @("docs", "documentation", "api", "version")
        "search-specialist" = @("search", "find", "locate", "scan")
        "code-mapper" = @("trace", "map", "ownership", "path")
        "browser-debugger" = @("browser", "ui", "reproduce", "frontend")
        "debugger" = @("bug", "debug", "root-cause", "failure")
        "frontend-developer" = @("frontend", "ui", "react", "vue", "angular")
        "backend-developer" = @("backend", "api", "server", "database")
        "test-automator" = @("test", "automation", "coverage", "e2e")
        "security-auditor" = @("security", "auth", "vulnerability")
        "refactoring-specialist" = @("refactor", "cleanup", "simplify")
        "multi-agent-coordinator" = @("parallel", "coordinate", "delegate")
    }

    if ($seed.ContainsKey($Name)) {
        foreach ($token in $seed[$Name]) {
            if (-not $list.Contains($token)) {
                $list.Add($token)
            }
        }
    }

    return $list.ToArray()
}

function Parse-Agent {
    param([string]$FilePath)

    $raw = Get-Content -Raw -LiteralPath $FilePath
    $nameMatch = [regex]::Match($raw, '(?m)^name\s*=\s*"([^"]+)"')
    $descriptionMatch = [regex]::Match($raw, '(?m)^description\s*=\s*"([^"]+)"')
    $modelMatch = [regex]::Match($raw, '(?m)^model\s*=\s*"([^"]+)"')
    $sandboxMatch = [regex]::Match($raw, '(?m)^sandbox_mode\s*=\s*"([^"]+)"')

    $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { [System.IO.Path]::GetFileNameWithoutExtension($FilePath) }
    $description = if ($descriptionMatch.Success) { $descriptionMatch.Groups[1].Value } else { "" }
    $model = if ($modelMatch.Success) { $modelMatch.Groups[1].Value } else { "" }
    $sandbox = if ($sandboxMatch.Success) { $sandboxMatch.Groups[1].Value } else { "" }

    [pscustomobject]@{
        name = $name
        description = $description
        model = $model
        sandbox_mode = $sandbox
        source_path = $FilePath
        keywords = Get-KeywordSet -Name $name -Description $description
    }
}

function Get-QueryKeywords {
    param([string]$Text)

    $normalized = Normalize-Text $Text
    $rawLower = $Text.ToLowerInvariant()
    $keywords = New-Object System.Collections.Generic.List[string]

    foreach ($token in ($normalized -split " " | Where-Object { $_.Length -ge 3 })) {
        if (-not $keywords.Contains($token)) {
            $keywords.Add($token)
        }
    }

    $intentMap = @{
        "review|审查|评审|pr" = @("review", "reviewer", "code-reviewer")
        "安全|漏洞|鉴权|权限" = @("security", "security-auditor", "penetration-tester")
        "测试|漏测|覆盖率|单测|e2e" = @("test", "test-automator", "qa-expert")
        "文档|官方文档|版本差异|api 文档" = @("docs", "docs-researcher", "documentation-engineer")
        "查找|搜索|定位|找一下|grep|find" = @("search", "search-specialist", "code-mapper")
        "报错|bug|异常|故障|崩溃" = @("bug", "debugger", "error-detective")
        "前端|页面|浏览器|ui|react|vue|angular" = @("frontend", "frontend-developer", "browser-debugger")
        "后端|接口|服务端|api|数据库" = @("backend", "backend-developer", "api-designer")
        "修复|实现|开发|写代码|新增" = @("fix", "implement", "build")
        "重构|整理代码|简化|解耦" = @("refactor", "refactoring-specialist", "legacy-modernizer")
        "并行|协调|拆任务|多 agent|多智能体" = @("parallel", "multi-agent-coordinator", "task-distributor")
        "powershell" = @("powershell", "powershell-7-expert", "powershell-module-architect")
        "python" = @("python", "python-pro")
        "docker" = @("docker", "docker-expert")
        "kubernetes|k8s" = @("kubernetes", "kubernetes-specialist")
        "terraform|terragrunt" = @("terraform", "terraform-engineer", "terragrunt-expert")
    }

    foreach ($pattern in $intentMap.Keys) {
        if ($rawLower -match $pattern) {
            foreach ($value in $intentMap[$pattern]) {
                if (-not $keywords.Contains($value)) {
                    $keywords.Add($value)
                }
            }
        }
    }

    return $keywords.ToArray()
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

        if ($Agent.keywords -contains $keyword) {
            $score += 2
            $matched.Add($keyword)
        }
    }

    if ($Agent.sandbox_mode -eq "read-only" -and ($QueryKeywords -contains "review" -or $QueryKeywords -contains "docs" -or $QueryKeywords -contains "search")) {
        $score += 2
    }

    if ($Agent.sandbox_mode -eq "workspace-write" -and ($QueryKeywords -contains "fix" -or $QueryKeywords -contains "implement" -or $QueryKeywords -contains "build")) {
        $score += 2
    }

    if ($Agent.name -eq "reviewer" -and ($QueryKeywords -contains "review") -and ($QueryKeywords -contains "security" -or $QueryKeywords -contains "test")) {
        $score += 6
    }

    [pscustomobject]@{
        agent = $Agent
        score = $score
        matched_keywords = ($matched | Select-Object -Unique)
    }
}

if (-not (Test-Path $AgentsPath)) {
    throw "Agents path not found: $AgentsPath"
}

$catalog = Get-ChildItem -Path $AgentsPath -Filter *.toml |
    Sort-Object FullName |
    ForEach-Object { Parse-Agent -FilePath $_.FullName }

$queryKeywords = Get-QueryKeywords -Text $Query
$ranked = foreach ($agent in $catalog) {
    Score-Agent -Agent $agent -QueryKeywords $queryKeywords
}

$topMatches = $ranked |
    Sort-Object -Property @{ Expression = "score"; Descending = $true }, @{ Expression = { $_.agent.name }; Descending = $false } |
    Where-Object { $_.score -gt 0 } |
    Select-Object -First $Top

if (-not $topMatches) {
    [pscustomobject]@{
        query = $Query
        query_keywords = $queryKeywords
        recommendation = $null
        alternates = @()
        confirmation_prompt = "我没有找到明显匹配的 agent。要不要我先按普通流程处理？"
    } | ConvertTo-Json -Depth 6
    exit 0
}

$best = $topMatches[0]
$reason = if ($best.matched_keywords.Count -gt 0) {
    "matched: " + ($best.matched_keywords -join ", ")
} else {
    "matched by description"
}

[pscustomobject]@{
    query = $Query
    query_keywords = $queryKeywords
    recommendation = [pscustomobject]@{
        name = $best.agent.name
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
                    description = $_.agent.description
                    score = $_.score
                }
            }
    )
    confirmation_prompt = "这个任务更适合 ``$($best.agent.name)``。原因：$reason。要不要我先用这个 agent？"
} | ConvertTo-Json -Depth 6
