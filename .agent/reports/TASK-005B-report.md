# TASK-005B Implementation Report

## Task ID

`TASK-005B`

## Changes

List created, modified, or deleted files:

- Created:
  - `.agent/README.md`
  - `.agent/workflows/git-pr.md`
  - `.agent/workflows/ci-gate.md`
  - `.agent/reviews/REVIEW_TEMPLATE.md`
  - `.agent/agents/planner.md`
  - `.agent/agents/coding-agent.md`
  - `.agent/agents/review-agent.md`
  - `.agent/tasks/active/TASK-005B-workflow-v2-protocol.md`
  - `.agent/reports/TASK-005B-report.md`
- Modified:
  - `.agent/workflows/task-lifecycle.md` (V1 → V2; V1 kept as changelog; V2.1 CI paths)
  - `.agent/tasks/TASK_TEMPLATE.md` (V1 fields kept; V2 fields + `ci_required`)
  - `.agent/reports/REPORT_TEMPLATE.md` (Commit, Branch, Review Status added)
  - `.agent/state.json` (V2 fields + Review Agent; `last_completed_task` still `null`)
  - `docs/AGENTS.md`
  - `docs/CODING_AGENT_RULES.md`
  - `docs/AGENT_TASK_TEMPLATE.md`
- Deleted:
  - None

## Tests

Describe verification steps and results:

- Command(s) run:
  - File presence check for README, lifecycle, git-pr, ci-gate, templates, TASK-005B active file, report
  - Grep lifecycle for all nine states + `review_round`
  - Grep templates for required field names
  - Confirm `.github/` absent
  - `git diff --name-only -- apps agents` (empty)
  - Inspect `state.json`: TASK-003 keys present, `last_completed_task` is `null`, `agents.review` present
- Result: `pass` (initial implementation). Round 1 Independent Review **REJECT** (see below). Fix-round checks are under Validation.

## Issues

- CI Gate is protocol only. No Actions workflow yet (TASK-005C).
- Suggested 3-round review cap is documented, not enforced by a script.
- TASK-003 remains historically unqueued; not backfilled.
- This session created no `task/*` branch (required stop at `in_review`).
- Review Round 1 did not persist a file under `.agent/reviews/` (Review Agent was forbidden to write). Decision is recorded here and in the TASK Result.

## Commit

- none

## Branch

- none (`task/TASK-005B-workflow-v2-protocol` is the intended name after Review approve)

## Review Status

`pending` (Round 2). Round 1 decision was **reject**, not approve.

## Review Round 1

Decision: **REJECT**

Source: Independent Review Agent session (not this Coding Agent). `review_round` was 1.

Blocking issues:

- **B-001** — CI failure: `ci-gate.md` allowed both in-place `task/*` push and “return to `in_review`”, but lifecycle did not allow `ci_running → in_review`. Agents had no single legal recovery path (`ci_running` dead-end / Review skip).
- **B-002** — `ci_status: n/a` was defined but never connected to `awaiting_merge` or `completed`. With no `.github/workflows`, no TASK (including this one) could finish without inventing `passed` or jumping states.

Non-blocking N-001–N-008 were not in this fix round.

## Fixes Applied

- **B-001:** One recovery model in both lifecycle and ci-gate. After CI fail: (1) in-scope retry stays `ci_running`; (2) out-of-scope fix is `ci_running` → `coding` then report → `in_review`; (3) Human `blocked` / `cancelled`. No `ci_running` → `in_review` shortcut. No `awaiting_merge` on failure.
- **B-002:** TASK field `ci_required`. `yes` keeps `git_ready → ci_running → awaiting_merge` on pass. `no` skips CI: `git_ready → awaiting_merge` with `ci_status: n/a`. Human-only exception when CI is required but workflows do not exist yet. `n/a` is a defined event, not `passed`.

Minimal related sync: `git-pr.md`, `README.md`, `TASK_TEMPLATE.md`, `coding-agent.md`, this TASK file, `state.json` `ci_required`.

## Validation

- CI-required: `git_ready` → `ci_running`; pass → `awaiting_merge`; fail → retry / `coding` / `blocked` / `cancelled`; never `awaiting_merge` on fail.
- CI-not-required: `git_ready` → `awaiting_merge` (`ci_status: n/a`); skips `ci_running`.
- Human merge remains the only path to `completed`.
- Review approve remains the only normal entry to `git_ready`.
- Review reject remains `in_review` → `coding` with `review_round += 1`.
- After this fix: `status: in_review`, `review_round: 2`.
- No commit, push, PR, merge, or `.github/workflows`.

## Ready for Review Round 2

YES

## Next Steps

1. Independent Review Agent Round 2: use `.agent/reviews/REVIEW_TEMPLATE.md` with `review_round: 2`.
2. If `approve`, a later session may create `task/TASK-005B-workflow-v2-protocol` and open a PR (not this session). Because `ci_required: no`, that PR would go to `awaiting_merge` with `ci_status: n/a`.
3. TASK-005C: migrate GitHub Actions CI into this repository for `ci_required: yes` TASKs.
4. Do not treat Round 1 as APPROVE.
