# Agent Workflow — CI Gate

Version: 1.4

Purpose: Protocol for the GitHub Actions quality gate, and how it maps to Workflow V2 state.

CI implementation for this repository is **TASK-005C-B**: `.github/workflows/ci.yml`.

Confirmed decision: D4 — `personal-ai-ecosystem` is the future unified CI home.

Related: `.agent/workflows/task-lifecycle.md`, `.agent/workflows/git-pr.md`.

Round-2 fix (Review B-001, B-002): CI-required vs CI-not-required paths, and an executable CI-failure recovery that cannot dead-end in `ci_running`.

TASK-005C-B (V1.2): GitHub Checks are the CI runtime source of truth; `.agent/state.json` is intent plus durable record; Actions must not write git.

TASK-005C-D (V1.4): `observe-ci.ps1 -Wait`; `wait-for-merge.ps1`; D-001 `archive-push.ps1`; N-002 live Checks at archive; Gate 1 `plan_approved`.

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

- On PR open: GitHub Actions starts automatically. Protocol intent is `ci_running` / `running` (preferably already in the pre-PR delivery commit). Do not push a post-PR metadata commit. Write live `pr_url` with `scripts/workflow/open-pr.ps1`.
- On CI pass (`ci-gate` green): protocol status is `awaiting_merge` / `passed` in `.agent/runtime.json` via `observe-ci.ps1`. Durable git record is the Human-merge archive.
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

## 6. Runtime source of truth (TASK-005C-B / TASK-005C-C)

Three layers. They must not impersonate each other.

| Layer | Role |
|-------|------|
| GitHub Actions / GitHub Checks (`ci-gate`) | **CI runtime source of truth.** Pass/fail is whatever the check says for that SHA. |
| `.agent/runtime.json` (gitignored) | **Live protocol overlay.** `pr_url`, observed `ci-gate`, live `ci_running` / `awaiting_merge`. May be rewritten without a git commit. |
| `.agent/state.json` | Workflow/task **intent** and **durable record**. May lag GitHub. Durable `pr_url` / `ci_status` at archive. |
| Human merge | Only path to `completed`. CI green is not merge permission. |

GitHub Actions **must not**:

- `git commit` / `git push`
- modify `.agent/state.json` or any other repository file
- use `permissions.contents: write`

If Actions wrote `state.json` and committed it, the new commit would retrigger CI → self-reference loop, and would add an unreviewed metadata SHA to an already-reviewed PR (TASK-005B commit `cf55243` anti-pattern).

Who records protocol CI fields:

1. **Before PR open** (review-approved delivery commit): Coding Agent may set `status: ci_running`, `ci_status: running`, `pr_url: null`.
2. **PR open:** `scripts/workflow/open-pr.ps1` (after Review approve, on `task/*` only). PR body carries TASK / report / review links (`git-pr.md`). Live `pr_url` goes to `.agent/runtime.json`.
3. **After Checks settle:** `scripts/workflow/observe-ci.ps1 -Wait` treats `ci-gate` as authoritative. Timeout: STOP for Human Gate 2; do not forge `passed` or `failed`. Do **not** push a post-PR metadata commit.
4. **After Human merge:** `wait-for-merge.ps1` detects `MERGED`. Archive on `main` writes durable `pr_url`, `ci_status: passed` or `n/a`, `status: completed`. Durable `passed` requires a **live** `gh pr checks` query (N-002), not stale `runtime.json`. `finalize-prep.ps1` prepares the archive and does not push. `archive-push.ps1` may push `main` only after independent D-001 checks. `AGENT_D001_ARCHIVE=1` is not authorization.

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

Future Branch Protection (Human, not this TASK; **TASK-005C-F**) should require **only** `ci-gate`. Do not require the individual app jobs (skipped jobs would block protocol-only PRs).

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

---

## 9. Observer scripts and live overlay (TASK-005C-C / TASK-005C-D)

Scripts run on the developer machine via GitHub CLI. They are not GitHub Actions. Prefer `pwsh`. Keep `ConvertFrom-GhJson` and `Resolve-GhExe`.

| Script | Does | Refuses |
|--------|------|---------|
| `scripts/workflow/start-coding.ps1` | **PRIMARY Gate 1:** `plan_approved === true` → `status=coding` | `plan_approved != true` (implementation must not start) |
| `scripts/workflow/bootstrap.ps1` | Derive next actor/action from `state.json` + applicable review (C-001). Default fail-closed. `-Repair` regenerates gitignored handoff | merge / push `main`; guessing across contradicting artifacts |
| `scripts/workflow/enter-review.ps1` | `coding` → `in_review`; `review_round` 0→1 only (C-002); derived handoff | Review file writes; merge |
| `scripts/workflow/apply-review-decision.ps1` | Apply review file `approve`/`reject`; increment round only on reject | implement fixes; merge; increment on approve |
| `scripts/workflow/open-pr.ps1` | Confirm `task/*` + Review `decision: approve`; push `task/*` if needed; `gh pr create` or reuse; write runtime | `main`; no approve; `plan_approved` false (**defense-in-depth only**); `gh pr merge` |
| `scripts/workflow/write-handoff.ps1` | Write gitignored derived `.agent/handoff.md` from state/review | merge / push `main`; caller-chosen next_actor |
| `scripts/workflow/observe-ci.ps1` | `gh pr checks`; map **only** job `ci-gate`; `-Wait` polls until settled or timeout | Forging `passed`/`failed` on timeout; skipped app jobs as `ci-gate` failure; `ci_required: yes` → `awaiting_merge` unless `ci-gate` is success |
| `scripts/workflow/wait-for-merge.ps1` | Poll `gh pr view` until `MERGED` or timeout | Forging `MERGED`; `gh pr merge` |
| `scripts/workflow/status.ps1` | Read-only print of git + `state.json` + handoff + runtime + Checks | All writes |
| `scripts/workflow/finalize-prep.ps1` | On synced `main` after PR `MERGED`: move TASK, durable `state.json` from **live** Checks (N-002) | `task/*`; unmerged PR; **push**; merge |
| `scripts/workflow/archive-push.ps1` | D-001: independently re-verify all preconditions, then commit + `git push origin main` | Marker-only authorization; non-allowlist; unsynced/unmerged; force; `gh pr merge` |

There is **no** merge script.

`AGENT_D001_ARCHIVE=1` is a capability marker for the controlled archive-push path. It **alone does not authorize** push to `main`.

Permissions policy: `.agent/workflows/permissions.md`. Project hook: `.cursor/hooks/deny-forbidden-git.ps1`.

### `.agent/runtime.json` schema

Gitignored. Not a git source of truth. `source` is `github-pr` after open and `github-checks` after observe.

| Field | Values |
|-------|--------|
| `version` | `1.0` |
| `task_id` | Active TASK id |
| `pr_url` | GitHub PR URL or `null` |
| `pr_number` | Integer or `null` |
| `head_sha` | PR head SHA |
| `ci_gate` | `pending` \| `success` \| `failure` \| `n/a` |
| `protocol_status` | Live workflow status (`ci_running` / `awaiting_merge` / …) |
| `protocol_ci_status` | `running` \| `passed` \| `failed` \| `n/a` |
| `ci_required` | boolean |
| `merged` | boolean |
| `next_actor` | live handoff actor (optional) |
| `next_action` | live handoff action (optional) |
| `observed_at` | ISO-8601 timestamp |
| `source` | `github-pr` \| `github-checks` |

`ci_gate` is the Check fact. `protocol_ci_status` is the Workflow V2 field. For `ci_required: no`, `ci-gate` may be green while `protocol_ci_status` stays `n/a`.

Human installs and authenticates `gh` (least privilege: Contents read, Pull requests write, Checks/Actions read). Agents must not store a PAT in the repo.

Local check: `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/workflow/test-guardrails.ps1`.
