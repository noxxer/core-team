#!/bin/bash
# Доказательство мутацией для check-connection-points.sh.
#
# Мир с дефектом — проверка, которая считает «плагин установлен» ответом на
# вопрос «инструмент работает». Ровно так шесть выключенных плагинов выглядят
# закрытыми точками, а роль зовёт навык, которого в сессии нет.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-connection-points.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=37
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=9
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Список плагинов подменяется командой: зависимость явная, иначе прибор непроверяем.
make_list() {  # строки вида «имя:enabled» / «имя:disabled»
  local d f entry name state; d=$(mktemp -d); TRASH+=("$d"); f="$d/list.sh"
  {
    printf '#!/bin/bash\n'
    printf 'printf "Installed plugins:\\n\\n"\n'
    for entry in "$@"; do
      name=${entry%%:*}; state=${entry##*:}
      printf 'printf "  \\xe2\\x9d\\xaf %s@somemarket\\n    Version: 0.1.0\\n    Scope: project\\n    Status: %s\\n\\n"\n' \
        "$name" "$state"
    done
  } > "$f"
  chmod +x "$f"
  printf '%s' "$f"
}

make_points() {  # строки вида «точка|чем закрыта|деградация» либо «точка|чем|деградация|где»
  local d f entry name closed degr where; d=$(mktemp -d); TRASH+=("$d"); f="$d/points.md"
  {
    printf -- '---\nartifact_id: "connection-points"\n---\n\n# Точки подключения\n\n'
    printf '| Точка | Обязательство | Чем закрыта | Источник | Где лежит | Деградация |\n'
    printf '|---|---|---|---|---|---|\n'
    for entry in "$@"; do
      IFS='|' read -r name closed degr where <<< "$entry"
      # Адрес по умолчанию заполнен: его отсутствие — отдельный случай ниже.
      printf '| `%s` | обязательство слоя | %s | маркет | %s | %s |\n' \
        "$name" "$closed" "${where:-spec/result.md}" "$degr"
    done
  } > "$f"
  printf '%s' "$f"
}

make_canon_no_location() {  # точки канона, у которых результата-артефакта нет
  local d f name; d=$(mktemp -d); TRASH+=("$d"); f="$d/canon.md"
  {
    printf '# Канон точек\n\n'
    printf '| Точка | Обязательство | Чем закрывается | Источник | Где лежит | Деградация |\n|---|---|---|---|---|---|\n'
    for name in "$@"; do printf '| `%s` | обязательство | плагин | — | — | проза |\n' "$name"; done
  } > "$f"
  printf '%s' "$f"
}

make_canon() {  # имена точек, объявленных ядром
  local d f name; d=$(mktemp -d); TRASH+=("$d"); f="$d/canon.md"
  {
    printf '# Канон точек\n\n'
    printf '| Точка | Обязательство | Чем закрывается | Источник | Где лежит | Деградация |\n|---|---|---|---|---|---|\n'
    for name in "$@"; do printf '| `%s` | обязательство | плагин | — | путь | проза |\n' "$name"; done
  } > "$f"
  printf '%s' "$f"
}

# Среда без CLI: команда падает. Именно код возврата, а не пустой вывод,
# отличает «измерить нечем» от «плагинов не установлено ни одного».
make_broken_list() {
  local d f; d=$(mktemp -d); TRASH+=("$d"); f="$d/broken.sh"
  printf '#!/bin/bash\nexit 127\n' > "$f"; chmod +x "$f"; printf '%s' "$f"
}

EMPTY_CANON=$(mktemp -d); TRASH+=("$EMPTY_CANON")
printf '# Канон без таблицы\n' > "$EMPTY_CANON/canon.md"
NO_CANON="/nonexistent-canon-$$.md"

run_code() { ( PLUGIN_LIST_CMD="${3:-true}" bash "$CHECKER" "$1" "${2:-$NO_CANON}" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( PLUGIN_LIST_CMD="${3:-true}" bash "$CHECKER" "$1" "${2:-$NO_CANON}" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

LIST_OK=$(make_list "project-spec:✔ enabled" "planner:✔ enabled")
LIST_OFF=$(make_list "project-spec:✘ disabled")
LIST_EMPTY=$(make_list)
LIST_BROKEN=$(make_broken_list)

# --- Здоровое ----------------------------------------------------------------
P=$(make_points "requirements|\`project-spec\`|проза" "planning|\`planner\`|форк в ядре")
check "оба плагина включены" 0 "$(run_code "$P" "" "$LIST_OK")"
check "число точек названо" "да" "$(says "$(run_out "$P" "" "$LIST_OK")" "разобрано: 2")"

P=$(make_points "drift-registry|ядро|—")
check "точку закрывает само ядро" 0 "$(run_code "$P" "" "$LIST_OK")"

P=$(make_points "scenario-verification|—|ручная проверка, покрытие не считается")
check "не закрыта, но деградация объявлена" 0 "$(run_code "$P" "" "$LIST_OK")"

# --- Мутация 1: «установлен» принято за «работает» ----------------------------
P=$(make_points "requirements|\`project-spec\`|проза")
check "плагин установлен, но ВЫКЛЮЧЕН" 1 "$(run_code "$P" "" "$LIST_OFF")"
check "…и сказано, что выключен" "да" "$(says "$(run_out "$P" "" "$LIST_OFF")" "ВЫКЛЮЧЕН")"
check "…и назван разрыв «установлен ≠ работает»" "да" \
  "$(says "$(run_out "$P" "" "$LIST_OFF")" "не то же самое, что работает")"

# --- Мутация 2: отсутствующий плагин считается закрывающим --------------------
P=$(make_points "scenario-verification|\`smotrovaya\`|ручная проверка")
check "плагин не установлен вовсе" 1 "$(run_code "$P" "" "$LIST_OK")"
check "…и сказано НЕ УСТАНОВЛЕН" "да" "$(says "$(run_out "$P" "" "$LIST_OK")" "НЕ УСТАНОВЛЕН")"
check "…и названа команда установки" "да" \
  "$(says "$(run_out "$P" "" "$LIST_OK")" "claude plugin install smotrovaya")"

# Имя с маркетплейсом — тот же плагин, а не другой.
P=$(make_points "requirements|\`project-spec@senior-developer-tools\`|проза")
check "имя с @маркетплейсом разбирается" 0 "$(run_code "$P" "" "$LIST_OK")"

# --- Мутация 3: незакрытая точка без объявленной деградации -------------------
P=$(make_points "scenario-verification|—|—")
check "не закрыта и деградация прочерком" 1 "$(run_code "$P" "" "$LIST_OK")"
check "…и названа дыра без имени" "да" "$(says "$(run_out "$P" "" "$LIST_OK")" "Дыра без имени")"
P=$(make_points "scenario-verification|—|")
check "деградация пустой ячейкой" 1 "$(run_code "$P" "" "$LIST_OK")"
P=$(make_points "scenario-verification|—|?")
check "деградация вопросительным знаком" 1 "$(run_code "$P" "" "$LIST_OK")"

# --- Мутация 3б: адрес результата не назван -----------------------------------
# Замер боевого прогона: требования вёл сторонний инструмент, клал их в свой файл,
# а проверка ядра искала в своём и сообщала «записей ноль» при восьми записях.
# Адрес спрашивается у слоёв, у которых результат-артефакт есть по канону.
CANON_LOC=$(make_canon "requirements")
P=$(make_points "requirements|\`project-spec\`|проза|—")
check "закрыта чужим, адрес не назван" 1 "$(run_code "$P" "$CANON_LOC" "$LIST_OK")"
check "…и сказано, что пойдут не туда" "да" \
  "$(says "$(run_out "$P" "$CANON_LOC" "$LIST_OK")" "не найдут того, что есть")"

P=$(make_points "requirements|\`project-spec\`|проза|spec/requirements.md")
check "адрес назван — законно" 0 "$(run_code "$P" "$CANON_LOC" "$LIST_OK")"

# У ремесла результата-артефакта нет: в каноне прочерк, адреса не спрашиваем.
CANON_CRAFT=$(make_canon_no_location "craft:clarity")
P=$(make_points "craft:clarity|\`planner\`|общие принципы|—")
check "у слоя без артефакта адрес не нужен" 0 "$(run_code "$P" "$CANON_CRAFT" "$LIST_OK")"

# Слой закрыт средствами фреймворка: свои пути ядро знает и без подсказки.
P=$(make_points "drift-registry|ядро|—|—")
check "ядро закрывает — адрес не нужен" 0 "$(run_code "$P" "" "$LIST_OK")"

# --- Мутация 4: канон ядра не сверяется --------------------------------------
CANON=$(make_canon "requirements" "scenario-verification")
P=$(make_points "requirements|\`project-spec\`|проза")
check "точка ядра в проекте отсутствует" 1 "$(run_code "$P" "$CANON" "$LIST_OK")"
check "…и сказано, что слой невидим" "да" \
  "$(says "$(run_out "$P" "$CANON" "$LIST_OK")" "он невидим")"
P=$(make_points "requirements|\`project-spec\`|проза" "scenario-verification|—|ручная проверка")
check "все точки ядра на месте" 0 "$(run_code "$P" "$CANON" "$LIST_OK")"

# Непустота сторон прежде равенства: пустой канон — отказ, а не тождество.
check "канон без таблицы — отказ" 1 "$(run_code "$P" "$EMPTY_CANON/canon.md" "$LIST_OK")"
check "…и сказано, что сверять не с чем" "да" \
  "$(says "$(run_out "$P" "$EMPTY_CANON/canon.md" "$LIST_OK")" "сверять не с чем")"

# --- Мутация 5: ноль разобранных точек принят за успех ------------------------
D=$(mktemp -d); TRASH+=("$D"); printf -- '---\nartifact_id: "x"\n---\n\n# Точки\n\nТекста нет.\n' > "$D/points.md"
check "файл есть, точек ноль" 1 "$(run_code "$D/points.md" "" "$LIST_OK")"
check "…и назван отказ разбора" "да" "$(says "$(run_out "$D/points.md" "" "$LIST_OK")" "не разобрано ни одной")"

# Строка-пример из прозы точкой не считается: имя точки — в обратных кавычках.
printf '\n| точка | что | чем | откуда | как |\n|---|---|---|---|---|\n' >> "$D/points.md"
check "строка без обратных кавычек не точка" 1 "$(run_code "$D/points.md" "" "$LIST_OK")"

# --- Мутация 6: «измерить нечем» принято за «всё в порядке» -------------------
P=$(make_points "requirements|\`project-spec\`|проза")
check "CLI недоступен — форма проверена, код 0" 0 "$(run_code "$P" "" "$LIST_BROKEN")"
check "…и закрытие названо НЕ СВЕРЕННЫМ" "да" \
  "$(says "$(run_out "$P" "" "$LIST_BROKEN")" "ЗАКРЫТИЕ НЕ СВЕРЕНО")"
check "…и сказано «не измерено», а не «в порядке»" "да" \
  "$(says "$(run_out "$P" "" "$LIST_BROKEN")" "не измерено")"
# Форма при этом проверяется по-настоящему: дыра без имени краснеет и без списка.
P=$(make_points "scenario-verification|—|—")
check "дыра краснеет и когда измерить нечем" 1 "$(run_code "$P" "" "$LIST_BROKEN")"

# CLI ответил, плагинов ноль — это НЕ «измерить нечем»: заявленный плагин отсутствует.
P=$(make_points "requirements|\`project-spec\`|проза")
check "CLI ответил, плагинов ноль — красное" 1 "$(run_code "$P" "" "$LIST_EMPTY")"
check "…и это не «не сверено»" "нет" \
  "$(says "$(run_out "$P" "" "$LIST_EMPTY")" "ЗАКРЫТИЕ НЕ СВЕРЕНО")"

# --- Мутация 7: множественные беды считаются одной ---------------------------
P=$(make_points "requirements|\`smotrovaya\`|проза" "scenarios|—|—" "planning|\`project-spec\`|проза")
check "две беды разом — красное" 1 "$(run_code "$P" "" "$LIST_OFF")"
check "…и счёт назван" "да" "$(says "$(run_out "$P" "" "$LIST_OFF")" "думает неправду: 3")"

# --- Мутация 8: отсутствие файла принято за отказ -----------------------------
check "файла точек нет — тихо" 0 "$(run_code "/nonexistent-points-$$.md" "" "$LIST_OK")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
