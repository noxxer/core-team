#!/bin/bash
# Доказательство мутацией для check-marketplace.sh.
#
# Мир с дефектом — проверка, которая верит витрине на слово. Ровно так витрина
# фреймворка с самого заведения не проходила схему CLI: `owner` строкой вместо
# объекта, источник ядра в непринимаемой форме, и узнать об этом было негде.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-marketplace.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=26
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Репозиторий-образец: витрина + каталоги плагинов с манифестами.
make_repo() {  # $1 = json витрины; далее — «имя:версия» каталогов в plugins/
  local d entry name version; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude-plugin"
  printf '%s\n' "$1" > "$d/.claude-plugin/marketplace.json"
  shift
  for entry in "$@"; do
    name=${entry%%:*}; version=${entry##*:}
    mkdir -p "$d/plugins/$name/.claude-plugin" "$d/plugins/$name/skills"
    printf '{"name":"%s","version":"%s","description":"x"}\n' "$name" "$version" \
      > "$d/plugins/$name/.claude-plugin/plugin.json"
  done
  printf '%s' "$d"
}

market() {  # $1 = json владельца, $2 = json массива плагинов
  printf '{"name":"core-team","owner":%s,"plugins":%s}' "$1" "$2"
}

OWNER_OK='{"name":"noxxer"}'
ONE='[{"name":"smotrovaya","source":"./plugins/smotrovaya"}]'

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое ----------------------------------------------------------------
R=$(make_repo "$(market "$OWNER_OK" "$ONE")" "smotrovaya:0.1.0")
check "витрина согласована с репозиторием" 0 "$(run_code "$R")"
check "число записей названо" "да" "$(says "$(run_out "$R")" "записей 1")"

# --- Мутация 1: форма владельца не проверяется -------------------------------
R=$(make_repo "$(market '"noxxer"' "$ONE")" "smotrovaya:0.1.0")
check "owner строкой вместо объекта" 1 "$(run_code "$R")"
check "…и названа схема CLI" "да" "$(says "$(run_out "$R")" "claude plugin validate")"
R=$(make_repo "$(market '{"url":"https://x"}' "$ONE")" "smotrovaya:0.1.0")
check "owner без имени" 1 "$(run_code "$R")"

# --- Мутация 2: пустая витрина принята за успех ------------------------------
R=$(make_repo "$(market "$OWNER_OK" '[]')")
check "ноль плагинов в витрине" 1 "$(run_code "$R")"
check "…и назван пустой перечень" "да" "$(says "$(run_out "$R")" "пустом множестве")"

# --- Мутация 3: источник ведёт в никуда --------------------------------------
R=$(make_repo "$(market "$OWNER_OK" '[{"name":"smotrovaya","source":"./plugins/smotrovaya"}]')")
check "каталога плагина нет вовсе" 1 "$(run_code "$R")"
check "…и сказано про отсутствующий манифест" "да" "$(says "$(run_out "$R")" "нет манифеста плагина")"

# --- Мутация 4: имя витрины разошлось с манифестом ---------------------------
R=$(make_repo "$(market "$OWNER_OK" '[{"name":"smotrovaia","source":"./plugins/smotrovaya"}]')" "smotrovaya:0.1.0")
check "витрина называет плагин иначе" 1 "$(run_code "$R")"
check "…и названы оба имени" "да" "$(says "$(run_out "$R")" "а его манифест")"

# --- Мутация 5: плагин лежит, но не объявлен (класс E) -----------------------
R=$(make_repo "$(market "$OWNER_OK" "$ONE")" "smotrovaya:0.1.0" "analytics:0.1.0")
check "каталог есть, в витрине нет" 1 "$(run_code "$R")"
check "…и сказано, что не доедет" "да" "$(says "$(run_out "$R")" "до потребителя он не доедет")"

# --- Мутация 6: запись ведёт в пустой каталог ---------------------------------
# Мир с дефектом: манифест есть, компонентов нет. Установка проходит УСПЕШНО и
# даёт ноль — так запись ядра с источником «./» показывала «Skills (0)».
R=$(make_repo "$(market "$OWNER_OK" "$ONE")" "smotrovaya:0.1.0")
rm -rf "$R/plugins/smotrovaya/skills"
check "каталог без единого компонента" 1 "$(run_code "$R")"
check "…и названа успешная пустота" "да" "$(says "$(run_out "$R")" "установка пройдёт успешно и даст ноль")"
mkdir -p "$R/plugins/smotrovaya/commands"
check "одних команд достаточно" 0 "$(run_code "$R")"

# --- Мутация 7: пустая версия плагина ----------------------------------------
R=$(make_repo "$(market "$OWNER_OK" "$ONE")" "smotrovaya:")
check "у плагина пустая версия" 1 "$(run_code "$R")"
check "…и названо последствие" "да" "$(says "$(run_out "$R")" "не отличит новое от старого")"

# --- Корневой источник «./»: манифест рядом с витриной ------------------------
# Замер, ради которого случай переписан: запись ядра с источником «./» ставилась
# БЕЗ ОШИБКИ и показывала «Skills (0), Agents (0)» — файлы ядра лежат в `.claude/`,
# куда плагинный загрузчик не смотрит. Пустой корень теперь красный.
R=$(make_repo "$(market "$OWNER_OK" '[{"name":"core-team","source":"./"}]')")
printf '{"name":"core-team","version":"9.9.9","description":"x"}\n' > "$R/.claude-plugin/plugin.json"
check "источник «./» без компонентов в корне — красное" 1 "$(run_code "$R")"
mkdir -p "$R/skills"
check "…с компонентами в корне — законно" 0 "$(run_code "$R")"
printf '{"name":"core-teem","version":"9.9.9","description":"x"}\n' > "$R/.claude-plugin/plugin.json"
check "…и опечатка в его имени ловится" 1 "$(run_code "$R")"

# --- Записи без имени и без источника ----------------------------------------
R=$(make_repo "$(market "$OWNER_OK" '[{"source":"./plugins/smotrovaya"}]')" "smotrovaya:0.1.0")
check "запись без имени" 1 "$(run_code "$R")"
R=$(make_repo "$(market "$OWNER_OK" '[{"name":"smotrovaya"}]')" "smotrovaya:0.1.0")
check "запись без источника" 1 "$(run_code "$R")"

# --- Витрина не разбирается --------------------------------------------------
R=$(make_repo '{"name": "core-team", "plugins": [')
check "битый JSON витрины" 1 "$(run_code "$R")"
check "…и назван разбор" "да" "$(says "$(run_out "$R")" "не разбирается как JSON")"

# --- Законная тишина ---------------------------------------------------------
D=$(mktemp -d); TRASH+=("$D")
check "витрины нет — копия потребителя" 0 "$(run_code "$D")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
