# Agent Workflow — CI Gate

Version: 1.2

Purpose: Protocol for the GitHub Actions quality gate, and how it maps to Workflow V2 state.

CI implementation for this repository is **TASK-005C-B**: `.github/workflows/ci.yml`.

Confirmed decision: D4 — `personal-ai-ecosystem` is the future unified CI home.

Related: `.agent/workflows/task-lifecycle.md`, `.agent/workflows/git-pr.md`.

Round-2 fix (Review B-001, B-002): CI-required vs CI-not-required paths, and an executable CI-failure recovery that cannot dead-end in `ci_running`.

TASK-005C-B (V1.2): GitHub Checks are the CI runtime source of truth; `.agent/state.json` is intent plus durable record; Actions must not write git.

---

## 1. `ci_required`

Every TASK must set `ci_required`: `yes` or `no`.

Planner fills it on the TASK file. Copy into `state.json` as boolean `ci_required` (`true` = yes).

Guidance (not automatic):

| Typical `scope` | Typical `ci_required` |
|-----------------|------------------------|
| `apps/sales-agent` | `yes` |
| `agents/knowledge-agent` | `yes` |
| `docs` / `.agent` protocol only | `no` |
| `ecosystem` that adds/changes `.github/workflows` | `yes` |

Not every TASK must have CI. `ci_required: no` is a first-class path, not a workaround.

---

## 2. Two legal paths after `git_ready`

Review **approve** is still the only normal entry to `git_ready`. Then:

### 2.1 CI-required (`ci_required: yes`)

```
git_ready
    ↓
ci_running
    ↓ CI pass
awaiting_merge
```

- On PR open: GitHub Actions starts automatically. Protocol intent is `ci_running` / `running` (preferably already in the pre-PR delivery commit). Do not push a post-PR metadata commit.
- On CI pass (`ci-gate` green): protocol status is `awaiting_merge` / `passed`. Durable git record is the Human-merge archive.
- On CI fail: **must not** enter `awaiting_merge`. Recovery is section 4.

### 2.2 CI-not-required (`ci_required: no`)

```
git_ready
    ↓
awaiting_merge
```

- On PR open: `status` → `awaiting_merge`, `ci_status: n/a`.
- **Skip** `ci_running`. Do not invent `ci_status: passed`.
- Human merge remains the gate before `completed`.
- The workflow still runs; app jobs skip; `ci-gate` should be green.

Coding Agent may take path 2.2 only when the TASK file says `ci_required: no`.

### 2.3 Human exception — CI required but no workflow yet (**retired**)

This exception existed until TASK-005C-B added `.github/workflows/ci.yml`.

**Retired.** Do not set `ci_status: n/a` on a `ci_required: yes` TASK to skip GitHub Checks. Coding Agent and Review Agent must not declare this exception. They must not pretend CI passed (`passed` is only for a real green `ci-gate` check).

If GitHub Actions is disabled at the repository level, Human may set `blocked`. That is not `n/a`.

---

## 3. `ci_status` values

| Value | Meaning | Who may set it |
|-------|---------|----------------|
| `not_started` | No PR / no CI run yet | Planner / Coding Agent |
| `running` | Checks in progress | Coding Agent, as **intent** in the pre-PR delivery commit (CI-required). GitHub Actions starts from the `pull_request` event; it does not write this field. |
| `passed` | Required check `ci-gate` actually green | Coding Agent or Human **recording** a real green GitHub Check. GitHub Actions must not commit this. |
| `failed` | Required check `ci-gate` red | Coding Agent or Human recording a real red GitHub Check. GitHub Actions must not commit this. |
| `n/a` | CI not applicable: `ci_required: no` only | Coding Agent only for `ci_required: no`. The retired §2.3 exception is not available. |

Default for a new TASK is `not_started`.

`n/a` is a defined transition into `awaiting_merge` (path 2.2 only). It is not a synonym for `passed`.

---

## 4. CI failure recovery (CI-required only)

**Hard rule:** CI failure must not set `awaiting_merge`.

`ci_running` is not a dead-end. After `ci_status: failed`, exactly one of these applies:

| Case | Who | Next `status` | `ci_status` | Review |
|------|-----|---------------|-------------|--------|
| **In-scope retry** | Coding Agent | stay `ci_running` | `failed` then `running` on the new push | No new review. Push on `task/*` is limited to CI config, test harness, or already-approved files with no new behavior. |
| **Out-of-scope fix** | Coding Agent | `coding` | stay `failed` | New behavior / unreviewed product or protocol change. Then write a report and enter `in_review` as usual (`review_round` unchanged unless a Review **reject** happens). Do **not** keep pushing product code while `ci_running`. Do **not** jump directly to `in_review` (report first). |
| **Stuck** | Human | `blocked` | stay `failed` | Human decides. |
| **Abandon** | Human | `cancelled` | stay `failed` | Human only. |

If unsure whether a change is in-scope, treat it as **out-of-scope** (`ci_running` → `coding`).

There is no `ci_running` → `in_review` shortcut and no `ci_running` → `awaiting_merge` on failure.

---

## 5. Pass (CI-required only)

- Required GitHub Actions check **`ci-gate`** on the TASK PR is green.
- Individual app jobs may be `skipped` when out of change scope; `ci-gate` still passes.
- Then protocol status is `awaiting_merge` / `ci_status: passed`.
- Do **not** push a bookkeeping commit to the open PR solely to write that into `state.json` (see §6). Durable git record is the Human-merge archive (lifecycle §8).
- Human may merge `main`. Still no automatic merge.

---

## 6. Runtime source of truth (TASK-005C-B)

Two layers. They must not impersonate each other.

| Layer | Role |
|-------|------|
| GitHub Actions / GitHub Checks (`ci-gate`) | **CI runtime source of truth.** Pass/fail is whatever the check says for that SHA. |
| `.agent/state.json` | Workflow/task **intent** and **durable record**. May lag GitHub. |
| Human merge | Only path to `completed`. CI green is not merge permission. |

GitHub Actions **must not**:

- `git commit` / `git push`
- modify `.agent/state.json` or any other repository file
- use `permissions.contents: write`

If Actions wrote `state.json` and committed it, the new commit would retrigger CI → self-reference loop, and would add an unreviewed metadata SHA to an already-reviewed PR (TASK-005B commit `cf55243` anti-pattern).

Who records protocol CI fields:

1. **Before PR open** (review-approved delivery commit): Coding Agent may set `status: ci_running`, `ci_status: running`, `pr_url: null`.
2. **PR body** carries the PR URL plus TASK / report / review links (`git-pr.md`).
3. **After Checks settle:** Coding Agent / Human treat `ci-gate` as authoritative. Do **not** push a post-PR metadata commit.
4. **After Human merge:** archive on `main` writes durable `pr_url`, `ci_status: passed` or `n/a`, `status: completed`.

`ci_required: no` TASKs still trigger the workflow. App jobs skip; `ci-gate` goes green quickly. Agent protocol still uses `ci_status: n/a` (not `passed`). Future Branch Protection should require only `ci-gate`, including for protocol PRs.

---

## 7. Implemented CI jobs (TASK-005C-B)

Workflow: `.github/workflows/ci.yml`.

| Change scope | Job | What it runs |
|--------------|-----|----------------|
| `apps/sales-agent/backend/**` | `sales-agent-backend` | Python 3.12; `pip install -r requirements.txt`; FastAPI import. **No pytest** (no tests in tree). |
| `apps/sales-agent/frontend/**` | `sales-agent-frontend` | Node 20; `npm ci`; `npm run build` |
| `agents/knowledge-agent/backend/**` | `knowledge-agent-backend` | Python 3.12; `pip install -r requirements.txt`; `python -m pytest -q`. No Postgres service. No secrets. |
| `.github/workflows/**` | all three app jobs | Dogfood CI changes |
| `push` to `main` | all three app jobs | Do not skip after merge |
| `docs` / `.agent` (no app/workflow paths) | none of the app jobs | `changes` + `ci-gate` only; `ci-gate` must pass |

Path detection is native `git diff --name-only <base>...<head>` in job `changes`. Workflow-level `on.paths` is not used (a skipped workflow cannot satisfy a required check). Third-party `dorny/paths-filter` is not used.

Aggregate job **`ci-gate`**:

- `if: always()` so it runs even when app jobs are skipped
- `changes` must be `success`
- each app job must be `success` or `skipped`
- any `failure` / `cancelled` / other result → `ci-gate` fails

Future Branch Protection (Human, not this TASK; suggested TASK-005C-D) should require **only** `ci-gate`. Do not require the individual app jobs (skipped jobs would block protocol-only PRs).

Sibling `brightHe2026/sales-agent` CI is not retired in this TASK.

---

## 8. Scope hint for `ci_required`

Planner still fills `ci_required` on the TASK file. It is not inferred by GitHub Actions.

| Typical `scope` | Typical `ci_required` | Jobs that will actually run |
|-----------------|------------------------|-----------------------------|
| `apps/sales-agent` | `yes` | sales-agent backend and/or frontend, by path |
| `agents/knowledge-agent` | `yes` | knowledge-agent pytest |
| `ecosystem` that adds/changes `.github/workflows` | `yes` | all app jobs |
| `docs` / `.agent` protocol only | `no` | app jobs skip; `ci-gate` still runs |

Mixed protocol + app TASK: `ci_required: yes`. If unsure, choose `yes`.
