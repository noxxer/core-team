#!/bin/bash
# Доказательство мутацией для collect-upstream-candidates.sh.
#
# Мир с дефектом — сборщик, который ничего не находит и говорит «чисто».
# Именно так контур возврата и был устроен до этой правки: кандидаты
# существовали (7 правил в двух проектах), но их никто не собирал.
#
#   bash .claude/hooks/collect-upstream-candidates.test.sh
#   printf '#!/bin/sh\nexit 0\n' > /tmp/naive.sh
#   bash .claude/hooks/collect-upstream-candidates.test.sh /tmp/naive.sh   # упадёт

set -uo pipefail

COLLECTOR=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/collect-upstream-candidates.sh"}
[ -f "$COLLECTOR" ] || { printf 'нет файла сборщика: %s\n' "$COLLECTOR" >&2; exit 1; }

EXPECTED_CASES=14
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_root() {
  local dir
  dir=$(mktemp -d)
  TRASH+=("$dir")
  printf '%s' "$dir"
}

add_file() {  # $1 = корень, $2 = имя, $3 = содержимое
  printf '%s\n' "$3" > "$1/$2"
}

marker() {  # $1 = корзина, $2 = причина
  printf '<!-- upstream-candidate: %s — %s -->' "$1" "$2"
}

run_code() { ( bash "$COLLECTOR" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$COLLECTOR" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then
    printf 'PASS  %-46s ожидание %s\n' "$1" "$2"
  else
    printf 'FAIL  %-46s ожидание %s, получено %s\n' "$1" "$2" "$3"
    failed=$((failed + 1))
  fi
}

says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Находит то, ради чего написан -------------------------------------------

R=$(make_root); add_file "$R" rules.md "правило$(marker 'ядро' 'верно для любого проекта')"
check "маркер «ядро» найден" "да" "$(says "$(run_out "$R")" "[ядро] ")"

R=$(make_root); add_file "$R" stack.md "$(marker 'stacks/backend-python' 'верно для стека')"
check "маркер stacks найден" "да" "$(says "$(run_out "$R")" "[stacks/backend-python]")"

R=$(make_root); add_file "$R" hook.sh "# $(marker 'ядро' 'правило в скрипте тоже кандидат')"
check "маркер в .sh найден" "да" "$(says "$(run_out "$R")" "[ядро] ")"

R=$(make_root)
add_file "$R" a.md "$(marker 'ядро' 'первое')"
add_file "$R" b.md "$(marker 'ядро' 'второе')"
check "оба маркера сосчитаны" "да" "$(says "$(run_out "$R")" "Кандидатов наверх: 2")"

check "причина попадает в отчёт" "да" "$(says "$(run_out "$R")" "первое")"

# --- Законная тишина ---------------------------------------------------------

R=$(make_root); add_file "$R" plain.md "обычный текст без маркеров"
check "маркеров нет — тихо и ноль" 0 "$(run_code "$R")"
check "…и число просмотренных названо" "да" "$(says "$(run_out "$R")" "Просмотрено файлов: 1")"

# --- Маркер оформлен неверно: fail-closed ------------------------------------

R=$(make_root); add_file "$R" wrong.md "$(marker 'dpf' 'предметное наверх не едет')"
check "корзина dpf отвергнута" 1 "$(run_code "$R")"

R=$(make_root); add_file "$R" noreason.md "<!-- upstream-candidate: ядро -->"
check "маркер без причины отвергнут" 1 "$(run_code "$R")"

# --- Отказ инструмента ≠ чистота ---------------------------------------------

check "каталога нет — отказ, не «чисто»" 1 "$(run_code "/nonexistent-$$")"

R=$(make_root)
check "каталог есть, файлов ноль — отказ" 1 "$(run_code "$R")"

# --- Документация формата — не находка (поймано на ревью) --------------------

R=$(make_root)
printf 'Формат маркера:\n\n```\n%s\n```\n' "$(marker 'ядро' 'пример из документации')" > "$R/doc.md"
check "маркер в блоке кода не считается" "да" "$(says "$(run_out "$R")" "Кандидатов наверх: 0")"

R=$(make_root)
printf 'Ставь `%s` рядом с правкой.\n' "$(marker 'ядро' 'пример в кавычках')" > "$R/inline.md"
check "маркер в обратных кавычках не считается" "да" "$(says "$(run_out "$R")" "Кандидатов наверх: 0")"

# И при этом настоящий маркер в том же файле находится: исключение документации
# не должно превратиться в исключение находок.
R=$(make_root)
printf 'Формат: `%s`\n\nПравило проекта. %s\n' \
  "$(marker 'ядро' 'пример')" "$(marker 'ядро' 'настоящая находка')" > "$R/both.md"
check "рядом с примером находка видна" "да" "$(says "$(run_out "$R")" "настоящая находка")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s — тест проверил не всё, что обязан\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi

printf '\nсборщик: %s\nслучаев: %s, провалено: %s\n' "$COLLECTOR" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
