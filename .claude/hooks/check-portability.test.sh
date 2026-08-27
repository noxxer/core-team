#!/bin/bash
# Доказательство мутацией для check-portability.sh.
#
# Мир с дефектом — вера, что кросс-платформенность проверяет shellcheck. Проба:
# файл с четырьмя платформенными несовместимостями подряд (`date -j`, `stat -f`,
# `grep -P`, `readlink -f`) даёт shellcheck **ноль** замечаний на любом уровне
# строгости: он разбирает синтаксис оболочки, а не аргументы чужих программ.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-portability.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=19
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=7
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_dir() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }
put() { printf '#!/bin/bash\n%s\n' "$3" > "$1/$2"; }
Q=$(printf "'")
# Образцы нарушений НЕ пишем литералом: прибор сканирует и наборы тоже, и файл
# с литеральным `grep -P` внутри сам становится непереносимым. Собираем из частей.
DASH='-'
G_GREP="grep ${DASH}P"
G_SORT="sort ${DASH}V"
G_READLINK="readlink ${DASH}f"
COMMA=","
G_MATCH="match(\$0, /x/${COMMA} m)"

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Переносимо ---------------------------------------------------------------
D=$(new_dir); put "$D" ok.sh 'd=$(date -j -f %Y "$x" +%s 2>/dev/null || date -d "$x" +%s)'
check "обе формы date рядом — переносимо" 0 "$(run_code "$D")"
check "…и число файлов названо" "да" "$(says "$(run_out "$D")" "осмотрено файлов 1")"

D=$(new_dir); put "$D" ok.sh 'if [ "$(uname)" = "Darwin" ]; then stat -f %m "$1"; else stat -c %Y "$1"; fi'
check "обе формы stat через uname — переносимо" 0 "$(run_code "$D")"

D=$(new_dir); put "$D" ok.sh '# в комментарии про date -j и stat -f говорить можно'
check "упоминание в комментарии не находка" 0 "$(run_code "$D")"

D=$(new_dir); printf '#!/bin/bash\necho "видел `%s` в чужом коде"\n' "$G_GREP" > "$D/ok.sh"
check "упоминание в обратных кавычках не находка" 0 "$(run_code "$D")"

# --- Пара разошлась -----------------------------------------------------------
D=$(new_dir); put "$D" bad.sh 'd=$(date -j -f %Y "$x" +%s)'
check "date -j без date -d" 1 "$(run_code "$D")"
check "…и назван файл с правилом" "да" "$(says "$(run_out "$D")" "bad.sh: date -j без date -d")"
check "…и сказано про молчаливую деградацию" "да" "$(says "$(run_out "$D")" "молча деградирует")"

D=$(new_dir); put "$D" bad.sh 'd=$(date -v+30d +%F)'
check "date -v без date -d" 1 "$(run_code "$D")"
D=$(new_dir); put "$D" bad.sh 's=$(stat -f %z "$1")'
check "stat -f без stat -c" 1 "$(run_code "$D")"

# --- Только GNU ---------------------------------------------------------------
D=$(new_dir); put "$D" bad.sh "${G_GREP} 'x' f"
check "grep с флагом P — только GNU" 1 "$(run_code "$D")"
check "…и сказано, что замены нет" "да" "$(says "$(run_out "$D")" "запасной формы не существует")"
D=$(new_dir); put "$D" bad.sh "${G_READLINK} /tmp"
check "readlink с флагом f — только GNU" 1 "$(run_code "$D")"
D=$(new_dir); put "$D" bad.sh "${G_SORT} < f"
check "sort с флагом V — только GNU" 1 "$(run_code "$D")"

# --- Форма, молчащая на чужой платформе ---------------------------------------
D=$(new_dir); printf '#!/bin/bash\nsed -i %s%s "s/a/b/" f\n' "$Q" "$Q" > "$D/bad.sh"
check "sed -i с пустым аргументом" 1 "$(run_code "$D")"
check "…и назван самый дорогой класс" "да" "$(says "$(run_out "$D")" "остаётся зелёным")"

D=$(new_dir); put "$D" bad.sh "awk '{ if (${G_MATCH}) print m[1] }' f"
check "match с тремя аргументами — только GNU awk" 1 "$(run_code "$D")"

# --- Половина «найдено не ноль» -----------------------------------------------
D=$(new_dir)
check "каталог есть, файлов .sh нет" 1 "$(run_code "$D")"
check "каталога нет вовсе — тоже отказ" 1 "$(run_code "/nonexistent-portability-$$")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
