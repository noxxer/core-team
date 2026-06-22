---
argument-hint: "[focus area или 'full' для полной регенерации]"
description: Сгенерировать или обновить llms.txt + llms-full.txt в корне проекта по стандарту llmstxt.org. Делегирует keeper-subagent-у.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# /update-docs — Обновление llms.txt и llms-full.txt

Активируй skill `llms-keeper` (`.claude/skills/llms-keeper/SKILL.md`) и делегируй keeper-subagent-у.

## Аргументы

- **`$ARGUMENTS` пусто или `full`** → полная регенерация
- **`$ARGUMENTS` = focus area** (например `architecture`, `patterns`, `testing`) → приоритизировать эту область при анализе

## Workflow

1. Запусти `Agent(subagent_type=keeper)` с задачей: «Активируй skill llms-keeper и сгенерируй / обнови llms.txt + llms-full.txt в корне проекта (`<project-root>/`). Focus: $ARGUMENTS».
2. Keeper:
   - Прочитает `references/llmstxt-spec.md` для quality-чеклиста
   - Если файлы существуют → парсит footer, сравнивает git log, обновляет только затронутые секции
   - Если не существуют → полная генерация
3. После завершения — keeper отчитывается: какие секции обновлены, на основе какого commit, статус quality-чеклиста.

## Boundaries

- **Записывать только** в корень проекта: `llms.txt`, `llms-full.txt`
- **Не модифицировать** никакие другие файлы (никакие правки в коде, никаких других docs)
- **PII-stripping обязателен** перед записью (emails, tokens 40+ chars, user-home paths → masked)
