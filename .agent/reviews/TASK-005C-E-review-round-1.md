# TASK-005C-E Independent Review — Round 1

Copied from `.agent/reviews/REVIEW_TEMPLATE.md`.
`N` matches `.agent/state.json` `review_round` (1) at the time of this review.

Review Agent is an independent Cursor session. Coding Agent did not fill this file.
This session received at most `ROLE=review-agent` (C-003). TASK, round, artifacts, scope, and restrictions were derived from `.agent/state.json`, `.agent/handoff.md`, `bootstrap.ps1`, and the files listed below. This session did not participate in TASK-005C-E implementation and did not use the Coding Agent transcript as evidence.

---

## Task ID

`TASK-005C-E`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent (Round 1). Not the Coding Agent session.

## Review Round

Field: `review_round`

`1`

## Review Scope

Field: `review_scope`

- Independent Review Round 1 of uncommitted TASK-005C-E working-tree changes on `task/TASK-005C-E-review-session-automation`.
- Compared against the active TASK, Coding report, Workflow V2.5 (`BOOTSTRAP.md`, `task-lifecycle.md`, `git-pr.md`, `ci-gate.md`, `permissions.md`), role files, C-001 / C-002 / C-003 / D-003 / D-004, and the complete `main...HEAD` + working-tree / untracked diff.
- Guardrails were re-run in this session **before** this review file existed (`154/154`). That result is **not** GitHub CI and does **not** override B-001: the new C-001 assertion is coupled to the absence of this TASK's own review file.
- This session writes this review, `state.json` (`in_review` → `coding`, `review_round` 1 → 2), and gitignored `.agent/handoff.md` via `apply-review-decision.ps1`. No implementation edit, no commit, no push, no PR, no merge, no archive, no TASK-005C-F.

## Decision

Field: `decision`

`reject`

- `reject` → `status` becomes `coding` and `review_round` increases by 1 **once** (C-002)

Rejected transition: `in_review` → `coding` (`review_round: 2`). `plan_approved` stays `true` (do not re-run Gate 1).

**TASK-005C-E is not allowed to enter Git Ready.**

## Blocking Issues

Field: `blocking_issues`

- **B-001** — `scripts/workflow/test-guardrails.ps1` proves “in_review has no current decision” by constructing `active_task=TASK-005C-E` / `status=in_review` / `review_round=1` against the **live** repo. `Get-ApplicableReviewPath` then looks for `.agent/reviews/TASK-005C-E-review-round-1.md`. That file is a required Independent Review deliverable. The assertion `Decision -eq '(none)'` therefore holds only while Review has not started, and fails as soon as this file exists (this round, later rounds, Coding’s pre-PR re-run, and any later `test-guardrails.ps1`). Requirement 10 (guardrails still pass) cannot survive this TASK’s own review loop.

## Non-blocking Issues

Field: `non_blocking_issues`

- **N-001** — `.agent/workflows/task-lifecycle.md` section 5 repeats the same D-003 paragraph twice. Docs only.
- **N-002** — `observe-ci.ps1` still computes `$nextActor` / `$nextAction` (including `ci-recovery` on `ci-gate` failure) and then ignores them. `Write-DerivedHandoff` derives `ci_running` → `observe-ci`. Intentional C-001 overlay, but the dead locals will confuse the next editor. Recovery remains in notes + `ci-gate.md`.
- **N-003** — `Get-LatestReview` (used by `open-pr.ps1` / `Assert-ReviewApproved`) and `Get-ReviewDecisionFromText` (used by `apply-review-decision.ps1` / derived handoff) try the `## Decision` heading vs `decision:` field in **opposite order**. Harmless while review files follow the template; a mixed file could split open-pr from C-001.
- **N-004** — `apply-review-decision.ps1` does not refuse `reject` when the structured `required_fixes` YAML block is missing. Protocol says that block is Coding SoT on reject; enforcement is Review process, not the script.
- **N-005** — Canonical docs/rules invoke `pwsh`; this host resolved `bootstrap.ps1` only via `powershell.exe`. Scripts themselves run on Windows PowerShell 5.1. Not a protocol break.

Do not treat N-items as a substitute for B-001.

## Required Fixes

Field: `required_fixes`

Required because `decision` is `reject`. Coding Agent must address these in the next `coding` round. Review Agent will not implement them. Human must not rewrite this block; Coding reads this file.

```yaml
required_fixes:
  - id: B-001
    files:
      - scripts/workflow/test-guardrails.ps1
    must: Recouple the C-001 "in_review without this round's review file" assertion so it does not use this TASK's live review path (TASK-005C-E review-round-1.md or any later N).
    done_when: test-guardrails.ps1 passes both when .agent/reviews/TASK-005C-E-review-round-N.md is absent and when it is present (this Round 1 reject file and any later round file). Use a fake TASK id and/or an isolated fixture directory that has no review file.
```

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [x] **C-003 dogfood (this spawn):** this Independent Review session received at most `ROLE=review-agent`; TASK, `review_round=1`, artifacts, scope, restrictions, and `next_action=independent-review` were derived from the repo (`bootstrap.ps1` matched handoff)
- [ ] **C-003 dogfood (reject return):** after this reject, Human returns to Coding with at most `continue from handoff`; Coding must read `required_fixes_file` (this file) — proven on the next Coding session, not here
- [x] **C-001:** contradicting/missing handoff fail-closed (tested); live handoff matched derived facts at review start
- [x] **C-002:** helper table 0→1 / re-entry unchanged / reject +1 / approve unchanged (tested). This reject increments 1→2 once via `apply-review-decision.ps1`
- [ ] **approve** return into `git_ready` → `open-pr` → observe — not reached this round
- [x] Repeated-round protocol exists (`enter-review.ps1` does not increment on re-entry)
- [x] D-003 Independent Review is this separate session; no self-review; no subagent substitute; no SDK spawn in workflow scripts
- [x] Human Gate 1 and Gate 2 are not automated
- [x] No Review auto-spawn; no SDK/Automations spawn in this TASK
- [x] No Branch Protection; protocol points at TASK-005C-F; no `apps/` / `agents/` / `ci.yml` changes (`git diff --name-only -- apps agents .github` empty)
- [x] No merge script; `gh pr merge` still refused
- [x] `plan_approved` default false; `start-coding.ps1` still PRIMARY
- [ ] Local guardrails cover new contracts **and still pass after this review file exists** — **fails B-001**
- [x] Report under `.agent/reports/TASK-005C-E-report.md`
- [ ] Independent Review file with `decision: approve` — this round is `reject`
- [ ] PR associated TASK + report + review (after `git_ready`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`

Notes:

Protocol V2.5 shape is otherwise in place: `.agent/BOOTSTRAP.md`, always-apply `.cursor/rules/agent-bootstrap.mdc`, derived `Write-DerivedHandoff` / `bootstrap.ps1` fail-closed + `-Repair`, `enter-review.ps1` C-002, `apply-review-decision.ps1` reject/approve table, structured `required_fixes` on the review template, Branch Protection retargeted to TASK-005C-F in protocol files (historical TASK-005C-D artifacts left as history). D-001 / Gate 1 / merge-forbidden tests still passed in the pre-file `154/154` run.

B-001 is the reason Git Ready is refused. Do not open a PR. Do not start TASK-005C-F. Do not `gh pr merge`.

## Next Steps

1. `apply-review-decision.ps1` (this Review session) → `status=coding`, `review_round=2`, derived handoff `next_actor=coding-agent` `next_action=fix-round` `required_fixes_file=.agent/reviews/TASK-005C-E-review-round-1.md`.
2. Human returns to the Coding session with at most `continue from handoff` (C-003). Do not paste or rewrite B-001.
3. Coding Agent applies B-001 from this file, updates the report, `enter-review.ps1` (do **not** increment `review_round`).
4. Human spawns Independent Review Round 2 with at most `ROLE=review-agent` or `@handoff`.
