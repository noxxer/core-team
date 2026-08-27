#!/bin/bash
# Доказательство мутацией для check-requirements.sh.
#
# Мир с дефектом — обязательства, живущие в реестре рисков. Ровно так 16 записей
# из 18 в боевом проекте были обязательствами под именем рисков: согласие,
# оферта, разрешённые провайдеры, аудит-логи. У риска нет исполнителя, поэтому
# никто их не брал, и Founder называл их по памяти как «требования, которых нет».

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-requirements.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=25
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_file() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s/requirements.md' "$d"; }

# $1=файл $2=ёмкость («-» = поля нет)
head_of() {
  local f=$1 ceiling=$2
  { printf -- '---\nartifact_id: "requirements"\n'
    [ "${ceiling}" = "-" ] || printf 'unassigned_ceiling: %s\n' "${ceiling}"
    printf -- '---\n\n# Требования\n\n## Действующие требования\n\n'
    printf '| ID | Требование | Источник | Исполнитель | Как проверяется | Статус |\n'
    printf '|----|-----------|----------|-------------|-----------------|--------|\n'
  } > "$f"
}
# $1=файл $2=id $3=источник $4=исполнитель $5=проверка $6=статус
row() { printf '| %s | формулировка | %s | %s | %s | %s |\n' "$2" "$3" "$4" "$5" "$6" >> "$1"; }

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровые требования -----------------------------------------------------
F=$(new_file); head_of "$F" 5
row "$F" NFR-01 "152-ФЗ ст.12" "модуль провайдера" "tests/test_region.py::test_egress" "проверяется машиной"
check "источник, исполнитель и проверка на месте" 0 "$(run_code "$F")"
check "…и разобранное названо" "да" "$(says "$(run_out "$F")" "разобрано 1")"

row "$F" FR-01 "оферта п.4.2" "FEAT-0031" "гарда нет — на внимании роли test" "покрыто"
check "два требования, оба исполнимы" 0 "$(run_code "$F")"

# --- Нет источника обязательства ---------------------------------------------
F=$(new_file); head_of "$F" 5
row "$F" NFR-02 "" "модуль" "tests/x.py" "покрыто"
check "источник пуст" 1 "$(run_code "$F")"
check "…и названо пожеланием" "да" "$(says "$(run_out "$F")" "НЕТ ИСТОЧНИКА")"
check "…и назван выход в backlog" "да" "$(says "$(run_out "$F")" "backlog")"

F=$(new_file); head_of "$F" 5
row "$F" NFR-03 "<источник>" "модуль" "tests/x.py" "покрыто"
check "подсказка формы источником не считается" 1 "$(run_code "$F")"

# --- Покрытие заявлено без проверки ------------------------------------------
F=$(new_file); head_of "$F" 5
row "$F" NFR-04 "152-ФЗ" "модуль" "" "покрыто"
check "статус «покрыто», проверки нет" 1 "$(run_code "$F")"
check "…и назван класс CHK-WIRE" "да" "$(says "$(run_out "$F")" "CHK-WIRE")"

F=$(new_file); head_of "$F" 5
row "$F" NFR-05 "152-ФЗ" "модуль" "" "проверяется машиной"
check "статус «проверяется машиной» без адреса" 1 "$(run_code "$F")"

F=$(new_file); head_of "$F" 5
row "$F" NFR-06 "152-ФЗ" "" "" "объявлено"
check "статус «объявлено» проверки не требует" 0 "$(run_code "$F")"

# --- Очередь не взятых -------------------------------------------------------
F=$(new_file); head_of "$F" 2
for i in 1 2; do row "$F" "FR-0$i" "оферта" "" "" "объявлено"; done
check "не взятых ровно по ёмкости" 0 "$(run_code "$F")"
check "…и они перечислены явно" "да" "$(says "$(run_out "$F")" "Не взяты (2 из 2")"
row "$F" FR-03 "оферта" "" "" "объявлено"
check "не взятых больше ёмкости" 1 "$(run_code "$F")"
check "…и назван выбор из двух" "да" "$(says "$(run_out "$F")" "поднять \`unassigned_ceiling:\`")"

F=$(new_file); head_of "$F" -
for i in 1 2 3 4 5 6; do row "$F" "FR-1$i" "оферта" "" "" "объявлено"; done
check "ёмкости в шапке нет — умолчание 5" 1 "$(run_code "$F")"

# Шапки нет вовсе, а в теле есть число: если читать весь файл, гард позеленеет.
F=$(new_file); head_of "$F" -
printf '\nunassigned_ceiling: 99\n' >> "$F"
for i in 1 2 3 4 5 6; do row "$F" "FR-3$i" "оферта" "" "" "объявлено"; done
check "число в теле при пустой шапке не поднимает ёмкость" 1 "$(run_code "$F")"

F=$(new_file); head_of "$F" 5
printf '\nunassigned_ceiling: 99\n' >> "$F"
for i in 1 2 3 4 5 6; do row "$F" "FR-2$i" "оферта" "" "" "объявлено"; done
check "ёмкость в теле настройкой не является" 1 "$(run_code "$F")"

# --- Разбор ------------------------------------------------------------------
F=$(new_file)
printf -- '---\nunassigned_ceiling: 5\n---\n\n# Требования\n\nбез раздела\n' > "$F"
check "раздела нет — разобрать нечем" 1 "$(run_code "$F")"
check "…и сказано, что имя раздела — контракт" "да" "$(says "$(run_out "$F")" "контракт с этим прибором")"

F=$(new_file); head_of "$F" 5
check "раздел есть, записей ноль — законно" 0 "$(run_code "$F")"
check "…и сказано, что так бывает редко" "да" "$(says "$(run_out "$F")" "бывает редко")"

F=$(new_file); head_of "$F" 5
printf '<!--\n' >> "$F"; row "$F" NFR-99 "" "" "" "покрыто"; printf -- '-->\n' >> "$F"
check "строка в комментарии записью не является" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 5
row "$F" NFR-07 "152-ФЗ" "модуль" "tests/x.py" "проверяется машиной"
printf '\n## Снятые требования\n\n| NFR-90 | старое | | | | |\n' >> "$F"
check "соседний раздел не считается" 0 "$(run_code "$F")"

check "файла нет вовсе — тихо" 0 "$(run_code "/nonexistent-requirements-$$")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
