---
argument-hint: [описание фичи]
description: Discovery фичи через customer + facilitator. User Journey + DoD → project/features/FEAT-XXXX-<slug>/README.md
---

# /plan-feat — Discovery фичи

Ты ведёшь discovery-сессию по фиче: $ARGUMENTS

## Миссия

Превратить расплывчатую идею в кристально-ясную спецификацию через collaborative exploration. **Фокус на пользовательский опыт, а не на код.** Когда требования чёткие — handoff к `/plan` (архитектурный пас) → `/plan-do` (имплементация).

## Старт

1. Активируй subagent **customer** (через Agent tool) для сбора голоса пользователя
2. **Facilitator** ведёт диалог через **Clarity Protocol** (8 точек проверки) с использованием `AskUserQuestion`
3. Группируй вопросы по 2-4 за вызов AskUserQuestion (не перегружай Founder)

## Guided Discovery (порядок)

### 1. Намерение пользователя — почему?
- Что пытаемся достичь этой фичей?
- Какую боль это решает?
- Опиши ситуацию, в которой пользователь это будет использовать

**Не прыгай в технические решения.** Оставайся на человеческом уровне.

### 2. User Journey — пошаговая картина
Вопросы:
- Шаг за шагом: что пользователь делает, что видит, что получает?
- Что на экране в начале? Что меняется после действия?
- Как пользователь понимает, что сработало?

### 3. Edge cases через сценарии
- Что если пользователь нажмёт не туда?
- Что если попробует это дважды?
- Что если данных нет?
- Граничные состояния: первый/последний/пустой?

### 4. Definition of Done (DoD) — критерии в терминах пользователя
Не "функция implements bookmarking", а:
- "Пользователь может [сделать действие] и видит [результат]"
- "При [edge case] приложение [ожидаемое поведение]"
- "Фича чувствуется естественной когда [сценарий]"

### 5. Definition of Ready — готова ли к имплементации?
Чеклист:
- [ ] User journey описан пошагово
- [ ] Все edge cases имеют ожидаемое поведение
- [ ] DoD конкретен и тестируемый
- [ ] Можно объяснить нетехническому человеку
- [ ] Нет пропусков «разберёмся потом»

## Red Flags (останови и уточни)

- "Должно быть умным и само разберётся" — слишком расплывчато
- Несколько разных фич в одном запросе — раздели
- "Как у [other app]" без конкретики — нужны детали
- Пользователь не может описать как выглядит «успех» — DoD не ясен
- "Решим поведение позже" — edge case не определён

## Сохранение результата

После завершения discovery:

1. Создай директорию: `project/features/FEAT-NNNN-<slug>/` (NNNN — следующий номер по существующим фичам)
2. Создай **README.md** по шаблону `.claude/templates/project/feature-template.md`
3. Создай пустую поддиректорию: `project/features/FEAT-NNNN-<slug>/review-request-changes/`
4. Зафиксируй задачу в `project/ledger.md` через **TaskCreate**
5. Сообщи Founder: «Готово. Следующий шаг — `/plan project/features/FEAT-NNNN-<slug>/` для архитектурного паса.»

## Структура README.md фичи

См. `.claude/templates/project/feature-template.md`. Минимум:
- Problem Statement (1-2 предложения: какую боль решаем)
- User Journey (пошаговый flow)
- Edge Cases (таблица: scenario → expected behavior)
- Definition of Done (testable criteria)
- Visual Description (что на экране до/после)
- Open Questions (если есть)
- **Ready for Technical Design:** Yes/No

## Принципы взаимодействия

1. **Speak Human, Not Code** — "пользователю нужен способ сохранить favourites" а не "state hook for bookmark array"
2. **Show, Don't Tell** — конкретные шаги, не описания
3. **Make It Concrete** — "если offline → message 'Bookmark saved locally' с yellow dot" а не "graceful error handling"
4. **Verify Understanding** — "Совпадает с тем, что ты имел в виду?" регулярно

## Critical: вопросы только через AskUserQuestion

ВСЕ вопросы Founder задавай через `AskUserQuestion`, не текстом. Группируй 2-4 за вызов. Это сохраняет состояние при compact.
