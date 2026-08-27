#!/bin/bash
# Доказательство мутацией для check-install-integrity.sh.
# Мир с дефектом — проверка, которая смотрит на наличие файлов и молчит про то,
# подключены ли они. Ровно так `VERSION` не доезжал до потребителя, `hooks.json`
# выглядел конфигом, а числа в документации отставали от наборов.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-install-integrity.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=52
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_copy() {  # печатает корень исправной копии
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude/hooks" "$d/.claude/templates/project"
  printf '5.0.0\n' > "$d/.claude/VERSION"
  printf '#!/bin/bash\n#\n# ТИР: показ — пояснение\nexit 0\n' > "$d/.claude/hooks/session-start.sh"
  chmod +x "$d/.claude/hooks/session-start.sh"
  printf '# ТИР: стоп — пояснение\nSLOTS=(%s)\nEXPECTED_CASES=7\n' "'Структура (Iceberg)' 'Ловушки сессии'" > "$d/.claude/hooks/check-session-reflection.sh"
  chmod +x "$d/.claude/hooks/check-session-reflection.sh"
  printf 'EXPECTED_CASES=7\n' > "$d/.claude/hooks/check-session-reflection.test.sh"
  chmod +x "$d/.claude/hooks/check-session-reflection.test.sh"
  printf '### Структура (Iceberg)\n### Ловушки сессии (Trap Scan)\n' > "$d/.claude/templates/project/session-template.md"
  mkdir -p "$d/.claude/agents" "$d/.claude/skills/навигатор"
  mkdir -p "$d/.claude/knowledge/dpf"
  printf '# Ремесло\n' > "$d/.claude/knowledge/dpf/development.md"
  printf -- '---\nname: dev\nskills: [навигатор]\n---\n\nЧитай `.claude/knowledge/dpf/development.md`.\n\n## Для памяти роли\n- Текущий фокус: <...>\n' > "$d/.claude/agents/dev.md"
  printf '# Навык\n' > "$d/.claude/skills/навигатор/SKILL.md"
  mkdir -p "$d/.claude/rules" "$d/.claude/knowledge/stacks"
  printf 'ok\n' > "$d/.claude/knowledge/stacks/справочник.md"
  printf -- '---\npaths:\n  - "**/*.py"\n---\n\nЧитай `.claude/knowledge/stacks/справочник.md`.\n' > "$d/.claude/rules/стек.md"
  printf 'Доказательство мутацией — `check-session-reflection.test.sh` (7 случаев).\n' > "$d/.claude/CLAUDE.md"
  cat > "$d/.claude/settings.json" <<'JSON'
{ "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] } ] } }
JSON
  printf '%s' "$d"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Исправная копия ---------------------------------------------------------
C=$(make_copy)
check "исправная копия проходит" 0 "$(run_code "$C")"
check "число проверенных пунктов названо" "да" "$(says "$(run_out "$C")" "Проверено пунктов:")"

# --- Версия не доехала -------------------------------------------------------
C=$(make_copy); rm -f "$C/.claude/VERSION"
check "нет .claude/VERSION" 1 "$(run_code "$C")"
check "…и сказано про обещание CLAUDE.md" "да" "$(says "$(run_out "$C")" "обещает версию именно там")"
C=$(make_copy); : > "$C/.claude/VERSION"
check "VERSION пуст" 1 "$(run_code "$C")"

# --- Хук лежит, но не исполняем ----------------------------------------------
C=$(make_copy); chmod -x "$C/.claude/hooks/session-start.sh"
check "хук не исполняем" 1 "$(run_code "$C")"
check "…и назван файл" "да" "$(says "$(run_out "$C")" "не исполняем")"

# --- Хук объявлен, файла нет --------------------------------------------------
C=$(make_copy); rm -f "$C/.claude/hooks/session-start.sh"
check "объявленного хука нет на диске" 1 "$(run_code "$C")"
check "…и назван путь" "да" "$(says "$(run_out "$C")" "хук объявлен, файла нет")"

# --- Хуки лежат, но не объявлены ---------------------------------------------
C=$(make_copy); printf '{}\n' > "$C/.claude/settings.json"
check "ни один хук не объявлен" 1 "$(run_code "$C")"
check "…и сказано «файл лежит» ≠ «вызывается»" "да" "$(says "$(run_out "$C")" "ни одного объявленного хука")"
C=$(make_copy); rm -f "$C/.claude/settings.json"
check "settings.json отсутствует" 1 "$(run_code "$C")"

# --- Слоты шаблона разъехались с проверщиком ---------------------------------
C=$(make_copy); printf '### Структура (Iceberg)\n' > "$C/.claude/templates/project/session-template.md"
check "слот проверщика пропал из шаблона" 1 "$(run_code "$C")"
check "…и назван именно он" "да" "$(says "$(run_out "$C")" "Ловушки сессии")"

# --- Число случаев в документации отстало ------------------------------------
C=$(make_copy); printf 'EXPECTED_CASES=9\n' > "$C/.claude/hooks/check-session-reflection.test.sh"
check "документация отстала от набора" 1 "$(run_code "$C")"
check "…названы оба числа" "да" "$(says "$(run_out "$C")" "документация говорит 7 случаев, в наборе 9")"

# --- Роль объявляет навык, которого нет --------------------------------------
C=$(make_copy); rm -rf "$C/.claude/skills/навигатор"
check "объявленного навыка нет в копии" 1 "$(run_code "$C")"
check "…названы роль и навык" "да" "$(says "$(run_out "$C")" 'dev.md объявляет навык «навигатор»')"

# --- Правило ведёт в никуда --------------------------------------------------
C=$(make_copy); rm -f "$C/.claude/knowledge/stacks/справочник.md"
check "правило ведёт в несуществующий файл" 1 "$(run_code "$C")"
check "…названы правило и путь" "да" "$(says "$(run_out "$C")" 'правило стек.md ведёт в несуществующий')"

# Глоб в шапке `paths:` ссылкой не является — иначе гард ругается на сам себя.
C=$(make_copy)
printf -- '---\npaths:\n  - ".claude/knowledge/**"\n  - ".claude/skills/**"\n---\n\nТело без ссылок.\n' \
  > "$C/.claude/rules/глоб.md"
check "глоб в шапке правила — не находка" 0 "$(run_code "$C")"

# --- Ремесло роли не доехало -------------------------------------------------
C=$(make_copy); rm -rf "$C/.claude/knowledge/dpf"
check "слоя DPF нет вовсе" 1 "$(run_code "$C")"
check "…и сказано про активационный ритуал" "да" "$(says "$(run_out "$C")" "слоя DPF нет вовсе")"

C=$(make_copy); rm -f "$C/.claude/knowledge/dpf/development.md"
check "роль ссылается на ремесло, файла нет" 1 "$(run_code "$C")"
check "…названы роль и ремесло" "да" "$(says "$(run_out "$C")" "dev.md ссылается на ремесло development.md")"

C=$(make_copy); printf -- '---\nname: dev\n---\n\nБез ссылки на ремесло.\n' > "$C/.claude/agents/dev.md"
check "роль не называет свой DPF" 1 "$(run_code "$C")"

# --- Отказ инструмента, а не чистая система ----------------------------------
# Запасной путь отрезан: объявления хуков тоже сняты, иначе случай краснел бы
# из-за «объявлен, файла нет», а не из-за пустого перечня (выжившая мутация).
C=$(make_copy); rm -f "$C/.claude/hooks/"*.sh; printf '{}\n' > "$C/.claude/settings.json"
check "хуков нет вовсе — не зелёный" 1 "$(run_code "$C")"
check "…и это назван отказ перечисления" "да" "$(says "$(run_out "$C")" "не найдено ни одного скрипта")"
check "нет .claude вовсе" 1 "$(run_code "$(mktemp -d)")"

# --- 9. Сущности: короткая таблица ↔ полный словарь ---------------------------
# Класс: признак различения живёт в CLAUDE.md (всегда в контексте), определения —
# в knowledge/entities.md. Расходятся молча, и роль применяет признак, которого нет.
entity_claude() {  # $1=корень $2..=имена сущностей для таблицы
  local root=$1; shift
  { printf 'Доказательство мутацией — `check-session-reflection.test.sh` (7 случаев).\n\n'
    printf '## Сущности — признак различения\n\n'
    printf '| Сущность | Что это |\n|---|---|\n'
    for t in "$@"; do printf '| **%s** | пояснение |\n' "$t"; done
  } > "${root}/.claude/CLAUDE.md"
}
entity_dict() {  # $1=корень $2..=имена разделов словаря
  local root=$1; shift
  mkdir -p "${root}/.claude/knowledge"
  { printf '# Сущности\n\n'; for t in "$@"; do printf '## %s\n\nтекст\n\n' "$t"; done; } \
    > "${root}/.claude/knowledge/entities.md"
}

D=$(make_copy); entity_claude "$D" Обязательство Требование Риск
entity_dict "$D" Обязательство Требование Риск
check "таблица и словарь совпадают" 0 "$(run_code "$D")"

D=$(make_copy); entity_claude "$D" Обязательство Требование Риск
entity_dict "$D" Обязательство Требование
check "сущность без раздела в словаре" 1 "$(run_code "$D")"
check "…и названа именно она" "да" "$(says "$(run_out "$D")" "сущность «Риск» названа")"

# Упоминание в тексте определением не является.
D=$(make_copy); entity_claude "$D" Обязательство Риск
entity_dict "$D" Обязательство
printf 'Риск упоминается здесь в прозе, а раздела у него нет.\n' >> "$D/.claude/knowledge/entities.md"
check "имя в прозе за определение не сходит" 1 "$(run_code "$D")"

D=$(make_copy); entity_claude "$D" Обязательство
check "раздел объявлен, словаря нет" 1 "$(run_code "$D")"
check "…и сказано, чего нет" "да" "$(says "$(run_out "$D")" "knowledge/entities.md нет")"

# Половина «найдено не ноль»: раздел есть, разобрано ноль — съехавшая разметка.
D=$(make_copy); entity_dict "$D" Обязательство
printf 'x\n\n## Сущности — признак различения\n\nтекст без таблицы\n' > "$D/.claude/CLAUDE.md"
check "раздел есть, а таблица не разобрана" 1 "$(run_code "$D")"
check "…и это названо отказом разбора" "да" "$(says "$(run_out "$D")" "ни одной сущности")"

# Жирное начертание в СЛЕДУЮЩЕМ разделе сущностью не является.
D=$(make_copy); entity_claude "$D" Обязательство
entity_dict "$D" Обязательство
printf '\n## Стеки\n\n| Стек | Кто читает |\n|---|---|\n| **Frontend React** | architect |\n' \
  >> "$D/.claude/CLAUDE.md"
check "таблица соседнего раздела не считается" 0 "$(run_code "$D")"

# Законная тишина: копия без раздела сущностей (версия до 5.2).
D=$(make_copy)
check "раздела «Сущности» нет вовсе — тихо" 0 "$(run_code "$D")"

# --- 10. Одна спецификация блока памяти на файл роли -------------------------
# Класс: в пяти файлах ролей лежали ДВА описания одного блока, второе просило
# «Что сделано» — хронику, которую первое запрещает. Плюс висячая ``` от старого.
role_spec() {  # $1=корень $2=число описаний блока $3=число ограждений
  local root=$1 blocks=$2 fences=$3 i
  { printf -- '---\nname: dev\nskills: [навигатор]\n---\n\n'
    printf 'Читай `.claude/knowledge/dpf/development.md`.\n\n'
    for ((i = 1; i <= blocks; i++)); do printf '## Для памяти роли\n- Текущий фокус: <...>\n\n'; done
    for ((i = 1; i <= fences; i++)); do printf '```\nтекст\n'; done
  } > "${root}/.claude/agents/dev.md"
}

D=$(make_copy); role_spec "$D" 1 2
check "одно описание блока памяти" 0 "$(run_code "$D")"

D=$(make_copy); role_spec "$D" 2 2
check "два описания блока в одном файле" 1 "$(run_code "$D")"
check "…и названо противоречием" "да" "$(says "$(run_out "$D")" "противоречие в одном файле")"

D=$(make_copy); role_spec "$D" 1 3
check "непарное ограждение кода" 1 "$(run_code "$D")"
check "…и сказано, чем это плохо" "да" "$(says "$(run_out "$D")" "читается как код")"

# Половина «найдено не ноль»: роли есть, описания блока нет ни в одной.
D=$(make_copy); role_spec "$D" 0 2
check "ни одной спецификации блока памяти" 1 "$(run_code "$D")"
check "…и это названо отказом" "да" "$(says "$(run_out "$D")" "нет ни в одном")"

# --- 11. Каждый прибор объявляет свой тир ------------------------------------
# Класс: 19 приборов под одним словом «ОБЯЗАТЕЛЬНО». Прибор без тира выпадает из
# сводки находок молча — его находки исчезают из порядка по ставке.
D=$(make_copy)
check "исправная копия: тиры объявлены" 0 "$(run_code "$D")"

D=$(make_copy); printf '#!/bin/bash\nexit 0\n' > "$D/.claude/hooks/check-безтира.sh"
chmod +x "$D/.claude/hooks/check-безтира.sh"
check "прибор без тира — находка" 1 "$(run_code "$D")"
check "…и сказано, что находки выпадут" "да" "$(says "$(run_out "$D")" "выпадут из сводки молча")"

D=$(make_copy); printf '#!/bin/bash\n#\n# ТИР: важное — пояснение\nexit 0\n' > "$D/.claude/hooks/check-чужойтир.sh"
chmod +x "$D/.claude/hooks/check-чужойтир.sh"
check "тир не из набора — находка" 1 "$(run_code "$D")"
check "…и назван допустимый набор" "да" "$(says "$(run_out "$D")" "стоп/счёт/копия/волна/показ/сводка")"

# Половина «найдено не ноль»: приборы есть, тира нет ни у одного.
D=$(make_copy)
for f in "$D/.claude/hooks"/*.sh; do
  case "$f" in *.test.sh) continue ;; esac
  grep -v '^# ТИР:' "$f" > "$f.tmp" && mv "$f.tmp" "$f" && chmod +x "$f"
done
check "…и это названо пустой сводкой" "да" "$(says "$(run_out "$D")" "сводка находок пуста")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
