# Task Template

Use this template when creating a new task under `.agent/tasks/active/`.
Filename convention: `TASK-XXX-short-name.md`

---

## Task ID

`TASK-XXX`

## Agent Role

Options: `Coding-Agent` | `Knowledge-Agent` | `ChatGPT` | `Cursor`

## Goal

Describe the expected outcome in one or two sentences.

## Requirements

1. ...
2. ...
3. ...

## Constraints

- Do not modify unrelated business code
- Follow `docs/CODING_AGENT_RULES.md` when applicable
- Do not commit unless explicitly requested

## Validation

How to verify completion:

- [ ] Directory / files exist as specified
- [ ] Tests pass (if applicable)
- [ ] Report written under `.agent/reports/`

## Result

Fill after completion:

- Status: `pending` | `in_progress` | `completed` | `blocked`
- Report: `.agent/reports/TASK-XXX-report.md`
- Notes:
