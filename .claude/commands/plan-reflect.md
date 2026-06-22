---
argument-hint: "[feature-dir или пусто для текущей сессии]"
description: Пост-задачная рефлексия. Сравнить план с реальностью, обновить planner-context.md, эмитнуть Lessons learned.
allowed-tools: Read, Grep, Glob, Write, Bash
---

# /plan-reflect — Post-task learning

Активируй skill `planner-reflect` (`.claude/skills/planner-reflect/SKILL.md`) и следуй его workflow.

## Resolve feature-dir

- **`$ARGUMENTS` указан** → используй как feature-dir
- **`$ARGUMENTS` пусто** → выведи feature-dir из самого свежего `PLANNER_OUTPUT.md` в `project/features/`

## Workflow (из skill)

Skill выполняется один проход:
1. Соберёт 5 evidence sources (PLANNER_OUTPUT, git log, review-files, transcripts, user messages)
2. Классифицирует findings по 4 update types: gap-fill / model-strength / user-corrections / cost-calibration
3. Замаскирует PII (emails, длинные токены, user-home paths)
4. Запишет в `<project-root>/.claude/planner-context.md` (только этот файл)
5. Эмитнет в чат summary + всегда-присутствующий блок "Lessons learned"

## Graceful exit

- **Нет `PLANNER_OUTPUT.md`** → `nothing to reflect on; run /plan first`
- **Нет git history** → `plan exists but not yet executed; nothing to reflect`
- **Partial evidence** → продолжай, но укажи в summary, какие источники недоступны

## HITL-гейт для auto-memory

Если **тот же урок встречается во второй раз** (cross-FEAT) — skill **предлагает** Founder создать memory, но не создаёт автоматически:
> «Этот урок встречается во второй раз (FEAT-A, FEAT-B). Создать memory? (требуется явное подтверждение)»

## Boundaries

- **Единственный writeable файл:** `<project-root>/.claude/planner-context.md`
- **НЕ модифицируй код** ни при каких обстоятельствах
- **НЕ модифицируй `PLANNER_OUTPUT.md`** — это исторический артефакт
- **НЕ вызывай других agents** и не цепляйся к другим skills
- **НЕ выдумывай уроки** — empty `_no actionable lessons this session_` валиден
- **НЕ переписывай ручные правки** в `planner-context.md`

## После завершения

Верни Founder:
- Какие секции `planner-context.md` обновлены (с числом строк)
- Какие evidence sources были доступны / недоступны
- Блок "Lessons learned (FEAT-XXXX, YYYY-MM-DD)" — populated или empty
- Если есть HITL-suggest для memory — задавай через AskUserQuestion
