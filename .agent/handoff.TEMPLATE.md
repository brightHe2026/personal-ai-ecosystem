# Agent Handoff Template (V2.4)

Copy live values into gitignored `.agent/handoff.md` via `scripts/workflow/write-handoff.ps1` / `Write-Handoff`. Do not commit the live file. Do not paste ChatGPT transcripts between sessions.

---

task_id: TASK-XXX
status: specified | coding | in_review | git_ready | ci_running | awaiting_merge | completed | blocked | cancelled
plan_approved: false | true
next_actor: coding-agent | review-agent | human | planner
next_action: wait-plan-approval | implement | independent-review | open-pr-observe | merge-main | finalize-archive | next-task-or-stop
gate1_decision: APPROVED | (none)
approval_authority: Human/Planner | (none)

## Reads

- `.agent/tasks/active/TASK-XXX-*.md`
- `.agent/state.json`

## Forbidden

- `gh pr merge`
- self-review / simulate Review Agent in the Coding session
- business code under `apps/` or `agents/`
- forge CI `passed` or `failed`
- normal `git push origin main` (D-001 `archive-push` only, after independent checks)
- force push
- infer Gate 1 approval from conversation

## Notes

Human/Planner is the sole Gate 1 approval authority. `plan_approved=true` persistence is not itself approval.

`AGENT_D001_ARCHIVE=1` is a capability marker, not authorization to push `main`.
