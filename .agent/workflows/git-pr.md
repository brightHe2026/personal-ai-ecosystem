# Agent Workflow — Git / Pull Request

Version: 1.3

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
- `task/TASK-005C-B-ci-implementation`

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
              using `scripts/workflow/open-pr.ps1` (requires Review approve)
        ↓
ci_required: yes  →  status → ci_running, ci_status → running
                     then `observe-ci.ps1` until `ci-gate` green
                     → live awaiting_merge / passed
ci_required: no   →  status → awaiting_merge, ci_status → n/a
                     `observe-ci.ps1` still records the real `ci-gate` fact
```

If Review decision is `reject`, status returns to `coding`. No PR for that round.

Do not send a `ci_required: no` TASK through `ci_running`.
Do not send a `ci_required: yes` TASK to `awaiting_merge` until required check `ci-gate` is green. The retired Human `n/a` exception (`ci-gate.md` §2.3) is not available.

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

After the PR exists:

- Put the PR URL in the PR body (already required to link TASK + report + review).
- Capture live `pr_url` / Checks with `scripts/workflow/open-pr.ps1` and `observe-ci.ps1` into gitignored `.agent/runtime.json`.
- Do **not** push a new commit whose only purpose is to write `pr_url` / `ci_status` / `status` into `state.json`. That post-PR metadata commit is forbidden (TASK-005B `cf55243`; TASK-005C-A D3).
- If `ci_required: yes`, the review-approved delivery commit may already record intent: `status: ci_running`, `ci_status: running`, `pr_url: null`. GitHub Actions starts from the `pull_request` event and does not read or write `state.json`. Live `awaiting_merge` / `passed` is only after `observe-ci.ps1` sees `ci-gate` green.
- If `ci_required: no`, protocol status is `awaiting_merge` / `ci_status: n/a` without waiting on app jobs. `ci-gate` still runs and should be green with app jobs skipped. Protocol stays `n/a` (not `passed`).
- Durable `pr_url` is written at Human-merge archive (lifecycle §8), optionally prepared by `scripts/workflow/finalize-prep.ps1` (does not push `main`).

Do not set `ci_status: passed` unless required check `ci-gate` was actually green. Do not have GitHub Actions commit `state.json`.

---

## 6. Merge

- `ci_status: passed` or `n/a` does **not** allow automatic merge.
- Coding Agent and Review Agent must not merge. There is no `merge` script. `gh pr merge` is forbidden.
- Only **Human** merges `main`.
- After merge, follow lifecycle section 8 (archive + `completed`). `finalize-prep.ps1` may prepare the archive on a synced `main`; it does not push.

---

## 7. TASK-005B exception (this protocol task)

TASK-005B implements protocol only. Its Coding Agent session must **not** commit, push, or open a PR. Delivery stops at `in_review` for an independent Review Agent.
