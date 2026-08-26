---
paths:
  - "**/*.py"
  - "pyproject.toml"
  - "requirements*.txt"
---

# Стек: Python-бэкенд

Ты работаешь с Python-кодом. Стек-справочник загружается **по фазе**, а не целиком:

| Фаза | Файл |
|------|------|
| Проектирование (architect) | `.claude/knowledge/stacks/backend-python/design.md` |
| Реализация (dev) | `.claude/knowledge/stacks/backend-python/implement.md` |
| Ревью (test) | `.claude/knowledge/stacks/backend-python/review.md` + `.claude/knowledge/stacks/security.md` |

Прочитай нужный файл прежде, чем предлагать решение. Стек-нейтральные принципы — в
`.claude/skills/functional-clarity/`.

> Это правило — **триггер, а не копия**. Единственный источник содержания —
> `knowledge/stacks/`, чтобы не разъезжаться. Раньше загрузка держалась на том, что роль
> сама «детектирует стек»: обещание в промпте вместо срабатывания по факту касания файла.
