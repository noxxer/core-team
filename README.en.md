# Core Team

[Русский](README.md) · **English**

> A self-bootstrapping multi-agent framework for Claude Code.
> One conversation unfolds a team of specialized subagent-roles with persistent memory and mechanical quality gates.

![version](https://img.shields.io/badge/version-5.0.0-blue) ![license](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-orange) ![claude-code](https://img.shields.io/badge/Claude%20Code-framework-8A2BE2)

A dev core: **one Facilitator + 6 roles + DPF craft handbooks + memory + mechanical gates**.

> **Note:** the framework operates in **Russian** by default (the output-style and role prompts enforce Russian). This English README explains the architecture; the working language inside a project is Russian unless you adapt the output-style.

---

## Philosophy

### A team from a single conversation
You talk to the **Facilitator**. It doesn't answer creative questions itself — it routes tensions to specialist roles (architect, dev, test, cto, keeper), drives them to a decision, and records it. Roles are real Claude Code subagents with their own models (Opus/Sonnet), ownership zones, and **memory between sessions**.

### Memory matters more than a role catalog
Core Team's value is the **continuity engine**: `ledger.md` + `handoff.md` give a cold start without re-reading history; `roles/<role>/context.md` holds each role's memory; `planner-context.md` accumulates estimate calibration. A SessionStart hook adds the protocols to every session so discipline doesn't fade between sessions.

### Tensions = value
Disagreement between roles is a feature, not a bug. Any tension is captured as a task (`TaskCreate`), discussed by roles, and only then — if unresolved — escalated to the founder via `AskUserQuestion` with explicit consequences per option.

### A rule without a guard is just an opinion
Every class of bugs gets a machine-verifiable invariant test (**Detect → Fix → Guard → Document**). Decisions are recorded as ADRs with alternatives (NQD ≥3), kill-criteria, and a review date. The ledger is reconciled against git, not written from memory.

---

## What's inside

### Roles (core — active by default)
| Role | Model | Scope |
|------|-------|-------|
| **facilitator** *(default)* | sonnet | orchestrator: 3-stage protocol, Decider, ADR |
| **architect** | opus | design-only: bounded contexts, contracts, FPF gates |
| **dev** | sonnet | implementation from ARCH via TDD + Functional Clarity |
| **test** | sonnet | review: OWASP + FC + **CHK-WIRE/CHK-ORPHAN** + live prod-path |
| **cto** | opus | strategy, ADR, Evidence Graph, audits |
| **keeper** | sonnet | glossary/domain + llms.txt + prompt compression |

**Opt-in roles** (`templates/roles/optional/`): `product`, `guardian`, `analyst`, `designer`, `customer`. Wired in per project. Research overlay = `analyst` + `project/resources.md`.

### Skills
`functional-clarity` (22 principles + Code-Change Discipline) · `tdd-master` (Red-Green-Refactor) · `planner` + `planner-reflect` (planning + estimate calibration) · `navigator` (Iceberg / Cynefin / System Operator) · `fpf-integration` · `llms-keeper`.

**FPF is a working facilitator tool.** The First Principles Framework (A. Levenchuk) is wired into the decision loop: NQD gate (≥3 alternatives), Evidence Graph, Bounded Context, Decay Review Rule, Cynefin — all in `facilitator` (Pre-DEC checkpoint) and the ADR template. The full spec (~8.7MB) is not bundled; it's fetched on demand: `bash .claude/skills/fpf-integration/scripts/fetch-fpf-spec.sh` (into a global cache shared across projects). Without the spec it runs in degraded mode on glossary + tasks-lookup.

### DPF — craft handbooks for roles

Each role reads its own DPF (`.claude/knowledge/dpf/<craft>.md`) — craft patterns in the form "situation → move → anti-pattern → when NOT to apply → source", collected from canonical books, standards, and postmortems. It's the layer between the general FPF and project artifacts (FPPS → FPF → **DPF** → LPF). `/setup-project` extends DPFs for the project's domain; the build method is the `dpf-builder` skill.

### Commands
`/setup-project` · `/facilitator` · `/plan-feat` → `/plan` → `/plan-do` → `/plan-reflect` (feature pipeline) · `/end-session` (Navigator analysis + git-verify + decision gate) · `/update-docs` · `/self-service`.

### Structural gates
- **CHK-WIRE / CHK-ORPHAN** — green tests ≠ a working prod path; review walks the path live.
- **DEC-NNN ⟹ file** + same-session DEC-propagation — decisions don't rot.
- **Detect → Fix → Guard → Document** — an invariant test per bug class.
- **Express-Parallel** — background agents in disjoint file-ownership zones.
- **Explicit model selection** — against runaway cost on inherited Opus.
- **Ledger git-verified** — status is written from the code, not from memory.

### Memory & continuity
`project/ledger.md` (source of truth) · `project/sessions/handoff.md` · `project/roles/<role>/context.md` · `.claude/planner-context.md` · SessionStart + TaskCompleted hooks.

---

## Installation

Core Team installs by **copying the `.claude/` folder into your project**. The clone is a box of files: you move `.claude/` out of it and delete the box. You always work in your own repository, never inside the clone.

Pick your case.

### Case 1. New project

```bash
mkdir my-project && cd my-project
git init

git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git        # the clone is now a folder of files, not a repo
cp -r core-team/.claude .    # move the tool into your project
rm -rf core-team             # drop the box

claude
> /setup-project
```

`/setup-project` asks for project type, roles, and values, creates the `project/` folder (memory), and builds DPFs for your domain.

Bringing work over from a previous effort? After `/setup-project`, prompt:

> Here are materials from previous work: <files, links, chat export>. Sort them into Core Team artifacts: facts → `project/domain.md`, terms → `project/glossary.md`, decisions already made → `project/decisions/`, open questions → `project/inbox.md`. Don't duplicate what the framework contract already covers. Show the migration plan before writing.

### Case 2. Existing project, not yet on Core Team

First, a safety net — a separate branch you can drop in one move:

```bash
cd existing-project
git switch -c add-core-team

git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git
cp -r core-team/.claude .
rm -rf core-team

claude
> /setup-project
```

`/setup-project` sees your code and stack. To fold in your existing instructions (`CLAUDE.md`, guides, docs), prompt:

> The project already has instructions and material: <CLAUDE.md, docs/…>. Read them and fold into Core Team: facts → `project/domain.md`, terms → `project/glossary.md`, decisions → `project/decisions/`, tasks → `project/inbox.md`. Where the framework contract already states a rule, reference it instead of duplicating. Plan before writing.

**Rollback:** `git checkout . && git switch main && git branch -D add-core-team`.

### Case 3. Upgrading from an older Core Team

Your `project/` memory stays yours — leave it alone. Only the `.claude/` tool gets replaced:

```bash
cd your-project
git switch -c update-core-team

git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git
diff -rq .claude core-team/.claude   # see what will change first
cp -r core-team/.claude .            # overwrite .claude/ (project/ untouched)
rm -rf core-team
```

⚠️ The copy overwrites **your own edits inside `.claude/`**, if you made any. Check the `diff` before copying and reapply your changes after. Then prompt:

> I upgraded `.claude/` from an older Core Team. Run `/self-service` in audit mode: check connectivity, the new role DPFs, and whether my `project/` artifacts fit the new structure. List what changed in the contract. Don't touch anything in `project/` without confirmation.

**Rollback:** `git switch main && git branch -D update-core-team`.

---

One install — one `.claude/` (the tool) and one `project/` (the memory) at the root of your repo. Commit `project/`: it's the project's memory — ledger, decisions, role contexts.

> ⚠️ **Don't run your project inside the clone.** If you keep the clone's `.git` and work in `core-team/`: `git push` goes to the framework (`origin` is `noxxer/core-team`), `project/` silently won't commit (gitignored by the framework's rule), and `git pull` overwrites your edits. The clone is the source; your project is a separate repo.

### Don't stack other plugins with the same methodologies

Core Team ships its own versions of Functional Clarity, FPF, TDD, and planner. A second plugin with the same methodology produces contradictory guidance and wastes tokens. Attribution for the groundwork is in [CREDITS](CREDITS.md).

---

## Structure

```
.claude/
├── CLAUDE.md             # contract: roles, protocols, invariants, gates
├── agents/               # 6 core roles (subagents)
├── commands/             # slash commands
├── skills/               # functional-clarity, tdd-master, planner(+reflect), navigator, fpf, dpf-builder, llms-keeper
├── knowledge/            # core-protocols, biases, security, cost-model, fpf/, dpf/, stacks/
├── hooks/                # session-start.sh (contract injection) + verify-task.sh (memory gate)
├── output-styles/        # core-team (invariants + end-session nudge)
├── templates/            # project/ templates + opt-in roles
└── planner-context.md    # orchestrator memory (estimate calibration)

project/                  # created by /setup-project (gitignored — project runtime)
├── ledger.md · glossary.md · domain.md · values.md
├── decisions/DEC-*.md · sessions/ · roles/<role>/context.md
└── features/FEAT-*/  artifacts/
```

---

## Credits

Core Team stands on the shoulders of [i-m-senior-developer](https://github.com/spumer/i-m-senior-developer) ([@spumer](https://github.com/spumer)) and the [First Principles Framework](https://github.com/ailev/FPF) (A. Levenchuk). Full attribution in [CREDITS.md](CREDITS.md).

## Author

[@noxxer](https://github.com/noxxer)

## License

[PolyForm Noncommercial License 1.0.0](LICENSE) — free for personal, educational, and any noncommercial use. For commercial / paid products, arrange a separate license with the author ([@noxxer](https://github.com/noxxer)).
