# TASK-005C-D Implementation Report

Copied from `.agent/reports/REPORT_TEMPLATE.md`.

---

## Task ID

`TASK-005C-D`

## Changes

List created, modified, or deleted files:

- Created:
  - `scripts/workflow/start-coding.ps1` (Gate 1 PRIMARY enforcement)
  - `scripts/workflow/wait-for-merge.ps1`
  - `scripts/workflow/archive-push.ps1` (D-001; independent checks; marker is not authorization)
  - `scripts/workflow/write-handoff.ps1`
  - `.agent/workflows/permissions.md`
  - `.agent/handoff.TEMPLATE.md`
  - `.cursor/hooks.json`
  - `.cursor/hooks/deny-forbidden-git.ps1`
  - `.agent/reports/TASK-005C-D-report.md`
- Modified:
  - `.agent/workflows/task-lifecycle.md` (V2.3 → V2.4)
  - `.agent/workflows/git-pr.md` (V1.3 → V1.4)
  - `.agent/workflows/ci-gate.md` (V1.3 → V1.4)
  - `.agent/agents/coding-agent.md`
  - `.agent/agents/review-agent.md`
  - `.agent/agents/planner.md`
  - `.agent/README.md`
  - `.agent/tasks/TASK_TEMPLATE.md`
  - `.agent/tasks/active/TASK-005C-D-workflow-hardening.md`
  - `.agent/state.json` (`git_ready`; `plan_approved: true`; `review_round: 2`; `pr_url: null`)
  - `.gitignore` (`.agent/handoff.md`)
  - `scripts/workflow/lib.ps1` (B-001 task-bound MERGED PR; B-002 authorized unpushed retry facts; B-003 exact TASK-id allowlist)
  - `scripts/workflow/open-pr.ps1` (plan_approved defense-in-depth only)
  - `scripts/workflow/observe-ci.ps1` (`-Wait`; timeout does not forge passed/failed)
  - `scripts/workflow/finalize-prep.ps1` (N-002 live Checks; still no push)
  - `scripts/workflow/status.ps1`
  - `scripts/workflow/archive-push.ps1` (B-001/B-002/B-003)
  - `scripts/workflow/test-guardrails.ps1` (B-001/B-002/B-003 executable fail-closed tests)

Fix Round 2 (Independent Review Round 1 reject — B-001 / B-002 / B-003 only):

- B-001: `Assert-D001TaskPrBinding` requires runtime overlay bound to this TASK (`runtime.task_id`, `runtime.pr_number`), live GitHub `MERGED`+`mergedAt`, and `headRefName` == TASK `branch`. Missing identity, missing runtime, leftover other-TASK PR, headRefName mismatch, and non-MERGED all fail closed. `finalize-prep` / `archive-push` share `Assert-D001ArchivePreconditions`.
- B-002: `Assert-AuthorizedUnpushedArchiveFacts` + `archive-push` `Mode=retry` retries push only when local `main` is ahead of `origin/main` by exactly one commit whose subject, parent, and paths are the authorized D-001 archive for this TASK. Synced clean tree is not a push. Unexpected ahead / diverge / dirty+ahead / wrong subject / foreign paths fail closed. No generic clean-tree push-main.
- B-003: `Test-D001AllowlistedPath` / `Assert-D001DiffAllowlisted` take mandatory `TaskId`. Foreign `TASK-*.md` refused. `Get-D001ExactArchivePaths` + `git add` of those exact paths only (no directory-wide add).
- Deleted:
  - None

Not changed (hard boundary):

- `apps/` and `agents/` application code
- `.github/workflows/ci.yml` (still `contents: read`; no git write)
- no `merge.ps1`; no `gh pr merge`
- no Branch Protection (TASK-005C-E)
- no V3 Review auto-spawn
- `.agent/reviews/` (Independent Review is a separate session, D-003)

## Tests

Describe verification steps and results:

- Command(s) run:
  - Gate 1 evidence persisted: `GATE_1_DECISION=APPROVED` / `PLAN_APPROVED=true` / `APPROVAL_AUTHORITY=Human/Planner`
  - `git checkout -b task/TASK-005C-D-workflow-hardening`
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/start-coding.ps1` (PRIMARY Gate 1)
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1` (initial coding **89/89**; Fix Round 2 **123/123**)
  - `git diff --name-only -- apps agents .github` (empty)
- Result: `pass` — guardrails **123/123** after B-001/B-002/B-003
- Notes:
  - Gate 1: `Assert-PlanApproved` refuses false; `start-coding.ps1` is PRIMARY; `open-pr.ps1` labeled defense-in-depth; `plan_approved` stayed `true` (no Gate 1 re-run)
  - B-001 tests: unmerged PR, missing runtime, leftover TASK-005C-C runtime, headRefName mismatch, requested/runtime PR clash, missing task id
  - B-002 tests: one authorized unpushed commit retryable; synced HEAD is not retry; ahead-by-2 / diverge / dirty+ahead / wrong parent / wrong subject / foreign paths / missing state.json all fail closed
  - B-003 tests: foreign TASK-OTHER / TASK-ZZZ / TASK-005C-C refused; exact path set is state.json + this TASK active/completed only; archive-push does not `git add` entire directories
  - D-001: `Assert-D001ArchivePreconditions` does not read `AGENT_D001_ARCHIVE`; marker is not authorization
  - `ci.yml` still `contents: read`

## Issues

Known problems, blockers, or follow-ups:

- Independent Review Round 1 **reject** (B-001/B-002/B-003) addressed in Fix Round 2. Round-1 N-001 coverage added as executable unmerged/unsynced/mismatch tests. N-002 through N-007 not in this fix round.
- Project hook is defense in depth. Scripts remain the primary control.
- `archive-push.ps1` / `wait-for-merge.ps1` are not dogfooded on a live PR in this coding round (forbidden until Review approve + Human merge).
- Branch Protection remains TASK-005C-E.

## Commit

- none (this coding round has not been asked to commit)

## Branch

`task/TASK-005C-D-workflow-hardening`

Not pushed. No PR.

## Review Status

`approve` (Independent Review Round 2; `.agent/reviews/TASK-005C-D-review-round-2.md`)

## Next Steps

Recommended next actions:

1. Coding: `open-pr.ps1` then `observe-ci.ps1 -Wait` on `task/TASK-005C-D-workflow-hardening`.
2. This TASK is `ci_required: no` → protocol `n/a`; `ci-gate` should still go green with app jobs skipped.
3. **Human** merges `main` (Gate 2). `wait-for-merge.ps1` reads `MERGED`. Then `finalize-prep.ps1` + D-001 `archive-push.ps1`.
4. Do not start TASK-005C-E.
