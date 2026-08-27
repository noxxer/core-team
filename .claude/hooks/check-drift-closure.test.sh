#!/bin/bash
# Доказательство мутацией для check-drift-closure.sh.
#
# Мир с дефектом — мягкое правило «заполним адрес проверки при первом касании».
# Оно существовало и оставило проблему: 88 решений боевого проекта, `enforced_by`
# заполнен у НУЛЯ, при том что класс A («решение ↔ код») — 70% реестра дрейфа
# (52 открытых, 23 закрытых). Касания не будет: `decisions/` append-only.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-drift-closure.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=28
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_case() { local d; d=$(mktemp -d); TRASH+=("$d"); mkdir -p "$d/decisions"; printf '%s' "$d"; }

reg_head() {  # $1=каталог $2=граница («-» = поля нет)
  { printf -- '---\nartifact_id: "drift-registry"\nceiling: 20\n'
    [ "$2" = "-" ] || printf 'enforced_since_id: %s\n' "$2"
    printf -- '---\n\n# Реестр дрейфа\n\n## Открытые\n\n'
    printf '| ID | Класс | Источник | Что заявлено | Что в реальности | Чем закрывать | Владелец |\n'
    printf '|----|-------|----------|--------------|------------------|---------------|----------|\n'
  } > "$1/drift-registry.md"
}
open_row()  { printf '| **%s** | **%s** | %s | заявлено | реально | чем | dev |\n' "$2" "$3" "$4" >> "$1/drift-registry.md"; }
closed_head() {
  { printf '\n## Закрытые\n\n'
    printf '| ID | Класс | Источник | Что было | Как закрыто |\n'
    printf '|----|-------|----------|----------|-------------|\n'
  } >> "$1/drift-registry.md"
}
closed_row() { printf '| **%s** | **%s** | %s | было | закрыто |\n' "$2" "$3" "$4" >> "$1/drift-registry.md"; }
dec() {  # $1=каталог $2=имя $3=enforced_by
  printf -- '---\ndecision_id: "%s"\nstatus: "accepted"\nenforced_by: "%s"\n---\n\n# %s\n' \
    "$2" "$3" "$2" > "$1/decisions/$2.md"
}

run_code() { ( bash "$CHECKER" "$1/drift-registry.md" "$1/decisions" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1/drift-registry.md" "$1/decisions" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое закрытие -------------------------------------------------------
D=$(new_case); reg_head "$D" 1; closed_head "$D"
closed_row "$D" DR-10 A "DEC-001"; dec "$D" DEC-001 "tests/test_x.py::test_y"
check "источник назван, адрес проверки есть" 0 "$(run_code "$D")"
check "…и разобранное названо" "да" "$(says "$(run_out "$D")" "класса A — 1")"

D=$(new_case); reg_head "$D" 1; closed_head "$D"
closed_row "$D" DR-11 A "DEC-002"; dec "$D" DEC-002 "гарда нет — держится на внимании роли test"
check "дешёвая форма адреса законна" 0 "$(run_code "$D")"
D=$(new_case); reg_head "$D" 1; closed_head "$D"
closed_row "$D" DR-12 A "DEC-003"; dec "$D" DEC-003 "неприменимо — решение о найме"
check "«неприменимо» тоже адрес" 0 "$(run_code "$D")"

# Другие классы под это правило не подпадают.
D=$(new_case); reg_head "$D" 1; closed_head "$D"; closed_row "$D" DR-13 E ""
check "класс E правилом не охвачен" 0 "$(run_code "$D")"

# --- Источник не назван ------------------------------------------------------
D=$(new_case); reg_head "$D" 1; closed_head "$D"; closed_row "$D" DR-14 A ""
check "класс A закрыт без источника" 1 "$(run_code "$D")"
check "…и назван сам номер" "да" "$(says "$(run_out "$D")" "ИСТОЧНИК НЕ НАЗВАН (1): DR-14")"
check "…и назван законный выход" "да" "$(says "$(run_out "$D")" "источника нет: дефект")"

D=$(new_case); reg_head "$D" 1; closed_head "$D"; closed_row "$D" DR-15 A "источника нет: дефект без решения"
check "причина в ячейке источником не считается" 1 "$(run_code "$D")"

# --- Источник в никуда -------------------------------------------------------
D=$(new_case); reg_head "$D" 1; closed_head "$D"; closed_row "$D" DR-16 A "DEC-099"
check "названо решение без файла" 1 "$(run_code "$D")"
check "…и сказано, почему это хуже пустой" "да" "$(says "$(run_out "$D")" "выглядит как ответ")"

# --- Источник без адреса проверки — сердце правила ---------------------------
D=$(new_case); reg_head "$D" 1; closed_head "$D"
closed_row "$D" DR-17 A "DEC-004"; dec "$D" DEC-004 ""
check "адрес проверки пуст" 1 "$(run_code "$D")"
check "…и назван возврат того же дрейфа" "да" "$(says "$(run_out "$D")" "дрейф вернётся")"
check "…и перечислены дешёвые формы" "да" "$(says "$(run_out "$D")" "НЕ обязано быть тестом")"

D=$(new_case); reg_head "$D" 1; closed_head "$D"
closed_row "$D" DR-18 A "DEC-005"; dec "$D" DEC-005 "<адрес>"
check "подсказка формы адресом не считается" 1 "$(run_code "$D")"

# --- Граница по номеру: очередь конечна и объявлена --------------------------
D=$(new_case); reg_head "$D" 50; closed_head "$D"; closed_row "$D" DR-17 A ""
check "запись ниже границы не роняет" 0 "$(run_code "$D")"
check "…и посчитана как унаследованная" "да" "$(says "$(run_out "$D")" "унаследованных 1")"
closed_row "$D" DR-51 A ""
check "запись выше границы роняет" 1 "$(run_code "$D")"

D=$(new_case); reg_head "$D" -; closed_head "$D"; closed_row "$D" DR-02 A ""
check "границы в шапке нет — умолчание 1" 1 "$(run_code "$D")"

# Шапки нет вовсе, а в теле есть число: если читать весь файл, гард позеленеет.
D=$(new_case); reg_head "$D" -; printf '\nenforced_since_id: 999\n' >> "$D/drift-registry.md"
closed_head "$D"; closed_row "$D" DR-20 A ""
check "число в теле при пустой шапке границей не становится" 1 "$(run_code "$D")"

D=$(new_case); reg_head "$D" 1; printf '\nenforced_since_id: 999\n' >> "$D/drift-registry.md"
closed_head "$D"; closed_row "$D" DR-20 A ""
check "число в теле границей не является" 1 "$(run_code "$D")"

# --- Очередь разблокировки: ускорение ----------------------------------------
D=$(new_case); reg_head "$D" 1
open_row "$D" DR-30 A "DEC-010"; open_row "$D" DR-31 A "DEC-010"; open_row "$D" DR-32 A "DEC-011"
closed_head "$D"
check "очередь напечатана" "да" "$(says "$(run_out "$D")" "Очередь разблокировки")"
check "…и первым идёт решение с наибольшим числом" "да" "$(says "$(run_out "$D")" "DEC-010    разблокирует открытых записей: 2")"
check "…и одиночное решение тоже названо" "да" "$(says "$(run_out "$D")" "DEC-011    разблокирует открытых записей: 1")"

# Строка в комментарии записью не является.
D=$(new_case); reg_head "$D" 1; closed_head "$D"
printf '<!--\n| **DR-40** | **A** |  | было | закрыто |\n-->\n' >> "$D/drift-registry.md"
check "строка в комментарии не считается" 0 "$(run_code "$D")"

# --- Разбор ------------------------------------------------------------------
D=$(new_case); reg_head "$D" 1
check "раздела «Закрытые» нет — разобрать нечем" 1 "$(run_code "$D")"
check "…и сказано, что имя раздела — контракт" "да" "$(says "$(run_out "$D")" "контракт с этим прибором")"

check "реестра нет вовсе — тихо" 0 "$( ( bash "$CHECKER" "/nonexistent-drift-$$" ) >/dev/null 2>&1; printf '%s' "$?")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
