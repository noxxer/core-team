# Core Team

[Русский](README.md) · **English**

> A self-bootstrapping multi-agent framework for Claude Code.
> One conversation unfolds a team of specialized subagent-roles with persistent memory and mechanical quality gates.

![version](https://img.shields.io/badge/version-4.5.0-blue) ![license](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-orange) ![claude-code](https://img.shields.io/badge/Claude%20Code-framework-8A2BE2)

A dev core: **one Facilitator + 6 roles + memory + mechanical gates**.

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

Core Team is an integrated system (`.claude/` + contract + knowledge + templates), so it's installed by **overlaying it onto your project**, not as an isolated plugin. The clone is a throwaway source of files; you always work in **your own** repository.

```bash
# 1. Clone as a throwaway source and detach from the framework's origin
git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git          # detach: the clone is now just a folder of files

# 2. Overlay .claude/ onto YOUR project (its own git)
cp -r core-team/.claude /path/to/your-project/
rm -rf core-team               # source no longer needed

# 3. Initialize inside your project
cd /path/to/your-project
claude
> /setup-project
```

`/setup-project` walks you through: project type, active roles, values, `project/` structure, planner-context bootstrap.

**Model:** one `.claude/` (the tool) + one `project/` (the memory) per project, at the root of your repo. `project/` is the project's runtime memory (ledger, decisions, role contexts); in **your** repo it's an asset — **commit it**. (In the framework's own repo `project/` is gitignored because there it's "someone else's runtime" — don't conflate the two contexts.)

> ⚠️ **Anti-pattern: don't work inside the core-team clone.** If you keep the clone's `.git` and run your project right there, you get: (1) `origin` points at `noxxer/core-team` → risk of `git push`-ing your project into the framework; (2) `project/` silently gitignored by the framework's rule → your project memory never gets committed; (3) `git pull` of updates conflicts with your edits. The clone is the source; your project is a separate repo.

**Updating** an already-configured project: clone again and copy `.claude/` over the top (your project's `project/` runtime is untouched — it's yours).

### Self-contained

Core Team is **self-contained** — it ships its own tuned versions of common methodologies (Functional Clarity, FPF, TDD, planner). You don't need to stack additional plugins with overlapping methodologies on top: two versions of one methodology produce contradictory guidance and waste tokens. Attribution for the groundwork this framework stands on is in [CREDITS](CREDITS.md).

---

## Structure

```
.claude/
├── CLAUDE.md             # contract: roles, protocols, invariants, gates
├── agents/               # 6 core roles (subagents)
├── commands/             # slash commands
├── skills/               # functional-clarity, tdd-master, planner(+reflect), navigator, fpf, llms-keeper
├── knowledge/            # core-protocols, biases, security, cost-model, fpf/, stacks/
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
