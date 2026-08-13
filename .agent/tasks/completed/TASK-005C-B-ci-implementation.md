# TASK-005C-B — Personal AI Ecosystem CI Gate Implementation

Filename convention satisfied: `TASK-005C-B-ci-implementation.md`

---

## Task ID

`TASK-005C-B`

Field: `task_id`

## Scope

Field: `scope`

`ecosystem`

Touches `.github/workflows/` (new) and the minimum `.agent` protocol patches required to match TASK-005C-A source-of-truth decisions. Does not change application business behavior.

## Agent Role

`Coding-Agent`

Review must be a separate Cursor session (`Review-Agent`). This Coding Agent must not self-review.

## Goal

Field: `goal`

Implement a path-aware GitHub Actions CI MVP for the `personal-ai-ecosystem` monorepo, with a stable aggregate check named `ci-gate`, and patch Workflow V2 so GitHub Checks are the CI runtime source of truth while `.agent/state.json` remains intent plus durable record.

## Requirements

Field: `requirements`

1. Create this TASK file and update `.agent/state.json` (`active_task: TASK-005C-B`, `ci_required: true`).
2. Create `.github/workflows/ci.yml` for this monorepo. Do **not** copy sibling `sales-agent` TASK-004 `ci.yml` blindly.
3. Follow TASK-005C-A architecture:
   - One workflow, always triggered on `pull_request` and `push` to `main` (no workflow-level `on.paths` skip).
   - Native `git diff` path detection (no `dorny/paths-filter`).
   - Jobs: `changes`, `sales-agent-backend`, `sales-agent-frontend`, `knowledge-agent-backend`, `ci-gate`.
   - `permissions.contents: read` only.
   - GitHub Actions must not commit, push, or modify `state.json`.
4. `sales-agent-backend`: Python 3.12, `pip install -r requirements.txt`, FastAPI import check. Do **not** run pytest (no tests). Do **not** treat pytest exit 5 as success.
5. `sales-agent-frontend`: Node 20, `npm ci`, `npm run build`.
6. `knowledge-agent-backend`: Python 3.12, `pip install -r requirements.txt`, `pytest -q` (or `python -m pytest -q`). No Postgres service. No secrets. Do not read or commit `.env`. Do not change business code to make CI pass.
7. `.github/workflows/**` changes run **all** app jobs. `push` to `main` runs all app jobs. Protocol/docs-only PRs must not fail because app jobs were skipped (`ci-gate` treats `skipped` as pass).
8. Stable aggregate job `ci-gate` is the only check intended for future Branch Protection.
9. Patch `.agent/workflows/ci-gate.md` (and lifecycle / git-pr / coding-agent as needed):
   - GitHub Checks = CI runtime source of truth
   - `state.json` = intent + durable record
   - No Actions git writes; no post-PR metadata self-commit
   - Retire Human exception §2.3 once this workflow exists
10. Write `.agent/reports/TASK-005C-B-report.md`.
11. Stop at `in_review` for independent Review. Do not push, open a PR, merge, or self-review.

## Constraints

Field: `constraints`

- Do not modify sibling `sales-agent` repository
- Do not modify business function code under `apps/` or `agents/`
- Do not start TASK-005C-C
- Do not act as Independent Review Agent
- Do not merge `main`
- Do not bypass Human Merge Gate
- Do not modify GitHub Branch Protection
- Do not write secrets
- Do not commit `.env`
- Do not force push
- Do not commit to `main`
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Follow `.agent/workflows/git-pr.md`: commits allowed only on `task/*`; never commit or push `main`
- Do not open a PR until Review **approve** (`git_ready`)
- Do not pin knowledge-agent requirements or untrack `.env` (separate debt; out of scope)
- Do not retire sibling CI (out of scope)

## Validation

Field: `validation`

How to verify completion:

- [x] TASK file exists (archived to `.agent/tasks/completed/` after Human merge)
- [x] `.github/workflows/ci.yml` exists and uses monorepo paths (not TASK-004 `backend/` / `frontend/`)
- [x] Official actions only; `permissions.contents: read`; no `contents: write`
- [x] Path detection is native `git diff` (no third-party paths-filter)
- [x] `ci-gate` aggregates required jobs; skip → success; any required failure → failure
- [x] Frontend uses `npm ci`; sales-agent backend does not fake pytest; knowledge-agent runs pytest; no global exit 5
- [x] Protocol patches match Checks-as-SoT; §2.3 retired; no Actions commit loop
- [x] Report written under `.agent/reports/TASK-005C-B-report.md`
- [x] Independent Review file under `.agent/reviews/` with `decision: approve` — **Review Agent**, not this session
- [x] No sibling repo changes; no unrelated business code; no secrets / `.env` / `__pycache__` committed
- [x] PR associated TASK + report + review — https://github.com/brightHe2026/personal-ai-ecosystem/pull/2
- [x] CI passed — Human reported 5 GitHub checks green on PR #2; Actions shows CI run for PR #2 and for merge `4f551b3`
- [x] Human merged `main` — `4f551b3` (PR #2)

## Branch

Field: `branch`

`task/TASK-005C-B-ci-implementation`

Created during `coding`. Pushed after Review Round 1 **approve**. Human opened and merged PR #2.

## CI required

Field: `ci_required`

`yes`

Dogfood complete: PR #2 ran GitHub Actions; Human reported 5 checks passed; merge commit `4f551b3` is on `main`.

## Status

Field: `status`

`completed`

## Result

- Status: `completed`
- Report: `.agent/reports/TASK-005C-B-report.md`
- Review: `.agent/reviews/TASK-005C-B-review-round-1.md` (`decision: approve`)
- PR: https://github.com/brightHe2026/personal-ai-ecosystem/pull/2
- Merge: `4f551b3` (Human)
- Notes: Archived after Human merge. `review_round: 1`. `ci_required: yes`. `ci_status: passed` (GitHub Checks on PR #2; Human reported 5 checks green). N-001–N-004 remain non-blocking follow-ups. Do not start TASK-005C-C from this session.
