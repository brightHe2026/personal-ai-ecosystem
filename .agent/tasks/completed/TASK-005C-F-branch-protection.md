# TASK-005C-F — GitHub Branch Protection for `main`

Filename convention satisfied: `TASK-005C-F-branch-protection.md`

---

## Task ID

`TASK-005C-F`

Field: `task_id`

## Scope

Field: `scope`

`ecosystem`

Protocol + `scripts/workflow` verifier (and optional Human-gated apply helper) + Cursor/workflow docs. GitHub **settings** on `main` are the product of this TASK; they are applied by **Human**, not by unattended automation.

Does not change application business behavior under `apps/` or `agents/`. Prefer **no** change to `.github/workflows/ci.yml`. V3 Review auto-spawn remains out of scope.

## Agent Role

`Coding-Agent`

Review must be a **separate** Cursor session (`Review-Agent`). This Coding Agent must not self-review and must not simulate Review Agent in the same session (locked **D-003**). Coding-session subagents are not Independent Review.

## Goal

Field: `goal`

Protect `main` so GitHub merges require the aggregate check `ci-gate` only, block force-push and branch deletion, and still allow the existing D-001 archive-push path used by the repo owner. Human remains Gate 2 merge owner. Independent Review remains the review gate (no GitHub required approving reviews).

## Background

TASK-005C-B through TASK-005C-E delivered CI (`ci-gate`), Checks-as-SoT, Gate 1, D-001 archive, and V2.5 spawn-only Human relay. `main` is still unprotected: `GET /branches/main/protection` returns 404; repository rulesets are empty. Protocol files already reserve this work as **TASK-005C-F**.

GitHub E2E leftover from TASK-005C-B: the required-check **UI string** may be `ci-gate` or `CI / ci-gate`. Local `Test-IsCiGateName` already accepts both. This TASK must confirm the string GitHub will accept as a required context and must **not** add the three app jobs as required checks (skipped jobs would block protocol-only PRs).

## Locked decisions (proposed for Gate 1; do not reopen after approval)

Do not reopen once Human/Planner Gate 1 APPROVED. Implementation must match these exactly.

### D-001 / D-002 / D-003 / D-004 / D-005 / D-006 — inherited, unchanged

- **D-001** post-merge archive exception remains. `archive-push.ps1` is still the only script that may `git push origin main`, and only after independent checks. Marker is not authorization.
- **D-002** Gate 1 `plan_approved`; Human/Planner sole authority; `start-coding.ps1` PRIMARY.
- **D-003** Independent Review is a separate Cursor Agent session.
- **D-004** No SDK / Automations / subagent Review spawn (V3).
- **D-005** Git repository is the Agent communication bus (C-001).
- **D-006** Canonical bootstrap; spawn-only Human instruction.

### D-007 — Protection shape on `main`

Use **classic** GitHub Branch Protection on `main` (not an empty ruleset, not Actions-written git).

Required:

- Required status checks: **only** `ci-gate` (or the confirmed GitHub UI equivalent `CI / ci-gate` — see C-005). `strict: true` (branch must be up to date before merge).
- Do **not** require `sales-agent-backend`, `sales-agent-frontend`, `knowledge-agent-backend`, or `changes` as required checks.
- Disallow force pushes.
- Disallow deletions.

Required pull request:

- Require a pull request before merging.
- Required approving review count: **0**. Independent Review (`.agent/reviews/`) remains the review gate. Do not add CODEOWNERS-required reviews in this TASK.

### D-008 — D-001 coexistence (`enforce_admins: false`)

Do **not** set `enforce_admins: true` / “Include administrators” in this TASK.

Reason: Coding Agent uses the repo **owner** credentials. If administrators cannot bypass, `archive-push.ps1` `git push origin main` fails and D-001 breaks. Rewriting D-001 into a second archive PR is **out of scope** (more Human Gate 2 work).

Consequence (document in protocol): GitHub Branch Protection is a collaborator / accident control. It does **not** stop an agent that already holds owner credentials. Agent-side controls remain protocol + project hook + `archive-push.ps1` independent checks.

### D-009 — Human applies; Coding verifies; never Always Run

Enabling or changing Branch Protection is a **Human** GitHub-admin action (already listed in `.agent/workflows/permissions.md` as never Always Run).

Coding may:

- Document the intended payload.
- Add a **read-only** verifier (`scripts/workflow/verify-branch-protection.ps1` or equivalent).
- Optionally add an apply helper that prints the payload and refuses to mutate GitHub unless explicitly invoked with a documented `-Apply` (or equivalent) **after** Gate 1. That helper is never Always Run and must not run from CI.

Coding must not silently `gh api` PUT protection during bootstrap, review, CI, or archive.

### D-010 — No auto-merge; no V3; no product apps

- No `gh pr merge`; no merge script; no GitHub auto-merge enablement as part of this TASK.
- Do not start V3 Review auto-spawn.
- Do not modify `apps/` or `agents/` business code.

### C-004 — Verifier fail-closed (Gate 1 condition)

The verifier must **fail closed** when any of these is true after Human has applied protection (validation phase):

- `main` is unprotected
- required checks include any app job or omit `ci-gate` / `CI / ci-gate`
- force pushes are allowed
- deletions are allowed
- `enforce_admins` is true (violates D-008)
- required approving review count is greater than 0 (violates D-007)

Before Human applies protection, Coding may still land docs + verifier; the report must distinguish “not yet applied” from “applied and non-compliant.” Do not record a false PASS.

### C-005 — Required-check string (Gate 1 condition)

Confirm the exact context name GitHub accepts for required checks (E2E). Implementation must use that string in the protection payload. Protocol/docs/verifier must treat `ci-gate` and `CI / ci-gate` as the same aggregate job, consistent with `Test-IsCiGateName`. Do not guess a third name.

## Requirements

Field: `requirements`

1. Create this TASK file and set `.agent/state.json` to `active_task: TASK-005C-F`, `status: specified`, `plan_approved: false`, `review_round: 0`, `ci_required: false`, `pr_url: null`, `ci_status: not_started`. **This Coding session (Gate 1):** Preflight → Implementation Plan → **STOP**. Do not create a branch, do not edit implementation files, do not commit, do not push, do not open a PR, do not merge, do not apply Branch Protection, until Human/Planner issues machine-readable Gate 1 APPROVED evidence and `plan_approved` is true.
2. Protocol **V2.5 → V2.6** in `.agent/README.md`, `.agent/workflows/task-lifecycle.md`, `.agent/workflows/git-pr.md`, `.agent/workflows/ci-gate.md`, `.agent/workflows/permissions.md`, and role files as needed. Document D-007/D-008/D-009/D-010 and C-004/C-005.
3. Retarget leftover “do not start TASK-005C-F” / “Branch Protection is TASK-005C-F” **forbidden-next** lines to **do not start V3 Review auto-spawn**. Historical TASK-005C-E artifacts may remain as history.
4. Read-only verifier script: query GitHub protection for `main`, print a machine-readable compliant / non-compliant / not-protected result, fail closed per C-004. Always Run **candidate** (read-only). No merge, no push `main`, no protection mutation.
5. Optional apply helper: emit the exact API payload matching D-007/D-008; mutate GitHub only with explicit `-Apply` after Gate 1; never Always Run; never from CI; never from `bootstrap.ps1`.
6. Local guardrail tests for the expected protection shape (fixture JSON), C-004 fail-closed cases, and C-005 name matching. Existing D-001 / Gate 1 / merge-forbidden / C-001 / C-002 tests must still pass.
7. Prefer **no** `.github/workflows/ci.yml` change. Change it only if E2E proves the required-check context cannot be set without a job `name:` tweak, and keep path skip + aggregate `ci-gate` behavior identical.
8. Human applies protection (UI or Human-approved `-Apply`) in time for this TASK’s own PR to **dogfood** required `ci-gate` at Gate 2. Protocol `ci_required: no` / `ci_status: n/a` stays; GitHub may still require `ci-gate` to merge.
9. After Review **approve**, same Coding session continues `git_ready` → `open-pr.ps1` → `observe-ci.ps1 -Wait` without a new Human Git Ready prompt.
10. Write `.agent/reports/TASK-005C-F-report.md`. Independent Review is a **separate** session (D-003).
11. **C-003 dogfood:** this TASK’s Independent Review loop stays spawn-only (`ROLE=review-agent` / `@handoff`; reject return is `continue from handoff`).

## Constraints

Field: `constraints`

- Do not auto-merge; no `gh pr merge`; no merge script
- Do not automatically spawn a Review Agent session (SDK, Automations, or Coding-session subagent)
- Do not start V3 Review auto-spawn
- Do not rewrite D-001 into a second archive PR
- Do not set `enforce_admins: true` / Include administrators
- Do not require the three app jobs or `changes` as required checks
- Do not require GitHub approving reviews / CODEOWNERS in this TASK
- Do not enable GitHub auto-merge
- Do not modify business/application code under `apps/` or `agents/`
- Do not touch secrets / `.env`; do not print `.env`; do not commit `.env`; do not store a PAT in the repo
- Do not replace ChatGPT Planner
- Do not act as Independent Review Agent in the Coding session
- Do not merge `main` (Human Gate 2 stays)
- Do not force push
- Do not perform a normal (non-D-001) push to `main`
- Do not automate away Human Gate 1 or Human Gate 2
- Do not infer Gate 1 approval from conversation
- Do not modify implementation files before `plan_approved === true` (PRIMARY: `start-coding.ps1`)
- Do not apply Branch Protection before Gate 1
- Do not put protection apply into Always Run, bootstrap, CI, or archive-push
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md` including D-001 archive-push after independent checks
- Do not open a PR until Review **approve** (`git_ready`)
- Do not treat `AGENT_D001_ARCHIVE=1` as push authorization
- Do not commit `.agent/runtime.json` or `.agent/handoff.md`

## Validation

Field: `validation`

How to verify completion:

- [ ] **Gate 1:** Coding STOPPED after Implementation Plan until machine-readable APPROVED; `start-coding.ps1` is still PRIMARY
- [ ] Classic Branch Protection exists on `main` (no longer HTTP 404)
- [ ] Required checks are only `ci-gate` or confirmed `CI / ci-gate` (C-005); app jobs are not required
- [ ] Force push disallowed; deletions disallowed
- [ ] Pull request required; required approving review count is 0
- [ ] `enforce_admins` is false (D-008); D-001 `archive-push.ps1` still the documented `main` push path
- [ ] Verifier fail-closed cases covered by local guardrails (C-004)
- [ ] This TASK’s PR dogfoods GitHub requiring `ci-gate` at merge (protocol `ci_status` remains `n/a`)
- [ ] No Always Run / CI / bootstrap mutation of protection
- [ ] No `apps/` / `agents/` business changes; `ci.yml` unchanged unless C-005 forced a name-only tweak
- [ ] No merge script; `gh pr merge` still refused; no V3 spawn
- [ ] Protocol V2.6 documents D-007–D-010; leftover “do not start TASK-005C-F” retargeted to V3
- [ ] Report under `.agent/reports/TASK-005C-F-report.md`
- [ ] Independent Review file under `.agent/reviews/` with `decision: approve` — **Review Agent**, not Coding
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`
- [ ] D-001 archive of this TASK still succeeds after merge (dogfood D-008)

## Branch

Field: `branch`

`task/TASK-005C-F-branch-protection`

Do **not** create this branch before `plan_approved`. Create during `coding` after Gate 1. Push and PR only after Review **approve**.

## CI required

Field: `ci_required`

`no`

Protocol + scripts + GitHub settings. After Review **approve** and PR, skip `ci_running` and use `ci_status: n/a` → `awaiting_merge`. Workflow still runs; app jobs skip; `ci-gate` should be green. GitHub Branch Protection (once applied) will still require `ci-gate` to merge. `observe-ci` records the real `ci-gate` fact and protocol `n/a` without impersonating `passed`.

## Status

Field: `status`

`completed`
Human/Planner Gate 1 remains APPROVED. Independent Review Round 2 `decision: approve`. `review_round` stays **2** (C-002). Same Coding session continues `open-pr.ps1` → `observe-ci.ps1 -Wait`.

## Result

- Status: `completed`
- Report: `.agent/reports/TASK-005C-F-report.md`
- Review: `.agent/reviews/` (Independent Review file)
- Notes: Human merged `main`. Durable ci_status=n/a. PR https://github.com/brightHe2026/personal-ai-ecosystem/pull/6. Archived 2026-08-18T01:53:12+08:00.
