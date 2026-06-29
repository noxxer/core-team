# Core Team

**Русский** · [English](README.en.md)

> Саморазворачивающийся мультиагентный фреймворк для Claude Code.
> Один разговор разворачивает команду специализированных subagent-ролей с памятью между сессиями и механическими гейтами качества.

![version](https://img.shields.io/badge/version-5.0.0-blue) ![license](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-orange) ![claude-code](https://img.shields.io/badge/Claude%20Code-framework-8A2BE2)

Dev-ядро: **один Facilitator + 6 ролей + DPF-учебники ремёсел + память + механические гейты**.

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

### DPF — предметные учебники ремёсел

Каждая роль читает свой DPF (`.claude/knowledge/dpf/<ремесло>.md`) — паттерны ремесла в формате «ситуация → ход → антипаттерн → когда НЕ применять → источник», собранные из канонических книг, стандартов и постмортемов. Слой между общим FPF и артефактами проекта (FPPS → FPF → **DPF** → LPF). `/setup-project` достраивает DPF под предметную область проекта; метод сборки — skill `dpf-builder`.

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

Core Team ставится **наложением папки `.claude/` в твой проект**. Клон репозитория — это коробка с файлами: переносишь из неё `.claude/` к себе, коробку удаляешь. Работаешь всегда в своём репозитории, не внутри клона.

Выбери свой случай.

### Случай 1. Новый проект

```bash
mkdir my-project && cd my-project
git init

git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git        # клон больше не репозиторий, а папка с файлами
cp -r core-team/.claude .    # переносим инструмент к себе
rm -rf core-team             # коробку выбрасываем

claude
> /setup-project
```

`/setup-project` спросит тип проекта, роли и ценности, создаст папку `project/` (память) и соберёт DPF под твою предметную область.

Переносишь наработки из прошлой работы? После `/setup-project` дай промпт:

> Вот материалы прошлой работы: <файлы, ссылки, выгрузка истории чата>. Разложи их по артефактам Core Team: факты о проекте → `project/domain.md`, термины → `project/glossary.md`, уже принятые решения → `project/decisions/`, открытые вопросы → `project/inbox.md`. Не дублируй то, что уже задаёт контракт фреймворка. Покажи план переноса до записи.

### Случай 2. Существующий проект, ещё без Core Team

Сначала страховка — отдельная ветка, чтобы откатиться одним движением:

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

`/setup-project` увидит твой код и стек. Чтобы он подхватил твои прежние инструкции (`CLAUDE.md`, гайды, доки), дай промпт:

> В проекте уже есть инструкции и наработки: <CLAUDE.md, docs/…>. Прочитай и встрой в Core Team: факты → `project/domain.md`, термины → `project/glossary.md`, решения → `project/decisions/`, задачи → `project/inbox.md`. Где контракт фреймворка уже задаёт правило — сошлись на него, не дублируй. План до записи.

**Откат:** `git checkout . && git switch main && git branch -D add-core-team`.

### Случай 3. Обновление со старой версии Core Team

Память `project/` остаётся твоей — её не трогаем. Обновляем только инструмент `.claude/`:

```bash
cd your-project
git switch -c update-core-team

git clone --depth 1 https://github.com/noxxer/core-team.git
rm -rf core-team/.git
diff -rq .claude core-team/.claude   # сначала посмотри, что изменится
cp -r core-team/.claude .            # перезапись .claude/ (project/ не трогаем)
rm -rf core-team
```

⚠️ Копирование затрёт **твои правки внутри `.claude/`**, если ты их вносил. Сверься по `diff` до копирования и верни свои изменения после. Затем — промпт:

> Я обновил `.claude/` Core Team со старой версии. Прогони `/self-service` в режиме аудита: проверь связность, новые DPF-учебники ролей и совместимость моих `project/`-артефактов с новой структурой. Перечисли, что изменилось в контракте. В `project/` ничего не меняй без подтверждения.

**Откат:** `git switch main && git branch -D update-core-team`.

---

Одна установка — один `.claude/` (инструмент) и один `project/` (память) в корне твоего репозитория. Папку `project/` коммить: это память проекта — ledger, решения, контексты ролей.

> ⚠️ **Не веди проект внутри клона.** Если оставить `.git` клона и работать прямо в `core-team/`: `git push` уйдёт во фреймворк (`origin` указывает на `noxxer/core-team`), `project/` молча не закоммитится (gitignored правилом фреймворка), а `git pull` затрёт твои правки. Клон — источник, твой проект — отдельный репозиторий.

### Не ставь поверх другие плагины с теми же методиками

Core Team везёт свои версии Functional Clarity, FPF, TDD и planner. Второй плагин с той же методикой даёт противоречивые формулировки и лишние токены. Кого благодарить за основу — в [CREDITS](CREDITS.md).

---

## Структура

```
.claude/
├── CLAUDE.md             # контракт: роли, протоколы, инварианты, гейты
├── agents/               # 6 ядровых ролей (subagents)
├── commands/             # slash-команды
├── skills/               # functional-clarity, tdd-master, planner(+reflect), navigator, fpf, dpf-builder, llms-keeper
├── knowledge/            # core-protocols, biases, security, cost-model, fpf/, dpf/, stacks/
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
