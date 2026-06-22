---
description: "Первичная настройка проекта: домен, ценности, ledger/glossary/domain, planner-context bootstrap"
---

# Setup Project — Настройка проекта

Ты — мастер настройки. Проведи Founder через пошаговую инициализацию проекта в Core Team Framework (Variant C, subagent-based).

## Контекст

Прочитай `.claude/knowledge/guide-multi-agent-teams.md` для полных инструкций.

Канонические определения:
- **Subagent-роли** — `.claude/agents/` (8 ролей: facilitator, architect, dev, test, cto, designer, keeper, customer)
- **Шаблоны проектных артефактов** — `.claude/templates/project/`

## Процесс настройки

### Шаг 1: Определение проекта

Через `AskUserQuestion` спроси:
1. **Название проекта**
2. **Описание** — 1-2 предложения: что это за проект
3. **Тип проекта:**
   - `dev` — разработка ПО (TDD, /plan-feat, /plan-do, /plan-reflect)
   - `research` — исследование, стратегия, аналитика
   - `hybrid` — разработка + бизнес/исследование
   - `custom` — полная настройка ролей под домен

### Шаг 2: Активные роли (subagents)

Все 11 subagent-ов уже определены в `.claude/agents/`. На этом шаге решается, какие активны для данного типа проекта:

| Тип | Активные subagents |
|-----|--------------------|
| dev | facilitator + architect + dev + test + cto + product + designer + keeper |
| research | facilitator + cto + analyst + customer + keeper |
| hybrid | все 11 (facilitator, architect, dev, test, cto, product, guardian, analyst, designer, keeper, customer) |
| custom | определить вместе с Founder через тест необходимости |

**Опциональные включения** (по запросу Founder, не дефолт):
- `guardian` — для проектов с legal/compliance/PII или существенными рисками (рекомендуется добавить даже к dev/research)
- `analyst` — для проектов с рыночным фокусом (research всегда, dev — опционально)
- `product` — для projects с явной стратегией продукта (research — опционально, dev — обычно нужен)

**Тест необходимости роли** (для custom):
- [ ] Уникальные интересы
- [ ] Tensions с 2+ другими ролями
- [ ] Без неё — слепая зона
- [ ] Собственные артефакты
- [ ] Реальный стейкхолдер процесса

Используй `/self-service` для глубокого исследования новой custom-роли (лучшие практики, книги). Если custom-роль нужна — создай `.claude/agents/<role>.md` по образцу существующих.

### Шаг 3: Система ценностей

1. Прочитай `.claude/knowledge/values-template.md`
2. Покажи шаблон Founder через `AskUserQuestion`
3. Уточни: что изменить, добавить, убрать?
4. Рекомендация: 5-9 ценностей, упорядоченных по приоритету
5. Создай `project/values.md` — **конституционный файл** (только Founder редактирует)

### Шаг 4: Создание структуры project/

Создай файлы из шаблонов:

```
project/
├── ledger.md            ← templates/project/ledger.md
├── backlog.md           ← templates/project/backlog.md
├── values.md            ← настроенный на шаге 3
├── glossary.md          ← templates/project/glossary.md (RU/EN/определение/«не является»)
├── domain.md            ← templates/project/domain.md (факты о реальности, по bounded contexts)
├── roles/
│   ├── facilitator/context.md  ← templates/project/role-context-template.md
│   ├── architect/context.md
│   ├── dev/context.md
│   ├── test/context.md
│   ├── cto/context.md
│   ├── designer/context.md
│   ├── keeper/context.md
│   └── customer/context.md
├── artifacts/           ← по мере создания (artifact-template.md)
├── decisions/           ← по мере создания (adr-template.md)
├── sessions/            ← по мере сессий (session-template.md, handoff-template.md)
└── features/            ← по мере /plan-feat (feature-template.md)
```

### Шаг 5: Output Style

1. Скопируй `.claude/output-styles/core-team.md` — шаблон стиля
2. Замени `{{project_name}}` на название проекта (из шага 1)
3. `keep-coding-instructions`:
   - `dev` / `hybrid` → `true`
   - `research` / `custom` → `false` (спроси Founder при сомнении)
4. Установи стиль: в `.claude/settings.json` добавь `"outputStyle": "core-team"`

### Шаг 6: Infrastructure Principles (dev, hybrid)

Только если тип `dev` или `hybrid`:

1. Скопируй `.claude/templates/project/infrastructure-principles.md` → `project/artifacts/infrastructure-principles.md`
2. Замени `{{project_name}}`, `{{date}}`
3. Через AskUserQuestion обсуди с Founder:
   - **Стек:** язык, фреймворк, БД. Рекомендуй best practices
   - **Фаза:** что нужно сейчас vs что отложить
   - **Backend** — дефолты (uv, pytest, Docker) подходят? Или другой стек?
   - **Frontend** — нужен? Какой фреймворк?
4. Адаптируй секции под выбранный стек
5. Заполни "Проектно-специфичные принципы" и "Что НЕ нужно на старте"

**CTO владеет этим артефактом.**

### Шаг 7: Bootstrap planner-context.md

Запусти `Agent(subagent_type=facilitator)` с задачей: «Активируй skill `planner` (см. SKILL.md) и выполни bootstrap — создай `<project-root>/.claude/planner-context.md` по `references/template-context.md` и заполни секции 1-4 (каталог subagent-ов, slash-команд, skills, default-моделей) из текущего состояния `.claude/`.»

После bootstrap planner-context.md содержит:
- §1 Каталог 8 subagent-ов с моделями и триггерами
- §2 Каталог slash-команд (/facilitator, /setup-project, /end-session, /self-service, /plan-feat, /plan, /plan-do, /plan-reflect, /update-docs)
- §3 Каталог skills (functional-clarity, tdd-master, navigator, fpf-integration, planner, planner-reflect, llms-keeper)
- §4 Default-модели (Opus 4.7, Sonnet 4.6, Haiku 4.5)
- §5 Хранение фич: `project/features/FEAT-NNNN-<slug>/`
- §6 Соглашения именования
- §7 Метаданные bootstrap

### Шаг 8: Обновление CLAUDE.md

Заполни секцию **«Текущий проект»** (название, тип, фаза) — она в начале файла.

### Шаг 9: Проверка целостности

Запусти `Agent(subagent_type=facilitator)` с заданием: «`/self-service` в режиме аудита — проверь, что все 8 subagent-ов достижимы, нет осиротевших артефактов, File Ownership непротиворечив (см. таблицу в CLAUDE.md), все skills и команды на месте, planner-context.md согласован с фактическим состоянием `.claude/`».

### Шаг 10: Первая сессия

Предложи Founder запустить **`/facilitator`** для первой рабочей сессии (хотя facilitator — default, явный вызов помогает зафиксировать начало).

## Минимальная настройка (быстрый старт)

Если Founder хочет начать быстро:
1. Название + тип (Шаг 1)
2. Ценности по дефолту (Шаг 3)
3. Структура `project/` из шаблонов (Шаг 4)
4. Output Style (Шаг 5)
5. Bootstrap planner-context.md (Шаг 7)
6. `/facilitator` для начала работы — остальное по мере необходимости

## Critical: вопросы только через AskUserQuestion

Все вопросы Founder задавай через `AskUserQuestion`, не текстом. Группируй 2-4 за вызов.
Все задачи — через `TaskCreate` (compact-safe).
