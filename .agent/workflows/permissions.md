# Workflow V2.6 — Permissions / Always Run

Purpose: reduce Human shell-approval noise without weakening Gate 2 (merge) or D-001.

This file is **repository policy**. It does not change the user's global Cursor settings. Human may copy the Always Run list into Cursor if they want auto-run.

`AGENT_D001_ARCHIVE=1` is **not** a permission grant and **not** Always Run.

---

## Always Run candidates (read-only / gitignored overlay)

These commands do not merge, do not push `main`, and do not write application code:

- `git status` / `git diff` / `git log` / `git fetch` / `git rev-parse` / `git check-ignore` / `git branch --show-current`
- `pwsh -File scripts/workflow/status.ps1`
- `pwsh -File scripts/workflow/bootstrap.ps1` (without `-Repair`)
- `pwsh -File scripts/workflow/observe-ci.ps1` (including `-Wait`)
- `pwsh -File scripts/workflow/wait-for-merge.ps1`
- `pwsh -File scripts/workflow/test-guardrails.ps1`
- `pwsh -File scripts/workflow/verify-branch-protection.ps1` (read-only GET; no `-Apply`)
- `gh pr view` / `gh pr checks` / `gh auth status`
- `gh api repos/:owner/:repo/branches/main/protection` (GET only)

Prefer `pwsh`. Scripts keep `Resolve-GhExe` absolute-path fallback. Do not rewrite the machine PATH.

---

## After `git_ready` (still refuse `main`)

May run, but scripts must still refuse `main` and `gh pr merge`:

- `git commit` on `task/*`
- `git push` of the current `task/*` branch (`open-pr.ps1`)
- `pwsh -File scripts/workflow/open-pr.ps1`

Do **not** put arbitrary `git push` or `required_permissions: all` into Always Run.

---

## Never Always Run / never auto-approve

- `gh pr merge` (no merge script exists)
- normal `git push origin main` / `main:main`
- `--force` / `--force-with-lease` / skip hooks
- changing PATH, installing software, printing `.env`
- Branch Protection mutation / secrets / storing a PAT in the repo
- `scripts/workflow/apply-branch-protection.ps1` (Human `-Apply` only after Gate 1; never CI, bootstrap, or archive)
- `scripts/workflow/archive-push.ps1` (D-001; Human may approve that one invocation after MERGED)

---

## D-001 marker

`AGENT_D001_ARCHIVE=1` is an internal capability marker for the controlled `archive-push.ps1` path (and the project hook's distinction from a random push).

It **alone does not authorize** `git push` to `main`. `archive-push.ps1` must independently verify MERGED, branch `main`, synced `origin/main`, valid tree, allowlist diff, live Checks (N-002), finalize-prep, no `apps/` `agents/` `.github/workflows/**`, no force push, no `gh pr merge`.

---

## Project hook (defense in depth)

`.cursor/hooks.json` → `beforeShellExecution` → `.cursor/hooks/deny-forbidden-git.ps1`

- Always deny `gh pr merge`
- Always deny force push
- Deny `git push` to `main` unless the capability marker is set **and** the command is a non-force `git push origin main`
- Marker is **not** authorization; `archive-push.ps1` independent checks remain the control
- Hook can be disabled; protocol + scripts remain the primary control
