#!/bin/bash
# Доказательство мутацией для check-install-integrity.sh.
# Мир с дефектом — проверка, которая смотрит на наличие файлов и молчит про то,
# подключены ли они. Ровно так `VERSION` не доезжал до потребителя, `hooks.json`
# выглядел конфигом, а числа в документации отставали от наборов.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-install-integrity.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=119
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=40
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
  printf 'EXPECTED_CASES=7\nMUTATIONS=3\n' > "$d/.claude/hooks/check-session-reflection.test.sh"
  chmod +x "$d/.claude/hooks/check-session-reflection.test.sh"
  printf '### Структура (Iceberg)\n### Ловушки сессии (Trap Scan)\n' > "$d/.claude/templates/project/session-template.md"
  mkdir -p "$d/.claude/agents" "$d/.claude/skills/навигатор"
  mkdir -p "$d/.claude/knowledge/dpf"
  printf '# Ремесло\n' > "$d/.claude/knowledge/dpf/development.md"
  # Ритуал с `values.md` и владение одним артефактом — часть исправной копии:
  # без них проверки 11 и 12 краснели бы на эталоне, то есть на здоровом мире.
  printf -- '---\nname: dev\nskills: [навигатор]\n---\n\nЧитай `.claude/knowledge/dpf/development.md`.\n\n## Старт активации\n\n1. Прочитай `project/ledger.md`, `project/glossary.md`, `project/values.md` раздел 9\n\n## Работа\n\nтекст\n\n## Для памяти роли\n- Текущий фокус: <...>\n' > "$d/.claude/agents/dev.md"
  printf -- '---\nartifact_id: "словарь"\nowner: "dev"\nartifact_path: "project/glossary.md"\n---\n\n# Словарь\n' > "$d/.claude/templates/project/glossary.md"
  printf '# Навык\n' > "$d/.claude/skills/навигатор/SKILL.md"
  mkdir -p "$d/.claude/rules" "$d/.claude/knowledge/stacks"
  printf 'ok\n' > "$d/.claude/knowledge/stacks/справочник.md"
  printf -- '---\npaths:\n  - "**/*.py"\n---\n\nЧитай `.claude/knowledge/stacks/справочник.md`.\n' > "$d/.claude/rules/стек.md"
  printf 'Доказательство мутацией — `check-session-reflection.test.sh` (7 случаев, три мутации).\n' > "$d/.claude/CLAUDE.md"
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

# --- Библиотека приборам не ровня ---------------------------------------------
# Общий код, который подключают проверки, тира не объявляет: у него другой предмет.
# Без этого правила первая же библиотека делает копию неработоспособной.
C=$(make_copy)
printf '#!/bin/bash\n# Общая функция\nhelper() { :; }\n' > "$C/.claude/hooks/lib-points.sh"
chmod +x "$C/.claude/hooks/lib-points.sh"
check "библиотека без тира не мешает" 0 "$(run_code "$C")"

C=$(make_copy)
printf '#!/bin/bash\n# Проверка без объявленного тира\n' > "$C/.claude/hooks/check-nechto.sh"
chmod +x "$C/.claude/hooks/check-nechto.sh"
check "проверка без тира — находка" 1 "$(run_code "$C")"

# --- Набор живёт у плагина, а не у ядра ---------------------------------------
# Мир с дефектом: сверка чисел ищет набор только в `hooks/`. Тогда числа,
# заявленные для гардов плагинов, не сверяются ВОВСЕ — и молчат об этом,
# то есть «25 случаев» в документации остаётся мнением автора.
C=$(make_copy)
mkdir -p "$C/plugins/some-plugin/scripts"
printf 'EXPECTED_CASES=25\nMUTATIONS=8\n' > "$C/plugins/some-plugin/scripts/check-plugin-guard.test.sh"
printf 'Доказательство мутацией — `check-plugin-guard.test.sh` (25 случаев, восемь мутаций).\n' \
  >> "$C/.claude/CLAUDE.md"
check "число набора плагина сошлось" 0 "$(run_code "$C")"

printf 'EXPECTED_CASES=31\nMUTATIONS=8\n' > "$C/plugins/some-plugin/scripts/check-plugin-guard.test.sh"
check "число набора плагина разошлось" 1 "$(run_code "$C")"
check "…и названы оба числа" "да" \
  "$(says "$(run_out "$C")" "документация говорит 25 случаев, в наборе 31")"

# --- Плагин не установлен: ядро рассказывает о нём, но не обязано его иметь ---
# Мир с дефектом: ядро описывает приборы плагинов в своей документации, а сверка
# требует эти файлы на месте. Чистая установка ядра без плагинов объявлялась
# неработоспособной. Замер: свежая копия дала «КОПИЯ НЕ РАБОТОСПОСОБНА (2)»,
# и оба пункта — про набор, приезжающий с плагином `product-loop`.
C=$(make_copy)
printf 'Доказательство мутацией — `check-uninstalled-tool.test.sh` (25 случаев, восемь мутаций).\n' \
  >> "$C/.claude/CLAUDE.md"
check "набор неустановленного плагина не роняет копию" 0 "$(run_code "$C")"

# Граница: набор ЯДРА узнаётся по своему прибору рядом. Потерянный набор ядра
# прибор переживёт — и остаётся находкой, иначе правило стало бы лазейкой,
# через которую пропадает любой набор.
C=$(make_copy)
printf '#!/bin/bash\n# ТИР: стоп — пояснение\nexit 0\n' > "$C/.claude/hooks/check-core-own.sh"
chmod +x "$C/.claude/hooks/check-core-own.sh"
printf 'Доказательство мутацией — `check-core-own.test.sh` (12 случаев, две мутации).\n' \
  >> "$C/.claude/CLAUDE.md"
check "набор ядра пропал, прибор остался — находка" 1 "$(run_code "$C")"
check "…и он назван поимённо" "да" "$(says "$(run_out "$C")" "check-core-own.test.sh")"

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
    printf '## Старт активации\n\n1. Прочитай `project/ledger.md`, `project/glossary.md`, `project/values.md`\n\n'
    printf '## Работа\n\nтекст\n\n'
    for ((i = 1; i <= blocks; i++)); do printf '## Для памяти роли\n- Текущий фокус: <...>\n\n'; done
    for ((i = 1; i <= fences; i++)); do printf '```\nтекст\n'; done
  } > "${root}/.claude/agents/dev.md"
}

D=$(make_copy); role_spec "$D" 1 2
check "одно описание блока памяти" 0 "$(run_code "$D")"

D=$(make_copy); role_spec "$D" 2 2
check "два описания блока в одном файле" 1 "$(run_code "$D")"
check "…и названо противоречием" "да" "$(says "$(run_out "$D")" "противоречие в одном файле")"

# Ноль описаний — класс дороже дубля: хук требует блок в отчёте любой роли с файлом
# в `agents/`, и роль встаёт на первой активации, не сказав почему. Замер прогона
# 5.3.0 на чистой копии: блок был у 6 ядровых ролей из 6 и у 0 опциональных из 5.
D=$(make_copy); role_spec "$D" 0 2
check "ноль описаний блока памяти" 1 "$(run_code "$D")"
check "…и сказано, что хук не отпустит роль" "да" "$(says "$(run_out "$D")" "хук не отпустит роль")"

# Facilitator идёт основной сессией, под SubagentStop не попадает и блок не выдаёт.
D=$(make_copy); cp "$D/.claude/agents/dev.md" "$D/.claude/agents/facilitator.md"
python3 - "$D/.claude/agents/facilitator.md" <<'INNER'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
p.write_text(p.read_text(encoding='utf-8').replace('## Для памяти роли', '## Работа'), encoding='utf-8')
INNER
check "facilitator без блока — не находка" 0 "$(run_code "$D")"

# Шаблон опциональной роли смотрится наравне с agents/: это будущий файл роли,
# он копируется туда дословно. Дрейф между двумя каталогами — тот же класс E,
# только внутри поставки: блок добавили в agents/, а templates/ не тронули.
D=$(make_copy); mkdir -p "$D/.claude/templates/roles/optional"
printf -- '---
name: product
---

Мини-CEO.
' > "$D/.claude/templates/roles/optional/product.md"
check "шаблон opt-in роли без блока" 1 "$(run_code "$D")"
check "…и названа роль" "да" "$(says "$(run_out "$D")" "product: нет описания блока")"

D=$(make_copy); mkdir -p "$D/.claude/templates/roles/optional"
printf -- '---
name: product
---

## Для памяти роли
- Текущий фокус: <...>
' > "$D/.claude/templates/roles/optional/product.md"
check "шаблон opt-in роли с блоком" 0 "$(run_code "$D")"

# Дубль в ШАБЛОНЕ opt-in роли — тот же класс, что дубль в agents/, но в поставке
# он невидим: файл роли появится у потребителя при подключении, и покраснеет там.
# Замер (отчёт с мест по 5.3.1): пять шаблонов optional/ держали внешний заголовок
# раздела дословно равным имени блока внутри ограждения, и подключение любой
# opt-in роли давало «КОПИЯ НЕ РАБОТОСПОСОБНА» на первом прогоне.
D=$(make_copy); mkdir -p "$D/.claude/templates/roles/optional"
printf -- '---
name: product
---

## Для памяти роли

Последним разделом отчёта:

## Для памяти роли
- Текущий фокус: <...>
' > "$D/.claude/templates/roles/optional/product.md"
check "два описания блока в шаблоне opt-in роли" 1 "$(run_code "$D")"
check "…и названо противоречием" "да" "$(says "$(run_out "$D")" "описаний блока памяти 2")"

D=$(make_copy); role_spec "$D" 1 3
check "непарное ограждение кода" 1 "$(run_code "$D")"
check "…и сказано, чем это плохо" "да" "$(says "$(run_out "$D")" "читается как код")"

# Половина «найдено не ноль»: роли есть, описания блока нет ни в одной.
D=$(make_copy); role_spec "$D" 0 2
check "ни одной спецификации блока памяти" 1 "$(run_code "$D")"
check "…и это названо отказом" "да" "$(says "$(run_out "$D")" "нет ни в одном")"

# --- 14. Каждый прибор объявляет свой тир ------------------------------------
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

# --- 8b. Числа мутаций: документация ↔ объявление набора ---------------------
# Числа мутаций прогоном не пересчитать — но расходиться с записью автора они не
# должны. Класс «набор вырос, число в документации нет» случился трижды за один MR.
D=$(make_copy)
check "числа мутаций совпадают" 0 "$(run_code "$D")"

D=$(make_copy)
sed -i.bak 's/три мутации/семь мутаций/' "$D/.claude/CLAUDE.md" && rm -f "$D/.claude/CLAUDE.md.bak"
check "документация разошлась с набором" 1 "$(run_code "$D")"
check "…и названы оба числа" "да" "$(says "$(run_out "$D")" "документация говорит 7 мутаций, в наборе объявлено 3")"

D=$(make_copy)
sed -i.bak '/^MUTATIONS=/d' "$D/.claude/hooks/check-session-reflection.test.sh" && rm -f "$D/.claude/hooks/check-session-reflection.test.sh.bak"
check "набор не объявляет MUTATIONS" 1 "$(run_code "$D")"
check "…и это названо" "да" "$(says "$(run_out "$D")" "не объявляет MUTATIONS")"

# --- Маршрут ведёт к роли, которой нет ---------------------------------------
# Мир с дефектом: протоколы маршрутизируют tension по домену, и три роли боевого
# проекта (Growth, Brand, CFO) переехали в общие протоколы вместе с текстом.
# Facilitator, ведя «ресурсную» tension, шёл к CFO — и не находил никого:
# tension возвращалась неразобранной, а заметить это было нечем.
protocols_with() {  # $1 = корень, $2.. = строки таблицы
  mkdir -p "$1/.claude/knowledge"
  { printf '# Протоколы\n\n## Six Hats\n\n| Шляпа | О чём | Кто ведёт |\n|---|---|---|\n'
    shift
    printf '%s\n' "$@"
  } > "$1/.claude/knowledge/core-protocols.md"
}

C=$(make_copy)
mkdir -p "$C/.claude/templates/roles/optional"
printf 'роль\n\n## Для памяти роли\n- Текущий фокус: <...>\n' > "$C/.claude/templates/roles/optional/analyst.md"
protocols_with "$C" '| Белая | Факты | Analyst |' '| Зелёная | Реализация | Dev |'
check "маршруты ведут к существующим ролям" 0 "$(run_code "$C")"

protocols_with "$C" '| Белая | Факты | Analyst |' '| Жёлтая | Возможности | Growth |'
check "маршрут к несуществующей роли — находка" 1 "$(run_code "$C")"
check "…и роль названа" "да" "$(says "$(run_out "$C")" "«growth»")"

# Граница: заголовок таблицы адресатом не является. Без этого прибор объявлял
# «Минусы» ролью, которой нет, — на собственных протоколах фреймворка.
C=$(make_copy)
mkdir -p "$C/.claude/templates/roles/optional"
printf 'роль\n\n## Для памяти роли\n- Текущий фокус: <...>\n' > "$C/.claude/templates/roles/optional/analyst.md"
protocols_with "$C" '| Белая | Факты | Analyst |'
printf '\n## Альтернативы\n\n| Вариант | Плюсы | Минусы |\n|---|---|---|\n| А | быстро | дорого |\n' \
  >> "$C/.claude/knowledge/core-protocols.md"
check "заголовок таблицы маршрутом не считается" 0 "$(run_code "$C")"

# --- Бриф субагента: модель и запрет хроники ---------------------------------
# Мир с дефектом: гейт «модель каждого диспатча называется явно» существовал, а
# поля для него не было ни в форме брифа, ни в минимуме оркестратора — правило
# жило в `cost-model-discipline.md`, который читает `cto`, то есть не тот, кто
# диспатчит. Второй дефект того же файла: форма просила «дата, что сделано» —
# ровно ту хронику, которую запрещает канон блока памяти в файле роли, а бриф
# сильнее файла роли, потому что он и есть сообщение агенту.
brief_with() {  # $1 = корень копии, $2 = строка ОТЧЁТ, $3 = строка МОДЕЛЬ («-» = нет)
  { printf '# Бриф\n\n## Форма\n\n```\n'
    [ "$3" = "-" ] || printf '%s\n' "$3"
    printf 'ЗАДАЧА. что должно стать правдой\n'
    printf '%s\n' "$2"
    printf '```\n'
  } > "$1/.claude/templates/dispatch-brief.md"
}

C=$(make_copy)
brief_with "$C" 'ОТЧЁТ. Последний раздел — «Для памяти роли»: СРЕЗ СОСТОЯНИЯ, фокус и знания.' 'МОДЕЛЬ. <opus | sonnet>'
check "бриф с моделью и срезом проходит" 0 "$(run_code "$C")"

C=$(make_copy)
brief_with "$C" 'ОТЧЁТ. Последний раздел — «Для памяти роли»: дата, что сделано, решения.' 'МОДЕЛЬ. <opus | sonnet>'
check "бриф заказывает хронику — находка" 1 "$(run_code "$C")"
check "…и сказано, что канон требует срез" "да" "$(says "$(run_out "$C")" "заказывает хронику")"

C=$(make_copy)
brief_with "$C" 'ОТЧЁТ. Последний раздел — «Для памяти роли»: СРЕЗ СОСТОЯНИЯ.' '-'
check "в форме нет поля модели — находка" 1 "$(run_code "$C")"
check "…и назван гейт, который негде исполнить" "да" "$(says "$(run_out "$C")" "нет поля модели")"

# Граница: запрет — не заказ. Строка «Не «что сделано»» ЗАПРЕЩАЕТ хронику, и
# прибор, ищущий подстроку, принимал её за требование — на собственном тексте.
C=$(make_copy)
brief_with "$C" 'ОТЧЁТ. «Для памяти роли»: срез состояния. Не «что сделано за сессию» — это хроника.' 'МОДЕЛЬ. <opus>'
check "запрет хроники находкой не является" 0 "$(run_code "$C")"

# Проза за пределами формы разбирает этот же дефект и цитирует его: прибор,
# читающий весь файл, находил бы собственное объяснение.
C=$(make_copy)
brief_with "$C" 'ОТЧЁТ. «Для памяти роли»: срез состояния.' 'МОДЕЛЬ. <opus>'
printf '\n## Почему\n\n| Поле | Что ловит |\n|---|---|\n| Отчёт | просил «дата, что сделано» — хронику |\n' \
  >> "$C/.claude/templates/dispatch-brief.md"
check "цитата дефекта в прозе не считается" 0 "$(run_code "$C")"

# --- 17. Состав канона не пересказывается в файле роли ------------------------
# Мир с дефектом: инлайн-пересказ Code-Change Discipline в двух файлах ролей слово
# в слово называл себя «7 шагов» и перечислял шесть — терялось звено «поставить
# идею под сомнение первой», которое канон называет самым дорогим.
canon_of() {  # $1=корень $2=число в заголовке $3=число пунктов
  local i
  mkdir -p "$1/.claude/knowledge"
  { printf '# Дисциплина\n\n## %s шагов\n\n' "$2"
    for ((i = 1; i <= $3; i++)); do printf '%s. **Шаг %s** — текст.\n' "$i" "$i"; done
  } > "$1/.claude/knowledge/code-change-discipline.md"
}

D=$(make_copy); canon_of "$D" 7 6
check "канон обещает больше, чем перечисляет" 1 "$(run_code "$D")"
check "…и сказано, что расходится сам с собой" "да" "$(says "$(run_out "$D")" "расходится сам с собой")"

D=$(make_copy); canon_of "$D" 7 7
check "канон верен сам себе" 0 "$(run_code "$D")"

D=$(make_copy); canon_of "$D" 7 7
printf 'Правишь чужое — `.claude/knowledge/code-change-discipline.md`, 7 шагов: идея → допущения.\n' \
  >> "$D/.claude/agents/dev.md"
check "файл роли пересказывает состав" 1 "$(run_code "$D")"
check "…и назван дом состава" "да" "$(says "$(run_out "$D")" "состав живёт в каноне")"

# Проза, называющая число, списком не является: этим текстом объясняют сам дефект.
D=$(make_copy); canon_of "$D" 7 7
printf 'Канон — `.claude/knowledge/code-change-discipline.md`; прежний пересказ звал себя «7 шагов» и давал шесть.\n' \
  >> "$D/.claude/agents/dev.md"
check "проза о числе — не пересказ" 0 "$(run_code "$D")"

# --- 16. Роль не предписывает себе запись мимо File Ownership -----------------
# Мир с дефектом: расхождение ВНУТРИ одного файла, которого не видит ни одна
# сверка «файл с файлом». Замер: facilitator предписывал себе «fact → domain.md»,
# а его File Ownership этого пути не содержал — роль выбирала между записью без
# мандата и потерей входа, и слова «передай keeper-у» в тексте не было.
role_with_own() {  # $1=корень $2=строка функции $3=строки File Ownership
  printf -- '---\nname: dev\nskills: [навигатор]\n---\n\nЧитай `.claude/knowledge/dpf/development.md`.\n\n## Старт активации\n\n1. Прочитай `project/ledger.md`, `project/glossary.md`, `project/values.md`\n\n## Ключевые функции\n\n%s\n\n## File Ownership\n\n**Пишешь:**\n%s\n\n## Для памяти роли\n- Текущий фокус: <...>\n' \
    "$2" "$3" > "$1/.claude/agents/dev.md"
}

D=$(make_copy); role_with_own "$D" '- **факт** → `domain.md`' '- `project/roles/dev/context.md`'
check "предписана запись мимо File Ownership" 1 "$(run_code "$D")"
check "…и названо спором с собой" "да" "$(says "$(run_out "$D")" "спорит сама с собой")"

D=$(make_copy); role_with_own "$D" '- **факт** → `domain.md`' '- `project/domain.md`
- `project/roles/dev/context.md`'
check "путь есть в File Ownership" 0 "$(run_code "$D")"

# Справочник ремесла роль читает, а не пишет: без этой границы прибор давал две
# находки на строке про OWASP-справочник в `cto.md` и `guardian.md`.
D=$(make_copy); role_with_own "$D" '- OWASP — `core-team-dev:stacks` → `references/security.md`' '- `project/roles/dev/context.md`'
check "чужая раскладка — не находка" 0 "$(run_code "$D")"

# --- 15. Таблица ролей ↔ File Ownership ---------------------------------------
# Мир с дефектом: таблица-справка в CLAUDE.md читается чаще самих файлов ролей,
# и расходится с ними молча. Замер: таблица давала `cto` зону `decisions/DEC-*.md`
# без оговорки, хотя `Write` там по механике Decider Protocol делает facilitator.
table_of() {  # $1=корень $2=содержимое колонки «Пишет»
  printf 'Доказательство мутацией — `check-session-reflection.test.sh` (7 случаев, три мутации).\n\n| Subagent | Модель | Зона | Пишет |\n|---|---|---|---|\n| **dev** | sonnet | код | %s |\n' \
    "$2" > "$1/.claude/CLAUDE.md"
}

D=$(make_copy); role_with_own "$D" 'работа' '- `project/roles/dev/context.md`'
table_of "$D" '`project/requirements.md`, `roles/dev/context.md`'
check "таблица обещает больше, чем File Ownership" 1 "$(run_code "$D")"
check "…и названы обе стороны" "да" "$(says "$(run_out "$D")" "таблица ролей обещает dev")"

D=$(make_copy); role_with_own "$D" 'работа' '- `project/roles/dev/context.md`'
table_of "$D" '`roles/dev/context.md`'
check "таблица и File Ownership сходятся" 0 "$(run_code "$D")"

# Маска и каталог сверке не подлежат: их форма в двух местах законно разная.
D=$(make_copy); role_with_own "$D" 'работа' '- `project/roles/dev/context.md`'
table_of "$D" '`features/FEAT-*/ARCH-NN.md`, `decisions/`, `roles/dev/context.md`'
check "маска и каталог пропускаются" 0 "$(run_code "$D")"

# Половина «найдено не ноль» для самого разбора таблицы. Мир с дефектом: снять `**`
# вокруг имени роли (обычная работа markdown-форматтера) — и сверка владения молчит,
# ничем не отличаясь от исправной копии. Находка ревью 5.3.2, ставка P0.
D=$(make_copy); role_with_own "$D" 'работа' '- `project/roles/dev/context.md`'
printf 'Раздел про Роли = Subagents.\n\n| Subagent | Модель | Зона | Пишет |\n|---|---|---|---|\n| dev | sonnet | код | `project/requirements.md` |\n' \
  > "$D/.claude/CLAUDE.md"
check "таблица ролей не разобрана — находка" 1 "$(run_code "$D")"
check "…и сказано, что формат съехал" "да" "$(says "$(run_out "$D")" "разобрано ноль строк")"

# Коллизия имён: одноимённые файлы в разных каталогах для проекта норма
# (`README.md`, `context.md`), и сверка по basename засчитывала подмену пути.
D=$(make_copy); role_with_own "$D" 'работа' '- `project/docs/other/README.md`
- `project/roles/dev/context.md`'
table_of "$D" '`secrets/README.md`, `roles/dev/context.md`'
check "коллизия имён не засчитывается" 1 "$(run_code "$D")"

D=$(make_copy); role_with_own "$D" 'работа' '- `project/docs/other/README.md`
- `project/roles/dev/context.md`'
table_of "$D" '`docs/other/README.md`, `roles/dev/context.md`'
check "тот же путь целиком — сходится" 0 "$(run_code "$D")"

# --- 18. Владелец артефакта знает, чем владеет ---------------------------------
# Мир с дефектом: артефакт объявляет `owner: "cto"`, а в файле роли ноль упоминаний.
# Роль действует по своему промпту, а не по шапке чужого файла, которую может не
# открыть, — и артефакт замирает на дате заведения, ровно против чего поле и заведено.
# Замер с мест по 5.3.1: две такие пары (`requirements.md`, `claims.md`); наш прогон
# нашёл ещё три — `artifacts/README.md`, `resources.md`, `framework-feedback.md`.
owned_tpl() {  # $1=корень $2=owner $3=artifact_path (пусто — поля нет)
  mkdir -p "$1/.claude/templates/project"
  { printf -- '---\nartifact_id: "требования"\nowner: "%s"\n' "$2"
    [ -n "$3" ] && printf 'artifact_path: "%s"\n' "$3"
    printf -- '---\n\n# Требования\n'
  } > "$1/.claude/templates/project/requirements.md"
}

D=$(make_copy); owned_tpl "$D" dev project/requirements.md
check "владелец не называет свой артефакт" 1 "$(run_code "$D")"
check "…и названа цена" "да" "$(says "$(run_out "$D")" "замрёт на дате заведения")"

D=$(make_copy); owned_tpl "$D" dev project/requirements.md
printf 'Ведёшь `project/requirements.md`.\n' >> "$D/.claude/agents/dev.md"
check "владелец называет свой артефакт" 0 "$(run_code "$D")"

# Имя файла шаблона местом артефакта не является: `artifacts-readme.md` кладётся
# в `artifacts/README.md`, и угадывать это нечем — потому поле обязательно.
D=$(make_copy); owned_tpl "$D" dev ""
check "owner есть, artifact_path нет" 1 "$(run_code "$D")"
check "…и сказано, что сверять не с чем" "да" "$(says "$(run_out "$D")" "artifact_path не назван")"

# Владелец, названный не ролью («форму держит keeper»), под правило не подпадает:
# файла роли для него нет, сверять нечего.
D=$(make_copy); owned_tpl "$D" "какой-то человек" project/requirements.md
check "owner не роль — не находка" 0 "$(run_code "$D")"

# --- 19. Ценности проекта доезжают до роли, которая их нарушит -----------------
# Мир с дефектом: `values.md` читали три роли из восьми, и обе роли, физически
# трогающие код, были не в их числе. Проектная ценность («данные работодателя не
# попадают в репозиторий») оказывалась объявленной и недоставленной ПО КОНСТРУКЦИИ.
ritual_of() {  # $1=корень $2=текст ритуала
  printf -- '---\nname: dev\nskills: [навигатор]\n---\n\nЧитай `.claude/knowledge/dpf/development.md`.\n\n## Старт активации\n\n%s\n\n## Работа\n\nтекст\n\n## Для памяти роли\n- Текущий фокус: <...>\n' "$2" \
    > "$1/.claude/agents/dev.md"
}

D=$(make_copy); ritual_of "$D" '1. Прочитай `project/ledger.md`, `project/glossary.md`'
check "ритуал без values.md" 1 "$(run_code "$D")"
check "…и названа цена" "да" "$(says "$(run_out "$D")" "не доезжает до роли")"

D=$(make_copy); ritual_of "$D" '1. Прочитай `project/ledger.md`, `project/glossary.md`, `project/values.md` раздел 9'
check "ритуал читает values.md" 0 "$(run_code "$D")"

# Путь в File Ownership — разрешение, а не шаг активации: роль его не делает.
# Ровно так `architect` числился читающим ценности и не читал их.
D=$(make_copy); ritual_of "$D" '1. Прочитай `project/ledger.md`, `project/glossary.md`'
printf -- '\n## File Ownership\n\n**Читаешь:** всё, кроме `project/values.md` (только Founder пишет).\n' \
  >> "$D/.claude/agents/dev.md"
check "values.md только в File Ownership" 1 "$(run_code "$D")"

# --- 20. Предписанная команда исполнима при собственных запретах ---------------
# Мир с дефектом: два предписания одного файла требуют противоположного. Шаг 4
# `/setup-project` велел заводить память роли копированием шаблона, Шаг 5 того же
# файла ставил `permissions.deny` на каталог шаблонов, а клиент бракует `cp` по
# ИСТОЧНИКУ. Замер с мест по 5.3.1: после настройки завести память новой роли
# было нечем, и упирался в это тот, кто подключал роль в другой сессии.
setup_with() {  # $1=корень $2=текст предписания
  mkdir -p "$1/.claude/commands"
  { printf '### Шаг 4\n\n%s\n\n### Шаг 5\n\n' "$2"
    printf '```json\n{ "permissions": { "deny": [\n'
    printf '  "Edit(.claude/templates/**)", "Write(.claude/templates/**)"\n] } }\n```\n'
  } > "$1/.claude/commands/setup-project.md"
}

D=$(make_copy); setup_with "$D" 'Заводи память: `cp .claude/templates/project/role-context-template.md project/roles/dev/context.md`.'
check "предписан cp из запрещённого каталога" 1 "$(run_code "$D")"
check "…и названа причина" "да" "$(says "$(run_out "$D")" "нельзя выполнить после настройки")"

D=$(make_copy); setup_with "$D" 'Заводи память: `cat .claude/templates/project/role-context-template.md > project/roles/dev/context.md`.'
check "чтение шаблона в новый файл — законно" 0 "$(run_code "$D")"

# Проза, разбирающая этот самый дефект, пишет путь многоточием — иначе прибор
# находил бы собственное объяснение и краснел на файле, который его чинит.
D=$(make_copy); setup_with "$D" 'Почему не `cp .claude/templates/… project/…`: запрет бракует источник.'
check "цитата дефекта прозой — не находка" 0 "$(run_code "$D")"

# Подстановка в пути формы не отменяет: человек подставит имя роли и выполнит.
# Замер на этой же версии: инструкция импланта роли несла `cp …/<role>.md …`,
# и прибор молчал, пока класс символов не знал угловых скобок.
D=$(make_copy); setup_with "$D" 'Заводи роль: `cp .claude/templates/roles/optional/<role>.md .claude/agents/<role>.md`.'
check "cp с подстановкой в пути — находка" 1 "$(run_code "$D")"

# Половина «найдено не ноль» для экстрактора запретов. Мир с дефектом: блок `deny`
# переписан прозой — и проверка не делает ни одного сравнения, сертифицируя не
# «команда исполнима», а «формат не съехал». Находка ревью 5.3.2, ставка P0.
D=$(make_copy); mkdir -p "$D/.claude/commands"
printf '### Шаг 4\n\nЗаводи память: `cp .claude/templates/project/role-context-template.md project/roles/dev/context.md`.\n\n### Шаг 5\n\nЗапрещаем (deny) правку каталога шаблонов.\n' \
  > "$D/.claude/commands/setup-project.md"
check "блок deny не разобран — находка" 1 "$(run_code "$D")"
check "…и названа цена молчания" "да" "$(says "$(run_out "$D")" "молча не работает")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
