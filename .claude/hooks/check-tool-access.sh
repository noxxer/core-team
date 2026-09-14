#!/bin/bash
# Права инструмента: объявленный в проекте адрес доступен инструменту.
#
# ТИР: счёт — без прав агент не падает, а идёт обходным путём или спрашивает посреди работы
#
# Проект объявляет свои адреса дважды: `ledger.md` несёт `code_path` в шапке (код лежит
# в соседнем репозитории), `resources.md` — активы с колонкой «Как работать», где стоит
# команда доступа (`ssh` на стенд, `gh workflow run`). Инструмент об этом не знает ни
# того, ни другого: файловые инструменты за корень проекта не смотрят, а команда без
# разрешения останавливается классификатором. Между «актив объявлен» и «инструмент
# вправе им пользоваться» нет моста, и дыра молчит — агент не падает.
#
# Замер с мест (lotus-pro-team, 2026-09-09), цена названа по факту, а не предположена:
#   · все ДВЕНАДЦАТЬ правок кода соседнего репозитория сделаны через `python3 - <<'PY'`
#     внутри Bash — не потому, что так лучше, а потому что `Edit`/`Write` за корень не
#     смотрят и `permissions.additionalDirectories` никто не заполнял. У обхода нет
#     проверки «файл прочитан перед правкой», ради которой `Edit` и существует;
#   · замер боевой базы (`ssh … docker exec … psql`) заблокирован в момент, когда нужен
#     был ответ; диагноз строили по коду и сидам, настоящий замер получен на сорок
#     минут позже другим путём — и ПОСЛЕ того, как правка уже была написана;
#   · `code_path` при этом читал один прибор из четырёх, ходящих по коду.
#
# Один предмет — «объявленный адрес доступен инструменту», два исхода:
#   1. ОТКАЗ: `code_path` объявлен и отличен от корня, а в `permissions.additionalDirectories`
#      ни одного файла настроек его нет — правки пойдут обходом;
#   2. ПОКАЗ без отказа: команда доступа из колонки «Как работать» не встречается ни в
#      одном элементе `permissions.allow` — разрешения зависят от машины и классификатора,
#      красным это делать нельзя, но назвать вслух обязательно.
# Половина «найдено не ноль»: `code_path` не объявлен и команд доступа в активах ноль —
# прибор говорит «проверять нечего», а не «всё в порядке».
#
# Что НЕ проверяется намеренно: существование каталога по `code_path` — это предмет
# прибора следа работы; путь до файла в колонке «Как работать» — его проверяет
# `check-assets.sh`. Здесь только права.
#
# Файлы настроек читаются оба: `.claude/settings.json` (едет в git) и
# `.claude/settings.local.json` (права машины, в git не едут). JSON разбирается без `jq`:
# нужны два массива строк, и зависимость ради них дороже пяти строк awk. Комментарии `//`
# формата jsonc пропускаются.
#
# ЗАПУСК: bash .claude/hooks/check-tool-access.sh [корень проекта]
#   exit 0 — объявленный код доступен инструменту, либо проверять нечего
#   exit 1 — `code_path` объявлен, а прав на него у инструмента нет
#
# Доказательство мутацией: .claude/hooks/check-tool-access.test.sh

set -uo pipefail

ROOT=${1:-.}
PROJECT="${ROOT}/project"
LEDGER=${LEDGER_FILE:-${PROJECT}/ledger.md}
ASSETS=${ASSETS_FILE:-${PROJECT}/resources.md}
SETTINGS_FILES=${SETTINGS_FILES:-"${ROOT}/.claude/settings.json ${ROOT}/.claude/settings.local.json"}
SECTION=${ASSETS_SECTION:-Активы}

[ -d "${PROJECT}" ] || { printf 'каталога project нет — проект ещё не заведён\n'; exit 0; }

# Разбор шапки вынесен в библиотеку: комментарий после значения — не значение.
_lib_fm="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/lib-frontmatter.sh"
if [ -f "${_lib_fm}" ]; then
  # shellcheck source=/dev/null
  . "${_lib_fm}"
  field_of() { fm_field "$1" "$2"; }
else
  field_of() {  # $1 = файл, $2 = имя поля шапки
    awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1" 2>/dev/null \
      | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/^\"//; s/\"[[:space:]]*$//"
  }
fi

# Элементы массива строк из JSON по имени ключа — по одному в строке.
# Берётся первый массив с таким ключом; строка обрезается по первой `]`.
json_array() {  # $1 = файл, $2 = имя ключа
  [ -f "$1" ] || return 0
  awk -v key="\"$2\"" '
    {
      line = $0
      # Комментарий jsonc: `//` в начале строки или после пробела. Внутри строки
      # (`https://…`) перед ним стоит двоеточие, и он остаётся на месте.
      sub(/(^|[[:space:]])\/\/.*$/, "", line)
    }
    !inside && index(line, key) { inside = 1; line = substr(line, index(line, key) + length(key)) }
    inside {
      buf = buf line
      if (index(line, "]")) { inside = 0; done = 1 }
    }
    done { exit }
    END {
      if (buf == "") exit
      buf = substr(buf, 1, index(buf, "]"))
      n = split(buf, parts, "\"")
      for (i = 2; i <= n; i += 2) print parts[i]
    }' "$1"
}

normalize_path() {  # убирает `./` в начале и `/` в конце: `./src/` и `src` — один адрес
  local p=$1
  while case "${p}" in ./?*) true ;; *) false ;; esac; do p=${p#./}; done
  while case "${p}" in ?*/) true ;; *) false ;; esac; do p=${p%/}; done
  printf '%s' "${p}"
}

# --- 1. code_path ↔ additionalDirectories -------------------------------------
code_path=$(field_of "${LEDGER}" code_path 2>/dev/null || true)
code_path=$(normalize_path "${code_path}")
case "${code_path}" in
  ''|'.') code_path='' ;;   # корень проекта инструменту доступен и так
esac

settings_read=0
extra_dirs=()
allow=()
for sf in ${SETTINGS_FILES}; do
  [ -f "${sf}" ] || continue
  settings_read=$((settings_read + 1))
  while IFS= read -r item; do [ -n "${item}" ] && extra_dirs+=("$(normalize_path "${item}")"); done \
    < <(json_array "${sf}" additionalDirectories)
  while IFS= read -r item; do [ -n "${item}" ] && allow+=("${item}"); done \
    < <(json_array "${sf}" allow)
done

code_granted=1
if [ -n "${code_path}" ]; then
  code_granted=0
  for d in ${extra_dirs[@]+"${extra_dirs[@]}"}; do
    [ "${d}" = "${code_path}" ] && { code_granted=1; break; }
  done
fi

# --- 2. Команды доступа в активах ↔ allow -------------------------------------
# Строки таблицы раздела «Активы» вне HTML-комментариев — тот же фильтр, что у
# `check-assets.sh`: там живут образцы формы, и они записями не являются. Раздела нет —
# команд ноль; ошибку формы реестра называет прибор активов, здесь у неё нет хозяина.
trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^\*+//; s/\*+$//'; }

# Команда узнаётся по двум признакам разом, и оба нужны. Первое слово — исполняемое
# имя: строчная латиница, цифры, дефис (`ssh`, `gh`, `redis-cli`); слово с точкой —
# имя узла (`ns1.gcorelabs.net`) или файл, с косой чертой — путь, с заглавной —
# идентификатор (`NFR-22`), кириллицей — проза. И у команды есть аргументы (пробел
# внутри кавычек) либо имя из короткого списка тех, кого зовут и без аргументов.
# Замер боевого прогона по lotus-pro-team: прежняя форма «первое слово в кавычках»
# назвала командами «лендинг», «Выкладка», «нужна» и имя DNS-узла — четыре показа
# из четырёх ложные, а настоящие `ssh`, `dig`, `sudo` стояли в тех же ячейках
# вторыми и третьими кавычками и не были прочитаны вовсе.
BARE_COMMANDS=' ssh scp gh docker psql mysql kubectl curl dig sudo rsync aws gcloud az terraform ansible make redis-cli '

command_of() {  # $1 = ячейка «Как работать» → исполняемое имя команды или пусто
  local rest=$1 span first
  case "${rest}" in *'`'*) ;; *) return 0 ;; esac
  while [ -n "${rest}" ]; do
    case "${rest}" in *'`'*'`'*) ;; *) break ;; esac
    rest=${rest#*\`}
    span=${rest%%\`*}
    rest=${rest#*\`}
    span=$(trim "${span}")
    first=${span%% *}
    case "${first}" in
      ''|*[!a-z0-9_-]*) continue ;;           # не исполняемое имя: точка, слэш, заглавные, кириллица
      [!a-z]*) continue ;;
    esac
    case "${span}" in
      *' '*) printf '%s' "${first}"; return 0 ;;   # команда с аргументами
    esac
    case "${BARE_COMMANDS}" in *" ${first} "*) printf '%s' "${first}"; return 0 ;; esac
  done
  return 0
}

allowed_command() {  # $1 = имя команды → 0, если названа в каком-либо элементе allow
  local word=$1 item
  for item in ${allow[@]+"${allow[@]}"}; do
    grep -qE "(^|[^A-Za-z0-9_-])${word}([^A-Za-z0-9_-]|$)" <<< "${item}" && return 0
  done
  return 1
}

commands_total=0
unallowed=()
if [ -f "${ASSETS}" ]; then
  while IFS= read -r row; do
    id=$(trim "$(printf '%s' "${row}" | cut -d'|' -f2)")
    howto=$(trim "$(printf '%s' "${row}" | cut -d'|' -f10)")
    cmd=$(command_of "${howto}")
    [ -n "${cmd}" ] || continue
    commands_total=$((commands_total + 1))
    allowed_command "${cmd}" || unallowed+=("${id} → ${cmd}")
  done < <(awk -v want="## ${SECTION}" '
    /<!--/ {commented=1}
    commented {if (/-->/) commented=0; next}
    $0 == want {inside=1; next}
    /^## / {inside=0}
    inside && /^\|[[:space:]]*\**[A-Z]+-[0-9]+/ {print}
  ' "${ASSETS}")
fi

# --- Итог ---------------------------------------------------------------------
join_list() { printf '%s, ' "$@" | sed 's/, $//'; }

if [ -z "${code_path}" ] && [ "${commands_total}" -eq 0 ]; then
  printf 'проверять нечего: code_path не объявлен, команд доступа в активах нет\n'
  exit 0
fi

printf 'Права инструмента: code_path %s; команд доступа в активах %s; файлов настроек прочитано %s.\n' \
  "$([ -n "${code_path}" ] && printf '«%s»' "${code_path}" || printf 'не объявлен')" \
  "${commands_total}" "${settings_read}"

if [ ${#unallowed[@]} -gt 0 ]; then
  printf '\nДОСТУП БЕЗ РАЗРЕШЕНИЯ ИНСТРУМЕНТА (%s): %s.\n' "${#unallowed[@]}" "$(join_list "${unallowed[@]}")"
  printf 'Актив объявлен, а команда к нему в `permissions.allow` не названа: в момент замера\n'
  printf 'её остановит классификатор, и роль пойдёт обходом или спросит посреди работы.\n'
  printf 'Права машины в git не едут — предложи Founder-у внести команду в `permissions.allow`\n'
  printf 'файла `.claude/settings.local.json`. Отказом это не считается: разрешения зависят\n'
  printf 'от машины и классификатора.\n'
fi

if [ "${code_granted}" -eq 0 ]; then
  printf '\nCODE_PATH БЕЗ ПРАВ ИНСТРУМЕНТА: «%s» не назван в permissions.additionalDirectories.\n' "${code_path}" >&2
  printf 'Файловые инструменты за корень проекта не смотрят: правки кода пойдут обходом через\n' >&2
  printf 'Bash — без проверки «файл прочитан перед правкой», ради которой Edit существует.\n' >&2
  printf 'Замер: двенадцать правок из двенадцати за одну сессию сделаны через `python3 - <<PY`.\n' >&2
  printf 'Лечение: добавить «%s» в `permissions.additionalDirectories` файла\n' "${code_path}" >&2
  printf '`.claude/settings.local.json` (права машины в git не едут) либо `.claude/settings.json`.\n' >&2
  exit 1
fi
exit 0
