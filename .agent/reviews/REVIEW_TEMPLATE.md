# Agent Review Template

Copy this file to `.agent/reviews/TASK-XXX-review-round-N.md`.
`N` must match `.agent/state.json` `review_round`.

Review Agent must be an independent Cursor session. Coding Agent must not fill this file for its own TASK.

---

## Task ID

`TASK-XXX`

Field: `task_id`

## Reviewer

Field: `reviewer`

Independent Review Agent session identifier (chat title or agent name). Not the Coding Agent session.

## Review Round

Field: `review_round`

Integer matching `state.json`.

## Decision

Field: `decision`

`approve` | `reject`

- `approve` → `status` becomes `git_ready`
- `reject` → `status` becomes `coding` and `review_round` increases by 1

## Blocking Issues

Field: `blocking_issues`

Must be empty (or `None`) for `approve`.

- ...

## Non-blocking Issues

Field: `non_blocking_issues`

May exist on `approve`. Must not block `git_ready`.

- ...

## Required Fixes

Field: `required_fixes`

Required when `decision` is `reject`. Coding Agent must address these in the next `coding` round.

- ...

## Validation Result

Field: `validation_result`

Check the TASK Validation section:

- [ ] Directory / files exist as specified
- [ ] Tests pass (if applicable)
- [ ] Report written under `.agent/reports/`
- [ ] Scope respected (no forbidden paths)
- [ ] Git / PR / CI protocol respected for this phase

Notes:
