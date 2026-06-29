# DPF — Domain Principles Frameworks (каталог role-DPF)

> «Предметный учебник для AI-агента». Слой **между** общим FPF и локальными артефактами проекта.
> Источник концепции: практикум А. Левенчука, 28.06.2026 (экосистема FPPS → FPF → DPF → LPF).

## Экосистема принципов

| Слой | Расшифровка | Покрывает | Где у нас |
|------|-------------|-----------|-----------|
| **FPPS** | Foundation Principles Pattern Set | онтологика, семиотика, эпистемология | ядро внешнего FPF |
| **FPF** | First Principles Framework | общие принципы работы в коллективных проектах | `knowledge/fpf/` + skill `fpf-integration` |
| **DPF** | **Domain** Principles Framework | SoTA-ходы, термины, ошибки, границы домена/ремесла | **эта папка** (role-DPF) + `project/dpf/` (domain-DPF) |
| **LPF** | Local Practices Framework | регламент методов конкретного проекта | `project/values.md`, `infrastructure-principles.md`, role-context |

Идея слоя: AI-агент «стреляет по площадям» — знает общее, но не знает, что в **этом** ремесле
считается сильным ходом. DPF ограничивает внимание агента предметными паттернами.

## Что лежит здесь (role-DPF)

`.claude/knowledge/dpf/<role>.md` — предметный учебник **ремесла роли**, переиспользуемый между
проектами, едет с фреймворком. Роль читает свой DPF в активационном ритуале (после project-context,
до работы). Формат — `.claude/templates/dpf-template.md`.

Сгенерированы в v5.0 через `dpf-builder` (web-research по 11 каналам + verify отдельным проверяющим). Все — `maturity: draft`, пробелы для refine честно залогированы в §6 каждого файла.

| Файл | Роль | Паттернов | Maturity |
|------|------|-----------|----------|
| `facilitation.md` | facilitator | 13 | draft |
| `architecture.md` | architect | 13 | draft |
| `development.md` | dev | 12 | draft |
| `code-review.md` | test | 12 | draft |
| `tech-strategy.md` | cto | 12 | draft |
| `knowledge-keeping.md` | keeper | 11 | draft |
| `product-management.md` | product | 12 | draft |
| `risk-and-security.md` | guardian | 13 | draft |
| `market-analysis.md` | analyst | 12 | draft |
| `ux-design.md` | designer | 11 | draft |
| `customer-voice.md` | customer | 12 | draft |

> Ядровые роли (facilitator/architect/dev/test/cto/keeper) читают свой DPF в активационном ритуале.
> Opt-in роли (product/guardian/analyst/designer/customer) — их DPF едет в комплекте, но setup-чистка
> (Шаг 4b.1) удаляет учебники ролей, не активных в конкретном проекте.

## Как создаётся / обновляется

Через skill **`dpf-builder`** (`.claude/skills/dpf-builder/`): Collect (11 каналов) →
FPF-process (упаковка в E.8-паттерны) → Loop-improve (E.21). Первый DPF всегда черновик —
поднимается до `reliable` циклами улучшения.

## role-DPF vs domain-DPF

- **role-DPF** (здесь) — ремесло роли, общее. Коммитится в репо фреймворка.
- **domain-DPF** (`project/dpf/`) — предметная область конкретного проекта. Генерится при setup,
  коммитится в репо потребителя (в репо фреймворка `project/` — gitignored рантайм).
