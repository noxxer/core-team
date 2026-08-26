#!/bin/bash
# Доказательство мутацией для check-registry-ceiling.sh.
# Мир с дефектом — проверка, которая считает реестр здоровым, пока в нём есть строки.
# Ровно так реестр дорастает до 76 открытых записей, и в него перестают смотреть.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-registry-ceiling.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=15
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_registry() {  # $1 = потолок («-» = поля нет), $2 = открытых, $3 = закрытых
  local d f i; d=$(mktemp -d); TRASH+=("$d"); f="$d/registry.md"
  {
    printf -- '---\n'
    printf 'artifact_id: "drift-registry"\n'
    [ "$1" = "-" ] || printf 'ceiling: %s\n' "$1"
    printf -- '---\n\n# Реестр\n\n## Открытые\n\n'
    printf '| ID | Класс | Что заявлено |\n|----|-------|--------------|\n'
    for ((i=1; i<=$2; i++)); do printf '| DR-%03d | A | запись |\n' "$i"; done
    printf '\n## Закрытые\n\n| ID | Класс | Как закрыто |\n|----|-------|-------------|\n'
    for ((i=1; i<=$3; i++)); do printf '| DR-%03d | B | закрыто |\n' "$((900 + i))"; done
  } > "$f"
  printf '%s' "$f"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-48s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-48s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Под потолком ------------------------------------------------------------
R=$(make_registry 20 5 3)
check "открытых меньше потолка" 0 "$(run_code "$R")"
check "счётчики названы" "да" "$(says "$(run_out "$R")" "открытых 5, закрытых 3, потолок 20")"
R=$(make_registry 20 20 0)
check "ровно потолок — ещё не пробит" 0 "$(run_code "$R")"
R=$(make_registry 20 0 40)
check "пустой открытый список — норма" 0 "$(run_code "$R")"

# --- Потолок пробит ----------------------------------------------------------
R=$(make_registry 20 21 0)
check "на одну запись выше потолка" 1 "$(run_code "$R")"
check "…и названы оба числа" "да" "$(says "$(run_out "$R")" "открытых 21 при потолке 20")"
check "…и назван выбор из двух" "да" "$(says "$(run_out "$R")" "вытесняет запись ниже приоритетом")"
R=$(make_registry 20 76 32)
check "боевой масштаб — красное" 1 "$(run_code "$R")"

# --- Закрытые записи потолок не занимают -------------------------------------
R=$(make_registry 5 5 99)
check "закрытые не считаются открытыми" 0 "$(run_code "$R")"

# --- Ёмкость не объявлена ----------------------------------------------------
R=$(make_registry - 3 1)
check "потолка в шапке нет" 1 "$(run_code "$R")"
check "…и сказано про молчаливый рост" "да" "$(says "$(run_out "$R")" "растёт молча")"
R=$(make_registry много 3 1)
check "потолок не число" 1 "$(run_code "$R")"

# Число в теле настройкой не является — только шапка.
R=$(make_registry - 3 1); printf '\nceiling: 100\n' >> "$R"
check "ceiling в теле не считается" 1 "$(run_code "$R")"

# --- Разобрать нечем ---------------------------------------------------------
R=$(make_registry 20 3 1); sed -i '' 's/^## Открытые$/## Всякое/' "$R"
check "нет раздела «Открытые»" 1 "$(run_code "$R")"

# --- Законная тишина ---------------------------------------------------------
check "реестра нет вовсе — тихо" 0 "$(run_code "/nonexistent-registry-$$.md")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
