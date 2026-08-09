Coding-Agent Task Template

Version: 1.0

Purpose: This document defines the standard format for assigning
development tasks to AI Coding Agents.

Applicable Agents: - Cursor Agent - Codex Agent - Other software
engineering agents

------------------------------------------------------------------------

Task Information

TASK ID

Example: TASK-001

Task Name

Example: Implement Knowledge-Agent Document Pipeline

Priority

Options: - Critical - High - Medium - Low

------------------------------------------------------------------------

1. Objective

Describe the expected outcome.

Example: Implement document processing pipeline:

Document ↓ Parser ↓ Splitter ↓ Chunk ↓ Embedding ↓ Vector Storage

------------------------------------------------------------------------

2. Background

Explain: - Why this task exists - Current system status - Related
modules

------------------------------------------------------------------------

3. Related Documents

Agent must read:

docs/ARCHITECTURE.md docs/ROADMAP.md docs/KNOWLEDGE_ARCHITECTURE.md
docs/CODING_AGENT_RULES.md

------------------------------------------------------------------------

4. Current Code Context

Affected application:

apps/ or

agents/

Current modules: - models - services - providers - api

------------------------------------------------------------------------

5. Expected Changes

Files To Create

List new files.

Files To Modify

List modified files.

Files NOT Allowed To Modify

List restricted files.

------------------------------------------------------------------------

6. Technical Requirements

Requirements: 1. Follow existing architecture. 2. Use Service Layer for
business logic. 3. Use Provider abstraction for external AI capability.
4. Database changes require Alembic migration. 5. Avoid unnecessary
dependencies.

------------------------------------------------------------------------

7. Implementation Plan Required

Before coding, Agent must provide:

Architecture Impact

Does this change architecture? Reason:

File Change Plan

Create: Modify:

Risk Analysis

Potential risks:

------------------------------------------------------------------------

8. Coding Requirements

Agent must: - Follow CODING_AGENT_RULES.md - Keep code modular - Add
tests - Avoid unnecessary complexity

------------------------------------------------------------------------

9. Testing Requirements

Required: - Import verification - Unit test - Integration test when
needed

------------------------------------------------------------------------

10. Git Requirements

Before commit:

git status

git diff

Commit format:

feat: fix: refactor: docs: test: chore:

------------------------------------------------------------------------

11. Final Report Format

Agent must provide:

Summary

Changed Files

Verification

Remaining Issues

Next Recommended Task

------------------------------------------------------------------------

12. Human Approval Gate

Agent must stop and ask before: - Changing architecture - Changing
database design - Adding major dependencies - Changing deployment
strategy - Removing existing functionality
