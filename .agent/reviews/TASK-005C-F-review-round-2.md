# TASK-005C-F Independent Review — Round 2

Copied from `.agent/reviews/REVIEW_TEMPLATE.md`.
`N` matches `.agent/state.json` `review_round` (2) at the time of this review.

Review Agent is an independent Cursor session. Coding Agent did not fill this file.
This session received at most `ROLE=review-agent` (C-003). TASK, round, artifacts, scope, and restrictions were derived from `.agent/state.json`, `.agent/handoff.md`, `bootstrap.ps1` (via `powershell.exe`; `pwsh` is not on PATH), and the files listed below. This session did not participate in TASK-005C-F implementation and did not use the Coding Agent transcript as evidence.

---

## Task ID

`TASK-005C-F`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent (Round 2). Not the Coding Agent session.

## Review Round

Field: `review_round`

`2`

## Review Scope

Field: `review_scope`

- Independent Review Round 2 of uncommitted TASK-005C-F working-tree changes on `task/TASK-005C-F-branch-protection` (branch tip equals `main`; delivery is working-tree + untracked). Round 1 `required_fixes` was **B-001** only.
- Compared against the active TASK, Coding report (Fix Round 2), Workflow V2.6, D-007–D-010, C-004 / C-005, D-003 / D-009, Round 1 review file, and the complete working-tree / untracked diff.
- Guardrails were re-run in this session **before** this review file existed: **185/185**. That result is **not** GitHub CI.
- Live GitHub was re-queried in this session: first `verify-branch-protection.ps1` printed `verdict=compliant` (exit 0). Independent `gh api repos/:owner/:repo/branches/main/protection` is HTTP 200 with `required_status_checks.strict` true, `contexts: ["ci-gate"]`, `enforce_admins.enabled` false, force/deletions false, required approving review count 0. Rulesets length is `0`. A later verifier `-Json` call hit a transient GitHub HTTP 503 and threw (fail-closed; not a false PASS).
- This session writes this review, `state.json` (`in_review` → `git_ready`, `review_round` stays **2**), and gitignored `.agent/handoff.md` via `apply-review-decision.ps1`. No implementation edit, no commit, no push, no PR, no merge, no archive, no Branch Protection PUT, no V3 spawn.

## Decision

Field: `decision`

`approve`

- `approve` → `status` becomes `git_ready`; `review_round` **unchanged** (C-002)

Approved transition: `in_review` → `git_ready` (`review_round: 2`). `plan_approved` stays `true`.

**TASK-005C-F may enter Git Ready.** Same Coding session continues `open-pr.ps1` then `observe-ci.ps1 -Wait` (`ci_required: no` → protocol `n/a`). Do not wait for a new Human Git Ready prompt.

## Blocking Issues

Field: `blocking_issues`

None.

Round 1 **B-001** is closed. The report no longer claims live `GET /branches/main/protection` is HTTP 404 / `not-protected` / exit 2. This session’s independent GET and first verifier run match the Fix Round 2 report: applied and **compliant** (`strict: true`, required check only `ci-gate`). Coding must not have PUT protection to close B-001 (D-009); this session did not PUT; apply helper without `-Apply` printed the D-007/D-008 payload and refused to mutate.

The Round 1 `done_when` named the then-live non-compliant / `strict` false fact. Human applied the remaining D-007 bit before this round. Recording the current live C-004 fact (applied and compliant) is required; repeating stale `non-compliant` would be a false FAIL.

## Non-blocking Issues

Field: `non_blocking_issues`

- **N-001** — Guardrails still have no `strict: false` fixture, and the apply-payload assertion still does not require `"strict": true`. The payload itself includes `"strict": true` (this session’s apply helper print). Verifier already fail-closes that D-007 case. Test gap only. Carried from Round 1.
- **N-002** — `.agent/workflows/task-lifecycle.md` section 5 still repeats the same D-003 paragraph twice. Pre-existing; docs only. Carried from Round 1.
- **N-003** — Canonical docs/rules invoke `pwsh`; this host resolved `bootstrap.ps1` only via `powershell.exe`. Scripts themselves run on Windows PowerShell 5.1. Not a protocol break. Carried from Round 1.

Do not treat N-items as a substitute for a blocking issue. They do not block `git_ready`.

## Required Fixes

Field: `required_fixes`

`(none)`

```yaml
required_fixes: []
```

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [x] **C-003 dogfood (this spawn):** this Independent Review session received at most `ROLE=review-agent`; TASK, `review_round=2`, artifacts, scope, restrictions, and `next_action=independent-review` were derived from the repo (`bootstrap.ps1` matched handoff)
- [x] **C-003 dogfood (reject return):** Human returned to Coding with at most `continue from handoff`; Coding applied B-001 from `.agent/reviews/TASK-005C-F-review-round-1.md` (report Tests/Issues/Next Steps updated; no rewritten B-001 paste required)
- [x] **Gate 1:** `plan_approved: true`; `start-coding.ps1` remains PRIMARY; this session did not infer Gate 1
- [x] **Classic Branch Protection exists on `main` (no longer HTTP 404)** — live GET HTTP 200
- [x] Required checks on live `main` are only `ci-gate` (C-005); app jobs are not required
- [x] Force push disallowed; deletions disallowed (live GET)
- [x] Pull request required; required approving review count is 0 (live GET)
- [x] `enforce_admins` is false (D-008) (live GET)
- [x] D-007 `strict: true` — live `required_status_checks.strict` is **true**
- [x] Verifier fail-closed cases covered by local guardrails (C-004 listed fixtures) — **185/185**; live verifier `verdict=compliant` (no false PASS; 503 later threw)
- [ ] This TASK’s PR dogfoods GitHub requiring `ci-gate` at merge — not reached until Coding opens the PR after `git_ready`
- [x] No Always Run / CI / bootstrap mutation of protection; this session did not PUT; apply without `-Apply` refused
- [x] No `apps/` / `agents/` business changes; `ci.yml` unchanged (`git diff --name-only -- apps agents .github` empty)
- [x] No merge script; `gh pr merge` still refused; no V3 spawn
- [x] Protocol V2.6 documents D-007–D-010; leftover “do not start TASK-005C-F” retargeted to V3 in protocol/role/bootstrap/handoff template (historical TASK-005C-E artifacts left as history)
- [x] Report under `.agent/reports/TASK-005C-F-report.md` — present; live C-004 fact matches this session’s GET
- [x] Independent Review file with `decision: approve` — this file
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`
- [ ] D-001 archive of this TASK still succeeds after merge (dogfood D-008)

Notes:

Protocol + scripts shape is in place: V2.6 docs, read-only `verify-branch-protection.ps1`, Human-gated `apply-branch-protection.ps1` (Gate 1 + no `-Apply` + no `GITHUB_ACTIONS`), C-004 fixtures, C-005 payload `ci-gate`, D-008 `enforce_admins: false`, no `apps/` `agents/` `ci.yml` edits, no merge script, no V3 spawn. D-001 / Gate 1 / merge-forbidden / C-001 / C-002 tests still passed in the pre-file **185/185** run. Live protection matches D-007/D-008. B-001 is closed. Remaining validation is post-`git_ready` (PR, protocol `n/a`, Human Gate 2, D-001 archive).

Do not `gh api` PUT protection from Coding. Do not `gh pr merge`. Do not start V3 Review auto-spawn.

## Next Steps

1. `apply-review-decision.ps1` (this Review session) → `status=git_ready`, `review_round` stays **2**, derived handoff `next_actor=coding-agent` `next_action=open-pr-observe`.
2. **Same Coding session** (no new Human Git Ready prompt): commit remaining delivery on `task/TASK-005C-F-branch-protection` → `open-pr.ps1` → `observe-ci.ps1 -Wait` (`ci_required: no` → protocol `ci_status: n/a`).
3. **Human** Gate 2: merge `main` once this TASK’s PR dogfoods required `ci-gate`. Live protection already has `strict: true` and required check `ci-gate`.
4. After merge: `wait-for-merge.ps1` → `finalize-prep.ps1` + D-001 `archive-push.ps1` (dogfood D-008).
5. Do not `gh pr merge`. Do not start V3 Review auto-spawn. Review session STOP. Do not implement.
