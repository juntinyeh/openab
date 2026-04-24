# Agent Instructions

## 1. Memory Vault — `agent-memory`

Persistent memory for task summaries, learnings, and reference notes. Each agent uses a dedicated branch.

### Setup

```bash
cd /home/agent
if [ ! -d agent-memory ]; then gh repo clone juntinyeh-worker/agent-memory; fi
cd agent-memory && git fetch origin
git checkout Squidward || git checkout -b Squidward
git pull origin Squidward || true
```

### Usage

- Store memories as `.md` files — summaries, decisions, troubleshooting notes, discoveries
- **File naming**: `2026-04-21-topic.md`, `project-overview.md`
- **Commit often** after completing tasks or learning something important
- **Commit format**: `<type>: <description>` (types: `memory`, `task`, `debug`, `discovery`, `config`, `review`)
- Use `git log --oneline` as a searchable index of past work
- Check memory before starting new tasks for relevant context

### Rules

- NEVER include secrets, credentials, API keys, tokens, or passwords
- Redact sensitive values with `<REDACTED>`

---

## 2. Workspace — `agent-workspaces`

Temporary working storage for ongoing projects that don't have a dedicated repository yet. Each task gets its own branch.

### Setup

```bash
cd /home/agent
if [ ! -d agent-workspaces ]; then gh repo clone juntinyeh-worker/agent-workspaces; fi
cd agent-workspaces && git fetch origin
```

### Branch Naming

Create a new branch per task: `squidward-<date-or-context>-<short-description>`

Examples:
- `squidward-20260421-3-tier-webapp`
- `squidward-2026q1-cost-report`
- `squidward-cfn-template-draft`

### Usage

```bash
cd /home/agent/agent-workspaces
git checkout -b squidward-<date>-<description>
# ... do work, create files ...
git add -A
git commit -m "<type>: <description>"
git push origin HEAD
```

- Commit frequently as work progresses
- Each branch is a self-contained deliverable
- When work is finalized and moved to a dedicated repo, the branch can be deleted
- Commit messages should give a clear overview so `git log` is useful for tracking progress

### Rules

- NEVER include secrets, credentials, API keys, tokens, or passwords
- Redact sensitive values with `<REDACTED>`
- One branch per task/project — don't mix unrelated work
