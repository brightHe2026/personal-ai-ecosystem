# Agent Workflow — Task Lifecycle

Version: 1.0

Purpose: Define how ChatGPT (Planner), Coding-Agent (Cursor), and Review-Agent collaborate through Git task files under `.agent/`.

---

## 1. Task 创建流程

Planner creates a task file from the template, then places it in the active queue.

```
ChatGPT / Planner
        ↓
TASK.md  (from .agent/tasks/TASK_TEMPLATE.md)
        ↓
.agent/tasks/active/
```

Steps:

1. Planner copies `.agent/tasks/TASK_TEMPLATE.md`.
2. Fills Task ID, Agent Role, Goal, Requirements, Constraints, Validation.
3. Saves as `.agent/tasks/active/TASK-XXX-short-name.md`.
4. Updates `.agent/state.json`:
   - `active_task` → `TASK-XXX`
   - `queue` if needed
   - `agents.chatgpt.status` → `idle` (or `planning` while drafting)

---

## 2. Agent 执行流程

Coding-Agent picks up the active task, implements it, and writes a report.

```
.active/
   ↓
Coding-Agent 执行
   ↓
生成 report
```

Steps:

1. Coding-Agent reads `.agent/state.json` and the task under `.agent/tasks/active/`.
2. Sets `agents.cursor.status` → `working` (via state update by Planner/Agent as agreed).
3. Implements according to Requirements and Constraints.
4. Writes `.agent/reports/TASK-XXX-report.md` from `.agent/reports/REPORT_TEMPLATE.md`.
5. Leaves the task file in `active/` until Review finishes.

---

## 3. Review 流程

After coding, Review-Agent checks the report and changes.

```
Coding 完成
   ↓
Review-Agent
   ↓
Approved / Reject
```

Steps:

1. Review-Agent reads the task, report, and relevant diffs.
2. Validates against the task's Validation section.
3. Outcome:
   - **Approved** → proceed to completion flow
   - **Reject** → note Issues in the report (or a review note); Coding-Agent returns to execution flow

---

## 4. 完成流程

Only approved work is archived and reflected in state.

```
approved
   ↓
move → completed
   ↓
update state.json
```

Steps:

1. Move `.agent/tasks/active/TASK-XXX-*.md` → `.agent/tasks/completed/`.
2. Ensure report remains under `.agent/reports/`.
3. Update `.agent/state.json`:
   - `last_completed_task` → `TASK-XXX`
   - `active_task` → next task or `null`
   - remove task from `queue` if present
   - `agents.cursor.status` → `idle`
   - `updated_at` → current timestamp

---

## Path Reference

| Role | Path |
|------|------|
| Active tasks | `.agent/tasks/active/` |
| Completed tasks | `.agent/tasks/completed/` |
| Reports | `.agent/reports/` |
| Workflows | `.agent/workflows/` |
| Shared state | `.agent/state.json` |
