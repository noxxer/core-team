#!/bin/bash
# Доказательство мутацией для check-findings-budget.sh.
#
# Мир с дефектом — 19 приборов и одно слово «ОБЯЗАТЕЛЬНО» на всех. Замер боевого
# проекта: артефакты не по домам требуют 40 предметов при низкой ставке, память
# роли — 4 при высшей (`dev` 988 КБ, не читается). Внимание уходит к самой большой
# куче, а не к самой дорогой.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-findings-budget.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=23
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_hooks() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }

# $1=каталог $2=имя $3=тир $4=текст находки («-» = находок нет)
fake() {
  local d=$1 name=$2 tier=$3 finding=$4
  { printf '#!/bin/bash\n#\n# ТИР: %s — пояснение\n' "${tier}"
    printf 'printf "обычный отчёт\\n"\n'
    if [ "${finding}" = "-" ]; then printf 'exit 0\n'
    else printf 'printf "%%s\\n" "%s" >&2\nexit 1\n' "${finding}"; fi
  } > "${d}/check-${name}.sh"
  chmod +x "${d}/check-${name}.sh"
}
ledger_with() {  # $1=потолок («-» = поля нет)
  local d; d=$(mktemp -d); TRASH+=("$d")
  { printf -- '---\n'
    [ "$1" = "-" ] || printf 'findings_ceiling: %s\n' "$1"
    printf -- '---\n\n# Ledger\n'
  } > "$d/ledger.md"
  printf '%s/ledger.md' "$d"
}

run_code() { ( HOOKS_DIR="$1" LEDGER_FILE="${2:-/nonexistent}" bash "$CHECKER" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( HOOKS_DIR="$1" LEDGER_FILE="${2:-/nonexistent}" bash "$CHECKER" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }
before() {  # $1=вывод $2=что раньше $3=что позже
  local a b
  a=$(printf '%s\n' "$1" | grep -nF "$2" | head -1 | cut -d: -f1)
  b=$(printf '%s\n' "$1" | grep -nF "$3" | head -1 | cut -d: -f1)
  [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ] && printf 'да' || printf 'нет'
}

# --- Тишина ------------------------------------------------------------------
H=$(new_hooks); fake "$H" alpha стоп -; fake "$H" beta счёт -
check "находок нет — зелено" 0 "$(run_code "$H")"
check "…и сказано вслух" "да" "$(says "$(run_out "$H")" "Стоп-находок нет")"
check "…и число приборов названо" "да" "$(says "$(run_out "$H")" "прогнано приборов 2")"

# --- Стоп разбирается сейчас -------------------------------------------------
H=$(new_hooks); fake "$H" alpha стоп "ПАМЯТЬ НЕ ЧИТАЕТСЯ: dev (988 КБ)"
check "стоп-находка роняет" 1 "$(run_code "$H")"
check "…и названа тиром СТОП" "да" "$(says "$(run_out "$H")" "СТОП — разбирается сейчас")"

# --- Порядок внутри стопа: дешёвое из дорогого первым ------------------------
H=$(new_hooks)
fake "$H" heavy стоп "ТЯЖЁЛАЯ НАХОДКА (23)"
fake "$H" light стоп "ЛЁГКАЯ НАХОДКА (3)"
OUT=$(run_out "$H")
check "дешёвый стоп напечатан выше дорогого" "да" "$(before "$OUT" "check-light" "check-heavy")"
check "…и число предметов у каждого" "да" "$(says "$OUT" "предметов: 23")"
check "…и сумма предметов стопа" "да" "$(says "$OUT" "(26 предметов)")"

# --- Счёт копится под потолком -----------------------------------------------
H=$(new_hooks); fake "$H" bulk счёт "МЕЛОЧЬ (5)"
check "счёт в пределах потолка не роняет" 0 "$(run_code "$H")"
check "…и перечислен" "да" "$(says "$(run_out "$H")" "СЧЁТ — копится под потолком (5 из 20)")"

H=$(new_hooks); fake "$H" bulk счёт "МЕЛОЧЬ (40)"
check "счёт выше потолка роняет" 1 "$(run_code "$H")"
check "…и назван целью фазы" "да" "$(says "$(run_out "$H")" "цель фазы меняется")"
check "…и назван выбор из трёх" "да" "$(says "$(run_out "$H")" "не чиним")"

L=$(ledger_with 100)
check "потолок из ledger поднимает" 0 "$(run_code "$H" "$L")"
L=$(ledger_with -); printf '\nfindings_ceiling: 100\n' >> "$L"
check "число в теле ledger потолком не является" 1 "$(run_code "$H" "$L")"

# --- Порядок тиров: стоп всегда выше счёта -----------------------------------
H=$(new_hooks); fake "$H" alpha стоп "СТОП-НАХОДКА (1)"; fake "$H" zeta счёт "МЕЛОЧЬ (9)"
OUT=$(run_out "$H")
check "стоп напечатан выше счёта" "да" "$(before "$OUT" "СТОП — разбирается" "СЧЁТ — копится")"
check "…и большая куча не перебивает малую ставку" "да" "$(before "$OUT" "check-alpha" "check-zeta")"

# --- Счёт предметов ----------------------------------------------------------
H=$(new_hooks); fake "$H" alpha стоп "НАХОДКА БЕЗ ЧИСЛА"
check "находка без числа считается за один предмет" "да" "$(says "$(run_out "$H")" "предметов: 1")"

H=$(new_hooks); fake "$H" alpha стоп "ПЕРВАЯ (2)
вторая строка не заголовок
ВТОРАЯ (3)"
check "две находки в одном приборе складываются" "да" "$(says "$(run_out "$H")" "предметов: 5")"

# --- Границы -----------------------------------------------------------------
H=$(new_hooks); fake "$H" alpha копия "ПРО КОПИЮ (99)"; fake "$H" beta стоп -
check "чужой тир в сводку не входит" 0 "$(run_code "$H")"
check "…и в счёт приборов тоже" "да" "$(says "$(run_out "$H")" "прогнано приборов 1")"

H=$(new_hooks)
printf '#!/bin/bash\nexit 0\n' > "$H/check-noTier.sh"; chmod +x "$H/check-noTier.sh"
check "прибор без тира — сводить нечего" 1 "$(run_code "$H")"
check "…и это названо отказом" "да" "$(says "$(run_out "$H")" "сводить нечего")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
