# Changelog

Все значимые изменения фреймворка. Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версионирование — [SemVer](https://semver.org/lang/ru/).

## [5.0.0] — 2026-06-29

DPF-слой: предметные учебники ремесла для каждой роли + intake-протокол фасилитатора + полный FPF-индекс. Реализация идеи DPF (Domain Principles Framework) из практикума А. Левенчука (28.06.2026): экосистема **FPPS → FPF → DPF → LPF**.

### Added
- **DPF-слой (Domain Principles Framework)** — недостающее звено между общим FPF и локальными артефактами проекта. Предметные SoTA-ходы/термины/ошибки/границы, упакованные в FPF-паттерны (E.8: ситуация→силы→ход→последствия→**антипаттерны**→связи→«когда НЕ»→источник→проверка).
- **Skill `dpf-builder`** — переиспользуемый метод постройки DPF: Collect (11 каналов сбора, вкл. плейбуки топ-5 компаний, стандарты/сертификации, постмортемы, конкурирующие школы, метрики) → FPF-process (упаковка в паттерны) → Loop-improve (E.21, draft→reliable). + `references/collection-protocol.md`.
- **11 role-DPF** (`.claude/knowledge/dpf/`) — сгенерированы через web-research + verify отдельным проверяющим (E.21). Flagship `facilitation.md` (13 паттернов): полный обход thecoreprotocols.org + Holacracy IDM + IAF + Kaner + Schwarz + Liberating Structures + Edmondson + Parker + литература провалов многоагентных систем (MAST).
- **Intake-протокол фасилитатора** (capture-first): хаотичный вход Founder → `project/inbox.md` → триаж по типам (task/tension/decision/question/idea/fact) → маршрутизация по протоколам. Шаблон `templates/project/inbox.md`. Инвариант: потерянный вход = процессная ошибка.
- **DPF в setup-project** (Шаг 4b): domain-DPF проекта + project-overlay на активные роли + чистка DPF неактивных ролей.
- Шаблон `templates/dpf-template.md`; каталог `knowledge/dpf/README.md` (онтология экосистемы).

### Changed
- **Facilitator пересобран (гибрид).** Аддитивная база: + чтение facilitation-DPF и `inbox.md` в ритуале, + функция Intake&Triage, + защита от ложного консенсуса [P-13]. Существующие протоколы (Decider/Resolution/Perfection Game/Clarity) сохранены и связаны ссылками `[P-NN]`.
- **Все роли читают свой DPF** в активационном ритуале (6 ядровых агентов + 5 opt-in шаблонов).
- **FPF-индекс: lite → полный**, пересобран под FPF-Spec @`40b232f` (i-m-senior-developer v1.4.1): +33 паттерна (слой архитектуры `C.32.*`, этика `D.1–D.4`, **`E.4.DPF/PFR/PFAD` авторинг экосистемы FPF**, онбординг `A.0`), −32 устаревших ID. Pin обновлён в `UPSTREAM-SYNC.md` + `fetch-fpf-spec.sh`.
- **`/self-service` implant** теперь строит role-DPF новой роли через `dpf-builder`.
- **Финальный гейт setup (Шаг 9)** расширен: DPF-связность + дедуп + противоречия в конструкции пользователя.

### Fixed
- **Противоречие immutability vs DPF-чистка.** `.claude/knowledge/dpf/**` явно выведен из-под правила «knowledge/** неприкосновенен» (CLAUDE.md + self-service) — это генерируемый слой (имплант добавляет, setup чистит).

## [4.5.1] — 2026-06-24

Упаковочный фикс: шаблоны проекта не доезжали до потребителя + прояснена модель установки.

### Fixed
- **Шаблоны `project/` не публиковались.** Неякорёный паттерн `project/` в `.gitignore` матчил не только корневой рантайм, но и `.claude/templates/project/` — 20 шаблонов (включая `session-template.md`, `handoff-template.md`) были git-ignored и не попадали в клон/пакет. После `git clone` + `cp -r .claude` они отсутствовали в проекте, и роли помечали это как tension (T-001), создавая артефакты «по структуре напрямую». Паттерны якорены: `/_migration/`, `/project/`.
- Шаблоны `templates/project/**` добавлены в индекс (ранее существовали только на диске у автора).

### Changed
- **Install — канонизирована overlay-модель (A).** README (ru/en): клон — одноразовый источник, `git clone --depth 1` + `rm -rf .git` (отвязка от `origin` фреймворка), наложение `.claude/` на свой репозиторий. Добавлен блок про анти-паттерн «работа внутри клона» и пояснение, что `project/` в репо потребителя — коммитабельная память, а не gitignored-рантайм.

## [4.5.0] — 2026-06-22

Дистилляция v5 в одно dev-ядро на subagent-архитектуре.

### Added (структурные гейты)
- **CHK-WIRE / CHK-ORPHAN** в роли `test` + правило «review проходит прод-путь вживую» — против wire/contract drift (самый дорогой класс багов: 5 проектов).
- **Detect → Fix → Guard → Document** — конституционный принцип в `core-protocols.md`.
- **Express-Parallel Protocol** — фоновые агенты в непересекающихся file-ownership зонах + пост-верификация `ls`/`git status`.
- **Гейт решений** в `/end-session`: `DEC-NNN ⟹ файл`, pending-DEC с owner+deadline, **same-session DEC-propagation**, publish-with-task.
- **Ledger git-verified** — лёгкая сверка «done»-заявок с `git log` всегда, полная reconciliation по триггеру `[STUB]`.
- **Explicit model selection** обязателен на каждый dispatch (против 3-5x перерасхода на унаследованном Opus).
- Шаблон `project/resources.md` — research-overlay.
- **FPF fetch-on-demand:** `skills/fpf-integration/scripts/fetch-fpf-spec.sh` — полная спека (~8.7MB) качается в глобальный кеш по требованию, не бандлится (подход из i-m-senior-developer). Lite-набор (glossary + tasks-lookup + sections-map + grep-patterns) = degraded-режим.

### Changed
- Ядро ролей сокращено до **6 dev-ролей** (facilitator, architect, dev, test, cto, keeper), активных по умолчанию.
- `keeper` объединяет glossary/domain + llms.txt + archivist (сжатие промптов).
- **FPF — рабочий инструмент фасилитатора** (не lite-заглушка): NQD/Evidence Graph/Bounded Context/DRR/Cynefin в Pre-DEC checkpoint + ADR-шаблоне; навигация по полной спеке через fetch-скрипт.

### Moved (opt-in, не активны по умолчанию)
- `product`, `guardian`, `analyst`, `designer`, `customer` → `templates/roles/optional/`. Подключаются через `/setup-project` / `/self-service`.

### Removed (мёртвый вес)
- Из активного набора по умолчанию убраны бизнес/контент-роли (см. Moved). Skills и knowledge сохранены — дистилляция сузила активную поверхность.
- Полный `FPF-Spec.md` (~8.7MB) не бандлится (качается по требованию) — но навигация по нему сохранена полностью.

### Принцип релиза
Сужен **активный набор по умолчанию**, формулировки и шаблоны сохранены. Ценность фреймворка — движок памяти и непрерывности (ledger/handoff, per-role context, hooks, planner-context), а не каталог ролей.
