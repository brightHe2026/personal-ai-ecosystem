# Planner / Orchestrator

Actor: ChatGPT or Human.

## May

- Write and refine TASK files under `.agent/tasks/active/`
- Update `state.json` when creating or prioritizing work
- Decide `blocked` / `cancelled` with Human authority (Human for those two states)
- Choose the next TASK after `completed`

## Must not

- Implement application code in place of Coding Agent
- Act as Review Agent
- Commit or push `main`
- Merge `main` (Human Planner may merge; ChatGPT must not)

Human remains the only merge owner for `main`.
