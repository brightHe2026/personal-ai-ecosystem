# TASK-005C-F Implementation Report

Copied from `.agent/reports/REPORT_TEMPLATE.md`.

---

## Task ID

`TASK-005C-F`

## Changes

List created, modified, or deleted files:

- Created:
  - `scripts/workflow/verify-branch-protection.ps1` (read-only GET; `compliant` / `non-compliant` / `not-protected`; Always Run candidate)
  - `scripts/workflow/apply-branch-protection.ps1` (print D-007/D-008 payload; mutate only with `-Apply` after Gate 1; never Always Run / CI / bootstrap)
  - `scripts/workflow/fixtures/branch-protection/` (C-004 / C-005 JSON fixtures)
  - `.agent/reports/TASK-005C-F-report.md`
  - `.agent/tasks/active/TASK-005C-F-branch-protection.md`
- Modified:
  - `.agent/README.md` (V2.5 → V2.6)
  - `.agent/BOOTSTRAP.md` (V2.6; forbidden-next → V3 Review auto-spawn)
  - `.agent/workflows/task-lifecycle.md` (V2.6; D-007–D-010 / C-004 / C-005)
  - `.agent/workflows/git-pr.md` (v1.5 → v1.6; Branch Protection coexistence with D-001)
  - `.agent/workflows/ci-gate.md` (v1.4 → v1.5; required check only `ci-gate`; verifier/apply scripts)
  - `.agent/workflows/permissions.md` (V2.6; verifier Always Run candidate; apply helper Never Always Run)
  - `.agent/agents/coding-agent.md` (forbidden-next → V3)
  - `.agent/handoff.TEMPLATE.md` (V2.6; forbidden-next → V3)
  - `.cursor/rules/agent-bootstrap.mdc` (V2.6; do not start V3 Review auto-spawn)
  - `scripts/workflow/lib.ps1` (protection parse/verdict/payload; `Get-DefaultHandoffForbidden` retarget)
  - `scripts/workflow/test-guardrails.ps1` (C-004 / C-005 / D-007 / D-008; V3 forbidden retarget)
  - `.agent/state.json` (`plan_approved: true` after Gate 1; `coding` / `in_review` / Fix Round 2 keeps `review_round: 2`)
- Deleted:
  - None

Fix Round 2 (Independent Review Round 1 reject — B-001 only):

- B-001: report Tests/Issues no longer claim live `GET /branches/main/protection` is HTTP 404 / `verdict=not-protected` / exit 2. Independent Fix Round 2 `verify-branch-protection.ps1` is quoted below. Coding did not `gh api` PUT protection (D-009).

Not changed (hard boundary):

- `apps/` and `agents/` application code
- `.github/workflows/ci.yml` (C-005 confirmed live check name `ci-gate`; no job `name:` tweak)
- no `merge.ps1`; no `gh pr merge`
- no GitHub auto-merge
- no V3 Review auto-spawn / SDK `Agent.create`
- `.agent/reviews/` not written by Coding (Independent Review is a separate session, D-003). Round-1 reject file exists from the Review session.
- Coding did **not** PUT Branch Protection (D-009).

## Tests

Describe verification steps and results:

- Command(s) run:
  - Gate 1 evidence persisted: `GATE_1_DECISION=APPROVED` / `PLAN_APPROVED=true` / `APPROVAL_AUTHORITY=Human/Planner` / `TASK_ID=TASK-005C-F`
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/start-coding.ps1`
  - `git checkout -b task/TASK-005C-F-branch-protection`
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1` (initial coding **185/185**)
  - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/apply-branch-protection.ps1` (no `-Apply`) → printed payload, refused to mutate
  - `git diff --name-only -- apps agents .github` (empty)
  - **Fix Round 2 independent C-004 re-query (B-001):** `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/verify-branch-protection.ps1`
    - stdout: `verdict=compliant`
    - exit: `0`
    - paired read-only `gh api repos/:owner/:repo/branches/main/protection --jq`: HTTP 200; `strict: true`; `contexts: ["ci-gate"]`; `enforce_admins: false`; `force: false`; `deletions: false`; `pr_reviews: 0`
    - Coding did not PUT protection
- Result: `pass`
- Notes:
  - C-004 live fact must match GitHub, not a prior Coding run. Round 1 Coding recorded `not-protected` / HTTP 404 / exit 2. Round 1 Review found HTTP 200 / `non-compliant` / `required_status_checks.strict` false. This Fix Round 2 independent verify is **HTTP 200 / `compliant` / `strict: true`** (Human applied the remaining D-007 bit; Coding did not PUT).
  - C-005: live Checks on `main` and PR #5 report name **`ci-gate`**. Apply payload uses that string. Verifier also accepts `CI / ci-gate`.
  - C-004 fixtures: unprotected, extra app job, missing `ci-gate`, force allowed, deletions allowed, `enforce_admins: true`, review count `> 0`.
  - D-008: payload `enforce_admins: false`; live GET `enforce_admins.enabled` is false.
  - Existing D-001 / Gate 1 / merge-forbidden / C-001 / C-002 tests still pass.
  - Leftover “do not start TASK-005C-F” retargeted to V3 in protocol/role/bootstrap/handoff template. Historical TASK-005C-E report/reviews left as history.

## Issues

Known problems, blockers, or follow-ups:

- Independent Review Round 1 **reject** (B-001) addressed in Fix Round 2. Round-1 N-001 through N-003 not in this fix round.
- C-003: Human returned with `continue from handoff`; Coding applied `required_fixes` from `.agent/reviews/TASK-005C-F-review-round-1.md` without a rewritten B-001 paste.
- Live C-004 (Fix Round 2 independent `verify-branch-protection.ps1`): **applied and compliant** — HTTP 200, `verdict=compliant`, exit 0, `required_status_checks.strict` is **true**. Not `not-protected` / HTTP 404 / exit 2. Round 1 Review’s live GET (HTTP 200 / `non-compliant` / `strict` false) is superseded by this re-query. Coding did not PUT.
- Human next action is no longer “create protection because GET is 404” and no longer “enable Require branches to be up to date” unless a later GET shows `strict` false again. Remaining Human work is Gate 2 merge dogfood of required `ci-gate`.
- This machine’s shell is `powershell.exe` (Windows PowerShell 5.1); `pwsh` is not on PATH. Scripts still prefer `pwsh` with `Resolve-GhExe` fallback.

## Commit

Commits on `task/*` for this round (hash + message). Write `none` if this TASK forbids commit (example: TASK-005B protocol session).

- (this delivery commit on `task/TASK-005C-F-branch-protection`)

## Branch

`task/TASK-005C-F-branch-protection`

## Review Status

`approve` (Independent Review Round 2; `.agent/reviews/TASK-005C-F-review-round-2.md`)

## Next Steps

Recommended next actions:

1. Coding: `open-pr.ps1` then `observe-ci.ps1 -Wait` (this session; `ci_required: no` → protocol `n/a`).
2. **Human** merges `main` (Gate 2). Live protection already requires `ci-gate` with `strict: true`. `wait-for-merge.ps1` reads `MERGED`. Then `finalize-prep.ps1` + D-001 `archive-push.ps1`.
3. Do not `gh pr merge`. Do not start V3 Review auto-spawn. Coding must not PUT Branch Protection.
