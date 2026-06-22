# Core Team

**Русский** · [English](README.en.md)

> Саморазворачивающийся мультиагентный фреймворк для Claude Code.
> Один разговор разворачивает команду специализированных subagent-ролей с памятью между сессиями и механическими гейтами качества.

![version](https://img.shields.io/badge/version-4.5.0-blue) ![license](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-orange) ![claude-code](https://img.shields.io/badge/Claude%20Code-framework-8A2BE2)

Dev-ядро: **один Facilitator + 6 ролей + память + механические гейты**.

---

## Философия

### Команда из одного разговора
Ты разговариваешь с **Facilitator**. Он не отвечает сам на творческие вопросы — он маршрутизирует напряжения (tensions) к ролям-специалистам (architect, dev, test, cto, keeper), сводит их к решению и фиксирует. Роли — это полноценные Claude Code subagents со своими моделями (Opus/Sonnet), зонами ответственности и **памятью между сессиями**.

### Память важнее каталога ролей
Ценность фреймворка — **движок непрерывности**: `ledger.md` + `handoff.md` дают холодный старт без перечитывания истории; `roles/<role>/context.md` хранит память каждой роли; `planner-context.md` копит калибровку оценок. SessionStart-хук добавляет протоколы в каждую сессию, чтобы дисциплина не терялась.

### Tensions = ценность
Несогласие между ролями — фича, не баг. Любое напряжение фиксируется как задача (`TaskCreate`), обсуждается ролями и только потом, если не разрешилось, идёт к основателю через `AskUserQuestion` с явными последствиями каждой опции.

### Правило без гарда — это просто мнение
Каждый класс багов получает machine-verifiable инвариант-тест (**Detect → Fix → Guard → Document**). Решения фиксируются как ADR с альтернативами (NQD ≥3), kill-criteria и датой пересмотра. Ledger сверяется с git, а не пишется по памяти.

---

## Что внутри

### Роли (ядро — активны по умолчанию)
| Роль | Модель | Зона |
|------|--------|------|
| **facilitator** *(default)* | sonnet | оркестратор: 3-стадийный протокол, Decider, ADR |
| **architect** | opus | design-only: bounded contexts, контракты, FPF-гейты |
| **dev** | sonnet | реализация по ARCH через TDD + Functional Clarity |
| **test** | sonnet | review: OWASP + FC + **CHK-WIRE/CHK-ORPHAN** + live prod-path |
| **cto** | opus | стратегия, ADR, Evidence Graph, аудиты |
| **keeper** | sonnet | glossary/domain + llms.txt + сжатие промптов |

**Opt-in роли** (`templates/roles/optional/`): `product`, `guardian`, `analyst`, `designer`, `customer`. Подключаются под нужды проекта. Research-overlay = `analyst` + `project/resources.md`.

### Skills
`functional-clarity` (22 принципа + Code-Change Discipline) · `tdd-master` (Red-Green-Refactor) · `planner` + `planner-reflect` (планирование + калибровка оценок) · `navigator` (Iceberg / Cynefin / System Operator) · `fpf-integration` · `llms-keeper`.

**FPF — рабочий инструмент фасилитатора.** First Principles Framework (А. Левенчук) встроен в петлю принятия решений: NQD-гейт (≥3 альтернативы), Evidence Graph, Bounded Context, Decay Review Rule, Cynefin — всё в `facilitator` (Pre-DEC checkpoint) и шаблоне ADR. Полная спека (~8.7MB) не бандлится, а качается по требованию: `bash .claude/skills/fpf-integration/scripts/fetch-fpf-spec.sh` (в глобальный кеш, шарится между проектами). Без спеки работает degraded-режим по glossary + tasks-lookup.

### Команды
`/setup-project` · `/facilitator` · `/plan-feat` → `/plan` → `/plan-do` → `/plan-reflect` (feature pipeline) · `/end-session` (Navigator-анализ + git-verify + гейт решений) · `/update-docs` · `/self-service`.

### Структурные гейты
- **CHK-WIRE / CHK-ORPHAN** — зелёные тесты ≠ рабочий прод-путь; ревью проходит путь вживую.
- **DEC-NNN ⟹ файл** + same-session DEC-propagation — решения не «протухают».
- **Detect → Fix → Guard → Document** — инвариант-тест на каждый класс багов.
- **Express-Parallel** — фоновые агенты в непересекающихся file-ownership зонах.
- **Explicit model selection** — против перерасхода на унаследованном Opus.
- **Ledger git-verified** — статус пишется по факту кода.

### Память и непрерывность
`project/ledger.md` (источник истины) · `project/sessions/handoff.md` · `project/roles/<role>/context.md` · `.claude/planner-context.md` · SessionStart + TaskCompleted hooks.

---

## Установка

Core Team — интегрированная система (`.claude/` + контракт + knowledge + шаблоны), поэтому устанавливается копированием в проект, а не как изолированный плагин.

```bash
# 1. Склонировать
git clone https://github.com/noxxer/core-team.git
cd core-team

# 2. Скопировать .claude/ в свой проект
cp -r .claude /path/to/your-project/

# 3. Открыть проект в Claude Code и инициализировать
cd /path/to/your-project
claude
> /setup-project
```

`/setup-project` пройдёт по шагам: тип проекта, активные роли, ценности, структура `project/`, bootstrap planner-context.

**Обновление** в уже настроенном проекте: повторно скопировать `.claude/` (рантайм `project/` не трогается — он gitignored и принадлежит проекту).

### Самодостаточность

Core Team **самодостаточен** — везёт свои заточенные версии общих методик (Functional Clarity, FPF, TDD, planner). Дополнительные плагины со схожими методиками ставить поверх не нужно: две версии одной методики дают противоречивые формулировки и лишние токены. Атрибуция наработок, на которых стоит фреймворк, — в [CREDITS](CREDITS.md).

---

## Структура

```
.claude/
├── CLAUDE.md             # контракт: роли, протоколы, инварианты, гейты
├── agents/               # 6 ядровых ролей (subagents)
├── commands/             # slash-команды
├── skills/               # functional-clarity, tdd-master, planner(+reflect), navigator, fpf, llms-keeper
├── knowledge/            # core-protocols, biases, security, cost-model, fpf/, stacks/
├── hooks/                # session-start.sh (инъекция контракта) + verify-task.sh (gate памяти)
├── output-styles/        # core-team (инварианты + end-session nudge)
├── templates/            # шаблоны project/ + opt-in роли
└── planner-context.md    # память оркестратора (калибровка оценок)

project/                  # создаётся /setup-project (gitignored — рантайм проекта)
├── ledger.md · glossary.md · domain.md · values.md
├── decisions/DEC-*.md · sessions/ · roles/<role>/context.md
└── features/FEAT-*/  artifacts/
```

---

## Благодарности

Core Team стоит на плечах [i-m-senior-developer](https://github.com/spumer/i-m-senior-developer) ([@spumer](https://github.com/spumer)) и [First Principles Framework](https://github.com/ailev/FPF) (А. Левенчук). Полная атрибуция — в [CREDITS.md](CREDITS.md).

## Автор

[@noxxer](https://github.com/noxxer)

## Лицензия

[PolyForm Noncommercial License 1.0.0](LICENSE) — бесплатно для личного, учебного и любого некоммерческого использования. Для коммерческих / платных продуктов — отдельная договорённость с автором ([@noxxer](https://github.com/noxxer)).
