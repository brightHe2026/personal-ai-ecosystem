# Agent Handoff Template (V2.6)

Copy live values into gitignored `.agent/handoff.md` via `Write-DerivedHandoff` / `bootstrap.ps1 -Repair`. Do not commit the live file. Do not paste ChatGPT transcripts between sessions.

Handoff is a **derived transport overlay** (C-001). Authoritative facts: `state.json` (`status`, `plan_approved`, `review_round`) and the applicable review file (`decision`, `required_fixes`). If this file contradicts those artifacts, fail closed or regenerate. Do not guess.

---

task_id: TASK-XXX
status: specified | coding | in_review | git_ready | ci_running | awaiting_merge | completed | blocked | cancelled
plan_approved: false | true
review_round: 0 | 1 | 2 | …
next_actor: coding-agent | review-agent | human | planner
next_action: wait-plan-approval | implement | independent-review | fix-round | open-pr-observe | observe-ci | merge-main | finalize-archive | next-task-or-stop
decision: (none) | approve | reject
required_fixes_file: (none) | .agent/reviews/TASK-XXX-review-round-N.md
report_file: (none) | .agent/reports/TASK-XXX-report.md
task_file: .agent/tasks/active/TASK-XXX-*.md
gate1_decision: APPROVED | (none)
approval_authority: Human/Planner | (none)
human_instruction: ROLE=review-agent | ROLE=coding-agent | ROLE=human | ROLE=planner

## Reads

- `.agent/BOOTSTRAP.md`
- `.agent/state.json`
- `.agent/tasks/active/TASK-XXX-*.md`

## Forbidden

- `gh pr merge`
- self-review / simulate Review Agent in the Coding session
- Coding-session subagent as Independent Review (D-003)
- SDK Agent.create / Automations Review spawn (D-004 / V3)
- business code under `apps/` or `agents/`
- forge CI `passed` or `failed`
- normal `git push origin main` (D-001 `archive-push` only, after independent checks)
- force push
- infer Gate 1 approval from conversation
- rewrite `required_fixes` from a Human paraphrase (C-001)
- start V3 Review auto-spawn

## Notes

Human/Planner is the sole Gate 1 approval authority. `plan_approved=true` persistence is not itself approval.

`AGENT_D001_ARCHIVE=1` is a capability marker, not authorization to push `main`.

After Review reject, Human returns to Coding with at most `continue from handoff` (C-003).
