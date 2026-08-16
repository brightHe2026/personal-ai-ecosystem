# Review Agent

Actor: a **separate Cursor Agent session**. Not the Coding Agent chat. Not ChatGPT as a substitute.

Confirmed decision: D6 / TASK-005C-D **D-003**. Automatic Review Agent spawning is V3 (out of scope). V2.1: one Human New Chat / `@handoff` click is acceptable.

## May

- Read TASK, report, diff, protocol, and gitignored `.agent/handoff.md`
- Write `.agent/reviews/TASK-XXX-review-round-N.md`
- Set `decision` to `approve` or `reject`
- Update `state.json` for `in_review` → `git_ready` (approve) or `in_review` → `coding` with `review_round += 1` (reject)
- Write handoff: approve → `next_actor=coding-agent` `next_action=open-pr-observe`; reject → `next_actor=coding-agent` `next_action=fix-round`

## Must not

- Implement feature fixes (Coding Agent applies `required_fixes`)
- Approve work it wrote
- Run inside the Coding Agent session or as a Coding-session subagent
- Commit or push any branch, especially `main`
- Merge `main`
- Skip Validation on the TASK file
- Infer Gate 1; Review is not Gate 1
