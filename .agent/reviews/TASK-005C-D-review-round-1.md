# TASK-005C-D Independent Review — Round 1

Copied from `.agent/reviews/REVIEW_TEMPLATE.md`.
`N` matches `.agent/state.json` `review_round` (1) at the time of this review.

Review Agent is an independent Cursor session. Coding Agent did not fill this file.
This session did not participate in TASK-005C-D implementation and did not use the Coding Agent transcript as evidence.

---

## Task ID

`TASK-005C-D`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent (Round 1). Not the Coding Agent session.

## Review Round

Field: `review_round`

`1`

## Review Scope

Field: `review_scope`

- Independent Review Round 1 of uncommitted TASK-005C-D working-tree changes on `task/TASK-005C-D-workflow-hardening`.
- Compared against the active TASK, Coding report, Workflow V2.4 (`task-lifecycle.md`, `git-pr.md`, `ci-gate.md`, `permissions.md`), role files, D-001 / D-002 / D-003 / N-002, and the complete `main...HEAD` + working-tree / untracked diff.
- Guardrails were re-run in this session (`89/89`). That result is **not** GitHub CI and does **not** override the D-001 defects below.
- This session writes this review, `state.json` (`in_review` → `coding`, `review_round` 1 → 2), and gitignored `.agent/handoff.md`. No implementation edit, no commit, no push, no PR, no merge, no archive, no TASK-005C-E.

## Decision

Field: `decision`

`reject`

- `reject` → `status` becomes `coding` and `review_round` increases by 1

Rejected transition: `in_review` → `coding` (`review_round: 2`). `plan_approved` stays `true` (do not re-run Gate 1).

**TASK-005C-D is not allowed to enter Git Ready.**

## Blocking Issues

Field: `blocking_issues`

- **B-001** — D-001 `Assert-D001ArchivePreconditions` treats *any* GitHub `MERGED` PR number as authorization to archive the *current* TASK, then `archive-push.ps1` can `git push origin main`. The live PR is not bound to `state.active_task` / `runtime.task_id` / PR `headRefName`.
- **B-002** — `archive-push.ps1` is not recoverable after `git commit` succeeds and `git push origin main` fails: retry refuses as unsynced (`HEAD != origin/main`) and/or as empty diff. The only legal D-001 push path cannot finish its own commit.
- **B-003** — D-001 allowlist is TASK-class, not TASK-id, and `archive-push.ps1` `git add`s entire `.agent/tasks/active` and `.agent/tasks/completed`. Foreign `TASK-*.md` files are accepted and can be pushed to `main`.

## Non-blocking Issues

Field: `non_blocking_issues`

- **N-001** — Requirement 11 asks for executable D-001 refuses of unmerged PRs and unsynced `main`. The suite only source-matches `MERGED` / `mergedAt`. Must not remain the only coverage after B-001/B-002/B-003 are fixed.
- **N-002** — `Test-GitignoreHandoff` pipes `git check-ignore` to `Out-Null`, which can clobber `$LASTEXITCODE` on Windows PowerShell 5.1. `Test-GitignoreRuntime` does not. Reliability gap only; `.gitignore` itself is correct.
- **N-003** — Project hook does not detect `git push origin +main` or `git push origin refs/heads/main`. Hook is defense in depth; scripts remain primary. Tighten if touching the hook.
- **N-004** — `wait-for-merge.ps1` copies stale `runtime.ci_gate` / `protocol_ci_status` into the MERGED overlay instead of re-querying Checks. Archive path (N-002 live Checks) is the durable control; overlay can lag.
- **N-005** — `Update-ArchivedTaskFile` does not rewrite a TASK Status line of `` `ci_running` ``. This TASK is `ci_required: no`. Fix with archive status handling if touching that function.
- **N-006** — `Save-StateObject` / `ConvertTo-Json` may rewrite `state.json` key order, whitespace, and UTF-8 BOM (Coding report already noted this). Does not push by itself.
- **N-007** — `start-coding.ps1` is not invoked against a `plan_approved=false` fixture (live workspace is `true` / `in_review`). `Assert-PlanApproved` is unit-tested. Add a script-level false fixture when recoupling tests.

Round-1 N items must not be used as a substitute for fixing B-001–B-003.

## Required Fixes

Field: `required_fixes`

Required because `decision` is `reject`. Coding Agent must address these in the next `coding` round. Review Agent will not implement them.

1. **Bind D-001 GitHub `MERGED` to this TASK before any archive commit or `git push origin main`.** In `Assert-D001ArchivePreconditions` (and therefore both `finalize-prep.ps1` and `archive-push.ps1`): refuse unless the PR used for `Confirm-PrMergedLive` is the active TASK's PR. Minimum: `runtime.task_id` must equal `state.active_task` (or `last_completed_task` only after this TASK's own finalize), **and** live `headRefName` / PR identity must match the TASK `branch` field (or otherwise uniquely identify `TASK-005C-D`, not a previously merged PR). `Get-LivePrView` already fetches `headRefName` and currently ignores it for authorization.
2. **Make `archive-push.ps1` recover from commit-without-push.** After independent D-001 checks: if working tree is clean and `main` is ahead of `origin/main` only by allowlisted archive commit(s) for this TASK, push that commit. Do not classify that state as "unsynced, refuse" or "no archive diff". Do not force-push. Do not treat `AGENT_D001_ARCHIVE=1` as authorization.
3. **Tighten the D-001 allowlist to this TASK id only.** `Test-D001AllowlistedPath` / `Assert-D001DiffAllowlisted` must reject other `TASK-*.md` files. `archive-push.ps1` must `git add` only `.agent/state.json` and the specific TASK file being moved/updated — not the entire `active/` and `completed/` directories.
4. **Add executable guardrail tests** (not source-only matches) for: unmerged PR refuse; unsynced `main` refuse (true diverge / behind, not the legal ahead-archive case); PR/task mismatch refuse; foreign TASK path refuse; commit-ahead D-001 retry/push path. Keep `89/89` from becoming a weaker suite.

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [x] Directory / files exist as specified
- [x] Tests pass (if applicable) — `scripts/workflow/test-guardrails.ps1` **89/89** this session. **Not** a GitHub Actions PASS. **Not** sufficient for approve: D-001 authorization holes are untested (N-001).
- [x] Report written under `.agent/reports/`
- [x] Scope respected (no forbidden paths)
- [ ] Git / PR / CI protocol respected for this phase — D-001 independent authorization is incomplete (B-001–B-003). Gate 1 PRIMARY, D-003, N-002 mapping, merge/main/open-pr restrictions otherwise hold. No PR / merge / archive in this phase.

Notes:

- Independent Review file for round 1 is this file (`decision: reject`).
- Coding Agent must not write a review file for its own TASK (D-003).
- This TASK is `ci_required: no`. After a future `git_ready` + PR, protocol `ci_status` is `n/a`; `observe-ci.ps1` must still record the real `ci-gate` fact.

---

## 1. Executive Summary

Independent Review Round 1 of uncommitted TASK-005C-D (Workflow Hardening & Human Interaction Reduction).

Gate 1 (`plan_approved`, `start-coding.ps1` PRIMARY, `open-pr.ps1` defense-in-depth), D-003 (no self-review artifacts), N-002 live Checks at archive for `ci_required: yes`, `observe-ci -Wait` / `wait-for-merge` non-forge behavior, merge/main/open-pr restrictions, and scope boundaries (`apps/`, `agents/`, `.github/workflows/ci.yml`, no TASK-005C-E) **hold**.

D-001 does **not** hold. `archive-push.ps1` can push `main` after checks that (1) accept a previously merged PR as proof this TASK was merged, (2) cannot retry a local archive commit whose push failed, and (3) allow any `TASK-*.md` under active/completed, then `git add` those whole directories.

Local guardrails **89/89** were reproduced and do not cover B-001–B-003.

**Decision: REJECT.** TASK-005C-D is not allowed to enter Git Ready.

---

## 2. Scope Compliance

Repo: `F:/AI_Workspace/personal-ai-ecosystem`  
Branch: `task/TASK-005C-D-workflow-hardening` (matches TASK `branch`)  
HEAD: `9bff6aa` — same as `origin/main` (no TASK commits yet; uncommitted working tree + untracked files)  
Working tree: dirty, unstaged. Not pushed. No PR. `pr_url: null`.

Tracked diff vs `main`: **+843 / −174** across 16 files.  
Untracked (this TASK): `start-coding.ps1`, `wait-for-merge.ps1`, `archive-push.ps1`, `write-handoff.ps1`, `.cursor/hooks*`, `permissions.md`, `handoff.TEMPLATE.md`, TASK, report.

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

`state.json` at review start: `active_task: TASK-005C-D`, `status: in_review`, `review_round: 1`, `plan_approved: true`, `ci_required: false`, `ci_status: not_started`, `pr_url: null`.

No file was classified as premature TASK-005C-E or `apps/`/`agents/`/`ci.yml` scope creep. `.cursor/hooks.json` + `deny-forbidden-git.ps1` are in-scope (requirement 9). `planner.md` / `TASK_TEMPLATE.md` updates are justified protocol.

---

## 3. Architecture / Locked-Decision Verification

| Invariant | Verdict |
|-----------|---------|
| D-002 Gate 1: Human/Planner sole authority; Coding must not infer | **Hold** (protocol + `Assert-PlanApproved`; `start-coding.ps1` PRIMARY) |
| Gate 1 PRIMARY = `start-coding.ps1`; `open-pr.ps1` defense-in-depth only | **Hold** |
| D-003 Independent Review; Coding cannot self-review | **Hold** (this file; Coding report `pending`; no Coding-written `.agent/reviews/TASK-005C-D-*`) |
| N-002 durable `passed` from live Checks, not stale `runtime.json` | **Hold** (`Get-DurableCiStatusFromLiveChecks`; `ci_required: no` → `n/a`, not `passed`) |
| `observe-ci -Wait` timeout does not forge passed/failed | **Hold** |
| `wait-for-merge` timeout does not forge `MERGED` | **Hold** |
| No `gh pr merge` / no `merge.ps1` / no force push | **Hold** |
| D-001: `AGENT_D001_ARCHIVE=1` is not authorization | **Hold** (preconditions never read the marker; marker set after checks) |
| D-001: independent verification of *this* TASK's MERGED PR + allowlist | **Fail** (B-001, B-003) |
| D-001: no uncontrolled / unrecoverable push-`main` path | **Fail** (B-002) |

---

## 4. Gate 1

`start-coding.ps1` calls `Assert-PlanApproved` before setting `status=coding`. Legal statuses are `specified` or `coding` (idempotent). Current `in_review` DryRun refuses on status (reproduced). `open-pr.ps1` also calls `Assert-PlanApproved` and comments defense-in-depth. Protocol documents Human/Planner as sole authority; Coding mechanical write of the boolean is distinct.

`plan_approved: true` on the live `state.json` is accepted as Human/Planner Gate 1 for *this* TASK (TASK Result + review request). Review is not Gate 1.

---

## 5. D-001 Findings (blocking)

### B-001 — MERGED PR is not bound to the active TASK

`scripts/workflow/lib.ps1` `Assert-D001ArchivePreconditions`:

- Resolves `PrNumber` from `runtime.pr_number` when not passed.
- Does not require `runtime.task_id == state.active_task`.
- Calls `Confirm-PrMergedLive`, which only checks `state == MERGED` and `mergedAt`.
- `Get-LivePrView` fetches `headRefName` and the preconditions never compare it to the TASK `branch` field.

Review-time check: preconditions function text `mentions runtime.task_id: False`, `mentions headRefName: False`. `Confirm-PrMergedLive` has no Task parameter.

Because `archive-push.ps1` pushes `origin main` after these checks, a leftover gitignored `.agent/runtime.json` from TASK-005C-C (PR #3, already `MERGED`) plus allowlisted dirty files for TASK-005C-D is enough to archive the wrong TASK and push `main`. D-001 item 1 is "the PR" for this TASK, not any historical MERGED PR.

### B-002 — commit-then-failed-push is a dead end

`archive-push.ps1` order: `Assert-D001ArchivePreconditions` (requires `HEAD == origin/main`) → `git commit` → `git push origin main`.

If push fails:

- Local `main` is ahead of `origin/main`.
- Retry calls `Confirm-MainSyncedWithOrigin` → throws unsynced.
- If that were bypassed, empty working tree hits `no archive diff to commit`.
- Review-time: `handles unpushed/ahead: False`.

Normal `git push origin main` remains forbidden. Marker-only push remains unauthorized. Human *may* push `main`, which reintroduces a Human courier on the failure path this TASK was meant to automate. The script that is the sole D-001 exception cannot complete its own commit.

### B-003 — allowlist + `git add` are wider than D-001

D-001 allowlist is: this TASK file's move, `.agent/state.json`, and Status/Result on that same file.

Review-time: `Test-D001AllowlistedPath` returned **True** for `.agent/tasks/completed/TASK-OTHER-unrelated.md` and `.agent/tasks/active/TASK-ZZZ-not-this-task.md`. `Assert-D001DiffAllowlisted` **accepted** a mixed foreign-TASK path set.

`archive-push.ps1` then runs `git add -- .agent/state.json .agent/tasks/active .agent/tasks/completed`, which can stage those extra files. Cached allowlist re-check will still pass.

---

## 6. Independent Review / D-003

Coding did not write `.agent/reviews/TASK-005C-D-*`. Report `Review Status: pending`. Handoff asked for a separate session. This session is that session. Automatic Review spawn was not implemented. **Hold.**

---

## 7. N-002 / live CI truth

`Get-DurableCiStatusFromLiveChecks` re-queries `gh pr checks`. `ci_required: yes` + non-success throws (pending/unknown stay fail-closed via `Get-CiGateFact` default `pending`). `ci_required: no` writes durable `n/a`, not `passed`, even if `ci-gate` is green. `observe-ci -Wait` timeout breaks with `ci_gate=pending` and writes that fact. Mapping tests passed in this session. **Hold.** Residual: N-004 overlay copy after merge.

---

## 8. Git / PR / merge guardrails

| Control | Evidence |
|---------|----------|
| No `merge.ps1` | absent |
| No `gh pr merge` in scripts | surface scan 89/89; `Invoke-Gh` → `Assert-MergeForbidden` |
| Force push | `archive-push` has no `--force`; hook denies force even with marker |
| `open-pr` | `task/*` + Review `approve` + `plan_approved` + status `git_ready`/`ci_running`/`awaiting_merge`; pushes `HEAD` only after `Assert-TaskBranch` |
| `finalize-prep` | no `git push`; refuses `task/*` (DryRun this session) |
| Unauthorized push `main` | only `archive-push.ps1`; marker after checks — **but** B-001/B-003 make that path over-broad |

---

## 9. Tests

Re-run this session (not trusted from the Coding report):

```
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1
Passed=89 Failed=0
```

Focused review-time validation (temporary script, deleted; did not modify implementation):

- Foreign TASK paths allowlisted: **True**
- Preconditions bind `runtime.task_id` / `headRefName`: **False**
- `archive-push` handles unpushed/ahead: **False**

`89/89` does not test B-001–B-003. Required fix 4.

---

## 10. Blocking Issues

B-001, B-002, B-003 as above. Cause `reject`.

---

## 11. Non-blocking Issues

N-001 through N-007 as above. Must not cause reject by themselves. Must not be ignored if Coding is already editing the same functions.

---

## 12. Review Decision

**REJECT**

TASK-005C-D is **not** allowed to enter **Git Ready**.

`plan_approved` remains `true`. Do not re-run Gate 1.

---

## Required Next Action

Coding Agent (same implementation session or via `@handoff`) applies `required_fixes`, updates the report, sets `in_review` again, and writes handoff `next_actor=review-agent` `next_action=independent-review`.

1. Stay on `task/TASK-005C-D-workflow-hardening`.
2. Do not implement from this Review session.
3. Do not commit or push unless/until Human asks after a later **approve**.
4. Do not open a PR. Do not `gh pr merge`. Do not push `main`. Do not force push.
5. Do not start TASK-005C-E.
6. Independent Review Round 2 must be a **separate** session (D-003).

This Review Agent session stops here.
