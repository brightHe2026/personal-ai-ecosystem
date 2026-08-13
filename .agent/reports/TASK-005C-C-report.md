# TASK-005C-C Implementation Report

## Task ID

`TASK-005C-C`

## Changes

List created, modified, or deleted files:

- Created:
  - `.agent/tasks/active/TASK-005C-C-ci-state-integration.md`
  - `.agent/reports/TASK-005C-C-report.md`
  - `scripts/workflow/lib.ps1`
  - `scripts/workflow/open-pr.ps1`
  - `scripts/workflow/observe-ci.ps1`
  - `scripts/workflow/status.ps1`
  - `scripts/workflow/finalize-prep.ps1`
  - `scripts/workflow/test-guardrails.ps1`
- Modified:
  - `.gitignore` (`.agent/runtime.json`, `.agent/runtime.json.bak`)
  - `.agent/state.json` (`active_task: TASK-005C-C`, `status: git_ready`, `review_round: 1`, `ci_required: false`, `ci_status: not_started`, `pr_url: null`; schema keys kept)
  - `.agent/reviews/TASK-005C-C-review-round-1.md` (Independent Review; not written by this Coding session)
  - `.agent/workflows/ci-gate.md` (v1.2 → v1.3: three-layer SoT; observer scripts; runtime schema)
  - `.agent/workflows/task-lifecycle.md` (v2.2 → v2.3: live overlay; N-001 leftover `Human n/a exception` removed from `ci_running` exits)
  - `.agent/workflows/git-pr.md` (v1.2 → v1.3: `open-pr.ps1` / `observe-ci.ps1`; forbid `gh pr merge`)
  - `.agent/agents/coding-agent.md` (must use observer scripts; must not merge or commit runtime)
  - `.agent/README.md` (flow + index for scripts and gitignored runtime overlay)
- Deleted:
  - None

Not changed (hard boundary):

- `apps/` and `agents/` business code
- `.github/workflows/ci.yml` (still `contents: read`; no git write)
- sibling `sales-agent` repository
- GitHub Branch Protection / secrets / `.env`
- no TASK-005C-D artifacts

## Tests

Describe verification steps and results:

- Command(s) run:
  - Preflight: `git fetch origin`; `main` == `origin/main` @ `93d759a`; working tree was clean before this TASK
  - `gh` (full path `C:\Program Files\GitHub CLI\gh.exe`) `auth status`: logged in as `brightHe2026`, git protocol SSH, repo access confirmed; PR #2 `MERGED`
  - `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1`
  - `git check-ignore -v .agent/runtime.json`
  - `git diff --name-only -- apps agents .github` (empty)
- Result: `pass` for local guardrails (**44/44** after git_ready N-001 fixture and Windows PowerShell `ConvertFrom-GhJson` fix). Live `observe-ci.ps1` on PR #3 recorded real `ci-gate=success` with protocol `n/a` (not forged `passed`).
- Notes:
  - Guardrails cover: `ci-gate` name matching; skipped app jobs ignored; `ci_required: yes` cannot enter `awaiting_merge` on red/pending; `ci_required: no` keeps `n/a` even when `ci-gate` is green; refuse main / non-`task/*` / no approve / `pr merge`; `open-pr -DryRun` refuses `status: coding`; `observe-ci` errors with no PR; `finalize-prep` refuses `task/*`; runtime gitignored; `ci.yml` still read-only.
  - `open-pr` / `observe-ci` were **not** used to create a PR in this session (forbidden until Review approve).
  - This TASK is `ci_required: no`. After a future approve + PR, protocol `ci_status` is `n/a`; `observe-ci` still records the real `ci-gate` fact.

## Implementation summary

TASK-005C-A D1–D3 (Checks = CI SoT; Actions must not write git; no post-PR `state.json` commit) stay in force. TASK-005C-C Architecture adds the missing **observer** layer:

```
Review approve → git_ready
    → open-pr.ps1 (task/* only)
    → GitHub PR / Actions
    → observe-ci.ps1 (ci-gate only)
         green + ci_required yes → live awaiting_merge / passed
         red  + ci_required yes → stay ci_running / failed
         ci_required no         → awaiting_merge / n/a (ci-gate fact still recorded)
    → Human merge main
    → finalize-prep.ps1 (prepare archive; no push)
```

Three layers:

| Layer | Store | Writer |
|-------|--------|--------|
| CI fact | GitHub Checks `ci-gate` | Actions (`contents: read`) |
| Live protocol | `.agent/runtime.json` (gitignored) | Coding Agent scripts |
| Durable record | `.agent/state.json` | Intent commits + Human-merge archive |

## Issues

Known problems, blockers, or follow-ups:

- `gh` is installed but not on this Agent shell PATH (environment issue; not fixed this TASK). Scripts keep the approved absolute-path fallback.
- `finalize-prep.ps1` uses `ConvertTo-Json` for archive `state.json`; key order / whitespace may differ from hand-edited JSON. Only runs after Human merge on synced `main`; does not push.
- Dogfood of `open-pr` on **this** TASK waits for Independent Review approve. This session did not open a PR.
- Branch Protection remains TASK-005C-D.
- Pre-existing tracked `agents/knowledge-agent/backend/.env` is untouched (D9).

Fix Round 1 (Human/Planner): kept implementation; removed TASK-specific `open-pr` title; tightened `finalize-prep` MERGED+`mergedAt` gate; dropped cosmetic `git-pr.md` example. `lib.ps1` not thinned (no blocking duplicate/out-of-scope/SRP issue). `state.json` stays `in_review`.

## Commit

Commits on `task/*` for this round (hash + message). Write `none` if this TASK forbids commit (example: TASK-005B protocol session).

- none (Fix Round 1: Human/Planner forbade commit. Work remains unstaged on `task/TASK-005C-C-ci-state-integration`.)

## Branch

`task/TASK-005C-C-ci-state-integration`

Not pushed. No PR.

## Review Status

`approve`

Coding Agent sets `pending` when handing off. Only Review Agent changes this to `approve` or `reject` in the review file; keep this field in sync after review.

## Next Steps

Recommended next actions:

1. Independent Review Agent (separate Cursor session) writes `.agent/reviews/TASK-005C-C-review-round-1.md`.
2. On **approve**, Coding Agent sets `git_ready`, then uses `scripts/workflow/open-pr.ps1` (Human should not copy the PR body unless `gh` fails).
3. `observe-ci.ps1` records live overlay. This TASK is `ci_required: no` → protocol `n/a`; `ci-gate` should still go green with app jobs skipped.
4. **Human** merges `main`. Then `finalize-prep.ps1` may prepare archive. **Human** pushes `main`.
5. Do not enable Branch Protection (TASK-005C-D). Do not start TASK-005C-D from the Review session.
