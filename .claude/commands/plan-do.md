---
argument-hint: [путь к feature-dir или описание]
description: Оркестрация конвейера: architect → dev (TDD) → test (review) → keeper. Loop до "review clean".
---

# /plan-do — Конвейер реализации фичи

Ты — оркестратор имплементации фичи: $ARGUMENTS

**Default-роль оркестрации — facilitator.** Он диспатчит subagent-ов через Agent tool по плану из `PLANNER_OUTPUT.md` (если есть) или по дефолтному пайплайну ниже.

## Stage 0 — Planner (опционально, рекомендуется для L-фич)

Перед architect-фазой:

1. Если в `<feature-dir>/` нет `PLANNER_OUTPUT.md` И фича визуально крупная (несколько модулей, миграции, cross-stack) → вызови `/plan <feature-dir>/` (architecture mode). Planner выполнит bootstrap при первом запуске.
2. Прочитай `PLANNER_OUTPUT.md` — он определяет какие subagent-ы запустить, на каких моделях и в какой параллельности.
3. Перед implementation-фазой можно вызвать `/plan` ещё раз в **execution mode** на готовом ARCH — он обновит `PLANNER_OUTPUT.md`.

**Когда пропустить planner:**
- S-фича (1 модуль, <200 LOC, нет миграций)
- Bugfix в одной функции
- Founder явно сказал «без planner» / «быстро»

Planner — оптимизатор, **не обязательный гейт**.

## Default-конвейер (если PLANNER_OUTPUT.md отсутствует)

Конвейер последовательный, но может содержать параллельные фазы согласно `PLANNER_OUTPUT.md`. Имена subagent-ов — наши: architect / dev / test / keeper.

### Stage 1 — Designer (если фронтенд-фича)
Запуск `Agent(subagent_type=designer)`:
- Читает `<feature-dir>/README.md`
- Прочитает `.claude/knowledge/stacks/frontend-react/design.md` (если react-проект)
- Создаёт `<feature-dir>/UX-NN.md` со всеми 5 состояниями
- Передаёт architect-у

### Stage 2 — Architect (всегда)
Запуск `Agent(subagent_type=architect)` (model: opus):
- Читает `README.md` + `UX-NN.md` (если есть) + `PLANNER_OUTPUT.md`
- Детектирует стек → загружает `knowledge/stacks/<stack>/design.md`
- Применяет FPF-чеклист (A.7/A.10/A.11/A.1.1/A.15) — обязательно
- NQD: ≥3 альтернативы для complicated/complex
- Создаёт `<feature-dir>/ARCH-NN.md`
- Эскалация при breaking change → fasilitator → AskUserQuestion

### Stage 3 — Dev (имплементация)
Запуск `Agent(subagent_type=dev)` (model: sonnet):
- **Pre-feature TDD baseline** (обязательно): `pytest --co -q | tail -1` → зафиксировать N в `roles/dev/context.md`
- Читает `ARCH-NN.md` + `README.md`
- **Активирует tdd-master skill** (RED обязательно)
- Загружает `knowledge/stacks/<stack>/implement.md`
- Применяет functional-clarity (fail-fast, no Error Hiding)
- При правке существующего кода — Code-Change Discipline (7 шагов)
- Реализует фичу + тесты
- После имплементации: `pytest` → tests ≥ N + Δ. Если Δ < ожидаемой → пометить как Test Suite Staleness, эскалация
- Параллельный запуск нескольких dev возможен для **независимых частей** ARCH (см. PLANNER_OUTPUT.md)

### Stage 4 — Test (code review)
Запуск `Agent(subagent_type=test)` (model: sonnet):
- Читает код фичи + `ARCH-NN.md` + `README.md`
- **Всегда** загружает `knowledge/stacks/security.md` (OWASP Top 10)
- Загружает `knowledge/stacks/<stack>/review.md`
- Применяет FPF (A.7/A.10/A.11/A.1.1) + functional-clarity (Error Hiding) + Code-Change Discipline
- Создаёт `<feature-dir>/REVIEW-NN.md` с приоритизированными issues (P0/P1/P2/P3)
- **Не правит код** — только документирует

### Stage 4a — Architect drift-sweep (только для M/L фич)

> Триггер: размер фичи в `PLANNER_OUTPUT.md` = **M** (2-4 модуля, 200-800 LOC) или **L** (5+ модулей, multi-миграции). Для **S** (1 модуль, <200 LOC) — пропускаем.

Запуск `Agent(subagent_type=architect)` в short-режиме:
- Читает `ARCH-NN.md` + diff кода фичи (`git diff <base>..HEAD` или git log)
- Grep по контрактам / ключевым именам / инвариантам из ARCH — соответствует ли реальный код spec-у?
- **Если drift обнаружен** → создать **P0/P1 issue** в `REVIEW-NN.md` с пометкой `[ARCH-DRIFT]`, возврат на Stage 3 (dev исправляет)
- **Если drift отсутствует** → переход на Stage 5

Это дёшево (≤5 мин на фичу), ловит ~80% rotation-проблем (G.1 spec drift). Не подменяет полноценный review (Stage 4), а добавляет проверку spec↔code соответствия.

### Stage 5 — Fix or Complete
- Если P0/P1 issues → возврат к Stage 3 (dev исправляет)
- Если только P2/P3 или clean → переходим к Stage 6
- Loop до "review clean"

### Stage 6 — Keeper (после завершения)
Запуск `Agent(subagent_type=keeper)`:
- Извлекает стабильные паттерны (3+ использований, 1+ месяц, проверено)
- Обновляет `glossary.md`, `domain.md` (если новые термины/факты)
- Обновляет `PROJECT.md`/`FEATURES.md`/`CHANGELOG.md` (если ведутся)
- Обновляет `llms.txt` / `llms-full.txt` (если активирован llms-keeper)

### Stage 7 — Reflect (опционально)
Предложи Founder: «Запустить `/plan-reflect <feature-dir>`?» — особенно полезно после L-фич. Активирует skill `planner-reflect`, обновляет `planner-context.md` (gap-fills, model-strength, user-corrections, cost-calibration).

## Структура feature-dir

```
project/features/FEAT-NNNN-<slug>/
  README.md                           # Requirements (от /plan-feat)
  UX-NN.md                            # UI/UX design (от designer, опц.)
  PLANNER_OUTPUT.md                   # Planner output (от /plan, опц.)
  ARCH-NN.md                          # Architecture (от architect)
  REVIEW-NN.md                        # Review reports (от test)
  review-request-changes/             # Issue-файлы (legacy формат, опц.)
    FEAT-NNNN-ISSUE-0NN.md
    FEAT-NNNN-ISSUE-0NN_solved.md
  screenshots/ (опц.)
  test_cases/ (опц.)
```

## Critical Rules

- **Separation of concerns:**
  - architect = design only (no code, no tests)
  - dev = code only (with TDD tests as part of implementation)
  - test = review only (no code, no fixes)
  - keeper = docs only (no code, no decisions)
- **Loop until clean:** продолжать до "review clean" (нет P0/P1)
- **File ownership:** см. таблицу subagent-ов в CLAUDE.md
- **Все вопросы Founder через AskUserQuestion** (compact-safe)
- **Все задачи через TaskCreate** (compact-safe)
- **При breaking change** → AskUserQuestion перед продолжением
- **Cost-discipline:** Opus только для architect/cto. Если PLANNER_OUTPUT.md предлагает иное — обоснование обязательно.

## End-of-feature criteria

- ✅ Все P0/P1 issues исправлены
- ✅ test финализирует REVIEW-NN.md как `clean`
- ✅ glossary/domain обновлены (если применимо)
- ✅ ledger.md и handoff обновлены
- ✅ ADR (если решение стратегическое)
