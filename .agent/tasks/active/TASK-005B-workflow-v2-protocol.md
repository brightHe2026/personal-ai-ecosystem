# TASK-005B — Agent Workflow V2 Protocol Implementation

Filename convention satisfied: `TASK-005B-workflow-v2-protocol.md`

---

## Task ID

`TASK-005B`

## Scope

`.agent`

Also touches `docs/AGENTS.md`, `docs/CODING_AGENT_RULES.md`, `docs/AGENT_TASK_TEMPLATE.md` for cross-references only.

## Agent Role

`Coding-Agent`

Review must be a separate Cursor session (`Review-Agent`).

## Goal

Incrementally upgrade the TASK-003 `.agent/` protocol into Workflow V2: state machine, templates, Review artifact, Git/PR and CI-gate **protocol** (no GitHub Actions, no commit/PR in this session).

## Requirements

1. Create `.agent/README.md` as the workflow index.
2. Upgrade `.agent/workflows/task-lifecycle.md` to V2 with the required states and `in_review` → `coding` fix loop + `review_round`.
3. Extend `.agent/state.json` with `status`, `review_round`, `pr_url`, `ci_status`, and Review Agent; keep TASK-003 keys; do not fake `last_completed_task`.
4. Unify `.agent/tasks/TASK_TEMPLATE.md` with `task_id`, `scope`, `goal`, `requirements`, `constraints`, `validation`, `branch`, `status`, `result` without deleting TASK-003 fields.
5. Unify `.agent/reports/REPORT_TEMPLATE.md` with Changes, Tests, Issues, Commit, Branch, Review Status, Next Steps.
6. Add Review template under `.agent/reviews/`.
7. Add Git/PR protocol: `task/TASK-XXX-short-name`, no `main` commits by agents, PR links TASK+report+review, no auto-merge.
8. Add CI Gate protocol only (`git_ready` → `ci_running` → `awaiting_merge`); no `.github/workflows`.
9. Cross-reference `docs/AGENTS.md`, `docs/CODING_AGENT_RULES.md`, `docs/AGENT_TASK_TEMPLATE.md` without deleting existing rules.
10. Manage this TASK under `.agent/tasks/active/` and update `state.json`.
11. Write `.agent/reports/TASK-005B-report.md`.
12. Stop without commit, push, or PR; wait for independent Review.

## Constraints

- Do not modify unrelated business code
- Do not create `.github/workflows` or migrate CI (TASK-005C)
- Do not create PR, push, merge, or commit in this Coding session
- Do not delete or rebuild `.agent`
- Do not modify `apps/` or `agents/` business implementation
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md` (this TASK is the documented exception: no commit this session)

## Validation

How to verify completion:

- [ ] `.agent/README.md` exists and indexes V2 protocol
- [ ] `task-lifecycle.md` documents all required states and reject loop
- [ ] `state.json` has V2 fields + `agents.review`; `last_completed_task` is still `null`
- [ ] TASK / Report / Review templates contain required fields
- [ ] `git-pr.md` and `ci-gate.md` exist; no `.github/workflows` added
- [ ] docs cross-references updated, original rules kept
- [ ] This file is under `.agent/tasks/active/`
- [ ] Report written under `.agent/reports/TASK-005B-report.md`
- [ ] No commit / push / PR from this session
- [ ] Independent Review file under `.agent/reviews/` — **Review Agent**, not this session

## Branch

`task/TASK-005B-workflow-v2-protocol`

Not created in this Coding session (protocol task stops at `in_review`).

## CI required

`no`

Protocol-only TASK. After a future Review **approve** and PR, skip `ci_running` and use `ci_status: n/a` → `awaiting_merge`. This session still must not commit, push, or open a PR.

## Status

`in_review`

## Result

- Status: `in_review`
- Report: `.agent/reports/TASK-005B-report.md`
- Review Round 1: **REJECT** (B-001, B-002). Independent Review session did not write `.agent/reviews/` (review-agent constraint).
- Review Round 2: pending independent Review Agent (`review_round: 2`)
- Notes: First Workflow V2 managed TASK and first Fix Loop. TASK-003 remains unarchived (`last_completed_task` left `null`). `ci_required: no`.
