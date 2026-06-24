# Changelog

Все значимые изменения фреймворка. Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версионирование — [SemVer](https://semver.org/lang/ru/).

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
