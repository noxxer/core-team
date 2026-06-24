# Scorecard — Kill Criteria Watchlist

**Owner:** guardian
**Last updated:** YYYY-MM-DD

> Каждое решение (DEC) с `kill_criteria` отслеживается здесь. Guardian проверяет пороги на каждом экспресс-ревью. При достижении порога — Pivot-or-Persevere review через facilitator.

---

## Активные kill-criteria из DEC

| DEC | Решение | Метрика | Порог (kill) | Текущее значение | Дата замера | Статус | Action |
|-----|---------|---------|--------------|------------------|-------------|--------|--------|
| DEC-NNN | <решение> | <точная метрика> | <конкретное число с условием> | <текущее> | YYYY-MM-DD | green / yellow / red | <следующий шаг> |
| DEC-NNN | ... | ... | ... | ... | ... | ... | ... |

**Цвета:**
- 🟢 **green** — далеко от порога (>50% запаса)
- 🟡 **yellow** — приближается (≤50% запаса) — повышенное внимание
- 🔴 **red** — порог достигнут — **Pivot-or-Persevere review обязателен**

---

## PMF gates (Sean Ellis Test)

Перед переходом из Build в Grow:

| Gate | Метрика | Порог go | Порог pivot | Текущее | Дата |
|------|---------|----------|-------------|---------|------|
| Sean Ellis | «very disappointed» если продукт исчезнет | ≥40% | <25% | XX% | YYYY-MM-DD |
| Retention curve | flattening month 2-3 | визуальный flat | продолжающее падение | <observation> | YYYY-MM-DD |
| Cohort activation | % first-week active | ≥X% | <Y% | XX% | YYYY-MM-DD |

---

## Review-протокол

**Когда:** на каждом экспресс-ревью / при создании нового DEC с `kill_criteria` / по запросу facilitator

**Как:**
1. Прочитать `project/decisions/` — найти все DEC с заполненным `kill_criteria`
2. Для каждого — найти текущее значение метрики (от analyst-а или из системы)
3. Обновить таблицу выше
4. При yellow → notify facilitator + product
5. При red → инициировать Pivot-or-Persevere review (через AskUserQuestion с вариантами)

---

## Связанные артефакты

- `project/decisions/` — источник kill_criteria
- `project/artifacts/risk-registry.md` — связи с рисками
- `project/artifacts/experiment-board.md` — kill criteria экспериментов (отдельный watchlist там)
- `project/artifacts/metrics-board.md` (от analyst) — источник текущих значений метрик
