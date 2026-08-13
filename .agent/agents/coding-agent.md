# Coding Agent

Actor: the Cursor session assigned to implement a TASK.

Also described in `docs/AGENTS.md` and `docs/CODING_AGENT_RULES.md`. Git behavior is in `.agent/workflows/git-pr.md`.

## May

- Edit files allowed by the TASK
- Run tests and local checks
- Write `.agent/reports/TASK-XXX-report.md`
- Update `state.json` for `coding` / `in_review` / `git_ready` transitions it caused
- Record CI **intent** in the pre-PR delivery commit (`ci_running` / `ci_status: running`, `pr_url: null`) when `ci_required: yes`
- After observing required GitHub check `ci-gate` green, treat protocol status as `awaiting_merge` / `ci_status: passed` (do not push that mirror onto the open PR)
- After observing `ci-gate` red, follow `ci-gate.md` recovery (in-scope retry on `task/*`, or `ci_running` → `coding`)
- Commit and push on `task/*` only

## Must not

- Review its own TASK (no self-review)
- Write `.agent/reviews/` for its own TASK
- Commit or push `main`
- Merge `main`
- Open a PR before Review **approve** (`git_ready`)
- Push a post-PR bookkeeping commit whose only purpose is `pr_url` / `ci_status` / `status` in `state.json`
- Set `ci_status: passed` without a green `ci-gate` check
- Take the retired Human CI exception (`ci-gate.md` §2.3)
- Access enterprise confidential data (`docs/AGENTS.md`)
