#!/bin/bash
# Доказательство мутацией для check-role-memory.sh.
#
# Мир с дефектом — проверка, которая считает память роли здоровой, пока файл
# существует. Ровно так три самые нагруженные роли боевого проекта дорастают
# до 571.5 / 334.5 / 303.5 КБ при пределе чтения 256 КБ, продолжают числиться
# свежими у термометра и работают, ни разу не открыв свою память.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-role-memory.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=22
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_roles() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }

# $1=каталог $2=роль $3=строк-наполнителя $4=датированных заголовков $5=max_lines («-» = поля нет)
add_role() {
  local dir=$1 role=$2 lines=$3 dated=$4 declared=$5 f i
  mkdir -p "${dir}/${role}"
  f="${dir}/${role}/context.md"
  {
    printf -- '---\n'
    printf 'role: "%s"\n' "${role}"
    printf 'last_updated: "2026-08-26"\n'
    [ "${declared}" = "-" ] || printf 'max_lines: %s\n' "${declared}"
    printf -- '---\n\n# %s: Private Context\n\n## Текущий фокус\n\n' "${role}"
    for ((i = 1; i <= dated; i++)); do
      printf '## Сессия 2026-08-%02d — работа за день\n\nчто сделано\n\n' "$((i + 9))"
    done
    for ((i = 1; i <= lines; i++)); do printf -- '- строка состояния %s\n' "${i}"; done
  } > "$f"
  printf '%s' "$f"
}

# Ровный добор до заданного размера: наполнитель без переводов строки, чтобы
# байты и строки мерились независимо друг от друга.
pad_file() {  # $1=файл $2=целевой размер в байтах
  local cur need
  cur=$(wc -c < "$1" | tr -d ' ')
  [ "$cur" -ge "$2" ] && return 0
  need=$(( $2 - cur ))
  head -c "$need" < /dev/zero | tr '\0' 'x' >> "$1"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровая память ---------------------------------------------------------
D=$(new_roles)
add_role "$D" facilitator 40 0 - >/dev/null
add_role "$D" keeper 30 1 - >/dev/null
check "состояние в бюджете" 0 "$(run_code "$D")"
check "…и осмотренное названо" "да" "$(says "$(run_out "$D")" "осмотрено 2")"
add_role "$D" cto 90 2 - >/dev/null
check "три роли, все здоровы" 0 "$(run_code "$D")"

# --- Читаемость: жёсткий предел инструмента ----------------------------------
# Предел уменьшен, чтобы мерить границу точно, а не гонять сотни килобайт.
export ROLE_MEMORY_HARD_BYTES=4096

D=$(new_roles); F=$(add_role "$D" dev 20 0 -); pad_file "$F" 4096
check "ровно предел — не читается" 1 "$(run_code "$D")"
check "…и диагноз назван" "да" "$(says "$(run_out "$D")" "ПАМЯТЬ НЕ ЧИТАЕТСЯ")"
check "…и сказано про работу без памяти" "да" "$(says "$(run_out "$D")" "молча работает без памяти")"

D=$(new_roles); F=$(add_role "$D" dev 20 0 -); pad_file "$F" 4095
check "на байт ниже предела — читается" 0 "$(run_code "$D")"

D=$(new_roles); F=$(add_role "$D" dev 20 0 -); pad_file "$F" 3300
check "на подходе к пределу — ещё не отказ" 0 "$(run_code "$D")"
check "…но роль всё равно названа" "да" "$(says "$(run_out "$D")" "На подходе к пределу")"

unset ROLE_MEMORY_HARD_BYTES

# --- Контракт: состояние, а не журнал ----------------------------------------
D=$(new_roles); add_role "$D" test 20 4 - >/dev/null
check "четыре датированных заголовка — журнал" 1 "$(run_code "$D")"
check "…и назван адрес журнала" "да" "$(says "$(run_out "$D")" "project/sessions/")"

D=$(new_roles); add_role "$D" test 20 3 - >/dev/null
check "три датированных заголовка — ещё состояние" 0 "$(run_code "$D")"

# --- Бюджет строк ------------------------------------------------------------
export ROLE_MEMORY_MAX_LINES=50

D=$(new_roles); add_role "$D" architect 80 0 - >/dev/null
check "строк больше бюджета" 1 "$(run_code "$D")"
check "…и названы обе величины" "да" "$(says "$(run_out "$D")" "при бюджете 50")"

D=$(new_roles); add_role "$D" architect 80 0 400 >/dev/null
check "max_lines в шапке поднимает бюджет" 0 "$(run_code "$D")"

# Число в теле настройкой не является — только шапка.
D=$(new_roles); F=$(add_role "$D" architect 80 0 -); printf '\nmax_lines: 400\n' >> "$F"
check "max_lines в теле не считается" 1 "$(run_code "$D")"

D=$(new_roles); add_role "$D" architect 80 0 много >/dev/null
check "max_lines не число — берётся умолчание" 1 "$(run_code "$D")"

unset ROLE_MEMORY_MAX_LINES

# --- Половина «найдено не ноль» ----------------------------------------------
D=$(new_roles); mkdir -p "$D/dev" "$D/test"
check "каталоги ролей есть, файлов памяти нет" 1 "$(run_code "$D")"
check "…и сказано, что мерить нечего" "да" "$(says "$(run_out "$D")" "мерить нечего")"

# --- Законная тишина ---------------------------------------------------------
check "каталога ролей нет вовсе — тихо" 0 "$(run_code "/nonexistent-roles-$$")"

# --- Боевой масштаб: настоящие пределы, настоящие размеры --------------------
D=$(new_roles); F=$(add_role "$D" dev 20 0 -); pad_file "$F" 585179
check "585 КБ как у dev — красное" 1 "$(run_code "$D")"
F=$(add_role "$D" test 20 0 -); pad_file "$F" 342509
F=$(add_role "$D" architect 20 0 -); pad_file "$F" 310778
add_role "$D" facilitator 40 0 - >/dev/null
check "три роли боевого проекта названы" "да" \
  "$(says "$(run_out "$D")" "dev (571 КБ)")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
