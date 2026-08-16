# Agent Specification

Workflow V2 protocol (state machine, review isolation, git/PR, CI gate): `.agent/README.md`.
New Agent sessions: `.agent/BOOTSTRAP.md`.

This file remains the product-level agent map. It does not replace `.agent/` operational rules.


## Coding-Agent


### Responsibility

- Develop applications
- Maintain code repository
- Build automation tools


### Boundary

Cannot access enterprise confidential data.

Cannot self-review. Cannot commit or push `main`. Cannot merge `main`.

Git/PR rules: `.agent/workflows/git-pr.md`.


## Review-Agent


Independent Cursor Agent session. Not the Coding-Agent chat. Not a ChatGPT substitute.
Human spawn: `ROLE=review-agent` or `@handoff`. Do not paste a TASK dossier.


### Responsibility

- Defect-first review of TASK, report, and diff
- Write `.agent/reviews/` with `approve` or `reject`
- Drive `in_review` → `git_ready` or `in_review` → `coding`


### Boundary

Must not implement the TASK's feature fixes.
Must not commit or push `main`.
Must not merge `main`.

Role file: `.agent/agents/review-agent.md`.


## Planner / Orchestrator


ChatGPT or Human. Writes TASK specifications and coordinates the queue.


### Boundary

Does not replace Review-Agent.
Does not implement the TASK in place of Coding-Agent.
Only Human may merge `main`.


## Knowledge-Agent


### Responsibility

- Collect knowledge
- Build semantic index
- Manage personal memory


### Boundary

Cannot modify original knowledge source.



## Enterprise AI Agent


External company AI system.


Responsibility:

- Presales document processing
- Enterprise workflow automation


Boundary:

No access to Personal AI Ecosystem.
