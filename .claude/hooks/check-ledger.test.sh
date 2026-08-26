#!/bin/bash
# Доказательство мутацией для check-ledger.sh.
#
# Мир с дефектом — ledger, в который дописывают всё, потому что его читают все.
# Замер на четырёх боевых проектах: 320 / 427 / 473 / 3682 строки при отсутствии
# лестницы смыслов в трёх из четырёх, десятки разделов «## Сессия <дата> — итоги»
# при живом каталоге сессий, и главное — хроника в ШАПКЕ, куда не смотрел ни один
# прибор: `active_phase` 4141 символ, `current_omtm` 2340, плюс нумерованные поля
# `previous_phase_171`, `previous_phase_170` — лента без дна.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-ledger.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=27
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_file() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s/ledger.md' "$d"; }

# $1=файл $2=бюджет («-» = поля нет) $3..=дополнительные строки шапки
healthy() {
  local f=$1 budget=$2; shift 2
  { printf -- '---\nlast_updated: "2026-08-26"\n'
    [ "${budget}" = "-" ] || printf 'max_lines: %s\n' "${budget}"
    for extra in "$@"; do printf '%s\n' "${extra}"; done
    printf -- '---\n\n# Project Ledger\n\n## Зачем\n\n'
    printf -- '- **Миссия:** зачем существует проект\n'
    printf -- '- **Цель фазы:** что станет правдой к концу фазы\n'
    printf -- '- **Ближайший шаг:** что делаем в эту сессию\n\n'
    printf '## Активные задачи\n\n- [ ] задача\n'
  } > "$f"
}
pad_lines() { local i; for ((i = 1; i <= $2; i++)); do printf -- '- строка %s\n' "$i" >> "$1"; done; }
long_value() { head -c "$1" < /dev/zero | tr '\0' 'x'; }

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровый ledger ---------------------------------------------------------
F=$(new_file); healthy "$F" 300
check "состояние в бюджете, лестница на месте" 0 "$(run_code "$F")"
check "…и названы обе величины" "да" "$(says "$(run_out "$F")" "при бюджете 300")"

# --- Раздел-хроника ----------------------------------------------------------
F=$(new_file); healthy "$F" 300; printf '\n## Сессия 2026-08-19 — итоги\n\nчто было\n' >> "$F"
check "раздел «Сессия …» — хроника" 1 "$(run_code "$F")"
check "…и названа строка" "да" "$(says "$(run_out "$F")" "РАЗДЕЛ-ХРОНИКА")"
check "…и назван дом событий" "да" "$(says "$(run_out "$F")" "project/sessions/")"

F=$(new_file); healthy "$F" 300; printf '\n## 2026-08-19 — разбор\n\nтекст\n' >> "$F"
check "заголовок с датой — тоже хроника" 1 "$(run_code "$F")"

F=$(new_file); healthy "$F" 300; printf '\n## Активные задачи\n\n- решено 2026-08-26: брать sonnet\n' >> "$F"
check "дата в строке состояния законна" 0 "$(run_code "$F")"

# --- Поле превратилось в хронику: тело --------------------------------------
F=$(new_file)
{ printf -- '---\nmax_lines: 300\n---\n\n## Зачем\n\n'
  printf -- '- **Миссия:** зачем\n'
  printf -- '- **Цель фазы:** %s\n' "$(long_value 250)"
  printf -- '- **Ближайший шаг:** шаг\n'
} > "$F"
check "поле смысла разрослось" 1 "$(run_code "$F")"
check "…и назван предмет" "да" "$(says "$(run_out "$F")" "превратилось в хронику")"
check "…и названо поле с числом" "да" "$(says "$(run_out "$F")" "Цель фазы (250 симв.)")"

# --- Поле превратилось в хронику: ШАПКА -------------------------------------
# Главный случай замера: в шапку не смотрел ни один прибор.
F=$(new_file); healthy "$F" 300 "active_phase: \"$(long_value 500)\""
check "поле шапки разрослось" 1 "$(run_code "$F")"
check "…и названо как шапка" "да" "$(says "$(run_out "$F")" "шапка/active_phase")"

F=$(new_file); healthy "$F" 300 'active_phase: "v5.2 — ядро худеет"'
check "короткое поле шапки законно" 0 "$(run_code "$F")"

# --- Хроника накапливается полями -------------------------------------------
F=$(new_file); healthy "$F" 300 'previous_phase_171: "было раньше"'
check "нумерованное поле «предыдущая фаза»" 1 "$(run_code "$F")"
check "…и названо лентой без дна" "да" "$(says "$(run_out "$F")" "нет дна")"

F=$(new_file); healthy "$F" 300 'phase_170: "было"'
check "phase_NNN — тот же класс" 1 "$(run_code "$F")"

F=$(new_file); healthy "$F" 300 'active_phase: "текущая"'
check "active_phase лентой не является" 0 "$(run_code "$F")"

# --- Лестницы смыслов нет ---------------------------------------------------
F=$(new_file)
{ printf -- '---\nmax_lines: 300\n---\n\n# Ledger\n\n## Активные задачи\n\n- [ ] задача\n'; } > "$F"
check "лестницы смыслов нет" 1 "$(run_code "$F")"
check "…и сказано, чем это кончается" "да" "$(says "$(run_out "$F")" "начинается с середины")"

# --- Потолок ----------------------------------------------------------------
F=$(new_file); healthy "$F" 20; pad_lines "$F" 40
check "строк больше бюджета" 1 "$(run_code "$F")"
check "…и названы обе величины" "да" "$(says "$(run_out "$F")" "при бюджете 20")"

F=$(new_file); healthy "$F" 500; pad_lines "$F" 40
check "бюджет из шапки поднимает потолок" 0 "$(run_code "$F")"

F=$(new_file); healthy "$F" -; pad_lines "$F" 400
check "поля нет — умолчание 300" 1 "$(run_code "$F")"

F=$(new_file); healthy "$F" -; printf '\nmax_lines: 9999\n' >> "$F"; pad_lines "$F" 400
check "число в теле бюджетом не является" 1 "$(run_code "$F")"

# --- Разбор -----------------------------------------------------------------
F=$(new_file); printf 'просто текст без шапки и заголовков\n' > "$F"
check "ни шапки, ни заголовков — не ledger" 1 "$(run_code "$F")"
check "…и это названо отказом разбора" "да" "$(says "$(run_out "$F")" "это не ledger")"

check "файла нет вовсе — тихо" 0 "$(run_code "/nonexistent-ledger-$$")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
