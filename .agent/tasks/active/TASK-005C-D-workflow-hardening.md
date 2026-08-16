# TASK-005C-D — Personal AI Ecosystem Workflow Hardening & Human Interaction Reduction

Filename convention satisfied: `TASK-005C-D-workflow-hardening.md`

---

## Task ID

`TASK-005C-D`

Field: `task_id`

## Scope

Field: `scope`

`ecosystem`

Protocol + `scripts/workflow` hardening. Does not change `.github/workflows/ci.yml` or application business behavior.

## Agent Role

`Coding-Agent`

Review must be a **separate** Cursor session (`Review-Agent`). This Coding Agent must not self-review and must not simulate Review Agent in the same session (locked **D-003**).

## Goal

Field: `goal`

Harden Workflow V2 so Human is no longer an information courier: add machine-readable Gate 1 (`plan_approved`), file-based handoff, CI/merge observation without GitHub-tab transcription, and a narrowly scoped post-merge archive exception (D-001). Keep Human Decision Gates to Plan Approval and Merge to `main`.

## Locked decisions (Human/Planner)

Do not reopen. Implementation must match these exactly.

### D-001 — Post-Merge Archive exception

After **Human** merges the GitHub PR, automation may finalize/archive **only if all** are true:

1. GitHub authoritatively reports the PR as `MERGED`.
2. Local `main` is synchronized with `origin/main`.
3. The resulting git diff is restricted to the **archive allowlist** below.
4. No business/application code is changed.
5. Normal direct push-to-`main` remains prohibited outside this exception.

Archive allowlist (git paths only):

- `.agent/tasks/active/TASK-XXX-*.md` moved to `.agent/tasks/completed/`
- `.agent/state.json` durable archive fields
- Status / Result fields inside that same TASK file (after the move)
- No other paths. Especially not `apps/`, `agents/` (application code), `.github/workflows/**`

Still forbidden: `gh pr merge`, merge scripts, Actions writing git / `state.json`, force push, unrelated `main` commits.

### D-002 — Gate 1 `plan_approved`

Required lifecycle:

```
specified
  → Implementation Plan
  → STOP
  → Human/Planner approval
  → plan_approved
  → coding
```

`plan_approved` is machine-readable on `.agent/state.json` (boolean). Default `false` when a TASK is created.

Coding MUST NOT modify implementation files before `plan_approved === true`.

This TASK dogfoods Gate 1: the Coding Agent session that implements it must STOP after Preflight + Implementation Plan until Human/Planner explicitly approves that plan.

### D-003 — Independent Review

Independent Review remains a separate Agent session. TASK-005C-D must **not** simulate Review Agent inside the Coding Agent session. For V2.1, one Human New Chat / `@handoff` click is acceptable. Automatic Review Agent spawning is V3 (out of scope).

## Requirements

Field: `requirements`

Implement the Architecture Review **Recommended Scope** and **Acceptance Criteria** (session [TASK-005C-D Architecture](a6cb620a-3945-424d-a5c4-b70a9fb0f5c9)).

1. Protocol V2.3 → V2.4 in `.agent/workflows/task-lifecycle.md`, `git-pr.md`, `ci-gate.md` as needed, `.agent/agents/coding-agent.md`, `.agent/agents/review-agent.md`, `.agent/README.md`.
2. Add `plan_approved` to `state.json` schema. Planner/Coding may set it only after Human/Planner Plan approval. `open-pr.ps1` and implementation-start rules must refuse when `plan_approved` is not true for the active TASK (Coding already past Gate 1 for this TASK by then).
3. Handoff artifact: live `next_actor` / `next_action` (gitignored overlay and/or `.agent/handoff.md` as decided in the Implementation Plan). Agents read files, not ChatGPT paste, for Review / git_ready / finalize handoff.
4. `observe-ci.ps1 -Wait` (timeout, then STOP for Human Gate 2; do not forge failure or `passed`).
5. `wait-for-merge` (script or equivalent parameter): poll GitHub until `MERGED` or timeout. Human must not have to transcribe merge results.
6. After Review **approve**, the same Coding session continues `git_ready` → `open-pr.ps1` → observe without a new Human-authored Git Ready prompt.
7. After `MERGED` detect: run `finalize-prep`, then apply D-001 archive exception (commit + push `main` **only** for allowlisted archive diff). Re-query GitHub Checks before durable `ci_status: passed` (N-002). Do not trust a stale `runtime.json` overlay as CI SoT.
8. Permission / Always Run policy documented under `.agent/` (read-only git/gh/workflow scripts may be auto-run; never auto-approve `gh pr merge` or normal `git push origin main`).
9. Optional project hook (`.cursor/hooks`) that denies `gh pr merge` and `git push` to `main` except the D-001 archive path. Hook is defense in depth, not the only control.
10. Keep `ConvertFrom-GhJson` and `Resolve-GhExe` absolute-path fallback. Prefer `pwsh`. Do not rewrite the machine PATH.
11. Local guardrail tests: no `plan_approved` → no implement / no `open-pr` as specified in the plan; merge still refused; D-001 refuses non-allowlist diffs, unmerged PRs, unsynced `main`, and business-code changes.
12. Write `.agent/reports/TASK-005C-D-report.md`. Independent Review is a **separate** session (D-003).
13. **This Coding session (Gate 1):** Preflight → inspect this TASK → Implementation Plan → **STOP**. Do not create a branch, do not edit implementation files, do not commit, do not push, do not open a PR, do not merge, until Human/Planner explicitly approves the Implementation Plan and `plan_approved` is true.

## Constraints

Field: `constraints`

- Do not auto-merge; no `gh pr merge`; no merge script
- Do not give GitHub Actions `contents: write`; Actions must not write git or `state.json`
- Do not automatically spawn a Review Agent session
- Do not enable Branch Protection (queued separately; not this TASK)
- Do not change `.github/workflows/ci.yml` job matrix
- Do not modify business/application code under `apps/` or `agents/`
- Do not touch secrets / `.env`; do not print `.env`; do not commit `.env`
- Do not replace ChatGPT Planner
- Do not act as Independent Review Agent in the Coding session
- Do not merge `main` (Human Merge Gate stays)
- Do not force push
- Do not perform a normal (non-D-001) push to `main`
- Do not start V3 SDK / Automations Review spawning
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md` except the locked D-001 archive exception after Human merge
- Do not open a PR until Review **approve** (`git_ready`)
- Do not modify implementation files before `plan_approved`

## Validation

Field: `validation`

How to verify completion:

- [ ] Gate 1 is machine-checkable: `plan_approved` exists; Coding STOPs after Implementation Plan; no implementation files changed before approval
- [ ] Protocol documents file-based handoff (Review / git_ready / CI / finalize) without requiring Human to paste transcripts
- [ ] After `git_ready`, Coding can `open-pr` + observe without a new Human paste block
- [ ] `ci_required: yes` still cannot enter `awaiting_merge` unless real `ci-gate` is success (existing invariant)
- [ ] No merge script; `gh pr merge` still refused
- [ ] Human need not open the GitHub UI to learn CI; `observe-ci` is the live view
- [ ] Human need not transcribe merge; script reads `MERGED`
- [ ] `finalize-prep` + D-001 archive exception: MERGED + synced `main` + allowlist-only diff; otherwise refuse
- [ ] Durable `ci_status: passed` re-queries Checks (N-002)
- [ ] `.agent/runtime.json` remains gitignored; Actions still do not write git
- [ ] Local guardrails cover new refuse paths
- [ ] No business code, no `ci.yml` matrix change, no Branch Protection, no auto-merge
- [ ] Independent Review remains a separate session; this TASK does not implement auto-spawn
- [ ] Report under `.agent/reports/TASK-005C-D-report.md`
- [x] Independent Review file under `.agent/reviews/` with `decision: approve` — **Review Agent**, not Coding
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`

## Branch

Field: `branch`

`task/TASK-005C-D-workflow-hardening`

Do **not** create this branch before `plan_approved`. Create during `coding` after Gate 1. Push and PR only after Review **approve**.

## CI required

Field: `ci_required`

`no`

Protocol + scripts only. After Review **approve** and PR, skip `ci_running` and use `ci_status: n/a` → `awaiting_merge`. Workflow still runs; app jobs skip; `ci-gate` should be green. `observe-ci` records the real `ci-gate` fact and protocol `n/a` without impersonating `passed`.

## Status

Field: `status`

`git_ready`

Human/Planner Gate 1 remains APPROVED. Independent Review Round 2 `decision: approve`. Same Coding session continues `open-pr.ps1` → `observe-ci.ps1 -Wait`.

## Result

- Status: `git_ready`
- Report: `.agent/reports/TASK-005C-D-report.md`
- Review: `.agent/reviews/TASK-005C-D-review-round-2.md` (`decision: approve`); Round 1 reject is historical
- Notes: Gate 1 remains APPROVED (`plan_approved: true`). Independent Review Round 2 approved B-001/B-002/B-003 fixes. Coding Agent: open PR on `task/*` only. Do not merge. Do not start TASK-005C-E.
