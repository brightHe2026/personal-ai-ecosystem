# Agent Workflow — CI Gate

Version: 1.1

Purpose: Protocol for the GitHub Actions quality gate. This file does **not** create workflows.

CI implementation and migration from standalone `sales-agent` (TASK-004) is **TASK-005C**.

Confirmed decision: D4 — `personal-ai-ecosystem` is the future unified CI home.

Related: `.agent/workflows/task-lifecycle.md`, `.agent/workflows/git-pr.md`.

Round-2 fix (Review B-001, B-002): CI-required vs CI-not-required paths, and an executable CI-failure recovery that cannot dead-end in `ci_running`.

---

## 1. `ci_required`

Every TASK must set `ci_required`: `yes` or `no`.

Planner fills it on the TASK file. Copy into `state.json` as boolean `ci_required` (`true` = yes).

Guidance (not automatic):

| Typical `scope` | Typical `ci_required` |
|-----------------|------------------------|
| `apps/sales-agent` | `yes` |
| `agents/knowledge-agent` | `yes` |
| `docs` / `.agent` / `ecosystem` (protocol) | `no` |

Not every TASK must have CI. `ci_required: no` is a first-class path, not a workaround.

---

## 2. Two legal paths after `git_ready`

Review **approve** is still the only normal entry to `git_ready`. Then:

### 2.1 CI-required (`ci_required: yes`)

```
git_ready
    ↓
ci_running
    ↓ CI pass
awaiting_merge
```

- On PR open: `status` → `ci_running`, `ci_status` → `running`.
- On CI pass: `status` → `awaiting_merge`, `ci_status` → `passed`.
- On CI fail: **must not** enter `awaiting_merge`. Recovery is section 4.

### 2.2 CI-not-required (`ci_required: no`)

```
git_ready
    ↓
awaiting_merge
```

- On PR open: `status` → `awaiting_merge`, `ci_status` → `n/a`.
- **Skip** `ci_running`. Do not invent `ci_status: passed`.
- Human merge remains the gate before `completed`.

Coding Agent may take path 2.2 only when the TASK file says `ci_required: no`.

### 2.3 Human exception — CI required but no workflow yet

Until TASK-005C adds `.github/workflows/` in this repository, a TASK with `ci_required: yes` cannot obtain `ci_status: passed`.

**Human only** may then set `ci_status: n/a` and `git_ready` or `ci_running` → `awaiting_merge`, with a note on the TASK.

Coding Agent and Review Agent must not declare this exception. They must not pretend CI passed (`passed` is only for real green checks).

---

## 3. `ci_status` values

| Value | Meaning | Who may set it |
|-------|---------|----------------|
| `not_started` | No PR / no CI run yet | Planner / Coding Agent |
| `running` | Checks in progress | Coding Agent on PR open (CI-required) |
| `passed` | Required checks actually green | CI result (or Human recording a real green run) |
| `failed` | One or more required checks red | CI result |
| `n/a` | CI not applicable: `ci_required: no`, or Human exception in §2.3 | Coding Agent only for `ci_required: no`; otherwise Human |

Default for a new TASK is `not_started`.

`n/a` is a defined transition into `awaiting_merge` (paths 2.2 and 2.3). It is not a synonym for `passed`.

---

## 4. CI failure recovery (CI-required only)

**Hard rule:** CI failure must not set `awaiting_merge`.

`ci_running` is not a dead-end. After `ci_status: failed`, exactly one of these applies:

| Case | Who | Next `status` | `ci_status` | Review |
|------|-----|---------------|-------------|--------|
| **In-scope retry** | Coding Agent | stay `ci_running` | `failed` then `running` on the new push | No new review. Push on `task/*` is limited to CI config, test harness, or already-approved files with no new behavior. |
| **Out-of-scope fix** | Coding Agent | `coding` | stay `failed` | New behavior / unreviewed product or protocol change. Then write a report and enter `in_review` as usual (`review_round` unchanged unless a Review **reject** happens). Do **not** keep pushing product code while `ci_running`. Do **not** jump directly to `in_review` (report first). |
| **Stuck** | Human | `blocked` | stay `failed` | Human decides. |
| **Abandon** | Human | `cancelled` | stay `failed` | Human only. |

If unsure whether a change is in-scope, treat it as **out-of-scope** (`ci_running` → `coding`).

There is no `ci_running` → `in_review` shortcut and no `ci_running` → `awaiting_merge` on failure.

---

## 5. Pass (CI-required only)

- All required GitHub Actions checks on the TASK PR are green.
- Then: `status` → `awaiting_merge`, `ci_status` → `passed`.
- Human may merge `main`. Still no automatic merge.

---

## 6. What TASK-005C will implement (not this TASK)

- `.github/workflows/` in **this** repository
- Path-aware jobs for `apps/sales-agent` and `agents/knowledge-agent`
- Adapt, do not long-term dual-run, the existing TASK-004 workflow in `brightHe2026/sales-agent`

Until TASK-005C lands:

- TASKs with `ci_required: no` use path 2.2.
- TASKs with `ci_required: yes` wait for CI, or Human uses §2.3.
- Nobody pretends `passed`. Nobody merges `main` except Human.

---

## 7. Scope hint for future CI

| `scope` | Expected future jobs |
|---------|----------------------|
| `apps/sales-agent` | sales-agent backend + frontend |
| `agents/knowledge-agent` | knowledge-agent pytest |
| `ecosystem` / `.agent` / `docs` | none required; `ci_required: no` unless the TASK adds a schema check |
