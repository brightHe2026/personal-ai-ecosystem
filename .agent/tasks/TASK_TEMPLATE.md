# Task Template

Use this template when creating a new task under `.agent/tasks/active/`.
Filename convention: `TASK-XXX-short-name.md`

Operational envelope for Workflow V2. Specification depth (background, architecture impact, file allow-lists) still follows `docs/AGENT_TASK_TEMPLATE.md` when the TASK needs it — copy those sections in below `## Requirements` rather than replacing this file.

---

## Task ID

`TASK-XXX`

Field: `task_id`

## Scope

Field: `scope`

One of: `apps/sales-agent` | `agents/knowledge-agent` | `docs` | `ecosystem` | `.agent`

## Agent Role

Options: `Coding-Agent` | `Review-Agent` | `Knowledge-Agent` | `ChatGPT` | `Cursor` | `Planner`

Primary implementer for this TASK (usually `Coding-Agent`).

## Goal

Field: `goal`

Describe the expected outcome in one or two sentences.

## Requirements

Field: `requirements`

1. ...
2. ...
3. ...

## Constraints

Field: `constraints`

- Do not modify unrelated business code
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md`: commits allowed only on `task/*`; never commit or push `main` except D-001 `archive-push.ps1` after independent checks
- Do not modify implementation files before `plan_approved === true` (PRIMARY: `start-coding.ps1`)
- Do not open a PR until Review **approve** (`git_ready`)
- Do not merge `main` (Human only)
- Do not treat `AGENT_D001_ARCHIVE=1` as push authorization

## Validation

Field: `validation`

How to verify completion:

- [ ] Directory / files exist as specified
- [ ] Tests pass (if applicable)
- [ ] Report written under `.agent/reports/`
- [ ] Independent Review file under `.agent/reviews/` with `decision: approve`
- [ ] PR associated TASK + report + review (after `git_ready`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`

## Branch

Field: `branch`

Intended git branch (create at `coding` after Gate 1, not required at `specified`):

`task/TASK-XXX-short-name`

## CI required

Field: `ci_required`

`yes` | `no`

- `yes` — after `git_ready`, enter `ci_running`. `awaiting_merge` only on required check `ci-gate` pass.
- `no` — after `git_ready`, skip `ci_running` and enter `awaiting_merge` with `ci_status: n/a`.

Typical: `yes` for `apps/sales-agent` and `agents/knowledge-agent`; `no` for `.agent` / `docs` protocol TASKs.

## Status

Field: `status`

Workflow V2 (required on new tasks):

`specified` | `coding` | `in_review` | `git_ready` | `ci_running` | `awaiting_merge` | `completed` | `blocked` | `cancelled`

Gate 1 (D-002): `specified` → Implementation Plan → STOP → Human/Planner machine-readable APPROVED → `plan_approved: true` on `.agent/state.json` → `start-coding.ps1` → `coding`.

Default when creating a TASK: `plan_approved: false`. Human/Planner is the sole Gate 1 approval authority. Coding must not infer approval from chat.

New sessions bootstrap from `.agent/BOOTSTRAP.md`. Independent Review spawn is Human-only (`ROLE=review-agent` or `@handoff`). `review_round` increments only on Review reject (C-002).

## Result

Fill as the TASK moves. V1 fields kept for TASK-003 compatibility.

- Status: same as `status` above. Legacy aliases: `pending` | `in_progress` | `completed` | `blocked`
- Report: `.agent/reports/TASK-XXX-report.md`
- Review: `.agent/reviews/TASK-XXX-review-round-N.md`
- Notes:
