# Agent Workflow V2.4

`.agent/` is the **executable protocol** for Personal AI Ecosystem agent collaboration.

It is not application code. Apps live under `apps/`. Shared agents live under `agents/`.

All new TASKs follow this directory. Historical TASK-001 / TASK-002 remain under `docs/TASKS/` and are not backfilled.

---

## Target flow

```
ChatGPT / Human (Planner)
        ↓
Task Specification  (plan_approved: false)
        ↓
Coding Agent — Implementation Plan — STOP
        ↓ Human/Planner Gate 1 APPROVED → plan_approved=true → start-coding.ps1
Coding Agent
        ↓ handoff.md (gitignored)
Review Agent          ← independent Cursor session; no self-review (D-003)
        ↓ Fix Loop (reject → coding, review_round++)
        ↓ same Coding session after approve (no new Git Ready prompt)
Git Branch / Commit   ← task/* only; never main (except D-001 archive)
        ↓
Pull Request          ← Coding Agent: scripts/workflow/open-pr.ps1
        ↓
GitHub Actions CI          ← required check `ci-gate`; skip app jobs when ci_required: no (ci_status: n/a)
        ↓
observe-ci.ps1 -Wait  ← live overlay .agent/runtime.json (gitignored)
        ↓
wait-for-merge.ps1    ← GitHub MERGED; Human need not transcribe
        ↓
Human Merge           ← only Human merges main (Gate 2)
        ↓
finalize-prep + D-001 archive-push  ← independent checks; marker is not authorization
```

---

## Roles

| Role | Who | May write app code | May commit `task/*` | May commit / push `main` | May merge `main` |
|------|-----|--------------------|---------------------|--------------------------|------------------|
| Planner / Orchestrator | ChatGPT or Human | No | No | No | Human only |
| Coding Agent | Cursor session assigned to the TASK | Yes | Yes | **No**, except D-001 archive-push after independent checks | **No** |
| Review Agent | **Separate** Cursor session | No (except explicit TASK exception) | No | **No** | **No** |
| CI | GitHub Actions | No | No | No | No |
| Merge | Human | n/a | n/a | Yes | **Yes** |

Coding Agent must not review its own work. ChatGPT / Human must not replace Review Agent.

Role details: `.agent/agents/`.

---

## Protocol index

| Document | Purpose |
|----------|---------|
| `.agent/workflows/task-lifecycle.md` | State machine and file hand-off (V2.4) |
| `.agent/workflows/git-pr.md` | Branch, commit, PR, Human merge, D-001 archive |
| `.agent/workflows/ci-gate.md` | CI protocol (Checks = SoT; `-Wait`; N-002; workflow is `.github/workflows/ci.yml`) |
| `.agent/workflows/permissions.md` | Always Run / hook / D-001 marker policy |
| `scripts/workflow/` | Coding Agent GitHub CLI wrappers (`start-coding`, `open-pr`, `observe-ci`, `wait-for-merge`, `status`, `finalize-prep`, `archive-push`) |
| `.agent/handoff.TEMPLATE.md` | Session handoff schema; live `.agent/handoff.md` is gitignored |
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
| Shared state | `.agent/state.json` (`plan_approved` Gate 1 flag) |
| Live overlay | `.agent/runtime.json` (gitignored; TASK-005C-C) |
| Live handoff | `.agent/handoff.md` (gitignored; TASK-005C-D) |
| Workflow scripts | `scripts/workflow/` |

---

## How to start a TASK

1. Copy `.agent/tasks/TASK_TEMPLATE.md` → `.agent/tasks/active/TASK-XXX-short-name.md`.
2. Fill required fields (`task_id`, `scope`, `goal`, `requirements`, `constraints`, `validation`, `branch`, `ci_required`, `status`).
3. Update `.agent/state.json` (`active_task`, `status: specified`, `plan_approved: false`, `review_round: 0`, `ci_required`).
4. Coding Agent writes Implementation Plan and **STOPS** (Gate 1). Human/Planner issues machine-readable APPROVED evidence. Persist `plan_approved: true`. Run `start-coding.ps1`.
5. Coding Agent implements and writes `.agent/reports/TASK-XXX-report.md` plus `.agent/handoff.md`.
6. Independent Review Agent (separate session, `@handoff`) writes `.agent/reviews/TASK-XXX-review-round-N.md`.
7. After **approve**, the same Coding session may enter `git_ready` and run `scripts/workflow/open-pr.ps1` then `observe-ci.ps1 -Wait` (no new Human Git Ready prompt).
8. If `ci_required: yes`, live `awaiting_merge` only on real `ci-gate` pass. If `ci_required: no`, skip `ci_running` → `awaiting_merge` with `ci_status: n/a`. **Human** merges `main`. `wait-for-merge.ps1` reads `MERGED`. Then `finalize-prep.ps1` + D-001 `archive-push.ps1`.

Do not treat a TASK as complete because a report exists. Complete means Human merged `main` and state was archived.
