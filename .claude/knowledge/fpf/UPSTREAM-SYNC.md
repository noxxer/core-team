# FPF-индекс — журнал ре-индексации и провенанс

> Наш lite-набор `knowledge/fpf/` (`glossary` · `grep-patterns` · `sections-map` · `tasks-lookup`) — дистиллированный навигационный индекс внешней спеки [ailev/FPF](https://github.com/ailev/FPF). Это **не** Core-Team-логика, а индекс чужого артефакта — поэтому держим его в синхроне с апстримом, не теряя дистилляцию.

## Якорь индекса

- **index_built_against:** `40b232f11ed950ed34082273c57ff4f6c45b7f06` (ailev/FPF, 2026-06-26)
- Скрипт `fetch-fpf-spec.sh` пишет этот SHA в `FPF-Spec.version` и предупреждает о дрейфе, если `main` ушёл вперёд.

## Журнал (append-only)

### 2026-06-29 — полный ре-индекс под FPF-Spec @40b232f (v5.0)

Источник: `i-m-senior-developer` (@spumer), релиз **v1.4.1** (`functional-clarity` 0.3.2).
Принят целиком (не surgical) — переход lite → **полный индекс**, согласованный с апстримом.

Применено:
- 4 файла индекса (`glossary` · `grep-patterns` · `sections-map` · `tasks-lookup`) заменены на пересобранные
  под FPF-Spec @`40b232f` (~93 220 строк, реестр 279 паттернов: 274 Stable + 5 Planned). Кросс-ссылки
  адаптированы под наш layout (`fpf-*.md` → без префикса).
- Карта изменений апстрима: `+33 / −32 / 59 переименований`. Главное: слой архитектуры `C.32.*`
  (синтез кандидатов, Conway, decision records), этика `D.1–D.4`, **`E.4.DPF/PFR/PFAD` — авторинг
  экосистемы FPF** (прямо релевантно нашему DPF-слою), онбординг-глоссарий `A.0`.
- Pin обновлён: `646b0b9` → `40b232f` (здесь + в `fetch-fpf-spec.sh`).

Полный разбор апстрима — `CHANGES-fpf-spec.md` релиза v1.4.1.

### 2026-06-23 — drift-fix под FPF-Spec @646b0b9 (исторический lite-режим)

Источник миграции: `i-m-senior-developer` (@spumer), `functional-clarity/skills/fpf-integration/CHANGES-fpf-spec.md`.

Применено (surgical, по канону sections-map апстрима):
- Сквозное `describedEntity → EntityOfConcern` (glossary: Epistemic Viewing, Epistemic Retargeting, Episteme).
- `Language-State Transduction → Language-State Move`; `U.LanguageStateTransductionTrajectory → U.LanguageStateMoveTrajectory` (glossary, grep-patterns, tasks-lookup, sections-map A.16/A.16.0).

**Сознательно НЕ применено** (нарушило бы инвариант дистилляции lite-индекса):
- Полный re-index +168 новых ID (A.0 onboarding-glossary, A.3.4 Transformation, A.22 Structure, RPR-расширения) — апстрим разнёс под спеку ~85k строк. У нас lite-подмножество.
- Пересчёт номеров строк в `sections-map.md` — **known debt**: spec вырос, offset'ы могут не совпасть. `fetch-fpf-spec.sh` теперь сигналит дрейф. Re-index — отдельная задача.

## Как обновлять (ритуал)

1. `fetch-fpf-spec.sh --force` → сравнить `upstream_commit` с `index_built_against` в `FPF-Spec.version`.
2. Если разошлись — взять `CHANGES-fpf-spec.md` из свежего апстрима как карту миграции.
3. Перенести **только** переименования терминов и новые ID, релевантные нашему lite-подмножеству. Дистилляцию не раздувать.
4. Обновить `index_built_against` (здесь + в `fetch-fpf-spec.sh`) и дописать строку в журнал.
