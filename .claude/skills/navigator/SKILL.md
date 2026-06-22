---
name: navigator-abstraction-level
description: >
  This skill should be used when the team feels "stuck", "going in circles",
  needs to "switch abstraction level", "change perspective", diagnose
  "cognitive tunneling", "bike-shedding", "goal displacement", apply
  "Cynefin assessment", "system operator", "iceberg model", "ladder of
  abstraction", or navigate between strategic and tactical thinking.
version: 1.0.0
---

# Navigator — Навигатор уровней абстракции

Diagnose abstraction-level stuckness and navigate to the correct level. Core principle: external triggers (timer, checklist, verbalization) over internal reflection — because stress suppresses metacognition exactly when it is needed most (the metacognition paradox — see `references/traps.md`).

## Proactive Activation

Activate this skill not only reactively (when stuck), but proactively every 30 minutes of work. Set a timer. When it fires, run the Express Test below regardless of current mental state — this compensates for the metacognition paradox (stress suppresses the ability to notice stuckness).

## Phase 1: Diagnosis — "Where are we stuck?"

### Express Test (30 seconds)

1. **Can we explain WHY we are doing this?** (No → stuck low, ascend ↑)
2. **Can we name a CONCRETE next action?** (No → stuck high, descend ↓)
3. **Have we been discussing the same thing > 30 min?** (Yes → tunneling, force switch)
4. **Did we accept the first option without alternatives?** (Yes → Einstellung, need idea quota)

### Trap Identification

| Symptom | Trap | Instrument |
|---------|------|------------|
| "Obviously we need X" — no alternatives considered | **Einstellung** | → Idea Quota (3+) |
| Element locked to single function | **Functional fixedness** | → System Operator |
| Long work, feels productive, no real progress | **Tunneling** | → 30-min rule |
| Hour on a trivial detail, minute on key decision | **Bike-shedding** | → Scale Assessment |
| Process artifacts became the goal, not the product | **Goal displacement** | → Three "Why?" |
| One idea = final, no exploration | **Premature closure** | → Deferred Decision |
| Discussion stuck at one level only | **Dead-level abstracting** | → Ladder of Abstraction |

For detailed trap mechanisms, CLT science, and interconnections between traps, consult **`references/traps.md`**.

### Cynefin Assessment (before choosing any instrument)

| Domain | Strategy | Approach |
|--------|----------|----------|
| **Clear** (obvious cause-effect) | Sense → Categorize → Respond. Do NOT discuss | Apply established rules, best practices, templates |
| **Complicated** (expert analysis needed) | Sense → Analyze → Respond | Issue Trees, expert review, structured analysis |
| **Complex** (cause visible only retrospectively) | Probe → Sense → Respond. Do NOT analyze | Safe-to-fail experiments, brainstorming, prototyping |
| **Chaotic** (unknowable causes) | Act → Sense → Respond. Do NOT delay | Quick decisions, stabilize first, analyze later |

**Domain error**: applying analytics (Complicated) to a Complex problem — or experiments to a Clear one.

## Phase 2: Navigation — choose direction and instrument

### ↑ Ascend: from concrete to abstract

**When**: lost in details, lost strategy, goal displacement, no answer to "why?"

| # | Instrument | Quick Algorithm |
|---|-----------|----------------|
| 1 | **Three "Why?"** | "Why this action?" → "Why that?" → "Why does it matter for the *whole*?" |
| 2 | **Iceberg Model** | Event → Pattern → Structure → Mental Model (4 levels deep) |

### ↓ Descend: from abstract to concrete

**When**: drowning in concepts, can't start, procrastination, no next action

| # | Instrument | Quick Algorithm |
|---|-----------|----------------|
| 3 | **"How exactly?"** | "How does this look in a *specific case*?" → "What concretely *happens*?" → "First physical action?" |
| 4 | **Rubber Duck** | Explain the problem aloud as if the listener knows nothing — gaps surface at "stuck" points |
| 5 | **Writing = Thinking** | Write current understanding as connected prose, not bullet points — where text falls apart = shallow understanding |

### ↔ Horizontal: alternatives at the same level

**When**: Einstellung, premature closure, single option on the table

| # | Instrument | Quick Algorithm |
|---|-----------|----------------|
| 6 | **Idea Quota** | Ban repeating current option. Minimum 3 alternatives. MECE check. 4 Utley strategies if stuck |
| 7 | **Inversion** | "How can this decision FAIL?" → list all failure modes → verify protection |

### ↕ Scale switch: between system levels

**When**: decision ignores context, subplot doesn't serve the whole, functional fixedness

| # | Instrument | Quick Algorithm |
|---|-----------|----------------|
| 8 | **System Operator** | Fill 3x3 matrix (subsystem/system/supersystem x past/present/future). Empty cell = potential gap |
| 9 | **Leverage Points** | Paradigms > System goals > Rules > Structure > Parameters. Work at highest available lever |

### Timer switch

| # | Instrument | Quick Algorithm |
|---|-----------|----------------|
| 10 | **30-min Rule** | STOP → identify current level → switch to OPPOSITE for 15 min → evaluate. No progress? = missing info, not wrong level |

For full step-by-step algorithms, CLT mechanisms, and examples for each instrument, consult **`references/instruments.md`**.

## Phase 3: Six Socratic Questions (universal navigator)

| Type | Direction | Example |
|------|-----------|---------|
| **Clarification** | ↓ concrete | "What exactly do you mean by 'it doesn't work'?" |
| **Assumptions** | → deeper | "What is this assumption based on? Evidence or habit?" |
| **Evidence** | ↓ to data | "Where in the existing material is this confirmed?" |
| **Perspectives** | ↔ horizontal | "How does this look from a different stakeholder's point of view?" |
| **Consequences** | ↑ to system | "If we take this path, what does it mean for the larger structure?" |
| **Meta-question** | ⤴ meta-level | "Is this the right question? What are we really trying to understand?" |

## Metacognition Checklist (before closing any discussion)

- [ ] Problem defined at correct level (not symptom, not over-abstraction)
- [ ] Cynefin domain identified, instrument matches domain
- [ ] Alternatives considered (>=3 for complicated/complex decisions)
- [ ] Decision verified up (matches vision?) and down (implementable in prose?)
- [ ] No red flags: dead-level abstracting, premature closure, goal displacement

## Additional Resources

### Reference Files

For detailed algorithms, scientific foundations, and deep analysis:
- **`references/instruments.md`** — Full step-by-step algorithms for all 10 instruments with CLT mechanisms, examples, Socratic questions, and Porpoising technique
- **`references/traps.md`** — Cognitive trap mechanisms with scientific sources, CLT theory, metacognition paradox, trap interconnections, methodology limitations, and cross-section map
