# TASK-005C-E — Review Session Automation & Human Relay Reduction

Filename convention satisfied: `TASK-005C-E-review-session-automation.md`

---

## Task ID

`TASK-005C-E`

Field: `task_id`

## Scope

Field: `scope`

`ecosystem`

Protocol + bootstrap/handoff + Review-return artifacts + `scripts/workflow` + Cursor project rules. Does not change `.github/workflows/ci.yml` or application business behavior.

**ID reassignment (Human/Planner this TASK):** prior V2.4 text reserved `TASK-005C-E` for Branch Protection. This TASK is **Review Session Automation & Human Relay Reduction**. Branch Protection is deferred to **TASK-005C-F**. Implementation must retarget leftover "TASK-005C-E = Branch Protection" references.

## Agent Role

`Coding-Agent`

Review must be a **separate** Cursor session (`Review-Agent`). This Coding Agent must not self-review and must not simulate Review Agent in the same session (locked **D-003**). Coding-session subagents are not Independent Review.

## Goal

Field: `goal`

Make repository artifacts, `state.json`, and handoff the authoritative Agent-to-Agent communication bus so Human is no longer the transport layer between Coding and Independent Review, while preserving Human Gate 1 (Implementation Plan) and Human Gate 2 (merge to `main`). Independent Review remains a separate session. Automatic session spawn is out of scope.

## Background — Human relay observed in TASK-005C-D

V2.4 already added gitignored `.agent/handoff.md` (`next_actor` / `next_action`) and committed review files with `required_fixes`. During TASK-005C-D those artifacts existed, but Human still had to:

1. **Coding → Review spawn:** After `in_review`, Coding asked Human to New Chat and `@handoff`. Human still constructed a long Independent Review prompt (role, TASK, round, scope, restrictions, file list).
2. **Review reject → Coding:** Round 1 wrote `.agent/reviews/TASK-005C-D-review-round-1.md` with B-001/B-002/B-003 `required_fixes`. Human then pasted a rewritten CHANGES REQUIRED block into the Coding chat instead of pointing Coding at that file.
3. **Repeat round:** Human constructed a second Independent Review Round 2 prompt for a new chat.
4. **Approve → git_ready:** Same Coding session could continue `open-pr` (V2.4 already allows this), but Human still transcribed the approve result rather than relying on handoff + review `decision: approve`.

Remaining friction is **session bootstrap + authoritative return payloads**, not CI/merge observation (that was TASK-005C-D).

## Locked decisions (proposed for Gate 1; do not reopen after approval)

Do not reopen once Human/Planner Gate 1 APPROVED. Implementation must match these exactly.

### D-001 / D-002 / D-003 — inherited, unchanged

- **D-001** post-merge archive exception remains as implemented in TASK-005C-D.
- **D-002** Gate 1 `plan_approved`; Human/Planner sole authority; `start-coding.ps1` PRIMARY.
- **D-003** Independent Review is a separate Cursor Agent session. Not the Coding chat. Not a Coding-session subagent. Not ChatGPT as a substitute.

### D-004 — Session spawn remains Human (not V3 auto-spawn)

Cursor IDE does not provide a safely verifiable, in-product API for one Agent chat to open another independent Agent chat. The Cursor SDK `Agent.create` / `Agent.prompt` path and Coding-session `Task` subagents are **not** Independent Review.

Human New Chat (or equivalent product click) remains the spawn mechanism. One short Human instruction is acceptable. Automatic Review spawning is **V3 / out of scope**.

### D-005 — Git repository is the Agent communication bus

Conversation transcript is not authoritative workflow state. Field-level authority is **C-001** (do not treat handoff as a peer of `state.json` / review files).

### D-006 — Canonical bootstrap

A newly created Agent session with minimal Human instruction (`ROLE=...` and/or `@` `.agent/handoff.md` / `.agent/BOOTSTRAP.md`) must determine role, TASK, review round, required artifacts, review scope, and restrictions from repository artifacts. Human restatement of TASK context is optional commentary, not a protocol input.

### C-001 — Authority / conflict resolution (Gate 1 condition)

Field-level SoT. Do not invent a ranked “handoff vs state” guess.

| Fact | Authoritative source |
|------|----------------------|
| `status`, `plan_approved`, `review_round`, `active_task` | `.agent/state.json` |
| Review `decision` and `required_fixes` (B-nnn) | Latest **applicable** independent review file `.agent/reviews/TASK-XXX-review-round-N.md` |
| TASK scope / requirements / constraints / validation | Active TASK file |
| Coding change list / tests | `.agent/reports/TASK-XXX-report.md` |
| CI pass/fail, PR merged | GitHub Checks / PR view (unchanged V2.4) |
| `next_actor`, `next_action`, artifact **pointers** | `.agent/handoff.md` is a **transport hint overlay only**, derived from the rows above |

If handoff contradicts `state.json` or the applicable review file: **fail closed** or **regenerate** handoff from those durable artifacts. Agents must not pick the convenient side. Do not store a competing durable `next_actor` on `state.json`.

Applicable review file: the independent review for the round that produced the current return (the reject that opened this `coding` fix round, or the approve that opened `git_ready`). If `in_review` and `review-round-N.md` does not exist yet, there is no decision/`required_fixes` for this round; prior round files are history.

### C-002 — `review_round` semantics (Gate 1 condition)

`review_round` is the round that **will be / is currently being** reviewed. It is not “how many reviews have been written.”

| Event | `status` | `review_round` | Review file written this event |
|-------|----------|----------------|--------------------------------|
| TASK created | `specified` | `0` | none |
| First Coding report | `in_review` | **`1`** (from 0) | none; Review will write `review-round-1.md` |
| Round 1 **reject** | `coding` | **`2`** | `review-round-1.md` (N = round just reviewed) |
| Coding applies fixes, writes report | `in_review` | **`2` unchanged** | none; Review will write `review-round-2.md` |
| Round 2 **reject** | `coding` | **`3`** | `review-round-2.md` |
| Round 2 **approve** | `git_ready` | **`2` unchanged** | `review-round-2.md` |

Increment **once**, and only on Review **reject**. Coding must not increment when re-entering `in_review`. Review must not increment on **approve**. Review file `N` equals `review_round` at review start. After Round 1 reject, `required_fixes_file` is `review-round-1.md` even though `review_round` is already `2`.

### C-003 — End-to-end Human relay reduction (Gate 1 condition)

This TASK must dogfood a spawn-only Human path on its own Review loop:

- New independent Review session receives **at most** `ROLE=review-agent` or `@handoff` (no TASK dossier, no pasted findings).
- That session must derive TASK, `review_round`, task/report/review artifacts, scope, restrictions, and next action from repository artifacts.
- After **reject**, Human returns to Coding with **at most** `continue from handoff` (or equivalent). No copied/rephrased B-nnn.
- Coding must read `required_fixes_file` and apply those B-nnn IDs from the review file.
- Human remains required for session spawn, Gate 1, and Gate 2 only.

## Requirements

Field: `requirements`

1. Create this TASK file and set `.agent/state.json` to `active_task: TASK-005C-E`, `status: specified`, `plan_approved: false`, `review_round: 0`, `ci_required: false`. **This Coding session (Gate 1):** Preflight → Implementation Plan → **STOP**. Do not create a branch, do not edit implementation files, do not commit, do not push, do not open a PR, do not merge, until Human/Planner issues machine-readable Gate 1 APPROVED evidence and `plan_approved` is true.
2. Protocol V2.4 → **V2.5** in `.agent/README.md`, `.agent/workflows/task-lifecycle.md`, and role files as needed (`coding-agent.md`, `review-agent.md`, `planner.md`). Retarget Branch Protection from TASK-005C-E to **TASK-005C-F**.
3. Canonical bootstrap document (committed): `.agent/BOOTSTRAP.md` (and/or `.cursor/rules/` always-apply rule) so a new session reads `state.json` + handoff + TASK + report + latest review without a Human-authored dossier.
4. Extend handoff schema (`.agent/handoff.TEMPLATE.md` + `Write-Handoff`) as a **derived transport overlay** (C-001): pointers and `next_actor` / `next_action` generated from `state.json` + applicable review file. Never a competing SoT. Keep `.agent/handoff.md` gitignored. On contradiction: fail closed or regenerate; do not guess.
5. Add `scripts/workflow/bootstrap.ps1` (or equivalent extension of `status.ps1`) that **derives** role, TASK, round, next action, reads, forbidden, and `required_fixes_file` from `state.json` + review artifacts. If live handoff disagrees, fail closed (default) or regenerate (`-Repair`). Always Run candidate. No merge, no push `main`, no implementation writes.
6. Review template + protocol: the review file's `required_fixes` is the authoritative Coding input on `reject` (C-001). Structured IDs (B-nnn). Coding resumes from that file. Human must not paraphrase findings.
7. Review `reject` return flow (C-002): `in_review` → `coding`, `review_round += 1` **once**, `plan_approved` stays true. Handoff (regenerated) `next_actor=coding-agent` `next_action=fix-round`, `required_fixes_file` = the review file **just written** (`review-round-(old N).md`), not the new `review_round` number. Coding re-entry to `in_review` does **not** increment. Same protocol for every later round.
8. Review `approve` return flow: `in_review` → `git_ready`, `review_round` **unchanged**, handoff (regenerated) `next_actor=coding-agent` `next_action=open-pr-observe`. Existing `open-pr.ps1` → `observe-ci.ps1 -Wait` → Human Gate 2 path unchanged.
9. Document Cursor/product limitations: no Agent-spawned independent Review chat; no SDK auto-spawn; no Task-subagent-as-Review; Human Gate 1 and Gate 2 are not automated.
10. Local guardrail tests for C-001 conflict handling, C-002 increment table, bootstrap derive/fail-closed, and return-flow contracts. Existing D-001 / Gate 1 / merge-forbidden tests must still pass.
11. Write `.agent/reports/TASK-005C-E-report.md`. Independent Review is a **separate** session (D-003).
12. After Review **approve**, the same Coding session continues `git_ready` → PR → CI observe without a new Human Git Ready prompt (already V2.4; keep it).
13. **C-003 dogfood:** this TASK's own Independent Review loop must prove Human is spawn-only (see Validation).

## Constraints

Field: `constraints`

- Do not auto-merge; no `gh pr merge`; no merge script
- Do not automatically spawn a Review Agent session (SDK, Automations, or Coding-session subagent)
- Do not enable Branch Protection (TASK-005C-F)
- Do not change `.github/workflows/ci.yml`
- Do not modify business/application code under `apps/` or `agents/`
- Do not touch secrets / `.env`; do not print `.env`; do not commit `.env`
- Do not replace ChatGPT Planner
- Do not act as Independent Review Agent in the Coding session
- Do not merge `main` (Human Gate 2 stays)
- Do not force push
- Do not perform a normal (non-D-001) push to `main`
- Do not automate away Human Gate 1 or Human Gate 2
- Do not infer Gate 1 approval from conversation
- Do not modify implementation files before `plan_approved === true` (PRIMARY: `start-coding.ps1`)
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md` including D-001 archive-push after independent checks
- Do not open a PR until Review **approve** (`git_ready`)
- Do not treat `AGENT_D001_ARCHIVE=1` as push authorization
- Do not commit `.agent/runtime.json` or `.agent/handoff.md`

## Validation

Field: `validation`

How to verify completion:

- [ ] **C-003 dogfood:** new Independent Review session for this TASK receives at most `ROLE=review-agent` or `@handoff`; session derives TASK, `review_round`, artifacts, scope, restrictions, and next action from the repo (Human is spawn-only)
- [ ] **C-003 dogfood:** after reject, Human returns to Coding with at most `continue from handoff`; Coding reads `required_fixes_file` and B-nnn from the review file without Human copy/rephrase
- [ ] **C-001:** handoff that contradicts `state.json` / applicable review fails closed or is regenerated; Agents do not guess
- [ ] **C-002:** `review_round` matches the freeze table (no double increment / off-by-one); review file `N` is the round being reviewed
- [ ] `approve` returns through the review file + regenerated handoff into existing `git_ready` → `open-pr` → observe flow
- [ ] Repeated review rounds use the same protocol
- [ ] D-003 Independent Review remains a separate session; no self-review; no subagent substitute
- [ ] Human Gate 1 and Human Gate 2 are not automated
- [ ] No Review auto-spawn; no SDK/Automations spawn in this TASK
- [ ] No Branch Protection; no `apps/` / `agents/` / `ci.yml` changes
- [ ] No merge script; `gh pr merge` still refused
- [ ] `plan_approved` default false; `start-coding.ps1` still PRIMARY
- [ ] Local guardrails cover new bootstrap/handoff/return-flow contracts and still pass D-001 / Gate 1 / merge-forbidden tests
- [ ] Report under `.agent/reports/TASK-005C-E-report.md`
- [ ] Independent Review file under `.agent/reviews/` with `decision: approve` — **Review Agent**, not Coding
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`

## Branch

Field: `branch`

`task/TASK-005C-E-review-session-automation`

Do **not** create this branch before `plan_approved`. Create during `coding` after Gate 1. Push and PR only after Review **approve**.

## CI required

Field: `ci_required`

`no`

Protocol + scripts + Cursor rules only. After Review **approve** and PR, skip `ci_running` and use `ci_status: n/a` → `awaiting_merge`. Workflow still runs; app jobs skip; `ci-gate` should be green. `observe-ci` records the real `ci-gate` fact and protocol `n/a` without impersonating `passed`.

## Status

Field: `status`

`completed`
`plan_approved: true`. Independent Review Round 2 `decision: approve`. `review_round` stays **2** (C-002). Same Coding session continues `open-pr.ps1` → `observe-ci.ps1 -Wait`.

## Result

- Status: `completed`
- Report: `.agent/reports/TASK-005C-E-report.md`
- Review: `.agent/reviews/` (Independent Review file)
- Notes: Human merged `main`. Durable ci_status=n/a. PR https://github.com/brightHe2026/personal-ai-ecosystem/pull/5. Archived 2026-08-17T03:11:40+08:00.
