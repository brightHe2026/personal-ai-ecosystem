# Coding Agent

Actor: the Cursor session assigned to implement a TASK.

Also described in `docs/AGENTS.md` and `docs/CODING_AGENT_RULES.md`. Git behavior is in `.agent/workflows/git-pr.md`.
Bootstrap: `.agent/BOOTSTRAP.md`.

## May

- After **Human/Planner** machine-readable Gate 1 APPROVED evidence: persist `plan_approved=true` (mechanical write only; Coding is not the approval authority)
- Run `scripts/workflow/start-coding.ps1` (**PRIMARY Gate 1 enforcement**)
- Edit files allowed by the TASK
- Run tests and local checks
- Write `.agent/reports/TASK-XXX-report.md` and gitignored derived `.agent/handoff.md`
- Run `enter-review.ps1` after the report (`in_review`; C-002 does not increment on re-entry)
- Resume a **reject** round from `required_fixes_file` / B-nnn in the applicable review file (C-001). Human `continue from handoff` is sufficient (C-003)
- Update `state.json` for `coding` / `in_review` / `git_ready` transitions it caused
- Record CI **intent** in the pre-PR delivery commit (`ci_running` / `ci_status: running`, `pr_url: null`) when `ci_required: yes`
- After Review **approve** (`git_ready`), **in the same session**, open the PR with `scripts/workflow/open-pr.ps1` (no new Human Git Ready prompt)
- Observe required GitHub check `ci-gate` with `scripts/workflow/observe-ci.ps1 -Wait` into gitignored `.agent/runtime.json`
- Poll merge with `scripts/workflow/wait-for-merge.ps1` (do not forge `MERGED`)
- After observing required GitHub check `ci-gate` green, treat live protocol status as `awaiting_merge` / `ci_status: passed` (do not push that mirror onto the open PR)
- After observing `ci-gate` red, follow `ci-gate.md` recovery (in-scope retry on `task/*`, or `ci_running` → `coding`)
- After Human `MERGED` and independent D-001 checks: `finalize-prep.ps1` then `archive-push.ps1`
- Commit and push on `task/*` only (except the D-001 archive path at its proper lifecycle stage)

## Must not

- Infer Gate 1 approval from conversational context, Architecture approval, or `APPROVED WITH CONDITIONS`
- Modify implementation files, create the implementation branch, commit, push, or open a PR when `plan_approved != true`
- Treat `open-pr.ps1`'s `plan_approved` check as a substitute for `start-coding.ps1` (that check is defense-in-depth only)
- Review its own TASK (no self-review; D-003: do not simulate Review Agent in this session)
- Write `.agent/reviews/` for its own TASK
- Use a Coding-session subagent as Independent Review
- Spawn Review via Cursor SDK / Automations (D-004 / V3)
- Guess when handoff contradicts `state.json` or the applicable review (C-001: fail closed or `bootstrap.ps1 -Repair`)
- Increment `review_round` when re-entering `in_review` (C-002)
- Wait for Human to rephrase B-nnn; the review file is SoT
- Commit or push `main` except D-001 `archive-push.ps1` after **independent** verification of every D-001 precondition
- Treat `AGENT_D001_ARCHIVE=1` as authorization to push `main`
- Merge `main` (no `gh pr merge`; there is no merge script)
- Open a PR before Review **approve** (`git_ready`)
- Push a post-PR bookkeeping commit whose only purpose is `pr_url` / `ci_status` / `status` in `state.json`
- Commit `.agent/runtime.json` or `.agent/handoff.md`
- Set `ci_status: passed` without a green `ci-gate` check; at archive, re-query live Checks (N-002)
- Take the retired Human CI exception (`ci-gate.md` §2.3)
- Access enterprise confidential data (`docs/AGENTS.md`)
- Start TASK-005C-F (Branch Protection) or V3 Review auto-spawn
