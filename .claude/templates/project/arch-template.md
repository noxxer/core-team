# Architecture — FEAT-NNNN-<slug>

**Версия:** ARCH-01 (или ARCH-02 при ревизии)
**Дата:** YYYY-MM-DD
**Автор:** architect (subagent, model: opus)
**Stack detected:** <python | react | …>
**Зависит от:** README.md, UX-NN.md (если есть), PLANNER_OUTPUT.md (если есть)

## Контекст

<Краткий пересказ what/why из README.md (1-2 абзаца). Линки на затронутые модули, ADR.>

## Bounded Contexts (FPF A.1.1)

Выявленные bounded contexts фичи. Каждый — с явным словарём, инвариантами, контрактом.

| Context | Назначение | Инварианты | Словарь | Hand-offs |
|---------|------------|------------|---------|-----------|
| <name> | <что делает> | <what must be true> | <ключевые термины из glossary> | <с чем общается> |

## Data Model

### Сущности (новые / изменённые)

| Сущность | Поля (key) | FK / связи | Cascade | Источник правды |
|----------|------------|------------|---------|-----------------|
| <Entity> | id, name, status, … | FK на <X>, … | CASCADE / RESTRICT | таблица или вычисляемое (с указанием триггера) |

### Чеклист нормализации (обязательный)

**Единственный источник правды:**
- [ ] Каждый факт хранится в одном месте
- [ ] Колонки, выводимые из других — явно помечены `[CACHE: source=…, trigger=…]` или удалены
- [ ] Нет транзитивных зависимостей (non-key → non-key)

**Целостность связей:**
- [ ] Каждый FK имеет смысловой эквивалент в `glossary.md`
- [ ] Нет циклических FK (или задокументирован порядок INSERT)
- [ ] Cascade-правила определены

**Кешированные агрегаты:**
- [ ] Указан источник правды (таблица/запрос)
- [ ] Триггер обновления описан
- [ ] Помечено `[CACHE: ...]`

## API / Контракты

### Endpoint-ы (новые / изменённые)

| Метод | Путь | Назначение | Request | Response | Ошибки |
|-------|------|------------|---------|----------|--------|
| POST | /v1/<path> | <что делает> | `{...}` | `{...}` | 400 / 404 / 409 |

### Breaking changes

- [ ] Нет breaking changes
- [ ] Есть breaking changes — задокументированы ниже + согласованы с Founder

| Изменение | Затронутые потребители | Migration path |
|-----------|------------------------|----------------|
| <change> | <consumers> | <how> |

## Структура модулей

```
<project>/
  module-a/                  # <bounded context A>
    handlers/
    services/
    models/
  module-b/                  # <bounded context B>
    ...
```

## FPF-чеклист (обязательный)

- [ ] **A.1.1 Bounded Context** — каждый модуль имеет границы, инварианты, словарь
- [ ] **A.3 Transformer Quartet** — agent/method/description/work чётко разделены
- [ ] **A.7 Strict Distinction** — роль (контракт) ≠ реализация
- [ ] **A.10 Evidence Graph** — claims подкреплены evidence (тест, прототип, ссылка)
- [ ] **A.11 Parsimony** — Composition / Non-Redundancy / Functional Naming / Sharp Boundary
- [ ] **A.15 Role-Method-Work Alignment** — ответственности модулей выровнены
- [ ] **NQD ≥3 альтернативы** для complicated/complex (см. секцию ниже)

## NQD-альтернативы (для complicated/complex)

1. **<Альтернатива A>** — pro: …, con: …, evidence: …
2. **<Альтернатива B>** — pro: …, con: …, evidence: …
3. **<Альтернатива C>** — pro: …, con: …, evidence: …

**Рекомендация:** <X>, потому что <обоснование на FPF A.10>.

## Точки расширения

<Где в архитектуре закладываем shape под будущие изменения. Конкретные интерфейсы / hooks / extension points.>

## Риски и митигации

| Риск | Вероятность | Impact | Митигация |
|------|-------------|--------|-----------|
| <риск> | low / medium / high | low / medium / high | <action> |

## Зависимости от других фич / ADR

- FEAT-XXXX — <что от него зависит>
- DEC-NNN — <какое решение применяем>

## Hand-off в dev

**Что dev должен сделать:**
1. Прочитать этот ARCH + README
2. Активировать tdd-master skill (RED-фаза обязательна)
3. Загрузить `knowledge/stacks/<stack>/implement.md`
4. Реализовать по структуре модулей выше с применением functional-clarity (fail-fast, no Error Hiding)
5. При нетривиальных правках существующего кода — Code-Change Discipline (7 шагов)

**Что dev НЕ должен делать:**
- Менять API-контракт без обсуждения с architect
- Принимать архитектурные решения самостоятельно (эскалация: `[NEEDS-ARCHITECTURE-REVIEW]`)
- Использовать паттерны из других bounded contexts без проверки инвариантов
