#!/bin/bash
# Доказательство мутацией для check-work-trail.sh.
#
# Мир с дефектом — набор гейтов, слепой к отсутствию: все они стоят на артефактах,
# а если файла нет, проверять нечего. Так пройден боевой прогон: код написан,
# снимки сняты, ни одной записи замысла и ни одной записи сессии.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-work-trail.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=19
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=6
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Проект: код, ленты замысла, сессии, решения — каждое по требованию.
make_project() {  # $1 = файлов кода, $2 = записей замысла, $3 = сессий, $4 = решений, $5 = путей пользования
  local d i; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/project/ideas" "$d/project/features" "$d/project/deliveries" \
           "$d/project/sessions" "$d/project/decisions" "$d/project/scenarios" "$d/backend"
  for ((i = 1; i <= ${5:-0}; i++)); do printf '# Путь %s\n' "$i" > "$d/project/scenarios/put$i.md"; done
  for ((i = 1; i <= $1; i++)); do printf 'print("код")\n' > "$d/backend/module$i.py"; done
  for ((i = 1; i <= $2; i++)); do printf '# Идея %s\n' "$i" > "$d/project/ideas/IDEA-000$i.md"; done
  for ((i = 1; i <= $3; i++)); do printf '# Сессия %s\n' "$i" > "$d/project/sessions/2026-08-2$i.md"; done
  for ((i = 1; i <= $4; i++)); do printf '# Решение %s\n' "$i" > "$d/project/decisions/DEC-00$i.md"; done
  printf '%s' "$d"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое ----------------------------------------------------------------
P=$(make_project 3 2 1 1)
check "код, замысел и сессия на месте" 0 "$(run_code "$P")"
check "числа названы" "да" "$(says "$(run_out "$P")" "кода 3, замысел 2")"

# --- Мутация 1: код без записанного замысла ----------------------------------
P=$(make_project 3 0 1 0)
check "код есть, замысла нет" 1 "$(run_code "$P")"
check "…и названо число файлов кода" "да" "$(says "$(run_out "$P")" "файлов кода 3")"
check "…и назван способ закрыть" "да" "$(says "$(run_out "$P")" "plan-feat")"

# --- Мутация 2: работа без летописи ------------------------------------------
P=$(make_project 2 1 0 0)
check "код есть, сессий нет" 1 "$(run_code "$P")"
check "…и сказано про следующую сессию" "да" "$(says "$(run_out "$P")" "начинается с нуля")"

P=$(make_project 0 0 0 2)
check "кода нет, решения есть — прибор молчит" 0 "$(run_code "$P")"

# --- Второй законный вход: продукт описан раньше кода -------------------------
# Замер боевого прогона: работа шла от описания продукта — пути пользования,
# требования, дерево обещаний, — а проверка требовала каталог идей и сообщала
# «построено без записанного зачем» на здоровом проекте.
P=$(make_project 3 0 1 0 2)
check "путь пользования засчитан как замысел" 0 "$(run_code "$P")"
check "…и число путей названо" "да" "$(says "$(run_out "$P")" "путей пользования 2")"

# Пути живут там, куда их кладёт сторонний инструмент: адрес берётся из таблицы.
P=$(make_project 3 0 1 0 0)
mkdir -p "$P/scenarios"
printf '# Путь\n' > "$P/scenarios/oplata.md"
printf '| Точка | Обязательство | Чем закрыта | Источник | Где лежит | Деградация |\n' \
  > "$P/project/connection-points.md"
printf '|---|---|---|---|---|---|\n| `scenarios` | пути пользования | `project-spec` | маркет | scenarios/ | проза |\n' \
  >> "$P/project/connection-points.md"
check "путь у стороннего инструмента засчитан" 0 "$(run_code "$P")"

# --- Мутация 3: проект без кода принят за нарушителя --------------------------
P=$(make_project 0 0 0 0)
check "проект без кода — не измеряется" 0 "$(run_code "$P")"
check "…и граница названа" "да" "$(says "$(run_out "$P")" "этим прибором не измеряется")"

# --- Замысел засчитывается из любой из трёх лент ------------------------------
P=$(make_project 2 0 1 0); printf '# Фича\n' > "$P/project/features/FEAT-0001.md"
check "замысел в features засчитан" 0 "$(run_code "$P")"
P=$(make_project 2 0 1 0); printf '# Поставка\n' > "$P/project/deliveries/DEL-0001.md"
check "замысел в deliveries засчитан" 0 "$(run_code "$P")"

# --- Мутация 4: служебные каталоги считаются кодом ----------------------------
P=$(make_project 0 0 0 0)
mkdir -p "$P/.claude/hooks" "$P/node_modules/pkg" "$P/deck/output/v1"
printf 'x\n' > "$P/.claude/hooks/tool.py"
printf 'x\n' > "$P/node_modules/pkg/index.js"
printf 'x\n' > "$P/deck/output/v1/shot.js"
check "служебные каталоги кодом не считаются" 0 "$(run_code "$P")"

# --- Две беды разом -----------------------------------------------------------
P=$(make_project 4 0 0 0)
check "ни замысла, ни сессий" 1 "$(run_code "$P")"
check "…и счёт пропусков назван" "да" "$(says "$(run_out "$P")" "пропусков следа: 2")"

# --- Законная тишина ----------------------------------------------------------
E=$(mktemp -d); TRASH+=("$E")
check "каталога project нет вовсе" 0 "$(run_code "$E")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
