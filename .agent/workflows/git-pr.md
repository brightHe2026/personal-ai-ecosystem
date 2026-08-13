# Agent Workflow — Git / Pull Request

Version: 1.1

Purpose: Branch, commit, PR, and merge rules for Workflow V2.

Related: `.agent/workflows/task-lifecycle.md`, `.agent/workflows/ci-gate.md`.

Confirmed decisions: D3 (commit policy).

---

## 1. Branch name

```
task/TASK-XXX-short-name
```

Examples:

- `task/TASK-005B-workflow-v2-protocol`
- `task/TASK-005C-ci-migration`

One TASK → one branch. Do not reuse `main` as a working branch.

The TASK file `branch` field must match this name.

---

## 2. Who may commit / push

| Actor | `task/*` commit | `task/*` push | `main` commit | `main` push | Merge to `main` |
|-------|-----------------|---------------|---------------|-------------|-----------------|
| Coding Agent | Allowed | Allowed | **Forbidden** | **Forbidden** | **Forbidden** |
| Review Agent | Forbidden | Forbidden | **Forbidden** | **Forbidden** | **Forbidden** |
| Planner (ChatGPT) | Forbidden | Forbidden | **Forbidden** | **Forbidden** | **Forbidden** |
| Human | Allowed | Allowed | Allowed | Allowed | **Required owner** |

Coding Agent may commit on `task/*` during `coding` (local progress) and after `git_ready` (PR-ready commits).

Entering **`git_ready`** (open / update the PR as the review-approved delivery) is allowed only after Review **approve**.

---

## 3. When git_ready is allowed

```
in_review + decision: approve
        ↓
status → git_ready
        ↓
Coding Agent: ensure branch, commit remaining protocol/code, open PR
        ↓
ci_required: yes  →  status → ci_running, ci_status → running
ci_required: no   →  status → awaiting_merge, ci_status → n/a
```

If Review decision is `reject`, status returns to `coding`. No PR for that round.

Do not send a `ci_required: no` TASK through `ci_running`.
Do not send a `ci_required: yes` TASK to `awaiting_merge` until CI **pass** or a Human `n/a` exception (`ci-gate.md` §2.3).

---

## 4. Before every commit

Still required (from `docs/CODING_AGENT_RULES.md`):

```
git status
git diff
```

Confirm the current branch is `task/*`, not `main`.

Commit message prefix:

```
feat:
fix:
refactor:
docs:
test:
chore:
```

Do not skip hooks. Do not `--force` push to `main`. Do not push `main`.

---

## 5. Pull request contents

PR must associate all three:

| Item | How |
|------|-----|
| TASK | Path `.agent/tasks/active/TASK-XXX-*.md` (or `completed/` after merge) |
| Report | Path `.agent/reports/TASK-XXX-report.md` |
| Review | Path `.agent/reviews/TASK-XXX-review-round-N.md` with `decision: approve` |

PR title should include `TASK-XXX`.

After the PR exists, set `state.json`:

- `pr_url` → the PR URL
- if `ci_required: yes`: `status` → `ci_running`, `ci_status` → `running`
- if `ci_required: no`: `status` → `awaiting_merge`, `ci_status` → `n/a`

Do not set `ci_status: passed` unless checks were actually green.

---

## 6. Merge

- `ci_status: passed` or `n/a` does **not** allow automatic merge.
- Coding Agent and Review Agent must not merge.
- Only **Human** merges `main`.
- After merge, follow lifecycle section 8 (archive + `completed`).

---

## 7. TASK-005B exception (this protocol task)

TASK-005B implements protocol only. Its Coding Agent session must **not** commit, push, or open a PR. Delivery stops at `in_review` for an independent Review Agent.
