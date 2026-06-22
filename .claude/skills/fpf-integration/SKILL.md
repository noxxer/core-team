---
name: FPF-Integration
description: >
  This skill should be used when the user asks to "integrate FPF", "add FPF to project",
  "FPF audit", "review decisions with FPF", "check evidence quality", "add decay mechanism",
  "review artifacts through FPF lens", "check cognitive biases in decisions",
  "add FPF checklists to roles", "NQD check", "evidence graph review",
  mentions "First Principles Framework", "FPF", or wants to improve decision-making
  quality in a multi-agent system. This skill also applies when the user mentions
  "bounded context audit", "terminology drift", "decision decay", or "alternatives check".

  Также активируется на русских триггерах: «фпф», «фреймворк первых принципов»,
  «evidence graph», «эвиденс»,«bounded context», «ограниченный контекст»,
  «нкд», «альтернативы», «проверь альтернативы», «решение устарело»,
  «decay решения», «строгое разделение ролей» (A.7), «парсимония», «онтологическая экономия»,
  «аудит решений», «качество evidence», «когнитивные искажения в решениях»,
  «выровнять ответственности модулей» (A.15), «transformer quartet» (A.3).

  Активируется автоматически при обсуждении архитектурных решений, ADR, спорах между ролями
  о смысле терминов, при правке стратегических документов, и в /plan для NQD-гейта.
version: 0.3.0
---

# FPF Integration for Multi-Agent Systems

Apply First Principles Framework (FPF) к решениям, артефактам и ролям мультиагентного проекта. Цель: качество решений, evidence-based reasoning, защита от когнитивных искажений.

## Core Principles (Quick Reference)

| Принцип | Правило | Проверка |
|---------|---------|----------|
| **A.10 Evidence Graph** | Claim without proof = opinion | «Source? Method? Date?» |
| **A.7 Strict Distinction** | Description ≠ capability ≠ fact | «Это как ДОЛЖНО работать или как ДЕЛАЕТ?» |
| **A.1.1 BoundedContext** | Meaning is local, translation explicit | «Все роли понимают термин одинаково?» |
| **A.11 Parsimony** | Add only what cannot be subtracted | «Существующее уже выражает это?» |
| **NQD** | ≥3 альтернативы для complicated/complex | «Ещё два варианта с trade-offs?» |
| **DRR Decay** | Evidence expires, decisions need review dates | «Когда evidence устареет?» |

## Cynefin-фильтр перед применением

| Домен | Применение FPF |
|-------|----------------|
| Clear | Применяй паттерн, NQD не нужен. Оставь след «Cynefin: Clear» в ADR |
| Complicated | Полный набор: NQD ≥3, A.10 Evidence Graph, kill-criterion |
| Complex | NQD ≥3 + safe-to-fail probes (эксперименты, не анализ) |
| Chaotic | Действуй → стабилизируй → потом аудит |

Без этого фильтра FPF превращается в чек-листы ради чек-листов.

## Три сценария применения

### A. Greenfield foundation (новый проект)

1. **`glossary.md`** (A.1.1) — термин | определение | «не является»
2. **`domain.md`** (A.10) — факты с источником и датой
3. **DRR-формат** для решений: `evidence_valid_until`, `review_date`, `alternatives_considered: N`
4. **USF/KDF/MDF/NOF** как стартовый ритуал сессий (что система? насколько знаем? лучший метод? конечная цель?)
   Полный протокол: `references/practical-tools.md`

### B. Retrofit (существующий проект, есть решения и артефакты)

1. **Inventory** — собрать все решения, артефакты, роли в один список
2. **6-вопросный экспресс-аудит** на каждое решение:
   - Каждый claim имеет источник? (A.10)
   - Рассмотрено ≥3 альтернатив? (NQD)
   - Какие искажения могли повлиять?
   - Когда evidence устареет? → `evidence_valid_until`
   - Kill-criterion явный, протокол проверки есть?
   - «Описано» vs «наблюдаемо» различено? (A.7)
3. **Terminology audit** — кросс-проверка терминов через все роли (A.1.1)

Детальные паттерны и кейс-стади: `references/audit-patterns.md`.

### C. Single decision review (точечный аудит одного решения)

Пройди 6-вопросный экспресс-аудит из B.2. Если ≥2 ответа «нет» — escalate to полный DRR.

## Role-checklists (как встроить в роли)

Для каждой роли в `project/roles/<role>/context.md`:

1. Определи домен роли (что решает, какие артефакты пишет)
2. Выбери top 3-5 принципов FPF, критичных для этой роли
3. Выбери top 2-3 когнитивных искажения, опасных для домена
4. Сформулируй чеклист 5-7 пунктов — **конкретно, не абстрактно**:
   - Хорошо: «Каждая оценка подкреплена конкретным наблюдением из интервью»
   - Плохо: «проверь смещения»

Шаблоны по архетипам ролей (analyst / architect / critic / stakeholder voice / coordinator / builder): `references/role-templates.md`.

## DRR (Design Rationale Record) — формат решений

```yaml
evidence_valid_until: "YYYY-MM-DD"
review_date: "YYYY-MM-DD"
alternatives_considered: N  # Cynefin-aware: Clear → 1 ОК; Complicated/Complex → ≥3
```

**Body:**
1. Контекст и проблема (USF: что система, что сломано)
2. Альтернативы с trade-offs (Cynefin-aware count)
3. Решение и rationale с evidence chain (source, method, date на каждый claim)
4. Self-assessment evidence: strong / partial / weak
5. Отвергнутые альтернативы — почему
6. Kill criteria + verification protocol (кто проверяет, когда, как)

Полный шаблон: `references/practical-tools.md`.

## Daily-workflow триггеры

| Событие | FPF-action |
|---------|------------|
| Старт сессии | USF/KDF/MDF/NOF (30 сек) |
| Новый термин | → `glossary.md` (A.1.1) |
| Новый факт | → `domain.md` с источником (A.10) |
| Решение | DRR-формат + Cynefin-aware NQD |
| «работает как X» | «Описание, capability или факт?» (A.7) |
| Только один вариант предложен | «Ещё две альтернативы» (NQD) |
| Обсуждение > 30 мин | Navigator abstraction test |
| `review_date` наступил | Перепроверить evidence или waiver |

## Review cycle

- **Bi-weekly:** проверь все `review_date`, expired → tension в следующей сессии
- **Monthly health check (15 мин):** % решений с ≥3 альтернатив, есть ли «weak» evidence, decay coverage, terminology drift
- **Quarterly deep review (1-2 ч):** полный аудит решений (сценарий B), retrospective FPF

## Anti-Patterns

| Anti-pattern | Симптом | Лечение |
|--------------|---------|---------|
| «All at once» | 20 принципов в первой сессии | Стартуй с 3: A.10, A.1.1, NQD |
| «FPF jargon» | Роли говорят «BoundedContext» | Простой язык: «факт или гипотеза?» |
| «Checklist for checklist's sake» | Галочки без думания | Чеклист = триггер мышления, не цель |
| «AI consensus = evidence» | 5 агентов согласны → правда | Агенты на одной модели ≠ независимые мнения |
| «FPF overload» | Чеклисты тяжелее проблемы | Упрости. FPF — инструмент, не цель |

## FPF Knowledge Base (fetch-on-demand)

Полный FPF-Spec.md (~8.7MB) **не бандлится** — Core Team везёт навигацию, а спека качается по требованию в глобальный кеш (шарится между проектами).

**Навигационные файлы (всегда на месте):**
- **`.claude/knowledge/fpf/glossary.md`** — 100 терминов FPF с определениями
- **`.claude/knowledge/fpf/tasks-lookup.md`** — задача → секции FPF → концепции
- **`.claude/knowledge/fpf/sections-map.md`** — карта секций (anchor-строки)
- **`.claude/knowledge/fpf/grep-patterns.md`** — regex для Grep по спеке

### Протокол доступа

- **Шаг 0 — pre-flight:** проверь наличие спеки до первого обращения — глобально `~/.claude/knowledge/fpf/FPF-Spec.md` или локально `.claude/knowledge/fpf/FPF-Spec.md`. Нет файла → **degraded mode**: работай по `glossary.md` + `tasks-lookup.md` (для большинства решений — NQD, Evidence Graph, Bounded Context, DRR — этого достаточно) и предложи пользователю `bash .claude/skills/fpf-integration/scripts/fetch-fpf-spec.sh`.
- **Шаг 1 — task mapping:** определи задачу → найди секцию в `tasks-lookup.md`.
- **Шаг 2 — grep-first:** ищи по паттерну из `grep-patterns.md`, не по номеру строки (anchor-строки в sections-map приблизительны).
- **Шаг 3 — context read:** читай вокруг grep-совпадений, не доверяй устаревшим offset-ам.

**Fetch:** `scripts/fetch-fpf-spec.sh` (флаги `--project`, `--force`). Качает из `ailev/FPF@main`, пишет `.version` для детекции дрейфа.

**Источник:** https://github.com/ailev/FPF (автор — Анатолий Левенчук). Подход fetch-on-demand — из i-m-senior-developer (@spumer).

## Reference Files

- `references/audit-patterns.md` — паттерны ретроспективного ревью + кейс-стади
- `references/role-templates.md` — шаблоны FPF-чеклистов по архетипам ролей
- `references/practical-tools.md` — USF/KDF/MDF/NOF, NQD-протокол, DRR-шаблон, Conformance Checklist
