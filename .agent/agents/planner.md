# Planner / Orchestrator

Actor: ChatGPT or Human.

## May

- Write and refine TASK files under `.agent/tasks/active/`
- Update `state.json` when creating or prioritizing work
- Set `plan_approved: false` when creating a TASK (required default)
- **Sole Gate 1 approval authority:** issue explicit, machine-readable Gate 1 APPROVED evidence (for example `GATE_1_DECISION=APPROVED` plus `PLAN_APPROVED=true`). Architecture approval is not Implementation Plan approval.
- Persist `plan_approved=true` after that evidence, or authorize Coding to perform the mechanical write
- Decide `blocked` / `cancelled` with Human authority (Human for those two states)
- Choose the next TASK after `completed`

## Must not

- Implement application code in place of Coding Agent
- Act as Review Agent
- Commit or push `main` (except Human merge / Human-owned git)
- Merge `main` (Human Planner may merge; ChatGPT must not)
- Ask Coding to infer Gate 1 from chat tone

Human remains the only merge owner for `main` (Gate 2).
