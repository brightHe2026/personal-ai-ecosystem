Coding-Agent Development Rules

Version: 1.0

Purpose:
Define development rules for AI Coding Agents (Cursor Agent / Codex Agent)
working inside personal-ai-ecosystem.

Core Principles:
- Keep architecture stable
- Reduce repetitive coding work
- Ensure AI-generated code follows engineering standards
- Allow multiple applications and agents to coexist

Project Context:
personal-ai-ecosystem contains independent applications and reusable AI agents.

Applications:
- apps/sales-agent: presales assistant, project management, document generation
- agents/knowledge-agent: document ingestion, knowledge extraction, vector search, RAG

Architecture Layers:
API Layer
- HTTP endpoints
- Validation
- Response formatting
- Must not directly access database or AI APIs

Service Layer
- Business workflows
- Data processing
- Orchestration

Provider Layer
- AI capability abstraction
- Providers must be replaceable
- Business logic must not directly call OpenAI or other vendors

Infrastructure Layer:
- Database
- Redis
- Docker
- Storage
- External connections

Database Rules:
- Use SQLAlchemy ORM
- Use Alembic migrations
- Database changes require migration and verification

AI Model Rules:
- Use interfaces and factory pattern
- Store secrets in environment variables
- Avoid hard-coded providers and keys

Coding Standards:
- Clear naming
- Simple design
- Maintainable code

Before Coding:
Agent must read:
- ARCHITECTURE.md
- ROADMAP.md
- KNOWLEDGE_ARCHITECTURE.md

Agent should provide:
- Implementation plan
- File changes
- Risks

Modification Rules:
Allowed:
- Create files
- Add functions
- Add tests
- Fix bugs

Human approval required:
- Architecture changes
- Database redesign
- Major dependencies
- Deployment changes
- Removing important modules

Git Rules:
Before commit:
git status
git diff

Commit format:
feat:
fix:
refactor:
docs:
test:
chore:

Workflow V2 (authoritative for branch / merge; see `.agent/workflows/git-pr.md`):
- Coding Agent may commit on `task/TASK-XXX-short-name` only
- Coding Agent and Review Agent must not commit or push `main`
- Only Human merges `main`
- Review approve is required before `git_ready` / PR
- CI green does not allow automatic merge

Agent Report Format:
1. Plan
2. Files Changed
3. Implementation
4. Verification
5. Next Step

Operational report file: `.agent/reports/REPORT_TEMPLATE.md` (includes Changes, Tests, Issues, Commit, Branch, Review Status, Next Steps). Keep the five headings above in the chat hand-off; persist the TASK using the `.agent` template.

Long Term Goal:
Human controls product direction and architecture.
AI handles implementation, testing, documentation and maintenance.

