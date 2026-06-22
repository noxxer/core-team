# Multi-Agent Role Framework: Инструкция по интеграции

Пошаговое руководство по созданию мультиагентной ролевой системы на базе Claude Code Agent Teams. Основано на опыте проекта Interview Process Framework.

---

> **⚠️ Migration Note (Variant C, 2026-04).**
>
> Этот гайд описывает прежнюю архитектуру, где роли жили в `.claude/commands/<role>.md`.
> В Variant C канонические определения ролей перенесены в **`.claude/agents/<role>.md`** (subagents с frontmatter: name/model/color/description/tools).
>
> При чтении этого документа: везде где написано `.claude/commands/<role>.md` — читай как `.claude/agents/<role>.md`. `.claude/commands/` теперь содержит **только slash-команды действия** (/facilitator, /setup-project, /plan-feat, /plan, /plan-do, /plan-reflect, /end-session, /self-service, /update-docs).
>
> Persistent memory ролей (`project/roles/<role>/context.md`) сохранена.
> Субагент при активации обязан её прочитать (определено в его собственном промпте).
>
> Полная актуальная архитектура — в `CLAUDE.md` (раздел "Роли = Subagents").

---

## Содержание

1. [Обзор подхода](#1-обзор-подхода)
2. [Предпосылки и установка](#2-предпосылки-и-установка)
3. [Шаг 1: Определи домен и роли](#3-шаг-1-определи-домен-и-роли)
4. [Шаг 2: Структура проекта](#4-шаг-2-структура-проекта)
5. [Шаг 3: CLAUDE.md — центральный контракт](#5-шаг-3-claudemd--центральный-контракт)
6. [Шаг 4: Command-файлы ролей](#6-шаг-4-command-файлы-ролей)
7. [Шаг 5: Приватные контексты ролей](#7-шаг-5-приватные-контексты-ролей)
8. [Шаг 6: Ledger — центр координации](#8-шаг-6-ledger--центр-координации)
9. [Шаг 7: Agent Teams — настройка](#9-шаг-7-agent-teams--настройка)
10. [Шаг 8: Hooks — quality gates](#10-шаг-8-hooks--quality-gates)
11. [Шаг 9: Два режима работы](#11-шаг-9-два-режима-работы)
12. [Ключевые решения и их обоснование](#12-ключевые-решения-и-их-обоснование)
13. [Чеклист запуска нового проекта](#13-чеклист-запуска-нового-проекта)
14. [Ссылки и документация](#14-ссылки-и-документация)

---

## 1. Обзор подхода

### Что это

Мультиагентная система, где каждый agent = голос конкретного стейкхолдера. Агенты работают в двух режимах:
- **Commands** (последовательный): Owner вызывает роли через slash-команды, один контекст
- **Agent Teams** (параллельный): роли — отдельные teammates, работают одновременно, общаются через SendMessage

### Зачем

Один LLM-контекст не может одновременно качественно представлять конфликтующие интересы. Когда рекрутер говорит "ускорить процесс", а guardian — "добавить проверки", эти tensions рождают ценность. Мультиагентная система делает tensions явными.

### Теоретическая база

| Фреймворк | Как используется |
|-----------|-----------------|
| Core Protocols (McCarthy) | Decider Protocol, Clarity Protocol, Perfection Game, Check-In, Pass |
| Holacracy 5.0 | Роли как функции, tension processing, governance |
| Six Thinking Hats (de Bono) | Режимы мозгового штурма, маппинг шляп на роли |

### Ключевой принцип

**Роли = голоса реальных стейкхолдеров, НЕ абстрактные функции.**

Плохо: "Examiner", "Assessor", "Coach" — размытые функции без привязки к реальным людям.
Хорошо: "Interviewer" (голос собеседующего), "Candidate" (голос кандидата), "Recruiter" (голос рекрутера) — конкретные участники процесса, чьи интересы и боли можно представить.

---

## 2. Предпосылки и установка

### Claude Code

- Claude Code CLI установлен и работает
- Подписка поддерживает Agent Teams (Opus/Sonnet)
- Документация: https://docs.anthropic.com/en/docs/claude-code

### Agent Teams (экспериментальная фича)

Agent Teams включается через переменную окружения. Создай файл `.claude/settings.json` в корне проекта:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "in-process"
}
```

**Режимы `teammateMode`:**

| Значение | Поведение |
|----------|-----------|
| `"auto"` | Авто-выбор: split-panes если tmux/iTerm2, иначе in-process |
| `"in-process"` | Все teammates в одном терминале; `Shift+Up/Down` для переключения |
| `"tmux"` | Каждый teammate в отдельном tmux pane |

**Где могут жить настройки (приоритет от высокого к низкому):**

| Scope | Путь | Шарится |
|-------|------|---------|
| Managed | `/Library/Application Support/ClaudeCode/` (macOS) | Да (IT) |
| User | `~/.claude/settings.json` | Нет |
| Project | `.claude/settings.json` | Да (git) |
| Local | `.claude/settings.local.json` | Нет |

---

## 3. Шаг 1: Определи домен и роли

### Процесс определения ролей

1. **Определи домен** — предметная область проекта (собеседования, продукт, онбординг...)
2. **Перечисли реальных участников** процесса — людей, которые вовлечены в домен
3. **Для каждого участника — определи интересы и боли** — что его волнует
4. **Проверь на tensions** — есть ли конфликты интересов между ролями (если нет — роль избыточна)
5. **Добавь мета-роли** — фасилитатор (обязателен), аналитик (данные), guardian (риски), автоматизатор (tooling)

### Тест на необходимость роли

Роль нужна, если:
- [ ] Представляет конкретного стейкхолдера с уникальными интересами
- [ ] Имеет tensions хотя бы с 2 другими ролями
- [ ] Без неё слепая зона — никто не поднимет эти вопросы
- [ ] Имеет собственные артефакты (файлы, которые правит)

### Пример: домен "Собеседования"

| Роль | Стейкхолдер | Ключевые tensions |
|------|------------|-------------------|
| Facilitator | Ведущий процесса | — (координирует, не спорит) |
| Methodologist | Архитектор процесса | vs Interviewer (теория vs практика) |
| Interviewer | Собеседующий | vs Recruiter (нагрузка vs скорость) |
| Recruiter | Рекрутер | vs Candidate (скорость vs опыт кандидата) |
| Team | Команда найма | vs TechLead (потребности команды vs стандарты) |
| TechLead | Техническое коммьюнити | vs Team (планка vs скорость найма) |
| Candidate | Кандидат | vs Guardian (опыт vs контроль) |
| Analyst | Аналитик данных | — (нейтрален, даёт данные) |
| Automator | Автоматизатор | vs всех (что автоматизировать vs что дорого) |
| Guardian | Страж fairness | vs Methodologist (контроль vs гибкость) |

### Минимальный набор ролей (5)

Если домен небольшой, достаточно 5 ролей:
1. **Facilitator** — координация (обязателен)
2. **2-3 стейкхолдера** — основные голоса
3. **Guardian/Analyst** — контроль качества

### Максимум ролей

Не больше 10-12. Каждый teammate = отдельный контекст LLM = токены. 5-6 одновременных teammates — оптимум для Agent Teams.

---

## 4. Шаг 2: Структура проекта

```
project-root/
├── .claude/
│   ├── CLAUDE.md              # Центральный контракт (все роли читают)
│   ├── settings.json          # Включение Agent Teams
│   ├── hooks/
│   │   ├── hooks.json         # Конфигурация hooks
│   │   └── verify-task.sh     # Quality gate для TaskCompleted
│   └── commands/
│       ├── facilitator.md     # Slash-команда /facilitator
│       ├── role-a.md          # /role-a
│       ├── role-b.md          # /role-b
│       └── ...
├── project/
│   ├── ledger.md              # Центр координации — состояние проекта
│   ├── backlog.md             # Tensions и задачи
│   ├── roles/
│   │   ├── role-a/
│   │   │   └── context.md     # Приватная память роли A
│   │   ├── role-b/
│   │   │   └── context.md
│   │   └── ...
│   ├── artifacts/             # Живые артефакты (правит владелец)
│   │   ├── artifact-a.md
│   │   └── artifact-b.md
│   ├── decisions/             # ADR — Architecture Decision Records
│   │   └── DEC-001_title.md
│   └── sessions/              # Логи сессий
│       └── YYYY-MM-DD_topic/
│           ├── session.md
│           └── handoff.md
```

### Зачем отделять `.claude/commands/` от `project/roles/`

- **`.claude/commands/<role>.md`** = инструкция для LLM: кто ты, что делаешь, как себя ведёшь. Это **промпт**. Не меняется между сессиями.
- **`project/roles/<role>/context.md`** = приватная память роли: что узнал, что решили, открытые вопросы. Это **данные**. Обновляется каждую сессию.

Разделение критично: промпт стабилен, контекст эволюционирует.

---

## 5. Шаг 3: CLAUDE.md — центральный контракт

**Файл:** `.claude/CLAUDE.md`

CLAUDE.md автоматически загружается Claude Code при старте сессии (включая spawn каждого teammate). Это единственное место, которое гарантированно читают все.

> Документация: Claude Code загружает CLAUDE.md иерархически — от user-level (`~/.claude/CLAUDE.md`) до project-level (`.claude/CLAUDE.md`). Teammates при spawn получают те же CLAUDE.md, что и обычная сессия из того же cwd.

### Что должно быть в CLAUDE.md

```markdown
# [Название проекта]

[1-2 предложения: что это за проект]

## Контекст предметной области
[Ссылки на источники данных, внешние системы, документацию]

## Универсальное правило контекста
Каждая роль перед началом работы читает `project/ledger.md` (всегда первым)
и свой `project/roles/<role>/context.md`.

## Команда
| Команда | Описание |
|---------|----------|
| `/facilitator` | [описание] |
| `/role-a` | [описание] |
| ...

## Взаимодействие с владельцем процесса
[Как роли общаются с Owner — обычно через фасилитатора]

## Два режима работы
[Commands vs Agent Teams — когда что использовать]

## Agent Teams Protocol
[Spawn шаблон, File Ownership, коммуникация, протокол teammate/leader]

## Протокол сессии (Commands режим)
[Начало → Работа → Завершение]

## Core Protocols
[Decider, Clarity, Perfection Game, Check-In, Pass]

## Фазы проекта
[Живые состояния: Audit ↔ Design ↔ Content ↔ ...]

## Формат артефактов
[YAML frontmatter, changelog]

## Формат решений (ADR)
[Шаблон DEC-NNN]

## Соглашения
[Язык, именование, нумерация]
```

### Критичные секции для Agent Teams

**File Ownership** — без этого teammates будут конфликтовать на файлах:

```markdown
### File Ownership (кто какие файлы правит)

| Роль | Владеет (пишет) | Читает |
|------|-----------------|--------|
| **Facilitator** | ledger.md, decisions/, sessions/ | Всё |
| **Role-A** | artifacts/artifact-a.md | Всё |
| **Role-B** | roles/role-b/context.md | artifact-a |
```

**Spawn шаблон** — как facilitator создаёт teammates:

```markdown
### Запуск команды
Task(
  name="<role>",
  team_name="<project>-YYYY-MM-DD-topic",
  subagent_type="general-purpose",
  prompt="Ты — <Role Name> в команде [проекта].
    1. Прочитай .claude/commands/<role>.md — это твоя роль
    2. Прочитай project/ledger.md — контекст проекта
    3. Прочитай project/roles/<role>/context.md — твоя память
    4. Работай над задачами из TaskList
    5. Общайся через SendMessage (по имени)
    6. Пиши ТОЛЬКО в свои файлы (File Ownership)
    7. Результат отправь facilitator через SendMessage"
)
```

**Протокол teammate:**

```markdown
### Протокол teammate (для каждой роли)
1. Прочитай `.claude/commands/<role>.md`
2. Прочитай `project/ledger.md`
3. Прочитай `project/roles/<role>/context.md`
4. Проверь `TaskList` — найди свои задачи
5. Работай, общайся через SendMessage
6. По завершении: обнови context.md, пометь задачу completed
7. Проверь TaskList на следующую задачу
```

---

## 6. Шаг 4: Command-файлы ролей

**Путь:** `.claude/commands/<role>.md`

Command-файлы превращаются в slash-команды: `/role-a`, `/facilitator` и т.д. Claude Code автоматически подхватывает все `.md` файлы из `.claude/commands/`.

> Документация: Команды = markdown-файлы в `~/.claude/commands/` (user-level) или `.claude/commands/` (project-level). Вызываются через `/name`. Поддерживают аргументы через YAML frontmatter.

### Шаблон command-файла роли

```markdown
# <Role Name> — <Название по-русски>

Ты — [роль] в [проекте]. [1 предложение: ключевой принцип].

## Миссия
[1-2 предложения: что эта роль обеспечивает]

## Домены
- [Область ответственности 1]
- [Область ответственности 2]
- ...

## Ключевые функции

### 1. [Функция]
- [Конкретные действия]
- [Инструменты и подходы]

### 2. [Функция]
...

## Фреймворки

| Фреймворк | Когда применять |
|-----------|----------------|
| [Название] | [Контекст] |

## Формат вывода

```
## [Role] Тема
### Ключевой вывод
[Структура ответа]
```

## Поведение
- [Принцип 1: как роль себя ведёт]
- [Принцип 2]
- [Антипаттерны: чего НЕ делать]

## Режим Agent Team

При работе как teammate:
- **Имя:** <role-name>
- **Владеешь:** `<путь к файлу>`
- **Ключевые собеседники:** [имена ролей]
- Общий протокол teammate: см. "Agent Teams Protocol" в CLAUDE.md

## Контекст

Дополнительно прочитай:
1. `project/roles/<role>/context.md`
2. [Другие релевантные артефакты]
```

### Что делает command-файл хорошим

1. **Миссия** — чёткая, в 1-2 предложения. Роль знает зачем она существует.
2. **Домены** — явные границы ответственности. Роль знает что её, а что нет.
3. **Формат вывода** — конкретный шаблон. Ответы структурированы и предсказуемы.
4. **Поведение** — принципы и антипаттерны. Роль знает как себя вести.
5. **Режим Agent Team** — имя, файлы, собеседники. Роль знает как работать в команде.
6. **Не перегружен** — command-файл ≤ 100 строк. Детали — в context.md.

### Facilitator — особый случай

Facilitator сложнее других ролей. В его command-файле дополнительно:

- **Tension Processing** — как принимать и маршрутизировать запросы
- **Clarity Protocol** — как прояснять неясности перед решением
- **Decider Protocol** — как проводить голосование
- **Team Leadership** — как запускать, мониторить и завершать Agent Team сессии
- **Шаблоны задач** — типичные наборы задач для разных типов сессий

---

## 7. Шаг 5: Приватные контексты ролей

**Путь:** `project/roles/<role>/context.md`

### Назначение

Context.md — приватная память роли между сессиями. Обновляется самой ролью в конце каждой сессии. Содержит:
- Что роль узнала (факты, данные)
- Результаты анализа
- Открытые вопросы роли
- Заметки для будущих сессий

### Шаблон начального context.md

```markdown
# <Role Name> — Приватный контекст

## Текущее состояние
Инициализация. [Краткое описание стартовой точки].

## Известное
- [Факт 1 о текущем состоянии домена]
- [Факт 2]

## Открытые вопросы
- OQ-R01: [Вопрос, на который роль хочет ответ]
- OQ-R02: [Ещё вопрос]

## Заметки для будущих сессий
- [Что важно помнить]
```

### Как context.md эволюционирует

После аудита context.md роли Guardian вырос до 200 строк:
- Результаты анализа по 8 направлениям
- Реестр рисков с вероятностями и митигациями
- Devil's Advocate: 3 главных риска
- Сводка рекомендаций с приоритетами

**Правило:** context.md обновляет только сама роль. Это предотвращает конфликты в Agent Teams.

---

## 8. Шаг 6: Ledger — центр координации

**Путь:** `project/ledger.md`

Ledger — единственный файл, который ВСЕ роли читают первым. Это "приборная панель" проекта.

### Шаблон ledger.md

```yaml
---
last_updated: "YYYY-MM-DD"
last_session: "session-id"
active_phase: "phase-name"
next_session_date: null
project_name: "Название проекта"
---

# Project Ledger

## Текущая фаза: [Название]
[1-2 предложения: что происходит]

## Контекст
[Ключевые факты о проекте, ссылки на внешние источники]

## Команда
| Роль | Статус | Фокус |
|------|--------|-------|
| Facilitator | Active | [текущий фокус] |
| Role-A | Active | [текущий фокус] |
| Role-B | Ready | — |

## Активные задачи
- [ ] [Задача 1]
- [ ] [Задача 2]

## Недавно завершено
- [x] [Что сделано]

## Блокеры
[Нет / список блокеров]

## Открытые вопросы
- OQ-01: [Вопрос]

## Ключевые решения
- DEC-001: [Решение] — [статус]

## Фазы
| Фаза | Статус | Описание |
|------|--------|----------|
| Phase 1 | Done | [Результат] |
| Phase 2 | Active | [Фокус] |
| Phase 3 | Pending | — |
```

### Кто обновляет ledger

**Только Facilitator** (в обоих режимах). Это предотвращает конфликты и обеспечивает единый источник правды.

---

## 9. Шаг 7: Agent Teams — настройка

### Включение

Файл `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "in-process"
}
```

### Архитектура Agent Teams

```
Team Lead (Facilitator)
├── TaskList (общий)
├── Teammate: role-a (general-purpose agent)
├── Teammate: role-b (general-purpose agent)
├── Teammate: role-c (general-purpose agent)
└── SendMessage ←→ между всеми
```

**Ключевые свойства:**
- Team lead = главная сессия Claude Code, которая создаёт команду
- Каждый teammate = отдельный экземпляр Claude со своим контекстом
- История переписки lead НЕ переносится в teammates — весь контекст через CLAUDE.md + spawn prompt
- Teammates общаются через SendMessage (DM друг другу)
- Координация через общий TaskList

### Spawn шаблон (детальный)

```
Task(
  name="analyst",                         # Имя = как к нему обращаться в SendMessage
  team_name="project-2026-02-18-audit",   # Уникальное имя команды
  subagent_type="general-purpose",        # Тип агента (general-purpose = полный доступ к инструментам)
  prompt="Ты — Analyst (Аналитик) в команде [проекта].

КОНТЕКСТ:
1. Прочитай .claude/commands/analyst.md — это твоя роль
2. Прочитай project/ledger.md — состояние проекта
3. Прочитай project/roles/analyst/context.md — твоя память

ЗАДАЧА СЕССИИ:
[Конкретное описание tension/вопроса сессии]

ПРОТОКОЛ:
- Работай над задачами из TaskList
- Общайся с другими ролями через SendMessage (по имени)
- Пиши ТОЛЬКО в свои файлы: project/artifacts/scorecard.md, project/artifacts/experiment-board.md
- Результат отправь facilitator через SendMessage
- По завершении: TaskUpdate → TaskList → claim next"
)
```

### Важные ограничения Agent Teams

| Ограничение | Последствие | Митигация |
|------------|------------|-----------|
| Контекст lead не переносится | Teammate не знает историю разговора | Всё важное — в CLAUDE.md, spawn prompt, ledger |
| Каждый teammate = отдельные токены | Стоимость растёт линейно | Спавнить 3-5 ролей, не все 10 |
| Broadcast дорогой | N teammates = N сообщений | Использовать DM, broadcast только для критичного |
| Нет вложенных команд | Teammate не может создать свою команду | Только lead управляет командой |
| Нет resume для teammates | После /resume нужно спавнить заново | Сохранять результаты в context.md |
| Один team per session | Lead управляет одной командой | Cleanup перед новой командой |

### Как teammates обнаруживают друг друга

Конфиг команды сохраняется в `~/.claude/teams/{team-name}/config.json`. Teammates могут прочитать этот файл чтобы узнать имена и типы других участников. Но обычно достаточно указать ключевых собеседников в command-файле роли.

### Жизненный цикл Team Session

```
1. TeamCreate(team_name="...")
2. TaskCreate × N  (задачи для teammates)
3. Task × N        (spawn teammates)
4. [Teammates работают, общаются через SendMessage]
5. [Lead мониторит, перенаправляет]
6. [Lead собирает результаты]
7. Clarity Protocol + Decider Protocol с Owner
8. SendMessage(type="shutdown_request") каждому teammate
9. Обновить ledger, создать handoff
10. TeamDelete — очистка
```

---

## 10. Шаг 8: Hooks — quality gates

### Конфигурация hooks

Hooks — shell-команды, которые выполняются в ответ на события Claude Code. Для Agent Teams релевантны:

| Hook | Когда срабатывает | Зачем |
|------|-------------------|-------|
| `TaskCompleted` | Teammate пытается пометить задачу completed | Quality gate: проверить что работа сделана |
| `TeammateIdle` | Teammate уходит в idle | Проверить что teammate не остановился рано |
| `SubagentStart` | Teammate заспавнен | Инициализация окружения |
| `SubagentStop` | Teammate завершился | Cleanup |

### Файл hooks.json

**Путь:** `.claude/hooks/hooks.json`

```json
{
  "hooks": {
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/verify-task.sh"
          }
        ]
      }
    ]
  }
}
```

> Hook принимает JSON на stdin с полями: `session_id`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`, `cwd` и др.

### Скрипт quality gate

**Путь:** `.claude/hooks/verify-task.sh`

```bash
#!/bin/bash
# Hook: TaskCompleted
# Exit 0 = OK (задача закрывается)
# Exit 2 = блокировать завершение + feedback teammate-у

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Пример: проверить что teammate обновил свой context.md
CONTEXT_FILE="project/roles/${TEAMMATE}/context.md"
if [ -f "$CONTEXT_FILE" ]; then
  MODIFIED=$(stat -f %m "$CONTEXT_FILE" 2>/dev/null || stat -c %Y "$CONTEXT_FILE" 2>/dev/null)
  NOW=$(date +%s)
  DIFF=$((NOW - MODIFIED))

  # Если context.md не обновлялся более 5 минут — предупредить
  if [ "$DIFF" -gt 300 ]; then
    echo "Обнови свой context.md с результатами работы перед закрытием задачи: $TASK_SUBJECT" >&2
    exit 2
  fi
fi

exit 0
```

Не забудь сделать исполняемым: `chmod +x .claude/hooks/verify-task.sh`

### TeammateIdle hook (опционально)

```json
{
  "hooks": {
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/check-idle.sh"
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# Exit 2 = не давать teammate уйти в idle
INPUT=$(cat)
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Проверить что все задачи teammate закрыты
# (упрощённый пример)
exit 0
```

---

## 11. Шаг 9: Два режима работы

### Commands (последовательный)

Для быстрых вопросов, работы с 1-2 ролями, обновления одного артефакта.

```
Owner: /facilitator
Facilitator: "Нужна экспертиза Methodologist"
Owner: /methodologist
Methodologist: [ответ]
Owner: /facilitator
Facilitator: [синтез, Decider Protocol]
```

**Преимущества:** единый контекст, быстро, дёшево по токенам.
**Недостатки:** роли не спорят друг с другом, нет параллельной работы.

### Agent Teams (параллельный)

Для глубоких сессий с 4+ ролями, аудитов, дизайн-сессий, brainstorm.

```
Owner: "Запусти аудит текущего процесса"
Facilitator:
  1. TeamCreate
  2. TaskCreate × 5
  3. Spawn: Analyst, Interviewer, Recruiter, Candidate, Guardian
  4. [Роли работают параллельно, спорят через SendMessage]
  5. [Facilitator собирает результаты]
  6. Clarity Protocol с Owner
  7. Shutdown + cleanup
```

**Преимущества:** tensions явные, параллельная работа, глубокий анализ.
**Недостатки:** дорого по токенам, сложнее координация.

### Когда что использовать

| Ситуация | Режим |
|----------|-------|
| Точечный вопрос одной роли | Commands |
| Обновление одного артефакта | Commands |
| Быстрая проверка идеи | Commands |
| Аудит (много ролей анализируют) | Agent Teams |
| Дизайн-сессия (дискуссии между ролями) | Agent Teams |
| Brainstorm (Six Hats) | Agent Teams |
| Любая работа, где tensions создают ценность | Agent Teams |

---

## 12. Ключевые решения и их обоснование

### Решение 1: Роли = голоса стейкхолдеров

**Проблема:** Абстрактные функциональные роли (Examiner, Assessor) не создают tensions.
**Решение:** Каждая роль = голос реального участника процесса.
**Обоснование:** Tensions между реальными стейкхолдерами — источник ценности. Рекрутер хочет ускорить, guardian хочет проверить — из этого рождается баланс.

### Решение 2: File Ownership

**Проблема:** Параллельные teammates могут одновременно редактировать один файл → потеря данных.
**Решение:** Каждая роль пишет ТОЛЬКО в свои файлы. Ownership зафиксирован в CLAUDE.md.
**Обоснование:** Claude Code Agent Teams не имеют механизма блокировки файлов. Единственный надёжный способ — организационный: разделить ответственность.

### Решение 3: Spawn prompt содержит маршрут чтения

**Проблема:** Контекст lead не переносится в teammates. Teammate стартует "с чистого листа".
**Решение:** Spawn prompt явно указывает 3 файла для чтения: command → ledger → context.
**Обоснование:** CLAUDE.md загружается автоматически, но command-файл и context нужно прочитать явно. Порядок важен: сначала "кто я" (command), потом "что происходит" (ledger), потом "что я знал" (context).

### Решение 4: Facilitator = единственный writer ledger.md

**Проблема:** Если несколько ролей обновляют ledger — конфликты и inconsistency.
**Решение:** Только Facilitator пишет в ledger, decisions/, sessions/.
**Обоснование:** Facilitator — координатор. Он синтезирует результаты всех ролей и фиксирует единую картину.

### Решение 5: Два режима (Commands + Agent Teams)

**Проблема:** Agent Teams дорогие по токенам. Не для каждого вопроса нужна команда.
**Решение:** Commands для быстрых вопросов, Agent Teams для глубокой работы.
**Обоснование:** 80% взаимодействий — точечные вопросы к 1-2 ролям. Только 20% требуют параллельной работы. Оба режима используют одни и те же файлы (commands, contexts, ledger).

### Решение 6: Context.md = приватная память роли

**Проблема:** Между сессиями роль теряет контекст (новый spawn = новый контекст LLM).
**Решение:** Каждая роль обновляет свой context.md в конце сессии.
**Обоснование:** Context.md — "жёсткий диск" роли. При следующем spawn роль читает его и восстанавливает знания. Это дешевле чем передавать всю историю в prompt.

### Решение 7: Handoff между сессиями

**Проблема:** Следующая сессия не знает что произошло в предыдущей.
**Решение:** Facilitator создаёт `sessions/YYYY-MM-DD_topic/handoff.md` с ключевыми результатами.
**Обоснование:** Handoff — компактная "записка" для следующей сессии. Намного дешевле чем перечитывать полный лог. Facilitator читает handoff при старте новой сессии.

### Решение 8: Core Protocols для принятия решений

**Проблема:** Обсуждения зацикливаются, решения размытые.
**Решение:** Формализованные протоколы: Clarity Protocol → Decider Protocol.
**Обоснование:** McCarthy Core Protocols проверены десятилетиями практики. Clarity Protocol гарантирует что все "серые зоны" прояснены ДО голосования. Decider Protocol — быстрый и явный.

---

## 13. Чеклист запуска нового проекта

### Подготовка

- [ ] Определить домен проекта
- [ ] Перечислить реальных стейкхолдеров (5-10)
- [ ] Проверить tensions между ролями
- [ ] Определить фазы проекта

### Структура файлов

- [ ] Создать `.claude/CLAUDE.md` с полным контрактом
- [ ] Создать `.claude/settings.json` (Agent Teams)
- [ ] Создать `.claude/commands/<role>.md` для каждой роли
- [ ] Создать `project/ledger.md`
- [ ] Создать `project/backlog.md`
- [ ] Создать `project/roles/<role>/context.md` для каждой роли
- [ ] Создать `project/artifacts/` (пустая папка)
- [ ] Создать `project/decisions/` (пустая папка)
- [ ] Создать `project/sessions/` (пустая папка)

### Agent Teams

- [ ] Определить File Ownership (таблица в CLAUDE.md)
- [ ] Написать spawn prompt в facilitator.md
- [ ] Определить ключевых собеседников для каждой роли
- [ ] Создать `.claude/hooks/hooks.json` (опционально)
- [ ] Создать `.claude/hooks/verify-task.sh` (опционально)
- [ ] Сделать hook-скрипты исполняемыми (`chmod +x`)

### Проверка

- [ ] `/facilitator` работает, читает ledger
- [ ] Каждая роль через `/role-name` корректно загружает контекст
- [ ] Agent Team сессия запускается: TeamCreate → TaskCreate → spawn → работа → shutdown
- [ ] Teammates общаются через SendMessage
- [ ] File Ownership соблюдается (нет конфликтов)

---

## 14. Ссылки и документация

### Claude Code

| Тема | Ссылка |
|------|--------|
| Claude Code Overview | https://docs.anthropic.com/en/docs/claude-code |
| Agent Teams | https://docs.anthropic.com/en/docs/claude-code/agent-teams |
| Hooks | https://docs.anthropic.com/en/docs/claude-code/hooks |
| Settings | https://docs.anthropic.com/en/docs/claude-code/settings |
| Commands (Slash) | https://docs.anthropic.com/en/docs/claude-code/slash-commands |
| CLAUDE.md | https://docs.anthropic.com/en/docs/claude-code/memory |

### Теоретическая база

| Тема | Источник |
|------|----------|
| Core Protocols | Jim & Michele McCarthy, "Software for Your Head" |
| Holacracy 5.0 | Brian Robertson, "Holacracy: The New Management System" |
| Six Thinking Hats | Edward de Bono, "Six Thinking Hats" |
| Structured Interviews | SHRM (Society for Human Resource Management) |
| ADR (Architecture Decision Records) | Michael Nygard, "Documenting Architecture Decisions" |

### Инструменты Agent Teams

| Инструмент | Назначение |
|------------|-----------|
| `TeamCreate` | Создать команду и общий task list |
| `TeamDelete` | Удалить команду и очистить ресурсы |
| `Task` (с `team_name`) | Спавнить teammate |
| `TaskCreate` | Создать задачу в общем task list |
| `TaskList` | Посмотреть все задачи |
| `TaskGet` | Детали конкретной задачи |
| `TaskUpdate` | Обновить статус задачи (pending → in_progress → completed) |
| `SendMessage` (type: message) | DM конкретному teammate |
| `SendMessage` (type: broadcast) | Сообщение всем (дорого!) |
| `SendMessage` (type: shutdown_request) | Попросить teammate завершиться |

---

## Приложение A: Полный пример — минимальный проект

### Домен: "Онбординг новых сотрудников"

**Роли (5):**
1. Facilitator — координация
2. Buddy — голос ментора/бадди
3. Manager — голос руководителя
4. Newbie — голос нового сотрудника
5. HRBizPartner — голос HR

**File Ownership:**

| Роль | Пишет | Читает |
|------|-------|--------|
| Facilitator | ledger.md, decisions/, sessions/ | Всё |
| Buddy | artifacts/buddy-program.md | Всё |
| Manager | artifacts/manager-checklist.md | Всё |
| Newbie | artifacts/onboarding-journey.md | Всё |
| HRBizPartner | artifacts/hr-process.md | Всё |

**Фазы:**
```
Audit → Design → Content → Pilot → Launch → Optimize
```

**Spawn пример:**

```
Task(
  name="newbie",
  team_name="onboarding-2026-03-01-audit",
  subagent_type="general-purpose",
  prompt="Ты — Newbie (Голос нового сотрудника) в команде по онбордингу.
    1. Прочитай .claude/commands/newbie.md
    2. Прочитай project/ledger.md
    3. Прочитай project/roles/newbie/context.md
    4. Tension: провести аудит текущего онбординга глазами новичка
    5. Работай над задачами из TaskList
    6. Пиши ТОЛЬКО в artifacts/onboarding-journey.md
    7. Результат отправь facilitator через SendMessage"
)
```

---

## Приложение B: Паттерны коммуникации в Agent Teams

### Паттерн 1: Запрос экспертизы

```
SendMessage(
  type="message",
  recipient="guardian",
  content="Мы предлагаем убрать один из этапов онбординга.
  Видишь ли ты риски для compliance?",
  summary="Запрос проверки compliance"
)
```

### Паттерн 2: Конструктивный спор

```
SendMessage(
  type="message",
  recipient="manager",
  content="Ты предлагаешь добавить 3 чек-поинта в первый месяц.
  Как buddy, я вижу что это перегрузит и ментора и новичка.
  Предлагаю 2 чек-поинта: на 2 неделю и на 4 неделю.
  Это покроет 80% рисков при 50% нагрузке.",
  summary="Контрпредложение по чек-поинтам"
)
```

### Паттерн 3: Эскалация к Facilitator

```
SendMessage(
  type="message",
  recipient="facilitator",
  content="Мы с Manager не можем договориться о количестве чек-поинтов.
  Нужно решение Owner. Мои аргументы: [кратко].
  Аргументы Manager: [кратко].",
  summary="Эскалация: количество чек-поинтов"
)
```

### Паттерн 4: Broadcast (только критичное)

```
SendMessage(
  type="broadcast",
  content="ВНИМАНИЕ: Обнаружено что текущий онбординг нарушает ТК РФ
  (ст. 212 об охране труда). Все предложения должны учитывать
  обязательный инструктаж в первый день.",
  summary="Legal блокер: охрана труда"
)
```
