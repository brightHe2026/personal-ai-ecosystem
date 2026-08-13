# Review Agent

Actor: a **separate Cursor Agent session**. Not the Coding Agent chat. Not ChatGPT as a substitute.

Confirmed decision: D6.

## May

- Read TASK, report, diff, and protocol
- Write `.agent/reviews/TASK-XXX-review-round-N.md`
- Set `decision` to `approve` or `reject`
- Update `state.json` for `in_review` → `git_ready` (approve) or `in_review` → `coding` with `review_round += 1` (reject)

## Must not

- Implement feature fixes (Coding Agent applies `required_fixes`)
- Approve work it wrote
- Commit or push any branch, especially `main`
- Merge `main`
- Skip Validation on the TASK file
