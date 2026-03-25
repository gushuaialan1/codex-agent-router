---
name: agent-router
description: Route a user task to the most suitable Codex custom agent before doing work. Use when the user asks which agent to use, wants to choose or recommend an agent first, wants to route a task, wants to decide whether a specialized agent is better, or wants confirmation before delegating to a recommended agent. Also use for requests such as “先判断用哪个 agent”, “先 route 一下”, “推荐一个 agent”, or “这个任务更适合哪个 agent”.
---

# Agent Router

Use this skill before substantial work when a custom Codex agent might be a better fit.

Common trigger phrases include:

- which agent should be used first
- recommend an agent for this task
- route this request first
- decide whether a specialized agent is better
- 先判断用哪个 agent
- 先 route 一下
- 推荐一个 agent
- 这个任务更适合哪个 agent

## Workflow

1. If the user already named a specific agent, do not override it unless there is a clear mismatch.
2. Run `scripts/route-task.ps1` with the user's request text.
3. Read the top recommendation, alternates, and confirmation prompt.
4. If the recommendation is materially better than handling the task directly, ask the user a short confirmation question using the returned prompt.
5. If the user agrees, delegate using the recommended agent. If the user declines, continue normally.

## Command

```powershell
pwsh -File scripts/route-task.ps1 -Query "<user request>"
```

Optional:

```powershell
pwsh -File scripts/route-task.ps1 -Query "<user request>" -AgentsPath "$HOME\.codex\agents"
```

## Interpretation

- Prefer the top recommendation when its score is clearly above the alternates.
- If the top results are close and represent a sequence rather than a single role, ask the user whether to use the primary recommendation first and mention one fallback.
- If no meaningful match is found, do not force an agent. Continue with the normal flow.

## Guardrails

- Do not recommend an agent just because one exists in the same category.
- Respect explicit user intent over router heuristics.
- Keep the confirmation short. One sentence is enough.
- If the task is trivial, skip delegation even if there is a possible match.
