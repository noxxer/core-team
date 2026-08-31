#!/bin/bash
# Доказательство мутацией для check-boundaries.sh.
#
# Мир с дефектом — проект, который знает свои ручки и не знает своих границ.
# Замер: расхождение формы на границе фронт↔бек рецидивировало десять раз при
# пяти слоях защиты, потому что CI-гейт против него существовал и не вызывался.
# Спросить «какая граница сейчас без гарда» было негде: списка границ не было.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-boundaries.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=41
# Читается снаружи: `check-install-integrity.sh` сверяет число с документацией.
# shellcheck disable=SC2034
MUTATIONS=10
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

TODAY=2026-08-31
export BOUNDARIES_TODAY="$TODAY"

DIR=""
F=""
new_file() {  # заводит каталог-корень и устанавливает DIR и F
  DIR=$(mktemp -d); TRASH+=("$DIR")
  mkdir -p "$DIR/backend" "$DIR/ci"
  printf 'схема\n' > "$DIR/backend/schemas.py"
  printf 'openapi\n' > "$DIR/openapi.json"
  printf 'гард\n' > "$DIR/ci/check-api.sh"
  printf 'шаги\n' > "$DIR/.gitlab-ci.yml"
  printf 'цель\n' > "$DIR/Makefile"
  F="$DIR/boundaries.md"
}

head_of() {  # $1=файл $2=stale_days («-» = поля нет)
  local f=$1 stale=$2
  { printf -- '---\nartifact_id: "boundaries"\n'
    [ "${stale}" = "-" ] || printf 'stale_days: %s   # комментарий значением не является\n' "${stale}"
    printf -- '---\n\n# Границы\n\n## Границы\n\n'
    printf '| ID | Граница | Источник правды о форме | Чем сверяется | Известные обходы | Сверялось |\n'
    printf '|----|---------|-------------------------|---------------|------------------|-----------|\n'
  } > "$f"
}
row() {  # $1=файл $2=ID $3=стороны $4=источник $5=сверка $6=обходы $7=дата
  printf '| %s | %s | %s | %s | %s | %s |\n' "$2" "$3" "$4" "$5" "${6:-—}" "${7:-—}" >> "$1"
}

run_code() { ( BOUNDARIES_ROOT="$DIR" bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( BOUNDARIES_ROOT="$DIR" bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-56s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-56s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровый реестр ---------------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-01 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "$TODAY"
check "стороны, источник и адрес гарда на месте" 0 "$(run_code "$F")"
check "…и разобранное названо" "да" "$(says "$(run_out "$F")" "разобрано 1")"

new_file; head_of "$F" 90
row "$F" BND-02 "бек ↔ Jira REST" "внешний, не наш" "ci/check-api.sh" "—" "$TODAY"
check "внешний источник путём не является" 0 "$(run_code "$F")"

# --- Стороны -----------------------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-03 "API" "backend/schemas.py" "ci/check-api.sh" "—" "$TODAY"
check "одно слово сторон не называет" 1 "$(run_code "$F")"
check "…и назван идентификатор" "да" "$(says "$(run_out "$F")" "СТОРОНЫ НЕ НАЗВАНЫ (1): BND-03")"
check "…и сказано, что у границы двое" "да" "$(says "$(run_out "$F")" "границы всегда двое")"

new_file; head_of "$F" 90
row "$F" BND-04 "фронт <-> бек" "backend/schemas.py" "ci/check-api.sh" "—" "$TODAY"
check "ASCII-запись сторон принимается" 0 "$(run_code "$F")"

# --- Источник правды о форме -------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-05 "фронт ↔ бек" "" "ci/check-api.sh" "—" "$TODAY"
check "источник пуст" 1 "$(run_code "$F")"
check "…и сказано, что сверять не с чем" "да" "$(says "$(run_out "$F")" "Сверять не с чем")"

new_file; head_of "$F" 90
row "$F" BND-06 "фронт ↔ бек" "—" "ci/check-api.sh" "—" "$TODAY"
check "прочерк источником не является" 1 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-07 "фронт ↔ бек" "backend/gone.py" "ci/check-api.sh" "—" "$TODAY"
check "источник ведёт в никуда" 1 "$(run_code "$F")"
check "…и назван путь" "да" "$(says "$(run_out "$F")" "BND-07 → backend/gone.py")"

new_file; head_of "$F" 90
row "$F" BND-08 "фронт ↔ бек" "backend/schemas.py → openapi.json" "ci/check-api.sh" "—" "$TODAY"
check "цепочка источников: оба звена на месте" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-09 "фронт ↔ бек" "backend/schemas.py → gone/api.json" "ci/check-api.sh" "—" "$TODAY"
check "цепочка источников: второе звено битое" 1 "$(run_code "$F")"

# --- Сверка: адрес -----------------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-10 "фронт ↔ бек" "backend/schemas.py" ".gitlab-ci.yml::codegen:check" "—" "$TODAY"
check "адрес с указанием места внутри файла" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-11 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh#шаг" "—" "$TODAY"
check "адрес с якорем" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-12 "фронт ↔ бек" "backend/schemas.py" "ci/gone.sh" "—" "$TODAY"
check "адрес гарда ведёт в никуда" 1 "$(run_code "$F")"
check "…и сказано, что указатель дороже пустоты" "да" "$(says "$(run_out "$F")" "дороже пустой ячейки")"

# Существование проверяется РАНЬШЕ догадки о форме пути: файл без косой черты
# и без расширения — законный адрес, если он есть.
new_file; head_of "$F" 90
row "$F" BND-13 "фронт ↔ бек" "backend/schemas.py" "Makefile" "—" "$TODAY"
check "существующий файл без косой черты — адрес" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-14 "фронт ↔ бек" "backend/schemas.py" "сверяем глазами при правке" "—" "$TODAY"
check "проза сверкой не является" 1 "$(run_code "$F")"
check "…и это названо отсутствием сверки" "да" "$(says "$(run_out "$F")" "ГРАНИЦА БЕЗ СВЕРКИ (1): BND-14")"
check "…и сказано, что расхождение уезжает молча" "да" "$(says "$(run_out "$F")" "уезжает в прод молча")"

new_file; head_of "$F" 90
row "$F" BND-15 "фронт ↔ бек" "backend/schemas.py" "" "—" "$TODAY"
check "пустая ячейка сверки" 1 "$(run_code "$F")"

# --- Сверка: долг ------------------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-16 "код ↔ алерты" "backend/schemas.py" "принято как долг до 2026-10-31, владелец dev" "—" "—"
check "долг в будущем прогон не роняет" 0 "$(run_code "$F")"
check "…и перечислен явно" "да" "$(says "$(run_out "$F")" "Принято как долг (1): BND-16 (до 2026-10-31)")"

new_file; head_of "$F" 90
row "$F" BND-17 "код ↔ алерты" "backend/schemas.py" "принято как долг до 2026-08-30, владелец dev" "—" "—"
check "долг просрочен на день" 1 "$(run_code "$F")"
check "…и сказано, что красное вернулось" "да" "$(says "$(run_out "$F")" "красное вернулось")"

new_file; head_of "$F" 90
row "$F" BND-18 "код ↔ алерты" "backend/schemas.py" "принято как долг до $TODAY, владелец dev" "—" "—"
check "долг ровно до сегодня ещё не просрочен" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-19 "код ↔ алерты" "backend/schemas.py" "принято как долг, владелец dev" "—" "—"
check "долг без даты долгом не является" 1 "$(run_code "$F")"

# --- Показ без отказа --------------------------------------------------------
new_file; head_of "$F" 90
row "$F" BND-20 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "2026-01-01"
check "отставшая сверка прогон не роняет" 0 "$(run_code "$F")"
check "…но печатается" "да" "$(says "$(run_out "$F")" "Сверка отстала (1): BND-20")"

new_file; head_of "$F" 90
row "$F" BND-21 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "2026-08-01"
check "свежая сверка молчит" "нет" "$(says "$(run_out "$F")" "Сверка отстала")"

new_file; head_of "$F" 5
row "$F" BND-22 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "2026-08-01"
check "порог отставания сужается полем шапки" "да" "$(says "$(run_out "$F")" "Сверка отстала")"

new_file; head_of "$F" 90
row "$F" BND-23 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "wizard зеркалится вручную" "$TODAY"
check "объявленный обход считается" "да" "$(says "$(run_out "$F")" "Обходы объявлены у 1 границ из 1")"

# --- Структура ---------------------------------------------------------------
new_file
{ printf -- '---\nartifact_id: "boundaries"\n---\n\n# Границы\n\n## Список\n\n'
  printf '| BND-30 | фронт ↔ бек | backend/schemas.py | ci/check-api.sh | — | %s |\n' "$TODAY"
} > "$F"
check "раздела с ожидаемым именем нет" 1 "$(run_code "$F")"
check "…и сказано, что имя раздела — контракт" "да" "$(says "$(run_out "$F")" "контракт с этим прибором")"

new_file; head_of "$F" 90
row "$F" BND-24 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "$TODAY"
printf '<!--\n| BND-99 | API |  |  | — | — |\n-->\n' >> "$F"
check "строка в комментарии записью не является" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
row "$F" BND-25 "фронт ↔ бек" "backend/schemas.py" "ci/check-api.sh" "—" "$TODAY"
printf '\n## Снятые\n\n| BND-90 | API |  |  | — | — |\n' >> "$F"
check "соседний раздел не считается" 0 "$(run_code "$F")"

new_file; head_of "$F" 90
check "ноль записей — предупреждение, не отказ" 0 "$(run_code "$F")"
check "…и сказано, что граница появляется раньше" "да" "$(says "$(run_out "$F")" "раньше, чем про неё вспоминают")"

DIR=$(mktemp -d); TRASH+=("$DIR")
check "файла нет вовсе — тихо" 0 "$(run_code "$DIR/nope.md")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
