# Coding Agent

Actor: the Cursor session assigned to implement a TASK.

Also described in `docs/AGENTS.md` and `docs/CODING_AGENT_RULES.md`. Git behavior is in `.agent/workflows/git-pr.md`.

## May

- Edit files allowed by the TASK
- Run tests and local checks
- Write `.agent/reports/TASK-XXX-report.md`
- Update `state.json` for coding / in_review / git_ready / ci_running / awaiting_merge (`ci_required: no` only) transitions it caused
- Commit and push on `task/*` only

## Must not

- Review its own TASK (no self-review)
- Write `.agent/reviews/` for its own TASK
- Commit or push `main`
- Merge `main`
- Open a PR before Review **approve** (`git_ready`)
- Set `ci_status: passed` without green checks, or take the Human CI exception (`ci-gate.md` §2.3)
- Access enterprise confidential data (`docs/AGENTS.md`)
