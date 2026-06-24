---
decision_id: "DEC-NNN"  # для эволюции: DEC-NNN-A, DEC-NNN-B и т.п.
title: "Краткое название решения"
status: "proposed"  # proposed | accepted | superseded | deprecated
date_proposed: "YYYY-MM-DD"
proposed_by: "role"  # facilitator | architect | cto | product | guardian | …
decided_in_session: "session_id"
reversibility: "two-way-door"  # one-way-door | two-way-door
kill_criteria: "Условие, при котором решение отменяется (DRR — FPF decay)"
review_due: "YYYY-MM-DD"  # дата следующей проверки релевантности (FPF DRR)
supersedes: ""  # DEC-NNN если этот ADR заменяет другой (полная замена)
superseded_by: ""  # DEC-NNN если этот ADR был заменён
parent_decision_id: ""  # DEC-NNN если это эволюция (sub-DEC: 007 → 007A → 007B)
metric_for_revisit: ""  # обязательно если решение выбирает инвариант (default, first/last/max/threshold)
---

# DEC-NNN: Краткое название решения

## Контекст
[Почему возник вопрос. Какая tension привела к обсуждению. Cynefin-домен (Clear/Complicated/Complex/Chaotic).]

## NQD — альтернативы (минимум 3 для complicated/complex)

| Вариант | Плюсы | Минусы | Evidence (FPF A.10) |
|---------|-------|--------|--------------------|
| A: ... | ... | ... | <тест/метрика/прототип/ссылка> |
| B: ... | ... | ... | <тест/метрика/прототип/ссылка> |
| C: ... | ... | ... | <тест/метрика/прототип/ссылка> |

## Решение
[Что выбрали и почему. Reversibility: one-way-door (необратимое) или two-way-door (легко откатить)?]

## Evidence Graph (FPF A.10)

Каждый ключевой claim в решении подкреплён evidence:

- **Claim:** «<утверждение>» — **Evidence:** <тест/бенчмарк/документ/прецедент>
- **Claim:** «...» — **Evidence:** ...

> Claim without chain is opinion. Если evidence слабое — пометь как assumption и добавь validation в kill_criteria.

## Bounded Context (FPF A.1.1)

В каком контексте применимо это решение? Какие инварианты должны выполняться, чтобы оно оставалось верным?

- **Контекст:** <модуль/слой/домен>
- **Инварианты:** <список условий>
- **Не применять в:** <где НЕ распространяется>

## Обоснование
[Аргументы ролей. Результат Clarity Protocol. Какие cognitive biases проверены (anchoring, sunk cost, survivorship)?]

## Последствия
[Что изменится, на что повлияет, какие артефакты обновить. Linkbacks: затронутые ADR, фичи, модули.]

## DRR — Decay Review Rule (FPF)

Это решение **стареет**. При достижении `review_due` или при срабатывании `kill_criteria`:

- Перепроверь Evidence Graph: те же ли факты?
- Перепроверь Bounded Context: тот же ли контекст применения?
- Изменилось → создай новый DEC с `supersedes: DEC-NNN` (если breaking) или `parent_decision_id: DEC-NNN` (если расширение/edge-case)

## Sub-DEC vs Supersede — когда что

- **Sub-DEC** (`DEC-NNN-A`, `parent_decision_id: DEC-NNN`) — **расширение, уточнение, edge-case** в рамках того же контекста и допущений. Родитель остаётся валидным, sub дополняет
- **Supersede** (новый `DEC-MMM`, `supersedes: DEC-NNN`) — **смена базового допущения**, breaking change, изменение контекста. Родитель помечается `status: superseded`

> Соблазн делать sub-DEC вместо честного supersede — типичный антипаттерн. Если меняется фундаментальное допущение → supersede, не sub.

## Invariant observability (если применимо)

Если решение выбирает **инвариант** (default-значение, first/last/max/min семантика, threshold) — заполни `metric_for_revisit` в frontmatter.

- Какая метрика покажет, что инвариант перестал быть оптимальным?
- В каком отчёте/дашборде она отслеживается?
- Кто owner мониторинга? (обычно guardian для kill-criteria или analyst для drift-метрик)

> Без `metric_for_revisit` инвариант невозможно осознанно пересмотреть — он просто застывает.
