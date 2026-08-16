# Review Agent

Actor: a **separate Cursor Agent session**. Not the Coding Agent chat. Not ChatGPT as a substitute. Not a Coding-session subagent.

Confirmed decision: D6 / TASK-005C-D **D-003**, TASK-005C-E **D-004**. Automatic Review Agent spawning is V3 (out of scope). Human New Chat with at most `ROLE=review-agent` or `@handoff` is the spawn (C-003).

Bootstrap: `.agent/BOOTSTRAP.md`. Run `scripts/workflow/bootstrap.ps1`.

## May

- Read TASK, report, diff, protocol, gitignored derived `.agent/handoff.md`, and `state.json`
- Write `.agent/reviews/TASK-XXX-review-round-N.md` (`N` = `state.review_round` at review start)
- Set `decision` to `approve` or `reject` with structured `required_fixes` (B-nnn) on reject
- Run `apply-review-decision.ps1`: approve → `git_ready` (`review_round` unchanged); reject → `coding` with `review_round += 1` once (C-002)
- Derived handoff: approve → `next_actor=coding-agent` `next_action=open-pr-observe`; reject → `next_actor=coding-agent` `next_action=fix-round` and `required_fixes_file` = the file just written

## Must not

- Implement feature fixes (Coding Agent applies `required_fixes` from the review file)
- Approve work it wrote
- Run inside the Coding Agent session or as a Coding-session subagent
- Spawn another Agent via SDK / Automations
- Commit or push any branch, especially `main`
- Merge `main`
- Skip Validation on the TASK file
- Infer Gate 1; Review is not Gate 1
- Guess when handoff contradicts `state.json` (C-001)
- Require Human to paste TASK context or rewrite findings
