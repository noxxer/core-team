---
argument-hint: "[путь к feature-dir или текстовое описание]"
description: Построить план выполнения через planner skill. Architecture mode (вход — README) или Execution mode (вход — ARCH-документ).
allowed-tools: Read, Grep, Glob, Write
---

# /plan — Построение плана

Активируй skill `planner` (`.claude/skills/planner/SKILL.md`) и следуй его workflow start-to-finish.

## Интерпретация $ARGUMENTS

- **Путь к feature-dir или README.md** → **Mode 1 (architecture planning)**
- **Путь к ARCH/PLAN/DESIGN-документу** (`*-PLAN-*.md`, `ARCH-*.md`, `*-DESIGN-*.md`, `ARCHITECTURE.md`) → **Mode 2 (execution planning)**
- **Free-text без пути** → architecture mode с **chat-output** (не пиши `PLANNER_OUTPUT.md`, выведи в чат по тому же шаблону)

## Workflow (из planner SKILL)

1. Прочитай `<project-root>/.claude/planner-context.md`. Если нет — bootstrap (`references/bootstrap.md`).
2. Классифицируй задачу → выбери mode.
3. Загрузи нужный reference (`architecture-mode.md` или `execution-mode.md`).
4. Эмитни `PLANNER_OUTPUT.md` (или вывод в чат).

## NQD-гейт (FPF)

Для **complicated** / **complex** решений (по Cynefin) — обязательны **≥3 альтернативы** с trade-offs в `PLANNER_OUTPUT.md` секции "NQD-альтернативы". Если меньше 3 → фасилитатор должен потребовать дополнить или явно зафиксировать как Clear/Complicated single-option.

## Boundaries

- **Не выполняй план.** Не пиши код, не вызывай subagent-ов исполнения, не редактируй существующие PLAN/DESIGN-файлы.
- **Write-разрешён только** на:
  1. `<project-root>/.claude/planner-context.md` — при bootstrap или re-scan
  2. `<feature-dir>/PLANNER_OUTPUT.md` — собственно план
- ≤7 subagent-ов в одной параллельной фазе (LIFT-COT: planning 6, validation 7, integration 4)
- Opus-выбор обоснован, не «на всякий случай»

## После эмиссии

Верни Founder краткое summary через чат:
- Mode (architecture / execution)
- Размер задачи (S/M/L) + критичность
- Параллелизм (сколько фаз, сколько subagent-ов)
- Cost-estimate vs naive
- Где `PLANNER_OUTPUT.md` лежит

И предложи следующий шаг: `/plan-do <feature-dir>` для запуска конвейера.
