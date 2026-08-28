---
paths:
  - "**/*.py"
  - "pyproject.toml"
  - "requirements*.txt"
---

# Стек: Python-бэкенд

Ты работаешь с Python-кодом. Стек-справочник читается **по фазе**, а не целиком:

| Фаза | Что читать |
|------|-----------|
| Проектирование (architect) | навык `core-team-dev:stacks`, `references/backend-python/design.md` |
| Реализация (dev) | тот же навык, `references/backend-python/implement.md` |
| Ревью (test) | `references/backend-python/review.md` + `references/security.md` (OWASP) |

Прочитай нужный справочник прежде, чем предлагать решение.

**Плагин ремесла не подключён** (точка `craft:tdd` / `craft:clarity` в
`project/connection-points.md` пуста) → работаешь на общих принципах: выжимка Функциональной
ясности в `CLAUDE.md`, `.claude/knowledge/code-change-discipline.md`,
`.claude/knowledge/security-rules.md`. **Скажи об этом вслух** — конвенции незнакомого стека,
выдуманные по аналогии, выглядят как знание.

> Это правило — **триггер, а не копия**. Единственный источник содержания — навык
> `core-team-dev:stacks`, и разъехаться им нечем. Правило живёт в ядре, потому что канал
> доставки по `paths:` проектный: плагины `rules/` не поставляют.
