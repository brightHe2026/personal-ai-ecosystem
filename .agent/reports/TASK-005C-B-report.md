# TASK-005C-B Implementation Report

## Task ID

`TASK-005C-B`

## Changes

List created, modified, or deleted files:

- Created:
  - `.agent/tasks/active/TASK-005C-B-ci-implementation.md`
  - `.github/workflows/ci.yml`
  - `.agent/reports/TASK-005C-B-report.md`
- Modified:
  - `.agent/state.json` (`active_task: TASK-005C-B`, `status: in_review`, `review_round: 1`, `ci_required: true`, `ci_status: not_started`, `pr_url: null`; schema keys kept)
  - `.agent/workflows/ci-gate.md` (v1.1 → v1.2: Checks-as-SoT, §2.3 retired, implemented job matrix)
  - `.agent/workflows/task-lifecycle.md` (v2.1 → v2.2: no post-PR metadata commit; §2.3 removed from legal exits)
  - `.agent/workflows/git-pr.md` (v1.1 → v1.2: no post-PR `state.json` commit; `ci-gate` is the required check)
  - `.agent/agents/coding-agent.md` (mirror Checks; forbid bookkeeping commit and retired §2.3)
  - `.agent/README.md` (CI index: `.github/workflows/ci.yml` + `ci-gate`)
  - `.agent/tasks/TASK_TEMPLATE.md` (`ci_required: yes` no longer points at §2.3)
- Deleted:
  - None

Not changed (hard boundary):

- `apps/` and `agents/` business code
- sibling `sales-agent` repository
- GitHub Branch Protection / secrets / `.env`
- no TASK-005C-C artifacts

## Tests

Describe verification steps and results:

- Command(s) run:
  - Preflight: `git status`, `git branch --show-current`, `git remote -v`, `git log -5 --oneline`, `git fetch origin` (clean `main` @ `e53fd35`, synced with `origin/main`)
  - Path existence for every `working-directory` / cache-dependency-path / test file referenced by CI
  - Workflow structure grep: official actions, `contents: read`, `npm ci`, Python 3.12, Node 20, `ci-gate` + `if: always()`, no `secrets.`, no `git commit`/`git push`, no pytest exit 5, no extra `pip install pytest`, no workflow-level `on.paths`
  - `bash -n` on the four `|` run scripts (path detection, two pip installs, ci-gate aggregate)
  - `git diff --name-only -- apps agents` (empty)
  - `state.json` schema keys + TASK-005C-B field values
- Result: `pass` for local structural checks. **Not** a GitHub Actions PASS.
- Notes:
  - This machine has no real Python interpreter and no `npm` (only a WindowsApps python stub and Cursor helper `node.exe`).
  - FastAPI import, `python -m pytest -q`, `npm ci`, and `npm run build` were **not** executed locally.
  - Job skip / aggregate behavior cannot be executed without GitHub runners.
  - Those items are marked **requires GitHub E2E validation**. They are not recorded as PASS.

## Implementation summary

TASK-005C-A recommended a monorepo CI MVP that is not a copy of sibling TASK-004 `ci.yml`. This round implements that architecture:

1. One always-on workflow (PR + push to `main`).
2. Native `git diff` path detection in job `changes`.
3. Three app jobs with monorepo paths.
4. Stable aggregate job `ci-gate`.
5. Workflow V2 protocol patched so GitHub Checks are runtime SoT and Actions never write git.

Deliberate differences from TASK-004 sibling CI:

| TASK-004 (sales-agent) | This repo |
|------------------------|-----------|
| `working-directory: backend` / `frontend` | `apps/sales-agent/backend` / `frontend` plus `agents/knowledge-agent/backend` |
| `npm install` | `npm ci` |
| pytest + treat exit 5 as success | sales-agent: **no pytest**; knowledge-agent: pytest, exit 5 fails |
| extra `pip install pytest` | only `requirements.txt` |
| no path filter | native path detection + `ci-gate` |
| no V2 / `state.json` contract | Checks = SoT; Actions must not commit state |

## CI architecture

```
pull_request / push → main
        ↓
   changes (always)
        ↓
   sales-agent-backend     (if sales backend or run-all)
   sales-agent-frontend    (if sales frontend or run-all)
   knowledge-agent-backend (if knowledge backend or run-all)
        ↓
   ci-gate (always; skip=ok, fail=red)
```

- `permissions.contents: read` only.
- Official actions only: `actions/checkout@v4`, `actions/setup-python@v5`, `actions/setup-node@v4`.
- Concurrency cancels stale runs on the same PR/ref.
- No third-party path-filter action. Workflow-level `on.paths` is not used because a skipped workflow cannot satisfy a future required check.

## Path detection

Job `changes` uses GitHub-native `git diff --name-only <base>...<head>` (`pull_request.base.sha` / `head.sha`, `fetch-depth: 0`).

Run-all (all three app flags true):

- `push` to `main`
- any path under `.github/workflows/**`

Otherwise flags are independent:

- `apps/sales-agent/backend/**` → `sales-agent-backend`
- `apps/sales-agent/frontend/**` → `sales-agent-frontend`
- `agents/knowledge-agent/backend/**` → `knowledge-agent-backend`

Protocol/docs-only (`.agent/**`, `docs/**`, including a lone `state.json` change) leaves all app flags false. App jobs skip. `ci-gate` still runs and must pass.

Native job-level `paths:` does not exist on GitHub Actions. That is why workflow-level `on.paths` was rejected (TASK-005C-A option A) and a third-party paths-filter action was not added (option C).

## Job matrix

| Job | When | Runtime | Commands |
|-----|------|---------|----------|
| `changes` | always | ubuntu-latest | native git diff → outputs |
| `sales-agent-backend` | sales backend or run-all | Python 3.12 | `pip install -r requirements.txt`; `from app.main import app` |
| `sales-agent-frontend` | sales frontend or run-all | Node 20 | `npm ci`; `npm run build` |
| `knowledge-agent-backend` | knowledge backend or run-all | Python 3.12 | `pip install -r requirements.txt`; `rm -f .env`; `python -m pytest -q` |
| `ci-gate` | always (`if: always()`) | ubuntu-latest | aggregate results |

This TASK's own PR changes `.github/workflows/**`, so the first GitHub run should execute **all** app jobs (dogfood).

## ci-gate behavior

`ci-gate` is the only name intended for future Branch Protection.

| Input | `ci-gate` |
|-------|-----------|
| `changes` = success; each app job = success or skipped | success |
| any required app job = failure / cancelled / other | failure |
| `changes` ≠ success | failure |

Skipped app jobs (protocol-only PR) are **not** failure. That is required so docs/`.agent` PRs do not fail because no business code changed.

Do not protect the three app jobs individually. A skipped required job would block protocol-only PRs.

GitHub UI may display the check as `CI / ci-gate`. Human enabling Branch Protection in TASK-005C-D must select the name shown on the first real run. Marked **requires GitHub E2E validation**.

## Workflow V2 integration

| Layer | Role |
|-------|------|
| GitHub Actions / Checks (`ci-gate`) | CI **runtime** source of truth |
| `.agent/state.json` | TASK intent + durable record (may lag) |
| Human merge | only path to `completed` |

Hard rules implemented in protocol + workflow:

- Actions `permissions.contents: read` — cannot commit `state.json`
- No post-PR bookkeeping commit of `pr_url` / `ci_status` (TASK-005B `cf55243` anti-pattern)
- Semantics remain: `git_ready` → `ci_running` → `awaiting_merge` on pass; fail → recovery, never `awaiting_merge`
- `ci_required: no` still uses `ci_status: n/a`; workflow still runs; app jobs skip; `ci-gate` should be green
- `ci-gate.md` §2.3 Human exception is **retired**

GitHub Actions does not modify repository state. There is no CI → commit → CI loop.

## Local validation

| Check | Result |
|-------|--------|
| Referenced paths exist | pass |
| YAML structure / job names / official actions | pass |
| `bash -n` on `|` scripts | pass |
| No secrets context / no git write / no `.env` commit | pass |
| No apps/agents business diff | pass |
| `state.json` schema preserved | pass |
| FastAPI import on this machine | **not run** — no Python 3.12 |
| knowledge-agent pytest on this machine | **not run** — no Python 3.12 |
| `npm ci` / `npm run build` on this machine | **not run** — no npm |
| GitHub job skip + `ci-gate` aggregate | **not run** — requires GitHub Actions |
| Branch Protection | **not changed** (forbidden) |

Do not treat this report as a forged CI PASS.

## Known limitations

- knowledge-agent `requirements.txt` is unpinned (CI drift risk). Out of scope to pin.
- `agents/knowledge-agent/backend/.env` remains git-tracked (pre-existing). This TASK does not print, commit, or untrack it. The knowledge-agent job deletes `.env` on the **runner workspace** before pytest so `load_dotenv()` cannot load secrets. Separate security TASK still needed to untrack + rotate.
- `app/core/database.py` calls `create_engine` at import. Current tests mock the session; MVP does not start Postgres. Future imports that actually connect will fail in CI.
- Sibling `brightHe2026/sales-agent` CI is not retired.
- Fork PRs fetching `head.sha` from `origin` may be fragile; this is a personal same-repo workflow. Fail-closed if SHAs are missing.
- Exact Branch Protection check string (`ci-gate` vs `CI / ci-gate`) needs the first GitHub run.

## GitHub-only validation items

requires GitHub E2E validation (after Review approve + PR, not this session):

1. Workflow file is recognized and job `ci-gate` appears.
2. This TASK PR (workflow change) runs all three app jobs.
3. FastAPI import succeeds on ubuntu-latest / Python 3.12.
4. `npm ci` + `npm run build` succeed on Node 20.
5. knowledge-agent `python -m pytest -q` succeeds without secrets or Postgres.
6. A docs/`.agent`-only commit skips app jobs and `ci-gate` is still green.
7. An intentional failing job turns `ci-gate` red.
8. Actions does not produce a commit on the branch.
9. Confirm the check name shown in the GitHub UI for Branch Protection.

## Security checks

- `permissions.contents: read` only
- no `secrets.*`
- no `.env` committed by this TASK
- knowledge-agent runner removes `.env` before tests (does not print it)
- no `__pycache__` added
- no sibling repo access/modification
- workflow does not dump environment

## Issues

- GitHub E2E for skip-only (protocol/docs) PRs was not a separate PR; PR #2 changed `.github/workflows/**` so all app jobs ran (intended dogfood).
- Local Python/npm toolchain is still missing; GitHub runners executed those commands.
- Pre-existing tracked `.env` is still security debt (not fixed here).
- N-001–N-004 remain non-blocking follow-ups.

## Commit

- `80dbc84` `feat: add monorepo CI gate for personal-ai-ecosystem`
- `a4d11c0` `docs: record TASK-005C-B local commit hash`
- `5a5d8e6` `chore: enter git_ready for TASK-005C-B after review approve`
- Merge: `4f551b3` `Merge pull request #2 from brightHe2026/task/TASK-005C-B-ci-implementation` (Human)

## Branch

`task/TASK-005C-B-ci-implementation`

Merged to `main` via PR #2. Remote task branch was not deleted.

## Review Status

`approve` (Independent Review Round 1: `.agent/reviews/TASK-005C-B-review-round-1.md`. N-001–N-004 non-blocking; no Fix Round.)

## Ready for review

Complete. Human merged. TASK archived to `completed/`.

## Next Steps

1. Human may push the local archive commit on `main` (this Finalization session does not push).
2. Do not enable Branch Protection until TASK-005C-D.
3. Do **not** start TASK-005C-C from this session.
