# TASK-005C-C — Personal AI Ecosystem CI Gate / Workflow State Integration

Filename convention satisfied: `TASK-005C-C-ci-state-integration.md`

---

## Task ID

`TASK-005C-C`

Field: `task_id`

## Scope

Field: `scope`

`ecosystem`

Protocol + `scripts/workflow` observer wrappers. Does not change `.github/workflows/ci.yml` or application business behavior.

## Agent Role

`Coding-Agent`

Review must be a separate Cursor session (`Review-Agent`). This Coding Agent must not self-review.

## Goal

Field: `goal`

Integrate the TASK-005C-B `ci-gate` check with Workflow V2 so Coding Agent observes GitHub Checks and drives live `git_ready` → `ci_running` → `awaiting_merge` without Actions writing git and without Agent merge of `main`.

## Requirements

Field: `requirements`

1. Create this TASK file and update `.agent/state.json` (`active_task: TASK-005C-C`, `ci_required: false`).
2. Follow TASK-005C-A D1–D3 and TASK-005C-C Architecture & Scope Review:
   - GitHub Checks (`ci-gate`) remain CI runtime source of truth.
   - `.agent/state.json` remains intent + durable archive.
   - Live protocol view is gitignored `.agent/runtime.json`.
   - GitHub Actions must not commit, push, or edit `state.json`.
3. Add `.agent/runtime.json` to `.gitignore`. Document schema in `ci-gate.md`.
4. Implement `scripts/workflow/` wrappers (PowerShell):
   - `open-pr.ps1` — after Review approve, on `task/*` only; `gh pr create`; write runtime; reuse existing PR.
   - `observe-ci.ps1` — map real `ci-gate` only; never forge `passed`; never treat skipped app jobs as failure.
   - `status.ps1` — read-only print of Checks + runtime + `state.json`.
   - `finalize-prep.ps1` — only on synced `main` after PR merged; prepare archive; **do not push**.
5. Hard refuse: `gh pr merge`, push `main`, open PR without `decision: approve`, `ci_required: yes` → `awaiting_merge` unless `ci-gate` is actually green.
6. Patch `.agent` protocol (lifecycle / git-pr / ci-gate / coding-agent / README) so Human no longer copies PR body or transcribes CI; Coding Agent observes GitHub via the scripts.
7. Fix leftover N-001 wording in `task-lifecycle.md` (`Human n/a exception`) because this TASK edits that file.
8. Local guardrail tests. Write `.agent/reports/TASK-005C-C-report.md`.
9. Stop at `in_review`. Do not push, open a PR, merge, or self-review in this Coding session.

## Constraints

Field: `constraints`

- Do not modify sibling `sales-agent` repository
- Do not modify business function code under `apps/` or `agents/`
- Do not modify `.github/workflows/ci.yml` job matrix
- Do not start TASK-005C-D
- Do not enable Branch Protection
- Do not act as Independent Review Agent
- Do not merge `main`
- Do not bypass Human Merge Gate
- Do not give Actions `contents: write`
- Do not write secrets or print `.env`
- Do not commit `.env`
- Do not force push
- Do not commit to `main`
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md`: commits allowed only on `task/*`; never commit or push `main`
- Do not open a PR until Review **approve** (`git_ready`)
- Do not add a `merge` script
- Do not auto-start Review sessions

## Validation

Field: `validation`

How to verify completion:

- [x] TASK file exists under `.agent/tasks/active/`
- [x] `.agent/runtime.json` is gitignored; schema documented
- [x] `scripts/workflow/` wrappers exist with refuse-on-main / refuse-without-approve / no merge
- [x] `observe-ci` maps only real `ci-gate`; failure cannot enter `awaiting_merge` when `ci_required: yes`
- [x] Protocol patches: Checks remain SoT; Actions must not write git; no post-PR `state.json` commit
- [x] Local guardrail tests pass
- [x] Report written under `.agent/reports/TASK-005C-C-report.md`
- [ ] Independent Review file under `.agent/reviews/` with `decision: approve` — **Review Agent**, not this session
- [x] No sibling repo changes; no unrelated business code; no secrets / `.env` / `__pycache__` committed
- [ ] PR associated TASK + report + review (after `git_ready`, via `open-pr.ps1`)
- [ ] CI passed **or** `ci_required: no` with `ci_status: n/a`
- [ ] Human merged `main`

## Branch

Field: `branch`

`task/TASK-005C-C-ci-state-integration`

Created during `coding`. Push and PR only after Review **approve**.

## CI required

Field: `ci_required`

`no`

Protocol + scripts only. After Review **approve** and PR, skip `ci_running` and use `ci_status: n/a` → `awaiting_merge`. Workflow still runs; app jobs skip; `ci-gate` should be green. `observe-ci` records `ci_gate` fact and protocol `n/a` together without impersonating `passed`.

## Status

Field: `status`

`git_ready`

## Result

- Status: `git_ready`
- Report: `.agent/reports/TASK-005C-C-report.md`
- Review: `.agent/reviews/TASK-005C-C-review-round-1.md` (`decision: approve`)
- Notes: Independent Review Round 1 approved. Pre-PR delivery. `ci_required: no`. Do not forge `passed`. Live `awaiting_merge` / `n/a` is overlay after PR, not this `state.json` commit.
