#!/bin/bash
# Доказательство мутацией для check-lane-acceptance.sh.
# Мир с дефектом — приёмка, которая верит отчёту: «файл заявлен, значит есть».
# Именно так три дорожки из шести теряли работу целиком и это считалось успехом.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-lane-acceptance.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=25
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=0   # мутации для этого набора не пересчитывались поимённо
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

workdir() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }

run_code() { ( bash "$CHECKER" "$@" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$@" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-48s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-48s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

W=$(workdir)
printf 'Разбор: карточка сетки без min-w-0 смещает попадание клика.\n' > "$W/lane-1.md"
printf 'Вердикт: needs-changes, 1×P0.\n' > "$W/lane-2.md"
: > "$W/пустая.md"
printf '   \n\t\n' > "$W/пробелы.md"
mkdir -p "$W/каталог.md"

# --- Законный зелёный --------------------------------------------------------
check "работа доехала" 0 "$(run_code "$W/lane-1.md")"
check "…и назван размер" "да" "$(says "$(run_out "$W/lane-1.md")" "принято")"
check "две дорожки из двух" 0 "$(run_code "$W/lane-1.md" "$W/lane-2.md")"
check "счётчики в итоге" "да" "$(says "$(run_out "$W/lane-1.md" "$W/lane-2.md")" "Дорожек: 2. Принято: 2. Не доехало: 0.")"

# --- Миры с дефектом ---------------------------------------------------------
check "файла нет — работа потеряна" 1 "$(run_code "$W/lane-нет.md")"
check "…и сказано, что не доехала" "да" "$(says "$(run_out "$W/lane-нет.md")" "не доехала")"
check "файл заведён и пуст" 1 "$(run_code "$W/пустая.md")"
check "…пустота отличается от отсутствия" "да" "$(says "$(run_out "$W/пустая.md")" "содержимого нет")"
check "только пробелы — тоже пусто" 1 "$(run_code "$W/пробелы.md")"
check "каталог вместо файла приёмки" 1 "$(run_code "$W/каталог.md")"

# --- Смешанная волна: принятые печатаются вместе с потерянными ---------------
MIXED=$(run_out "$W/lane-1.md" "$W/lane-нет.md" "$W/lane-2.md")
check "смешанная волна красная" 1 "$(run_code "$W/lane-1.md" "$W/lane-нет.md" "$W/lane-2.md")"
check "…уцелевшие названы поимённо" "да" "$(says "$MIXED" "Дорожек: 3. Принято: 2. Не доехало: 1.")"
check "…и предупреждение про респаун" "да" "$(says "$MIXED" "респаунить")"

# --- Наследие прошлого прогона ----------------------------------------------
OLD=$(workdir); printf 'вчерашний вердикт\n' > "$OLD/lane.md"
touch -t 202001010000 "$OLD/lane.md"
check "старый файл не является приёмкой" 1 "$(run_code --since "$(date +%s)" "$OLD/lane.md")"
check "…и назван наследием" "да" "$(says "$(run_out --since "$(date +%s)" "$OLD/lane.md")" "наследие прошлого прогона")"
check "свежий файл проходит --since" 0 "$(run_code --since 1 "$W/lane-1.md")"

# --- Граница собственной силы названа в выводе -------------------------------
check "без --since сказана оговорка" "да" "$(says "$(run_out "$W/lane-1.md")" "приёмка не отличает свежую работу")"
check "с --since оговорки нет" "нет" "$(says "$(run_out --since 1 "$W/lane-1.md")" "приёмка не отличает свежую работу")"

# --- Пути с пробелом ---------------------------------------------------------
printf 'вердикт дорожки\n' > "$W/с пробелом.md"
check "путь с пробелом принимается" 0 "$(run_code "$W/с пробелом.md")"
check "…и назван целиком" "да" "$(says "$(run_out "$W/с пробелом.md")" "с пробелом.md — принято")"

# --- Гард, которому нечего проверять, молчать не вправе ----------------------
check "ноль путей — не зелёный" 1 "$(run_code)"
check "…и сказано почему" "да" "$(says "$(run_out)" "принимать нечего")"

# --- Fail-closed на собственных аргументах -----------------------------------
check "--since без значения" 1 "$(run_code --since)"
check "--since не число" 1 "$(run_code --since вчера "$W/lane-1.md")"
check "неизвестный ключ" 1 "$(run_code --force "$W/lane-1.md")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
