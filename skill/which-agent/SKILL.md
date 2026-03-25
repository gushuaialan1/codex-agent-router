---
name: which-agent
description: Use when the user asks which Codex agent should handle a task, wants a quick agent recommendation first, asks to route a request, or says things like “用哪个 agent”, “推荐一个 agent”, “先判断一下”, or “这个任务适合哪个 agent”. This is a lightweight alias that should route to the agent-router workflow.
---

# Which Agent

Use this as a lightweight alias for `agent-router`.

## Workflow

1. Treat the user request as an agent-selection question first.
2. Use the `agent-router` skill workflow and scripts to evaluate the task.
3. Return the top recommendation and ask the user for confirmation before delegating.

## Trigger Phrases

- which agent should I use
- recommend an agent first
- route this task
- 用哪个 agent
- 推荐一个 agent
- 先判断一下
- 这个任务适合哪个 agent
