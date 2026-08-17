# TASK-005C-F Independent Review — Round 1

Copied from `.agent/reviews/REVIEW_TEMPLATE.md`.
`N` matches `.agent/state.json` `review_round` (1) at the time of this review.

Review Agent is an independent Cursor session. Coding Agent did not fill this file.
This session received at most `ROLE=review-agent` (C-003). TASK, round, artifacts, scope, and restrictions were derived from `.agent/state.json`, `.agent/handoff.md`, `bootstrap.ps1` (via `powershell.exe`; `pwsh` is not on PATH), and the files listed below. This session did not participate in TASK-005C-F implementation and did not use the Coding Agent transcript as evidence.

---

## Task ID

`TASK-005C-F`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent (Round 1). Not the Coding Agent session.

## Review Round

Field: `review_round`

`1`

## Review Scope

Field: `review_scope`

- Independent Review Round 1 of uncommitted TASK-005C-F working-tree changes on `task/TASK-005C-F-branch-protection` (branch tip equals `main`; delivery is working-tree + untracked).
- Compared against the active TASK, Coding report, Workflow V2.6 (`BOOTSTRAP.md`, `task-lifecycle.md`, `git-pr.md`, `ci-gate.md`, `permissions.md`), D-007–D-010, C-004 / C-005, D-003 / D-009, and the complete working-tree / untracked diff.
- Guardrails were re-run in this session **before** this review file existed: **185/185**. That result is **not** GitHub CI.
- Live GitHub was re-queried in this session: `GET /branches/main/protection` is HTTP 200 (not 404); rulesets are `[]`; PR #5 and `main` check-run names include **`ci-gate`**.
- This session writes this review, `state.json` (`in_review` → `coding`, `review_round` 1 → 2), and gitignored `.agent/handoff.md` via `apply-review-decision.ps1`. No implementation edit, no commit, no push, no PR, no merge, no archive, no Branch Protection PUT, no V3 spawn.

## Decision

Field: `decision`

`reject`

- `reject` → `status` becomes `coding` and `review_round` increases by 1 **once** (C-002)

Rejected transition: `in_review` → `coding` (`review_round: 2`). `plan_approved` stays `true` (do not re-run Gate 1).

**TASK-005C-F is not allowed to enter Git Ready.**

## Blocking Issues

Field: `blocking_issues`

- **B-001** — `.agent/reports/TASK-005C-F-report.md` records live verifier `verdict=not-protected`, exit 2, and “`main` is still unprotected (HTTP 404, empty rulesets).” Independent Review re-ran `verify-branch-protection.ps1` and `gh api repos/:owner/:repo/branches/main/protection`. Classic protection **exists** (HTTP 200). Verdict is `non-compliant` (exit 1) because `required_status_checks.strict` is `false`. Other D-007/D-008 fields already match: required check is only `ci-gate`, PR required with approving review count 0, `enforce_admins.enabled` false, force pushes and deletions disallowed. Rulesets are empty. C-004 requires the report to distinguish “not yet applied” from “applied and non-compliant” and forbids a false PASS. This is the second state, recorded as the first. Human next action differs: enable **Require branches to be up to date** (`strict: true`) via UI or Human-gated `-Apply`, not “create protection because GET is 404.” Coding must not PUT protection to close this finding (D-009).

## Non-blocking Issues

Field: `non_blocking_issues`

- **N-001** — Guardrails have no `strict: false` fixture, and the apply-payload assertion does not require `"strict": true`. The verifier already fail-closes that D-007 case (this session’s live GET). Test gap only.
- **N-002** — `.agent/workflows/task-lifecycle.md` section 5 still repeats the same D-003 paragraph twice. Pre-existing; docs only.
- **N-003** — Canonical docs/rules invoke `pwsh`; this host resolved `bootstrap.ps1` only via `powershell.exe`. Scripts themselves run on Windows PowerShell 5.1. Not a protocol break.

Do not treat N-items as a substitute for B-001.

## Required Fixes

Field: `required_fixes`

Required because `decision` is `reject`. Coding Agent must address these in the next `coding` round. Review Agent will not implement them. Human must not rewrite this block; Coding reads this file.

```yaml
required_fixes:
  - id: B-001
    files:
      - .agent/reports/TASK-005C-F-report.md
    must: Record the live C-004 fact that classic protection on main is applied and non-compliant (HTTP 200, verdict non-compliant, required_status_checks.strict false), not not-protected / HTTP 404 / exit 2.
    done_when: Report Tests and Issues quote an independent verify-branch-protection.ps1 run that matches live GitHub (non-compliant / strict not true). Next steps tell Human to set strict true (UI "Require branches to be up to date before merging" or apply-branch-protection.ps1 -Apply) and do not claim GET /branches/main/protection is 404. Coding must not gh api PUT protection to satisfy this finding (D-009).
```

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [x] **C-003 dogfood (this spawn):** this Independent Review session received at most `ROLE=review-agent`; TASK, `review_round=1`, artifacts, scope, restrictions, and `next_action=independent-review` were derived from the repo (`bootstrap.ps1` matched handoff)
- [ ] **C-003 dogfood (reject return):** after this reject, Human returns to Coding with at most `continue from handoff`; Coding must read `required_fixes_file` (this file) — proven on the next Coding session, not here
- [x] **Gate 1:** `plan_approved: true`; `start-coding.ps1` remains PRIMARY; this session did not infer Gate 1
- [ ] **Classic Branch Protection exists on `main` (no longer HTTP 404)** — live GET is HTTP 200, but the report still claims 404 (**B-001**)
- [x] Required checks on live `main` are only `ci-gate` (C-005); app jobs are not required
- [x] Force push disallowed; deletions disallowed (live GET)
- [x] Pull request required; required approving review count is 0 (live GET)
- [x] `enforce_admins` is false (D-008) (live GET)
- [ ] D-007 `strict: true` — live `required_status_checks.strict` is `false`; Human must still apply that bit (D-009). Report does not say so (**B-001**)
- [x] Verifier fail-closed cases covered by local guardrails (C-004 listed fixtures) — **185/185**; live `strict: false` also fail-closed (no false PASS)
- [ ] This TASK’s PR dogfoods GitHub requiring `ci-gate` at merge — not reached (no `git_ready` / PR this round)
- [x] No Always Run / CI / bootstrap mutation of protection; this session did not PUT; apply without `-Apply` refused
- [x] No `apps/` / `agents/` business changes; `ci.yml` unchanged (`git diff --name-only -- apps agents .github` empty)
- [x] No merge script; `gh pr merge` still refused; no V3 spawn
- [x] Protocol V2.6 documents D-007–D-010; leftover “do not start TASK-005C-F” retargeted to V3 in protocol/role/bootstrap/handoff template (historical TASK-005C-E artifacts left as history)
- [x] Report under `.agent/reports/TASK-005C-F-report.md` — present, but live C-004 fact is wrong (**B-001**)
- [ ] Independent Review file with `decision: approve` — this round is `reject`
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`
- [ ] D-001 archive of this TASK still succeeds after merge (dogfood D-008)

Notes:

Protocol + scripts shape is otherwise in place: V2.6 docs, read-only `verify-branch-protection.ps1`, Human-gated `apply-branch-protection.ps1` (Gate 1 + no `-Apply` + no `GITHUB_ACTIONS`), C-004 fixtures, C-005 payload `ci-gate` (live Checks on PR #5 and `main` also name `ci-gate`), D-008 `enforce_admins: false`, no `apps/` `agents/` `ci.yml` edits, no merge script, no V3 spawn. D-001 / Gate 1 / merge-forbidden / C-001 / C-002 tests still passed in the pre-file **185/185** run. Apply helper default path printed the D-007/D-008 payload and refused to mutate.

B-001 is the reason Git Ready is refused. Do not open a PR. Do not `gh api` PUT protection from Coding. Do not `gh pr merge`. Do not start V3 Review auto-spawn.

## Next Steps

1. `apply-review-decision.ps1` (this Review session) → `status=coding`, `review_round=2`, derived handoff `next_actor=coding-agent` `next_action=fix-round` `required_fixes_file=.agent/reviews/TASK-005C-F-review-round-1.md`.
2. Human returns to the Coding session with at most `continue from handoff` (C-003). Do not paste or rewrite B-001.
3. Coding Agent applies B-001 from this file, updates the report, `enter-review.ps1` (do **not** increment `review_round`). Do not PUT Branch Protection.
4. Human spawns Independent Review Round 2 with at most `ROLE=review-agent` or `@handoff`.
5. Human still owns enabling `strict: true` (D-009) in time for Gate 2 dogfood.
