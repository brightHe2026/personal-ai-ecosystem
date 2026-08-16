# TASK-005C-D Independent Review — Round 2

Copied from `.agent/reviews/REVIEW_TEMPLATE.md`.
`N` matches `.agent/state.json` `review_round` (2) at the time of this review.

Review Agent is an independent Cursor session. Coding Agent did not fill this file.
This session did not participate in TASK-005C-D implementation and did not use the Coding Agent transcript as evidence.

---

## Task ID

`TASK-005C-D`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent (Round 2). Not the Coding Agent session.

## Review Round

Field: `review_round`

`2`

## Review Scope

Field: `review_scope`

- Independent Review Round 2 of uncommitted TASK-005C-D working-tree changes on `task/TASK-005C-D-workflow-hardening`.
- Primary objective: independently prove or disprove that Round-1 blocking defects **B-001**, **B-002**, and **B-003** are actually fixed, without leftover-runtime bypasses, a generic clean-tree push-`main` path, or directory-wide TASK allowlisting.
- Compared against the active TASK, updated Coding report, Round-1 review, Workflow V2.4 (`task-lifecycle.md`, `git-pr.md`, `ci-gate.md`, `permissions.md`), role files, D-001 / D-002 / D-003 / N-002, and the complete `main...HEAD` + working-tree / untracked diff.
- Guardrails were re-run in this session (`123/123`). Additional adversarial cases were executed against the live helper functions. That result is **not** GitHub CI.
- This session writes this review, `state.json` (`in_review` → `git_ready`), and gitignored `.agent/handoff.md`. No implementation edit, no commit, no push, no PR, no merge, no archive, no TASK-005C-E.

## Decision

Field: `decision`

`approve`

- `approve` → `status` becomes `git_ready`

Approved transition: `in_review` → `git_ready`. `plan_approved` stays `true` (do not re-run Gate 1). `review_round` stays `2`.

**TASK-005C-D may enter Git Ready.** The same Coding session continues `open-pr.ps1` → `observe-ci.ps1 -Wait` without a new Human Git Ready prompt.

## Blocking Issues

Field: `blocking_issues`

None.

## Non-blocking Issues

Field: `non_blocking_issues`

Round-1 N-001 (unmerged / unsynced coverage) is addressed by executable tests and is closed.

Still open from Round 1; must not block `git_ready`:

- **N-002** — `Test-GitignoreHandoff` still pipes `git check-ignore` to `Out-Null` (Windows PowerShell 5.1 `$LASTEXITCODE` clobber). `Test-GitignoreRuntime` does not. Reliability gap only; `.gitignore` itself is correct.
- **N-003** — Project hook still does not detect `git push origin +main` or `git push origin refs/heads/main`. Hook is defense in depth; scripts remain primary.
- **N-004** — `wait-for-merge.ps1` still copies stale `runtime.ci_gate` / `protocol_ci_status` into the MERGED overlay. Archive path (N-002 live Checks) remains the durable control.
- **N-005** — `Update-ArchivedTaskFile` still does not rewrite a TASK Status line of `` `ci_running` ``. This TASK is `ci_required: no`.
- **N-006** — `Save-StateObject` / `ConvertTo-Json` may rewrite `state.json` key order, whitespace, and UTF-8 BOM. Does not push by itself.
- **N-007** — `start-coding.ps1` is still not invoked against a `plan_approved=false` fixture. `Assert-PlanApproved` remains unit-tested.

New residuals observed this round (non-blocking):

- **N-008** — Official B-002 tests exercise `Assert-AuthorizedUnpushedArchiveFacts` with constructed ahead/behind/parent/path facts. They do not create a real git fixture for `Get-AuthorizedUnpushedD001Commit`. The wrapper is a thin `rev-list` / `diff-tree` collector around the tested predicate. Source order still requires PR/task binding before retry detection.
- **N-009** — `finalize-prep.ps1` ignores `Mode=retry`. Re-running finalize-prep after a successful archive commit and failed push can dirty the tree and then fail the clean-tree retry. Recovery is **re-run `archive-push.ps1` only**, not the full finalize-prep + archive-push sequence.

## Required Fixes

Field: `required_fixes`

None. `decision` is `approve`.

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [x] Directory / files exist as specified
- [x] Tests pass (if applicable) — `scripts/workflow/test-guardrails.ps1` **123/123** this session. **Not** a GitHub Actions PASS. Protocol `ci_status` after PR remains `n/a` because `ci_required: no`.
- [x] Report written under `.agent/reports/`
- [x] Scope respected (no forbidden paths)
- [x] Git / PR / CI protocol respected for this phase — D-001 independent authorization now binds the live MERGED PR to this TASK, retries only the authorized unpushed archive commit, and stages exact TASK paths. Gate 1 PRIMARY, D-003, N-002 mapping, merge/main/open-pr restrictions hold. No PR / merge / archive in this phase.

Notes:

- Independent Review file for round 2 is this file (`decision: approve`).
- Coding Agent must not write a review file for its own TASK (D-003).
- This TASK is `ci_required: no`. After `git_ready` + PR, protocol `ci_status` is `n/a`; `observe-ci.ps1` must still record the real `ci-gate` fact.

---

## 1. Executive Summary

Independent Review Round 2 of uncommitted TASK-005C-D (Workflow Hardening & Human Interaction Reduction).

Round-1 blocking defects are **fixed** in the implementation, not only in the report:

| Defect | Round-2 verdict |
|--------|-----------------|
| **B-001** leftover / unrelated MERGED PR authorizes this TASK's archive | **Fixed.** `Assert-D001TaskPrBinding` requires runtime overlay bound to this TASK (`task_id` + `pr_number`), live `MERGED`+`mergedAt`, live PR number matching runtime, and `headRefName` equal to this TASK's `branch` field. |
| **B-002** commit-then-failed-push is a dead end, or becomes a generic push-`main` | **Fixed.** Retry is exactly one clean unpushed commit whose parent, subject, and paths are this TASK's archive. Synced clean tree is not a retry. Ordinary commits are refused. PR/task binding still runs first. |
| **B-003** TASK-class allowlist + directory `git add` | **Fixed.** Allowlist is exact current TASK id. `archive-push.ps1` `git add`s `Get-D001ExactArchivePaths` only and refuses extra staged paths. |

Gate 1 (`plan_approved`, `start-coding.ps1` PRIMARY, `open-pr.ps1` defense-in-depth), D-003, N-002 live Checks at archive, `observe-ci -Wait` / `wait-for-merge` non-forge behavior, merge/main restrictions, and scope boundaries hold.

Local guardrails **123/123** were reproduced in this session. Adversarial cases beyond the suite (missing `runtime.task_id` / `pr_number`, stale live PR number, empty `headRefName` / `mergedAt`, CLOSED-with-`mergedAt`, D runtime pointing at C's MERGED PR, foreign subject, extra `apps/` path, ordinary commit as retry, ahead-by-3, literal `TASK-*.md`) also fail closed.

**Decision: APPROVE.** TASK-005C-D may enter **Git Ready**.

---

## 2. Scope Compliance

Repo: `F:/AI_Workspace/personal-ai-ecosystem`  
Branch: `task/TASK-005C-D-workflow-hardening` (matches TASK `branch`)  
HEAD: `9bff6aa` — same as `origin/main` (no TASK commits yet; uncommitted working tree + untracked files)  
Working tree: dirty, unstaged. Not pushed. No PR. `pr_url: null`. No `.agent/runtime.json` overlay present.

Tracked diff vs `main`: **+1251 / −175** across 16 files.  
Untracked (this TASK): `start-coding.ps1`, `wait-for-merge.ps1`, `archive-push.ps1`, `write-handoff.ps1`, `.cursor/hooks*`, `permissions.md`, `handoff.TEMPLATE.md`, TASK, report, Round-1 review.

Hard boundaries held:

| Boundary | Result |
|----------|--------|
| `apps/` / `agents/` business code | `git diff --name-only main -- apps agents` empty |
| `.github/workflows/ci.yml` | unchanged vs `main`; `permissions.contents: read`; no `contents: write`; no git write |
| `.env` / secrets | not modified |
| Branch Protection / TASK-005C-E | not enabled / not started |
| Auto-merge / `merge.ps1` / `gh pr merge` | absent; `Assert-MergeForbidden`; hook denies `gh pr merge` |
| `.agent/reviews/` by Coding | no Coding-written review for this TASK |
| V3 Review auto-spawn | not implemented |

`state.json` at review start: `active_task: TASK-005C-D`, `status: in_review`, `review_round: 2`, `plan_approved: true`, `ci_required: false`, `ci_status: not_started`, `pr_url: null`.

No file was classified as premature TASK-005C-E or `apps/`/`agents/`/`ci.yml` scope creep.

---

## 3. Architecture / Locked-Decision Verification

| Invariant | Verdict |
|-----------|---------|
| D-002 Gate 1: Human/Planner sole authority; Coding must not infer | **Hold** |
| Gate 1 PRIMARY = `start-coding.ps1`; `open-pr.ps1` defense-in-depth only | **Hold** |
| D-003 Independent Review; Coding cannot self-review | **Hold** (this file; Coding report `pending`; no Coding-written `.agent/reviews/TASK-005C-D-*` except the required independent files) |
| N-002 durable `passed` from live Checks, not stale `runtime.json` | **Hold** (`Get-DurableCiStatusFromLiveChecks`; `ci_required: no` → `n/a`, not `passed`) |
| `observe-ci -Wait` timeout does not forge passed/failed | **Hold** |
| `wait-for-merge` timeout does not forge `MERGED` | **Hold** |
| No `gh pr merge` / no `merge.ps1` / no force push | **Hold** |
| D-001: `AGENT_D001_ARCHIVE=1` is not authorization | **Hold** (preconditions never read the marker; marker set after checks) |
| D-001: independent verification of *this* TASK's MERGED PR + allowlist | **Hold** (B-001, B-003 fixed) |
| D-001: no uncontrolled / unrecoverable push-`main` path | **Hold** (B-002 fixed; retry is not a generic clean-tree push) |

---

## 4. Gate 1

`start-coding.ps1` calls `Assert-PlanApproved` before setting `status=coding`. Legal statuses are `specified` or `coding` (idempotent). Current `in_review` DryRun refuses on status (suite reproduced). `open-pr.ps1` also calls `Assert-PlanApproved` and comments defense-in-depth. Protocol documents Human/Planner as sole authority.

`plan_approved: true` on the live `state.json` is accepted as Human/Planner Gate 1 for *this* TASK. Review is not Gate 1. Approve does not re-run Gate 1.

---

## 5. D-001 Round-2 Verification

### B-001 — PR/task binding (fixed)

`Assert-D001ArchivePreconditions` now:

1. Resolves TASK id from `state.active_task`, or `last_completed_task` only when `status=completed` and `active_task` is empty.
2. Reads expected `headRefName` from this TASK file's `branch` field (`Get-TaskExpectedBranch`).
3. Requires a runtime overlay (`Read-RuntimeObject`); missing overlay is ambiguous and refused.
4. Calls live `Confirm-PrMergedLive` then `Assert-D001TaskPrBinding`.

Independent fail-closed cases (suite + this session):

| Case | Result |
|------|--------|
| Unrelated leftover TASK-005C-C runtime (`task_id` mismatch) | refused (`PR/task mismatch`) |
| Missing runtime overlay | refused (`ambiguous PR evidence`) |
| Missing `runtime.task_id` with `pr_number` present | refused |
| Missing / zero `runtime.pr_number` | refused |
| Live PR number ≠ runtime PR number (stale / unrelated MERGED PR) | refused |
| Wrong `headRefName` (C branch on a MERGED PR) | refused |
| Empty `headRefName` | refused |
| This-TASK runtime pointing at C's MERGED PR #3 | refused (`headRefName mismatch`) |
| Non-MERGED / OPEN | refused |
| CLOSED even with `mergedAt` set | refused |
| Missing / empty `mergedAt` | refused |
| `last_completed_task` while status is not `completed` | refused |
| Matching runtime + this TASK branch + MERGED+`mergedAt` | accepted |

`Get-LivePrView` is still the GitHub evidence source. `headRefName` is no longer ignored. A leftover gitignored `.agent/runtime.json` from TASK-005C-C cannot authorize TASK-005C-D.

Retry / archive-push cannot skip this binding: `Assert-D001TaskPrBinding` runs inside preconditions **before** `Get-AuthorizedUnpushedD001Commit`.

### B-002 — commit-success / push-failure recovery (fixed)

`Get-AuthorizedUnpushedD001Commit` + `Assert-AuthorizedUnpushedArchiveFacts` authorize retry only when all of:

- current branch is `main` (`Assert-OnMain` in preconditions);
- local `main` is ahead of `origin/main` by **exactly one** commit;
- behind count is 0 (true diverge/behind refused);
- working tree is clean;
- that commit's parent SHA equals `origin/main`;
- subject equals `chore(agent): archive <this TASK id> as completed`;
- commit paths are D-001 allowlisted for **this** TASK and include `.agent/state.json` plus exactly one `completed/<this TASK>-*.md` file.

Independent fail-closed cases:

| Case | Result |
|------|--------|
| Ahead by 2+ | refused |
| Ahead by 3 | refused |
| Diverged / behind | refused |
| Unexpected parent | refused |
| Wrong subject / ordinary `feat:` commit | refused |
| Foreign TASK archive subject | refused |
| Foreign TASK path in the unpushed commit | refused |
| Extra `apps/` path | refused |
| Missing `state.json` | refused |
| This TASK's completed path with another TASK id | refused (subject and/or allowlist) |
| Synced HEAD (ahead=0, behind=0), including clean tree | **not retry** (`false` / `null`) → fresh path, which throws `no archive diff` if clean |
| Dirty + ahead | refused |

`archive-push.ps1` `Mode=retry` only calls `git push origin main` (capability marker after checks, no `--force`). Synced clean tree never enters retry. This is not a general clean-tree push-`main` bypass: an ordinary local commit on `main` fails subject/path checks, and even a crafted archive commit still needs this TASK's live MERGED PR.

### B-003 — exact TASK allowlist (fixed)

`Test-D001AllowlistedPath` / `Assert-D001DiffAllowlisted` require mandatory `TaskId`. Accepted paths are only `.agent/state.json` and `.agent/tasks/{active,completed}/<exact TaskId>-*.md`.

Independent checks:

| Case | Result |
|------|--------|
| `TASK-OTHER-unrelated.md` / `TASK-ZZZ-*.md` | refused |
| Sibling `TASK-005C-C-*.md` under current TASK-005C-D | refused |
| Literal `TASK-*.md` glob string | refused |
| Report / review paths | refused |
| `Get-D001ExactArchivePaths` | exactly three file paths (state + this TASK active + completed); not directories |
| `archive-push.ps1` `git add` | loops those exact paths; no `git add` of entire `active/` / `completed/`; no `git add -A` |
| Already-staged foreign path vs exact set | cached check throws `is not an exact D-001 path` |

Unrelated TASK files cannot ride the archive commit.

---

## 6. Independent Review / D-003

Coding did not write `.agent/reviews/TASK-005C-D-*` except the required independent Round-1 reject (previous Review session) and this Round-2 file. Report `Review Status: pending`. Handoff asked for a separate session. This session is that session. Automatic Review spawn was not implemented. **Hold.**

---

## 7. N-002 / live CI truth

`Get-DurableCiStatusFromLiveChecks` re-queries `gh pr checks`. `ci_required: yes` + non-success throws. `ci_required: no` writes durable `n/a`, not `passed`, even if `ci-gate` is green. `observe-ci -Wait` timeout breaks with `ci_gate=pending` and writes that fact. Mapping tests passed in this session. Preconditions query live Checks **before** retry detection. **Hold.** Residual: N-004 overlay copy after merge.

---

## 8. Git / PR / merge guardrails

| Control | Evidence |
|---------|----------|
| No `merge.ps1` | absent |
| No `gh pr merge` in scripts | surface scan 123/123; `Invoke-Gh` → `Assert-MergeForbidden` |
| Force push | `archive-push` has no `--force`; hook denies force even with marker |
| `open-pr` | `task/*` + Review `approve` + `plan_approved` + status `git_ready`/`ci_running`/`awaiting_merge`; pushes `HEAD` only after `Assert-TaskBranch` |
| `finalize-prep` | no `git push`; refuses `task/*` |
| Unauthorized push `main` | only `archive-push.ps1`; marker after checks; retry is not a generic clean-tree path |

---

## 9. Tests

Re-run this session (not trusted from the Coding report):

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1
Passed=123 Failed=0
```

The new tests call the real authorization functions (`Assert-D001TaskPrBinding`, `Assert-AuthorizedUnpushedArchiveFacts`, `Test-D001AllowlistedPath`, `Get-D001ExactArchivePaths`) with fail-closed fixtures. They are not only source-matches. They do not mock GitHub HTTP; live `gh pr view` remains a production call inside `Confirm-PrMergedLive`, which is still required by preconditions.

Additional adversarial cases in this session (25 function-level asserts): missing runtime identity fields, stale live PR number, empty `headRefName`/`mergedAt`, CLOSED, D runtime + C MERGED PR, broad `TASK-*.md`, extra `apps/` path, ordinary commit as retry, ahead-by-3. All refused except the intended completed-status `last_completed_task` fallback.

N-008: the git-wrapper `Get-AuthorizedUnpushedD001Commit` is not executed against a throwaway repo in the official suite. That does not reopen B-002; the wrapper only feeds git counts/paths/subject into the tested predicate, and preconditions still bind the live PR first.

---

## 10. Blocking Issues

None.

---

## 11. Non-blocking Issues

N-002 through N-007 (carried) and N-008 / N-009 (new residuals). Must not cause reject.

---

## 12. Review Decision

**APPROVE**

TASK-005C-D **may** enter **Git Ready**.

`plan_approved` remains `true`. Do not re-run Gate 1.

---

## Required Next Action

Coding Agent (same implementation session or via `@handoff`) follows the approved post-review flow. This Review session does not commit, push, open a PR, merge, or archive.

1. Stay on `task/TASK-005C-D-workflow-hardening`.
2. Enter `git_ready` (already recorded in `state.json` by this Review session).
3. Commit remaining protocol/code on `task/*` only (Human must ask if a commit is required by session rules; Coding follows `git-pr.md`).
4. Run `scripts/workflow/open-pr.ps1` then `observe-ci.ps1 -Wait`.
5. This TASK is `ci_required: no` → protocol `ci_status: n/a`. Do not impersonate `passed`.
6. Do not `gh pr merge`. Do not push `main` except later D-001 `archive-push.ps1` after Human merge and independent checks.
7. Do not force push.
8. Do not start TASK-005C-E.

This Review Agent session stops here.
