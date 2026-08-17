# Agent session bootstrap (Workflow V2.6)

The Git repository is the Agent communication bus. Conversation transcript is not workflow state.

Human is **spawn-only** between Coding and Independent Review (C-003). Human Decision Gates remain Gate 1 (plan) and Gate 2 (merge).

## Human instruction (sufficient)

New Chat, then **at most** one of:

```text
ROLE=review-agent
```

```text
ROLE=coding-agent
```

or `@` `.agent/handoff.md` / `@` `.agent/BOOTSTRAP.md`.

Do not paste TASK dossiers, transcripts, or rewritten B-nnn findings.

After Review **reject**, return to Coding with at most:

```text
continue from handoff
```

## What to do first

1. Read `.agent/state.json` (SoT for `status`, `plan_approved`, `review_round`, `active_task`).
2. Run `pwsh -File scripts/workflow/bootstrap.ps1` (fail closed if handoff contradicts; `-Repair` regenerates the overlay).
3. Read the **Reads** list it prints (TASK, report, applicable review, role file).
4. Become `next_actor` and perform `next_action`.
5. Obey **Forbidden**. Do not guess when artifacts conflict (C-001).

## Authority (C-001)

| Fact | Source |
|------|--------|
| `status`, `plan_approved`, `review_round` | `.agent/state.json` |
| `decision`, `required_fixes` | Latest **applicable** `.agent/reviews/TASK-XXX-review-round-N.md` |
| `next_actor` / `next_action` / pointers | Derived transport overlay `.agent/handoff.md` only |

If handoff contradicts durable artifacts: fail closed or `bootstrap.ps1 -Repair`. Never pick the convenient side.

## `review_round` (C-002)

The round that **will be / is being** reviewed. Increment **once**, only on Review **reject**. Coding must not increment when re-entering `in_review`. Approve does not increment. Review file `N` = `review_round` at review start.

## Must not

- Self-review or simulate Review Agent in the Coding session (D-003)
- Use a Coding-session subagent as Independent Review
- Spawn Review via Cursor SDK / Automations (D-004 / V3)
- Merge `main` / `gh pr merge`
- Infer Gate 1 from chat
- Start V3 Review auto-spawn

Independent Review writes `.agent/reviews/TASK-XXX-review-round-N.md` then `apply-review-decision.ps1`. Coding applies `required_fixes` from that file.
