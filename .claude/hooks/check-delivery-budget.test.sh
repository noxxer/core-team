#!/bin/bash
# Доказательство мутацией для check-delivery-budget.sh.
#
#   bash .claude/hooks/check-delivery-budget.test.sh                  # текущий прибор
#   bash .claude/hooks/check-delivery-budget.test.sh /tmp/mutant.sh    # обязан упасть
#
# Мутации, каждая роняет хотя бы один случай:
#   M1 сравнение `-gt` заменено на `-lt` (красное при недоборе)   → «в бюджете — зелёный», «байты выше потолка»
#   M2 stop_gates считает и наборы (фильтр *.test.sh снят)         → «приборы «стоп» посчитаны без наборов»
#   M3 отсутствие файла потолков не отказ                          → «файла потолков нет — отказ»
#   M4 неназванный потолок пропускается молча                      → «потолок не объявлен — отказ»

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-delivery-budget.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла прибора: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=14
# shellcheck disable=SC2034
MUTATIONS=4
ran=0; failed=0; TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { grep -qF -- "$2" <<< "$1" && printf 'да' || printf 'нет'; }
run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

make_copy() {  # копия в бюджете: CLAUDE.md 100 байт, стиль 50, старт 30; 2 «ОБЯЗАТЕЛЬНО»; 1 стоп-прибор; 1 «Замер»
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude/hooks" "$d/.claude/output-styles" "$d/.claude/commands" "$d/.claude/knowledge"
  head -c 100 /dev/zero | tr '\0' 'x' > "$d/.claude/CLAUDE.md"; printf ' Замер\n' >> "$d/.claude/CLAUDE.md"
  head -c 50 /dev/zero | tr '\0' 'y' > "$d/.claude/output-styles/core-team.md"
  head -c 30 /dev/zero | tr '\0' 'z' > "$d/.claude/hooks/session-start.sh"
  printf 'Шаг 1 — ОБЯЗАТЕЛЬНО\nШаг 2 — ОБЯЗАТЕЛЬНО\n' > "$d/.claude/commands/end-session.md"
  printf '#!/bin/bash\n# ТИР: стоп — пояснение\n' > "$d/.claude/hooks/check-a.sh"
  printf '#!/bin/bash\n# ТИР: счёт — пояснение\n' > "$d/.claude/hooks/check-b.sh"
  printf '#!/bin/bash\n# ТИР: стоп — набор, не прибор\n' > "$d/.claude/hooks/check-a.test.sh"
  printf '#!/bin/bash\n# ТИР: стоп — библиотека, не прибор\n' > "$d/.claude/hooks/lib-x.sh"
  budget "$d" 200 2 1 1
  printf '%s' "$d"
}
budget() {  # $1 = копия, далее потолки: bytes steps stops measurements («-» = поля нет)
  { printf -- '---\n'
    [ "$2" = "-" ] || printf 'session_bytes: %s        # байты\n' "$2"
    [ "$3" = "-" ] || printf 'mandatory_steps: %s\n' "$3"
    [ "$4" = "-" ] || printf 'stop_gates: "%s"\n' "$4"
    [ "$5" = "-" ] || printf 'claude_measurements: %s\n' "$5"
    printf -- '---\n# Бюджет\n'
  } > "$1/.claude/knowledge/delivery-budget.md"
}

C=$(make_copy)
check "в бюджете — зелёный" 0 "$(run_code "$C")"
check "значения напечатаны с потолками" "да/да" "$(says "$(run_out "$C")" "session_bytes")/$(says "$(run_out "$C")" "192 / 200")"
check "приборы «стоп» посчитаны без наборов и библиотек" "да" "$(printf '%s\n' "$(run_out "$C")" | grep -E '^ *stop_gates +1 / 1 ' >/dev/null && printf 'да' || printf 'нет')"

budget "$C" 150 2 1 1
check "байты выше потолка — красное, мера названа" "1/да" "$(run_code "$C")/$(says "$(run_out "$C")" "ВЫШЕ ПОТОЛКА: session_bytes = 192")"
budget "$C" 200 1 1 1
check "«ОБЯЗАТЕЛЬНО» выше потолка — красное" "1/да" "$(run_code "$C")/$(says "$(run_out "$C")" "mandatory_steps = 2")"
budget "$C" 200 2 0 1
check "стоп-приборов выше потолка — красное" 1 "$(run_code "$C")"
budget "$C" 200 2 1 0
check "«Замер» в CLAUDE.md выше потолка — красное" 1 "$(run_code "$C")"
check "…и красное предлагает выбор из трёх" "да" "$(says "$(run_out "$C")" "Одно из трёх")"

budget "$C" 200 2 1 1
check "потолок ровно равен мере — зелёный (граница включена)" 0 "$(run_code "$C")"

budget "$C" 200 - 1 1
check "потолок не объявлен — отказ, мера названа" "1/да" "$(run_code "$C")/$(says "$(run_out "$C")" "ПОТОЛОК НЕ ОБЪЯВЛЕН: mandatory_steps")"
budget "$C" - - - -
check "ни одного потолка — отказ" 1 "$(run_code "$C")"
rm -f "$C/.claude/knowledge/delivery-budget.md"
check "файла потолков нет — отказ" "1/да" "$(run_code "$C")/$(says "$(run_out "$C")" "не объявлены")"

D=$(mktemp -d); TRASH+=("$D")
check "не копия фреймворка — отказ" 1 "$(run_code "$D")"

C=$(make_copy); rm -f "$C/.claude/commands/end-session.md"
check "нет end-session — шагов ноль, не падение" 0 "$(run_code "$C")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"; failed=$((failed + 1))
fi
printf '\nприбор: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
