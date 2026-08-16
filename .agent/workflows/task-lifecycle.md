# Agent Workflow — Task Lifecycle

Version: 2.4

Purpose: Define how Planner (ChatGPT / Human), Coding Agent (Cursor), and Review Agent (separate Cursor session) collaborate through Git files under `.agent/`.

This document is the V2 contract. Section 10 records what V1 (TASK-003) defined and what changed.

---

## 1. State machine

Required states:

```
specified
    ↓ Implementation Plan (status stays specified; plan_approved stays false)
    ↓ STOP — Human/Planner Gate 1
    ↓ plan_approved = true   (authority: Human/Planner only)
    ↓ start-coding.ps1       (PRIMARY Gate 1 enforcement)
coding  ⇄  in_review     (reject: in_review → coding, review_round += 1)
    ↓ approve
git_ready
    ├─ ci_required yes → ci_running → (pass) awaiting_merge
    │                      ↑              ↑
    │                      │ fail, in-scope retry
    │                      └── (fail, out-of-scope) coding → in_review
    └─ ci_required no  → awaiting_merge   (ci_status: n/a; skip ci_running)
              ↓ Human merge (Gate 2)
              ↓ wait-for-merge (script reads MERGED; do not forge)
         finalize-prep + D-001 archive-push (allowlist only)
         completed

blocked      (Human or protocol cap)
cancelled    (Human only)
```

| State | Owner | Meaning | Legal exits |
|-------|--------|---------|-------------|
| `specified` | Planner | TASK file is in `active/`; Implementation Plan may be written; `plan_approved` defaults `false` | `coding` (only after Gate 1), `cancelled` |
| `coding` | Coding Agent | Implementation / fix round in progress | `in_review`, `blocked`, `cancelled` |
| `in_review` | Review Agent | Independent review of diff + report | `git_ready` (approve), `coding` (reject), `blocked`, `cancelled` |
| `git_ready` | Coding Agent | Review approved; branch / commit / PR allowed | `ci_running` (CI-required), `awaiting_merge` (`ci_required: no`), `blocked`, `cancelled` |
| `ci_running` | GitHub Actions | PR checks running or last run not green (CI-required only) | `awaiting_merge` (**pass only**), `ci_running` (in-scope retry), `coding` (out-of-scope fix), `blocked`, `cancelled` |
| `awaiting_merge` | Human | Waiting for Human to merge `main` (`ci_status` is `passed` or `n/a`) | `completed`, `blocked`, `cancelled` |
| `completed` | — | Merged to `main`; task archived | none |
| `blocked` | Human | Cannot proceed without a decision | `coding`, `specified`, `cancelled` |
| `cancelled` | Human | Abandoned | none |

Rules:

- **Gate 1 (D-002).** `specified` → Implementation Plan → STOP → Human/Planner approval → `plan_approved=true` → `start-coding.ps1` → `coding`. Coding MUST NOT modify implementation files before `plan_approved === true`.
- **Gate 1 authority.** Human/Planner is the sole approval authority. Coding Agent must never infer approval from conversational context. If Coding performs the mechanical write of `plan_approved=true`, it may do so only after explicit, machine-readable Gate 1 `APPROVED` evidence/handoff from Human/Planner. Approval authority and state persistence are distinct.
- **Gate 1 PRIMARY enforcement** is `scripts/workflow/start-coding.ps1`: `plan_approved != true` ⇒ implementation must not start. The `plan_approved` assertion in `open-pr.ps1` is defense-in-depth only and is not a substitute for blocking implementation before coding begins.
- Coding Agent must not move a task to `git_ready` without Review **approve**. That remains the only normal entry to `git_ready`.
- After Review **approve**, the same Coding session continues `git_ready` → `open-pr.ps1` → `observe-ci.ps1 -Wait` without a new Human-authored Git Ready prompt. Independent Review remains a **separate** session (D-003). Do not simulate Review Agent inside the Coding session.
- Agents read `.agent/handoff.md` (gitignored live overlay), TASK / report / review / `state.json` / GitHub. Human is not an information courier.
- Review reject **must** set `status` to `coding` and increment `review_round`.
- Suggested cap: 3 reject rounds, then `blocked` for Human.
- CI-required TASKs: `git_ready` → `ci_running` → `awaiting_merge` only on CI **pass**.
- CI-not-required TASKs: `git_ready` → `awaiting_merge` with `ci_status: n/a`. They skip `ci_running`.
- CI failure must not set `awaiting_merge`. Recovery: in-scope retry (stay `ci_running`), out-of-scope fix (`ci_running` → `coding`, then report → `in_review`), or Human `blocked` / `cancelled`. See `ci-gate.md`.
- There is no `ci_running` → `in_review` shortcut.
- `completed` is only after Human merge of `main`. Review approve is not completion. CI skip (`n/a`) is not merge permission.
- The TASK file stays in `.agent/tasks/active/` until `completed` or `cancelled`.

V1 Result aliases (still understood, do not use on new tasks):

| V1 Result | V2 `status` |
|-----------|-------------|
| `pending` | `specified` |
| `in_progress` | `coding` |
| `completed` | `completed` |
| `blocked` | `blocked` |

---

## 2. Shared state (`.agent/state.json`)

TASK-003 fields are kept:

- `version`, `updated_at`, `active_task`, `last_completed_task`, `queue`
- `agents.chatgpt`, `agents.cursor`
- `paths.tasks_active`, `paths.tasks_completed`, `paths.reports`, `paths.workflows`

V2 additions:

- `status` — current task state (section 1)
- `review_round` — integer; `0` before first review; `1` on first `in_review`
- `pr_url` — string or `null`
- `ci_status` — `not_started` \| `running` \| `passed` \| `failed` \| `n/a`
- `ci_required` — boolean; `true` when the TASK file says `ci_required: yes`
- `plan_approved` — boolean Gate 1 flag; default `false` when a TASK is created. Not a status enum value. Human/Planner is the sole approval authority. Reset to `false` at archive.
- `agents.review` — Review Agent (`role: review-agent`)
- `paths.reviews`, `paths.agents`

Compatibility:

- Do not invent `last_completed_task` for TASK-003. TASK-003 was never queued or archived.
- Keep key `agents.cursor` for the Coding Agent (do not rename the key).
- `queue` lists TASK ids waiting behind `active_task`. The active TASK is not duplicated in `queue`.

Agent `status` values: `idle` \| `working` \| `planning` (planner only). TASK-003 used `idle` / `working` / `planning`; keep them.

When to update `state.json` (same actor that caused the transition):

| Event | `status` | Other fields |
|-------|----------|--------------|
| Planner creates TASK | `specified` | `active_task`, `review_round: 0`, `pr_url: null`, `ci_status: not_started`, `ci_required` from TASK file, **`plan_approved: false`** |
| Human/Planner Gate 1 APPROVED | `specified` | **`plan_approved: true`** (authority is Human/Planner; Coding may persist the boolean only given machine-readable APPROVED evidence) |
| Coding Agent starts (`start-coding.ps1`) | `coding` | PRIMARY Gate 1: refuses unless `plan_approved === true`. `agents.cursor.status: working` |
| Coding Agent writes report | `in_review` | `review_round` = max(1, current); `agents.cursor.status: idle` |
| Review reject | `coding` | `review_round += 1` |
| Review approve | `git_ready` | — |
| PR opened, `ci_required: yes` | `ci_running` | Intent may already be in the pre-PR delivery commit (`ci_status: running`, `pr_url: null`). Live `pr_url` / Checks go in gitignored `.agent/runtime.json` via `scripts/workflow/open-pr.ps1` + `observe-ci.ps1`. Do **not** push a post-PR metadata commit. Durable `pr_url` at archive. |
| PR opened, `ci_required: no` | `awaiting_merge` | `ci_status: n/a`. Live overlay still records the real `ci-gate` fact. Do not push a post-PR metadata commit. |
| CI pass (`ci-gate` green) | `awaiting_merge` | Record live `ci_status: passed` from GitHub Checks into `.agent/runtime.json`. Do **not** have Actions write git. Do not push a bookkeeping commit. Durable record at archive. |
| CI fail (`ci-gate` red) | stay `ci_running` | Record live `ci_status: failed` from GitHub Checks into `.agent/runtime.json`. Actions do not write `state.json`. Never `awaiting_merge`. |
| CI fail, in-scope retry push | stay `ci_running` | `ci_status: running` |
| CI fail, out-of-scope fix | `coding` | `ci_status: failed`; then report → `in_review` (do not increment `review_round` here; increment only on Review reject) |
| Human merge + D-001 archive | `completed` | `last_completed_task`, `active_task` next or `null`; durable `pr_url` / `ci_status` from **live** GitHub Checks (N-002); `plan_approved: false` |

---

## 3. Task 创建流程 (specified)

Planner creates a task file from the template, then places it in the active queue.

```
ChatGPT / Human (Planner)
        ↓
TASK.md  (from .agent/tasks/TASK_TEMPLATE.md)
        ↓
.agent/tasks/active/
```

Steps:

1. Planner copies `.agent/tasks/TASK_TEMPLATE.md`.
2. Fills `task_id`, `scope`, `goal`, `requirements`, `constraints`, `validation`, `branch`, `ci_required`, and V1 fields still on the template (`Agent Role`, `Result`).
3. Saves as `.agent/tasks/active/TASK-XXX-short-name.md`.
4. Updates `.agent/state.json`:
   - `active_task` → `TASK-XXX`
   - `status` → `specified`
   - `review_round` → `0`
   - `pr_url` → `null`
   - `ci_status` → `not_started`
   - `ci_required` → from the TASK file (`yes` → `true`)
   - `plan_approved` → `false`
   - `queue` if a task is already active
   - `agents.chatgpt.status` → `idle` (or `planning` while drafting)

`branch` on the TASK file is the intended name: `task/TASK-XXX-short-name`. Creating the git branch is **not** required at `specified`.

---

## 4. Agent 执行流程 (coding)

Coding Agent picks up the active task **after Gate 1**, implements it, and writes a report.

```
.active/
   ↓ Implementation Plan + STOP (status remains specified)
   ↓ Human/Planner Gate 1 APPROVED (machine-readable) → plan_approved=true
   ↓ start-coding.ps1   ← PRIMARY enforcement
   ↓
Coding Agent 执行
   ↓
生成 report + .agent/handoff.md
   ↓
status → in_review
```

Steps:

1. Coding Agent reads `.agent/state.json` and the task under `.agent/tasks/active/`.
2. If `plan_approved` is not true: write Implementation Plan if needed, then **STOP**. Do not create the implementation branch. Do not modify implementation files. Do not infer approval from chat.
3. After Human/Planner machine-readable Gate 1 APPROVED: persist `plan_approved=true` only from that evidence; run `scripts/workflow/start-coding.ps1` (PRIMARY). Sets `status` → `coding` and `agents.cursor.status` → `working`. Create `task/TASK-XXX-short-name` during coding.
4. Implements according to Requirements and Constraints. Does not self-review. Does not simulate Review Agent (D-003).
5. Writes `.agent/reports/TASK-XXX-report.md` from `.agent/reports/REPORT_TEMPLATE.md`.
6. Leaves the task file in `active/` until the task is `completed` or `cancelled`.
7. Sets `status` → `in_review`, `review_round` to `1` if it was `0`, `agents.cursor.status` → `idle`. Writes handoff `next_actor=review-agent`, `next_action=independent-review`.
8. Stops and waits for an **independent** Review Agent session (Human New Chat / `@handoff` is acceptable in V2.1). Automatic Review spawn is V3 / out of scope.

Commits on `task/*` during coding are allowed (see `git-pr.md`). Opening a PR is not allowed until `git_ready`.

`open-pr.ps1` also asserts `plan_approved`; that check is defense-in-depth only and does not replace `start-coding.ps1`.

---

## 5. Review 流程 (in_review)

After coding, a **separate Cursor session** acting as Review Agent checks the report and changes.

```
Coding 完成
   ↓
Review Agent (independent session)
   ↓
approve → git_ready
reject  → coding  (review_round += 1)
```

Steps:

1. Review Agent reads the TASK, the coding report, and the relevant diff.
2. Validates against the TASK Validation section.
3. Writes `.agent/reviews/TASK-XXX-review-round-N.md` from `.agent/reviews/REVIEW_TEMPLATE.md` (`N` = current `review_round`).
4. Outcome:
   - **approve** → `status` → `git_ready`. Write handoff `next_actor=coding-agent`, `next_action=open-pr-observe`. Coding Agent in the **same** implementation session (or via `@handoff`) follows `git-pr.md` without a new Human-authored Git Ready prompt.
   - **reject** → record blocking issues and required fixes; `status` → `coding`; `review_round` += 1. `plan_approved` stays `true` (do not re-run Gate 1). Coding Agent returns to section 4.

Review Agent must not implement the fix. Coding Agent must not write the review file for its own TASK. Do not use a subagent in the Coding session as a substitute Review Agent (D-003).

---

## 6. Git / PR (git_ready)

Only after Review **approve**.

See `.agent/workflows/git-pr.md`.

Summary:

- Branch: `task/TASK-XXX-short-name`
- Coding Agent may commit on `task/*`
- Coding Agent and Review Agent must not commit or push `main`
- PR must link TASK, report, and the approving review
- Coding Agent opens the PR with `scripts/workflow/open-pr.ps1` after approve (not Human copy-paste). `open-pr` refuses unless `plan_approved` is true (defense-in-depth).
- Then: if `ci_required: yes` → `ci_running`; if `ci_required: no` → `awaiting_merge` with `ci_status: n/a`
- Live Checks overlay: `scripts/workflow/observe-ci.ps1 -Wait` → `.agent/runtime.json`
- Same session may then `wait-for-merge.ps1` until GitHub `MERGED` or timeout (do not forge MERGED)

---

## 7. CI Gate

See `.agent/workflows/ci-gate.md` (authoritative for CI-required vs not, failure recovery, `n/a`, and Checks-as-SoT).

GitHub Actions / GitHub Checks (`ci-gate`) are the CI **runtime** source of truth. `.agent/runtime.json` (gitignored) is the live protocol overlay. `.agent/state.json` is intent plus durable record and may lag. Actions must not commit `state.json`.

CI-required:

```
git_ready → ci_running → awaiting_merge   (pass only)
```

CI-not-required:

```
git_ready → awaiting_merge   (ci_status: n/a)
```

CI failure: never `awaiting_merge`. Recover via in-scope retry, `ci_running` → `coding`, or Human `blocked` / `cancelled`.

---

## 8. Human merge and 完成流程 (awaiting_merge → completed)

Only Human merges `main` (Gate 2). CI green is not merge permission. There is no merge script. `gh pr merge` is forbidden.

After Human merge, Coding/scripts detect `MERGED` via `wait-for-merge.ps1` (Human need not transcribe). Then:

1. `finalize-prep.ps1` on synced `main` (does not push). Re-query GitHub Checks before durable `ci_status: passed` (N-002). Do not trust stale `runtime.json`.
2. D-001 `archive-push.ps1` may commit + push `main` **only** after **independent** verification of all of:
   - authoritative GitHub PR state is `MERGED`
   - current branch is `main`
   - local `main` == `origin/main`
   - working tree / pre-existing state is valid
   - diff is strictly within the D-001 allowlist
   - required CI state is verified from live GitHub Checks
   - finalize-prep requirements are satisfied
   - no `apps/**`, `agents/**`, `.github/workflows/**` or other non-allowlisted changes
   - no force push
   - no `gh pr merge`
3. `AGENT_D001_ARCHIVE=1` is an internal capability marker for that controlled path. It **alone does not authorize** `git push` to `main`. `archive-push` must not short-circuit on the env var.
4. Allowlist (git paths only) for the **current TASK id** — not other `TASK-*.md` files:
   - that TASK's `.agent/tasks/active/TASK-<id>-*.md` moved to `.agent/tasks/completed/`
   - `.agent/state.json` durable archive fields
   - Status / Result fields inside that same TASK file (after the move)
   - Stage and validate those exact paths only. Do not `git add` entire `active/` or `completed/` directories.
5. Normal direct push-to-`main` remains prohibited outside this exception.
6. Update `.agent/state.json`:
   - `status` → `completed`
   - `last_completed_task` → `TASK-XXX`
   - `active_task` → next task or `null`
   - `plan_approved` → `false`
   - durable `pr_url` / `ci_status`
   - agents idle; `updated_at` now

V1 archived immediately after review approve. V2 does **not**. Archive only after Human merge.

Live session bridge: gitignored `.agent/handoff.md` (`next_actor` / `next_action`). Template: `.agent/handoff.TEMPLATE.md`. Permissions: `.agent/workflows/permissions.md`.

---

## 9. Path Reference

| Role | Path |
|------|------|
| Active tasks | `.agent/tasks/active/` |
| Completed tasks | `.agent/tasks/completed/` |
| Reports | `.agent/reports/` |
| Reviews | `.agent/reviews/` |
| Workflows | `.agent/workflows/` |
| Role files | `.agent/agents/` |
| Shared state | `.agent/state.json` |

---

## 10. TASK-003 (V1) changelog — do not treat as current procedure

V1 (lifecycle 1.0, commit `fb2b9ce`) defined four prose stages: create → execute → review → complete (archive on approve).

Kept from V1:

- Planner writes TASK files under `.agent/tasks/active/`
- Coding Agent writes `.agent/reports/TASK-XXX-report.md`
- Task remains in `active/` until the completion flow
- `state.json` keys `active_task`, `last_completed_task`, `queue`, `agents.chatgpt`, `agents.cursor`, and the original `paths`

Changed in V2:

- Explicit state machine including `git_ready`, `ci_running`, `awaiting_merge`, `blocked`, `cancelled`
- Review reject is a first-class loop: `in_review` → `coding` with `review_round`
- Review Agent is a required independent session and a `state.agents.review` entry
- Completion is Human merge, not review approve
- Git / PR / CI gates are mandatory protocol (CI workflow: TASK-005C-B, `.github/workflows/ci.yml`)
- V2.1 (TASK-005B review round 2): `ci_required` split; CI failure recovery; `n/a` is a defined path into `awaiting_merge`, not a dead field
- V2.2 (TASK-005C-B): GitHub Checks are CI runtime SoT; no Actions git writes; no post-PR `state.json` metadata commit; Human exception `ci-gate.md` §2.3 retired
- V2.3 (TASK-005C-C): Coding Agent observes Checks via `scripts/workflow/*` into gitignored `.agent/runtime.json`; `git_ready` → `ci_running` → `awaiting_merge` is live overlay, not an Actions git write; leftover `ci_running` Human `n/a` exception wording removed (N-001)
- V2.4 (TASK-005C-D): Gate 1 `plan_approved` (Human/Planner sole authority; `start-coding.ps1` PRIMARY enforcement); gitignored `.agent/handoff.md`; `observe-ci -Wait` / `wait-for-merge`; D-001 post-merge archive exception (`archive-push.ps1` independent checks; `AGENT_D001_ARCHIVE=1` is not authorization); N-002 live Checks at archive; project hook denies `gh pr merge` / unauthorized push `main`. Branch Protection remains TASK-005C-E. Independent Review spawn remains V3.
