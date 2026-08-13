# Agent Workflow V2

`.agent/` is the **executable protocol** for Personal AI Ecosystem agent collaboration.

It is not application code. Apps live under `apps/`. Shared agents live under `agents/`.

All new TASKs follow this directory. Historical TASK-001 / TASK-002 remain under `docs/TASKS/` and are not backfilled.

---

## Target flow

```
ChatGPT / Human (Planner)
        ↓
Task Specification
        ↓
Coding Agent
        ↓
Review Agent          ← independent Cursor session; no self-review
        ↓
Fix Loop (reject → coding, review_round++)
        ↓
Git Branch / Commit   ← task/* only; never main
        ↓
Pull Request          ← Coding Agent: scripts/workflow/open-pr.ps1
        ↓
GitHub Actions CI          ← required check `ci-gate`; skip app jobs when ci_required: no (ci_status: n/a)
        ↓
observe-ci.ps1        ← live overlay .agent/runtime.json (gitignored)
        ↓
Human Merge           ← only Human merges main
```

---

## Roles

| Role | Who | May write app code | May commit `task/*` | May commit / push `main` | May merge `main` |
|------|-----|--------------------|---------------------|--------------------------|------------------|
| Planner / Orchestrator | ChatGPT or Human | No | No | No | Human only |
| Coding Agent | Cursor session assigned to the TASK | Yes | Yes | **No** | **No** |
| Review Agent | **Separate** Cursor session | No (except explicit TASK exception) | No | **No** | **No** |
| CI | GitHub Actions | No | No | No | No |
| Merge | Human | n/a | n/a | Yes | **Yes** |

Coding Agent must not review its own work. ChatGPT / Human must not replace Review Agent.

Role details: `.agent/agents/`.

---

## Protocol index

| Document | Purpose |
|----------|---------|
| `.agent/workflows/task-lifecycle.md` | State machine and file hand-off (V2; V1 changelog inside) |
| `.agent/workflows/git-pr.md` | Branch, commit, PR, Human merge |
| `.agent/workflows/ci-gate.md` | CI protocol (Checks = SoT; workflow is `.github/workflows/ci.yml`; live overlay + observer scripts) |
| `scripts/workflow/` | Coding Agent GitHub CLI wrappers (`open-pr`, `observe-ci`, `status`, `finalize-prep`) |
| `.agent/tasks/TASK_TEMPLATE.md` | Operational TASK envelope |
| `.agent/reports/REPORT_TEMPLATE.md` | Coding Agent report |
| `.agent/reviews/REVIEW_TEMPLATE.md` | Review Agent decision |
| `.agent/state.json` | Shared machine-readable status |
| `.agent/agents/planner.md` | Planner boundary |
| `.agent/agents/coding-agent.md` | Coding Agent boundary |
| `.agent/agents/review-agent.md` | Review Agent boundary |

Human-facing specs that still apply, and now point here:

- `docs/AGENTS.md`
- `docs/CODING_AGENT_RULES.md`
- `docs/AGENT_TASK_TEMPLATE.md`

---

## Paths

| Kind | Path |
|------|------|
| Active tasks | `.agent/tasks/active/` |
| Completed tasks | `.agent/tasks/completed/` |
| Coding reports | `.agent/reports/` |
| Review files | `.agent/reviews/` |
| Workflows | `.agent/workflows/` |
| Role files | `.agent/agents/` |
| Shared state | `.agent/state.json` |
| Live overlay | `.agent/runtime.json` (gitignored; TASK-005C-C) |
| Workflow scripts | `scripts/workflow/` |

---

## How to start a TASK

1. Copy `.agent/tasks/TASK_TEMPLATE.md` → `.agent/tasks/active/TASK-XXX-short-name.md`.
2. Fill required fields (`task_id`, `scope`, `goal`, `requirements`, `constraints`, `validation`, `branch`, `ci_required`, `status`).
3. Update `.agent/state.json` (`active_task`, `status: specified` or `coding`, `review_round: 0`, `ci_required`).
4. Coding Agent implements and writes `.agent/reports/TASK-XXX-report.md`.
5. Independent Review Agent writes `.agent/reviews/TASK-XXX-review-round-N.md`.
6. After **approve**, Coding Agent may enter `git_ready` (branch / commit / PR per `git-pr.md`, using `scripts/workflow/open-pr.ps1`).
7. If `ci_required: yes`, observe `ci-gate` with `observe-ci.ps1` → live `awaiting_merge` only on pass. If `ci_required: no`, skip `ci_running` → `awaiting_merge` with `ci_status: n/a`. **Human** merges `main`. Then archive to `completed/`.

Do not treat a TASK as complete because a report exists. Complete means Human merged `main` and state was archived.
