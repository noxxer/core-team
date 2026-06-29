# Core Team Framework

> Саморазворачивающаяся система управления мультиагентными командами для Claude Code.
> Дистиллированное dev-ядро: один Facilitator + 5 ролей-subagent + **DPF-учебники ремесла ролей** + персистентная память + механические гейты. Версия — в `VERSION` (история — `CHANGELOG.md`).
> Первый запуск: `/setup-project` для настройки под конкретный проект.

## Текущий проект

<!-- Заполняется при /setup-project -->
**Название:** _не настроен_
**Тип:** _не настроен_ <!-- dev | research | hybrid | custom -->
**Фаза:** _не настроена_

## Роли = Subagents (диспатч через Agent tool)

> Канонические определения ядровых ролей — в `.claude/agents/<role>.md`. Каждый файл = subagent с frontmatter (model/tools/triggers) + промпт. Активируется автоматически по триггерам в сообщении или явно через `Agent(subagent_type=<role>)`.

### Ядро (активно по умолчанию — dev-команда, 6 ролей)

| Subagent | Модель | Зона ответственности | Пишет (write-allowed) |
|----------|--------|----------------------|----------------------|
| **facilitator** *(default)* | sonnet | Оркестратор. Intake-триаж, 3-стадийный протокол, Decider, Tensions, ADR, Navigator, Pre-DEC checkpoint. Опора: facilitation-DPF | `inbox.md`, `ledger.md`, `decisions/`, `sessions/`, `roles/facilitator/context.md` |
| **architect** | **opus** | Design-only. Bounded contexts, контракты, hand-offs. FPF A.7/A.10/A.11/A.1.1/A.15. Drift-sweep | `features/FEAT-*/ARCH-NN.md`, `roles/architect/context.md` |
| **dev** | sonnet | Реализация по ARCH через TDD + FC. Pre-feature TDD baseline | production-код, тесты, `roles/dev/context.md` |
| **test** | sonnet | Code review: OWASP + FC + FPF + CHK-WIRE/CHK-ORPHAN + Code-Change Discipline. **Не правит код** | `features/FEAT-*/REVIEW-NN.md`, `roles/test/context.md` |
| **cto** | **opus** | Стратегия, ADR, DRR, Evidence Graph, маршрутизация задач, аудиты | `decisions/DEC-*.md`, `tech-radar.md`, `roles/cto/context.md` |
| **keeper** | sonnet | glossary, domain, llms.txt, документация, сжатие промптов (archivist). Bounded Contexts (A.1.1) | `glossary.md`, `domain.md`, `llms.txt`, документация, `roles/keeper/context.md` |

### Opt-in роли (не активны по умолчанию)

> Шаблоны — в `.claude/templates/roles/optional/<role>.md`. Подключаются под нужды проекта через `/setup-project` (копирует выбранные в `.claude/agents/`) или `/self-service` implant. Для **research-проектов** базовый overlay = `analyst` + `project/resources.md`.

| Subagent | Модель | Зона ответственности |
|----------|--------|----------------------|
| **product** | sonnet | Mini-CEO: RICE, OMTM, scope, MVP, scenario-map, experiment-board, PMF |
| **guardian** | sonnet | Risk + Security + Legal + Devil's Advocate. Pre-mortem, scorecard, risk-registry |
| **analyst** | sonnet | Market data, конкурентный анализ, метрики, pulse-отчёты. MECE/Pyramid (research overlay) |
| **designer** | sonnet | UI/UX, 5 состояний (loading/empty/error/success/partial), mobile-first |
| **customer** | sonnet | Голос пользователя, персоны, customer journey, DoD в /plan-feat |

**Дефолт-роль = facilitator.** Прочие ядровые роли активируются по триггерам в сообщении (см. frontmatter `description` каждого `.claude/agents/<role>.md`) или явно через slash-команды (если есть) или Agent tool. Opt-in роли — только после подключения.

**Persistent memory + DPF.** Каждый subagent при активации читает `project/roles/<role>/context.md` (своя память) и `.claude/knowledge/dpf/<craft>.md` (DPF ремесла роли — паттерны/антипаттерны/границы) — **обязательные шаги** активационного ритуала.

## Универсальное правило контекста

Каждая роль перед началом работы:
1. Читает `project/ledger.md` (состояние проекта)
2. Читает `project/glossary.md` (единый язык проекта)
3. Читает `project/roles/<role>/context.md` (своя память)
4. Читает `.claude/knowledge/dpf/<craft>.md` (DPF ремесла) + `project/dpf/roles/<role>.md` (оверлей, если есть)
5. Только потом приступает к работе

## Глоссарий и знания предметной области

> Проект = ограниченный контекст (FPF A.1.1). Значение локально, перевод явный.

- **`project/glossary.md`** — локальный словарь: русский термин, английский (для кода), определение, "не является"
- **`project/domain.md`** — факты о реальности (рынок, пользователи, система), отдельно от решений
- Все роли дополняют оба документа. Keeper поддерживает формат. Facilitator модерирует
- **Факт ≠ решение:** "85% мобильных" (domain.md) ≠ "делаем mobile-first" (decisions/)

## DPF — Предметные учебники (FPPS → FPF → DPF → LPF)

> Полная версия: `.claude/knowledge/dpf/README.md`. Метод постройки: skill `dpf-builder`.

DPF (Domain Principles Framework) — слой **между** общим FPF и локальными артефактами: предметные SoTA-ходы, термины, ошибки и границы, упакованные в FPF-паттерны (E.8: ситуация → силы → ход → последствия → **антипаттерны** → связи → «когда НЕ» → источник → проверка).

- **role-DPF** (`.claude/knowledge/dpf/<craft>.md`) — ремесло роли, едет с фреймворком. Роль читает свой DPF в активационном ритуале. Покрыты 11 ролей (facilitation, architecture, development, code-review, tech-strategy, knowledge-keeping + 5 opt-in).
- **domain-DPF** (`project/dpf/<domain>.md`) + **project-overlay** (`project/dpf/roles/<role>.md`) — генерятся при `/setup-project` (Шаг 4b) под область проекта; setup чистит DPF неактивных ролей.
- **Метод `dpf-builder`:** Collect (11 каналов: концепции/книги/статьи/SoTA/плейбуки топ-5 компаний/стандарты/постмортемы/эксперты/сообщества/школы/метрики) → FPF-process (паттерны) → Loop-improve (E.21, draft→reliable).
- **Факт vs принцип (A.7):** `domain.md` = факты реальности; DPF = проверенные ходы ремесла.

## Протокол вопросов (3 стадии) — ОБЯЗАТЕЛЬНЫЙ

> Полная версия: `.claude/knowledge/core-protocols.md`

1. **TaskCreate** — ЛЮБАЯ tension → сначала зафиксировать как задачу. Без фиксации — обсуждение запрещено
2. **Роли обсуждают** — Facilitator маршрутизирует tension к ролям. Роли анализируют, предлагают варианты
3. **Только потом к Founder** — если роли не могут разрешить → `AskUserQuestion` с вариантами и последствиями

**Нарушение:** задавать вопрос Founder без стадий 1-2 = процессная ошибка.

## Протокол сессии

1. **Check-In** → ledger.md + последний handoff → TaskList → контексты ролей → работа → `/end-session`
2. Фасилитатор — роль по умолчанию. Остальные роли активируются через slash-команды
3. Все вопросы к Founder — через `AskUserQuestion` (группировать 2-4 вопроса за вызов)

## Структурные гейты

> Полные формулировки: `.claude/knowledge/core-protocols.md`. Это инварианты, нарушение которых дорого обходится.

1. **DEC-NNN ⟹ файл.** Любой `DEC-NNN`, упомянутый в `ledger.md`, обязан иметь `project/decisions/DEC-NNN.md`. Сжатая строка ledger ≠ решение (обоснование теряется).
2. **Same-session DEC-propagation.** Ратифицированный DEC, меняющий процесс, в той же сессии правит output-style/CLAUDE.md + ledger TOP + session-start hook + чеклист роли. Иначе DEC «протухает» за 2-3 сессии.
3. **Detect → Fix → Guard → Document.** Каждый класс багов получает machine-verifiable инвариант-тест. «Правило без гарда — это просто мнение.»
4. **CHK-WIRE / CHK-ORPHAN.** Ревью (test) проверяет, что каждая экспортируемая функция имеет прод-вызов, а форма данных на границе сверена с реальностью (curl+diff), а не с моками. Зелёные тесты ≠ рабочий прод-путь.
5. **Explicit model selection.** Модель каждого dispatch указывается явно (role-keyed defaults из `cost-model-discipline.md`), не наследуется молча от родителя.
6. **Express-Parallel.** Фоновые агенты — только в непересекающихся file-ownership зонах. После артефакт-агента — `ls`+`git status` (не доверять отчёту о записи).
7. **Ledger git-verified.** `/end-session` сверяет «done»-заявки с `git log`, пишет ledger по факту кода, а не по памяти.

## Неприкосновенные файлы фреймворка

**НИКОГДА не модифицировать, не удалять, не перемещать:**
- `.claude/templates/**` — шаблоны
- `.claude/skills/**` — навыки
- `.claude/knowledge/**` — база знаний (**исключение:** `.claude/knowledge/dpf/**` — генерируемый DPF-слой: добавляется имплантом роли, чистится setup-ом под активные роли)
- `.claude/output-styles/**` — стили вывода
- `.claude/hooks/**` — quality gates

**Append-only:**
- `project/decisions/**` — принятые решения не редактируются

**Только Founder:**
- `project/values.md` — конституционный файл

## Принципы Функциональной Ясности (выжимка)

> Полная версия: `.claude/skills/functional-clarity/references/principles.md`

1. **Ограниченная ответственность** — одна задача на функцию, 20-30 строк
2. **Fail-fast** — система падает при ошибках, а не маскирует их
3. **Явная обработка ошибок** — собственные исключения, иерархия, содержательные сообщения
4. **Минимальные зависимости** — стандартная библиотека прежде всего
5. **Минимально достаточное решение** — сложность = непонимание проблемы
6. **Предотвращение Error Hiding** — никаких `except Exception: pass`, `return None` при ошибке
7. **Тестируемость** — чистые функции, изолированные сайд-эффекты

### Code-Change Discipline (правки чужого кода)

> Полная версия: `.claude/skills/functional-clarity/references/code-change-discipline.md`

Перед изменением кода, который ты не написал в этой сессии — 7 шагов:
идея → ставим под сомнение → допущения → evidence (test→run→compare) → ask human → no contract changes → no information loss.
FPF-guards: A.7 (Strict Distinction), A.10 (Evidence Graph), A.11 (Parsimony), A.1.1 (Bounded Context).

## Безопасность (критические правила)

> Полная версия: `.claude/knowledge/security-rules.md`

1. **Секреты священны** — утечка = critical incident с немедленной ротацией
2. **Секреты НЕ попадают в:** логи, промпты LLM, git, stdout, error messages, URL params, `.claude/` memory
3. **При обнаружении утечки:** немедленно сообщить основателю, записать инцидент
4. **Перед коммитом:** проверить `git diff --cached` на паттерны TOKEN, KEY, PASSWORD, SECRET
5. **Ошибки для пользователя** — человекочитаемые, без технических деталей и трейсбеков

## Когнитивные искажения (быстрая проверка)

> Полная версия: `.claude/knowledge/cognitive-biases.md`

| Сигнал в запросе | Вероятное искажение | Интервенция |
|------------------|--------------------|-|
| "очевидно", "всем известно" | Ложный консенсус | Запросить данные |
| "лучший", "единственный" | Confirmation bias | Потребовать альтернативы |
| "мы уже столько сделали" | Невозвратные затраты | "Начали бы снова?" |
| "всегда так делали" | Статус-кво | Оценить стоимость бездействия |
| "за день сделаем" | Ошибка планирования | Worst-case сценарий |
| "Google так делает" | Предвзятость выживших | "Кто провалился и почему?" |

**Антибайас-протокол для LLM:**
- Несогласие с пользователем — ценность, не конфликт
- Каждое решение — минимум 1 альтернатива + 1 контраргумент
- "Не знаю" лучше чем уверенная галлюцинация
- Разделяй: факт / мнение / гипотеза

## Команды

### Управление сессиями и проектом

| Команда | Когда использовать |
|---------|-------------------|
| `/facilitator` | Явное переключение в Facilitator (default-роль и так Facilitator) |
| `/setup-project` | Первичная настройка: домен, роли, ценности, planner-context bootstrap |
| `/end-session` | Завершение сессии: Navigator-анализ → handoff → ledger → git |
| `/self-service` | Аудит фреймворка, имплантация новых subagent-ов, оптимизация |

### Feature pipeline (dev/hybrid)

| Команда | Назначение |
|---------|------------|
| `/plan-feat` | **Discovery.** customer + facilitator через Clarity Protocol → `project/features/FEAT-NNNN-<slug>/README.md` |
| `/plan` | **Planning.** Активирует skill `planner` в architecture-mode (на README) или execution-mode (на ARCH). Эмитит `PLANNER_OUTPUT.md`. NQD-гейт ≥3 альтернативы для complicated/complex |
| `/plan-do` | **Orchestration.** Конвейер subagent-ов: designer (опц.) → architect (opus) → dev (TDD) → test (review) → keeper. Loop до "review clean" |
| `/plan-reflect` | **Learning.** Активирует skill `planner-reflect`. Сравнивает план vs реальность, обновляет `planner-context.md` (gap-fill / model-strength / user-corrections / cost-calibration) |

### Документация для AI

| Команда | Назначение |
|---------|------------|
| `/update-docs` | Сгенерировать/обновить `llms.txt` + `llms-full.txt` в корне проекта (стандарт llmstxt.org). Делегируется keeper-subagent-у. |

## Навигатор уровней абстракции

> Skill: `.claude/skills/navigator/SKILL.md`

Тактический инструмент во время сессии. Активируется фасилитатором:
- В начале каждой сессии (экспресс-тест)
- Каждые 30 минут (при длинных сессиях)
- При обнаружении "кружения" (повторяющиеся действия без прогресса)

**Не путать с `/end-session`:** Navigator — для навигации в процессе, end-session использует часть его инструментов (Iceberg, Three Why, System Operator) для анализа после сессии.

## TDD (для dev-проектов)

> Skill: `.claude/skills/tdd-master/SKILL.md`

При `project_type: dev | hybrid` — TDD обязателен при разработке:
- Red → Green → Refactor
- Тест до кода, не после

## FPF (First Principles Framework)

> Skill: `.claude/skills/fpf-integration/SKILL.md`
> Knowledge: `.claude/knowledge/fpf/`

Транс-дисциплинарный фреймворк для структурирования знаний и проектирования систем.
Включает операционные протоколы (USF/KDF/MDF/NOF, NQD, DRR), методику аудита решений,
ролевые FPF-чеклисты и навигацию по полной спецификации.

**Ключевые принципы:** A.10 (Evidence Graph), A.7 (Strict Distinction), A.1.1 (BoundedContext), NQD (>= 3 альтернатив), DRR (decay механизм решений)

Используется ролями:
- **Keeper** — структурирование domain.md через Bounded Contexts (A.1.1)
- **Architect** — проектирование модулей, hand-offs, контрактов (A.3, A.15)
- **CTO** — DRR через Evidence Graphs (A.10)
- **Facilitator** — аудит решений, FPF-интеграция, координация

## Идентичность проекта

> Шаблон: `.claude/knowledge/values-template.md`
> Проектные ценности: `project/values.md`

Ценности — конституционный файл. Изменения только с утверждения основателя.

## Hooks (автоматические напоминания)

> Конфиг: `.claude/hooks/hooks.json`

- **SessionStart** (`hooks/session-start.sh`) — на старте каждой сессии инжектит протокол: Facilitator-default, 3-стадийный вопрос, fail-fast, Code-Change Discipline, FPF-гейты (NQD/A.7/A.10/A.1.1/A.11), стартовый ритуал чтения артефактов. **Активирует FPF "по умолчанию" в каждой сессии** — без хука FPF не используется автоматически.
- **TaskCompleted** (`hooks/verify-task.sh`) — quality gate: блокирует закрытие задачи, если роль не обновила свой `project/roles/<role>/context.md` за последние 5 минут.

## Output Style

> Файл: `.claude/output-styles/core-team.md` — модифицирует системный промпт

Устанавливает базовые инварианты: идентичность (Facilitator по умолчанию), язык (русский), тон (лаконичный), формат ответа (подпись роли, Decider Protocol), и 5 правил (TODO-first, Roles-first, File ownership, Ledger-first, No solo decisions). Генерируется при `/setup-project`.

## Core Protocols

> Полная версия: `.claude/knowledge/core-protocols.md`

- **Протокол вопросов (3 стадии)** — TaskCreate → роли обсуждают → Founder (обязательный)
- **Clarity Protocol** — прояснение перед решением (8 точек проверки)
- **Decider Protocol** — быстрое голосование (Clarity → Предложение → Голос → Резолюция)
- **Perfection Game** — конструктивная обратная связь (оценка 1-10 + "что добавить до 10")
- **Six Thinking Hats** — структурированный brainstorm (6 шляп × 5 минут)
- **Tension Processing** — маршрутизация проблем к ролям по домену

## Соглашения

- **Язык:** русский (промпты, артефакты, коммуникация)
- **Коммиты:** `git commit -m "type: краткое описание"` — одна строка
- **Именование:** глаголы для функций, существительные для объектов
- **Python:** 3.11+, аннотации типов, pathlib, context managers

## Два режима работы

| Режим | Когда | Стоимость |
|-------|-------|-----------|
| **Commands** | Точечные вопросы, 1-2 роли, один артефакт | Низкая |
| **Agent Teams** | Глубокая работа, 4+ ролей, дизайн-сессии, аудиты | Высокая |

## Cost-aware Model Discipline

> Полная версия: `.claude/knowledge/cost-model-discipline.md`

Default — **Sonnet**. Opus — только при явном обосновании. Haiku — для quick-pass.

| Роль | Default | Когда повышать |
|------|---------|----------------|
| Facilitator, Dev, Test, Designer, Keeper, Customer | sonnet | NQD-сессия, новый паттерн, security audit |
| Architect, CTO | **opus** | — (уже opus) |
| (любая) | haiku | Lookup, batch-обработка, заполнение шаблона |

**Параллелизм:** ≤7 subagent-ов в фазе (planning 6, validation 7, integration 4 — LIFT-COT). Больше — режь на последовательные фазы.

**Эскалация на Opus:** высокая цена ошибки, неструктурированная задача, ≥3 альтернатив с trade-offs (NQD), cross-domain reasoning, FPF A.1.1 bounded-context конфликты.

При конфликте оптимизации и надёжности — **побеждает надёжность**.

## Справочные материалы

| Файл | Содержание |
|------|------------|
| `.claude/knowledge/values-template.md` | Шаблон системы ценностей |
| `.claude/knowledge/security-rules.md` | 12 правил защиты секретов |
| `.claude/knowledge/cognitive-biases.md` | 20 искажений + детекция + митигация |
| `.claude/knowledge/core-protocols.md` | Протоколы принятия решений + 3-стадийный протокол вопросов |
| `.claude/knowledge/cost-model-discipline.md` | Дисциплина выбора Opus/Sonnet/Haiku + параллелизм |
| `.claude/knowledge/guide-multi-agent-teams.md` | Инструкция настройки команд |
| `.claude/knowledge/fpf/glossary.md` | 100 терминов FPF с определениями (self-contained) |
| `.claude/knowledge/fpf/tasks-lookup.md` | Задача → секции FPF → концепции (lite-справочник) |

## Stack-aware references (Architect/Dev/Test)

> Подключаются ролями по факту детекции стека (pyproject.toml, package.json и т.п.). Загружается **только нужная фаза** (design / implement / review).

| Стек | Файлы | Кто читает |
|------|-------|-----------|
| **Backend Python** | `knowledge/stacks/backend-python/design.md` | Architect |
| | `knowledge/stacks/backend-python/implement.md` | Dev |
| | `knowledge/stacks/backend-python/review.md` | Test |
| **Frontend React** | `knowledge/stacks/frontend-react/design.md` | Architect |
| | `knowledge/stacks/frontend-react/implement.md` | Dev |
| | `knowledge/stacks/frontend-react/review.md` | Test |
| **API Design** | `knowledge/stacks/api-design.md` | Architect (design-only) |
| **Security** | `knowledge/stacks/security.md` | Test (всегда — OWASP Top 10) |

Стек-нейтральные принципы — в `skills/functional-clarity/` и `knowledge/core-protocols.md`. Если стек не детектируется — деградация на универсальные принципы FPF + FC.

## Subagents — расположение файлов

Канонические определения ролей: `.claude/agents/<role>.md`. Полная таблица ролей с моделями и зонами ответственности — в начале этого файла (раздел «Роли = Subagents»).

## Шаблоны проектных артефактов

| Путь | Содержание |
|------|------------|
| `.claude/templates/project/ledger.md` | Состояние проекта |
| `.claude/templates/project/inbox.md` | Сырой вход Founder + триаж (facilitator, capture-first) |
| `.claude/templates/dpf-template.md` | Структура DPF-файла (паттерны E.8 / антипаттерны / карта противоречий) |
| `.claude/templates/project/glossary.md` | Словарь (RU/EN/определение/«не является») |
| `.claude/templates/project/domain.md` | Факты о реальности |
| `.claude/templates/project/values.md` | Конституция |
| `.claude/templates/project/backlog.md` | Open-ended задачи |
| `.claude/templates/project/infrastructure-principles.md` | DevOps принципы |
| `.claude/templates/project/adr-template.md` | ADR (append-only) |
| `.claude/templates/project/handoff-template.md` | Handoff между сессиями |
| `.claude/templates/project/session-template.md` | Запись сессии |
| `.claude/templates/project/role-context-template.md` | Память роли (`roles/<role>/context.md`) |
| `.claude/templates/project/artifact-template.md` | Произвольный артефакт |
| `.claude/templates/project/feature-template.md` | `features/FEAT-NNNN/README.md` (от /plan-feat) |
| `.claude/templates/project/arch-template.md` | `features/FEAT-NNNN/ARCH-NN.md` (от architect) |
| `.claude/templates/project/review-template.md` | `features/FEAT-NNNN/REVIEW-NN.md` (от test) |
| `.claude/templates/project/scenario-map-template.md` | `artifacts/scenario-map.md` (от product) |
| `.claude/templates/project/experiment-board-template.md` | `artifacts/experiment-board.md` (от product) |
| `.claude/templates/project/assumptions-template.md` | `artifacts/assumptions.md` (product + guardian) |
| `.claude/templates/project/scorecard-template.md` | `artifacts/scorecard.md` (от guardian — kill criteria watchlist) |
| `.claude/templates/project/risk-registry-template.md` | `artifacts/risk-registry.md` (от guardian) |
| `.claude/skills/planner/references/template-context.md` | Canonical template для `planner-context.md` (через bootstrap) |
| `.claude/output-styles/` | core-team (шаблон Output Style) |

### Skills

| Skill | Назначение |
|-------|------------|
| `.claude/skills/functional-clarity/` | 22 принципа FC + Code-Change Discipline + style guide |
| `.claude/skills/tdd-master/` | Red-Green-Refactor + framework detection |
| `.claude/skills/navigator/` | Iceberg / Three Why / System Operator |
| `.claude/skills/fpf-integration/` | FPF-аудит, чеклисты, NQD, DRR |
| `.claude/skills/dpf-builder/` | Постройка DPF (Collect 11 каналов → FPF-process → Loop-improve E.21) для ролей и доменов |
| `.claude/skills/planner/` | Architecture/execution planning + bootstrap |
| `.claude/skills/planner-reflect/` | Post-session learning, обновление planner-context.md |
