#!/bin/bash
# Доказательство мутацией для check-decisions.sh.
#
# Мир с дефектом здесь — проверщик, который говорит «годно» всему подряд.
# Тест обязан быть красным на такой заглушке и зелёным на настоящем скрипте:
#
#   bash .claude/hooks/check-decisions.test.sh                  # текущий
#   printf '#!/bin/sh\nexit 0\n' > /tmp/naive.sh
#   bash .claude/hooks/check-decisions.test.sh /tmp/naive.sh    # обязан упасть

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-decisions.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=26
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=2   # документ как адрес: распознавание якоря и его обязательность
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_dir() {
  local dir
  dir=$(mktemp -d)
  TRASH+=("$dir")
  printf '%s' "$dir"
}

add_decision() {  # $1 = каталог, $2 = id, $3 = дата, $4 = значение enforced_by («-» = поля нет)
  local file="$1/DEC-$2_test.md"
  {
    printf -- '---\n'
    printf 'decision_id: "DEC-%s"\n' "$2"
    printf 'date_proposed: "%s"\n' "$3"
    [ "$4" = "-" ] || printf 'enforced_by: "%s"\n' "$4"
    printf -- '---\n\n# DEC-%s\n' "$2"
  } > "$file"
}

run_checker() {  # $1 = каталог решений
  ( DECISIONS_ENFORCED_SINCE=2026-08-25 LEDGER_FILE="${LEDGER_OVERRIDE:-$1/-ledger-нет-}" bash "$CHECKER" "$1" >/dev/null 2>&1 )
  printf '%s' "$?"
}

run_output() {  # $1 = каталог решений — печатает stdout+stderr
  ( DECISIONS_ENFORCED_SINCE=2026-08-25 LEDGER_FILE="${LEDGER_OVERRIDE:-$1/-ledger-нет-}" bash "$CHECKER" "$1" 2>&1 )
}

make_ledger() {  # $1 = каталог, $2 = тело ledger — печатает путь
  printf '%s\n' "$2" > "$1/ledger.md"
  printf '%s/ledger.md' "$1"
}

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then
    printf 'PASS  %-44s ожидание %s\n' "$1" "$2"
  else
    printf 'FAIL  %-44s ожидание %s, получено %s\n' "$1" "$2" "$3"
    failed=$((failed + 1))
  fi
}

says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Законные значения -------------------------------------------------------

D=$(make_dir); add_decision "$D" 101 2026-09-01 "tests/test_x.py::test_y"
check "адрес — путь до проверки" 0 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 102 2026-09-01 "гарда нет — держится на внимании роли cto"
check "честное «гарда нет»" 0 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 103 2026-09-01 "неприменимо — решение не про код"
check "«неприменимо» для не-кодовых" 0 "$(run_checker "$D")"

# --- Миры с дефектом: наивный проверщик пропускает все три -------------------

D=$(make_dir); add_decision "$D" 104 2026-09-01 ""
check "новое решение с пустым полем" 1 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 105 2026-09-01 "-"
check "новое решение без поля вовсе" 1 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 106 2026-09-01 "покрыто тестами"
check "расплывчатое значение — не адрес" 1 "$(run_checker "$D")"

# --- Наследие ----------------------------------------------------------------

D=$(make_dir); add_decision "$D" 107 2026-08-01 "-"
check "унаследованное не роняет проверку" 0 "$(run_checker "$D")"
check "…и названо унаследованным" "да" "$(says "$(run_output "$D")" "Унаследованные без адреса")"

# --- Безвредность и половина «найдено не ноль» -------------------------------

check "каталога решений нет — тихо" 0 "$(run_checker "/nonexistent-$$")"

# Файлы есть, решений не разобрано ни одного: отказ инструмента, а не чистота.
D=$(make_dir); printf 'просто заметка\n' > "$D/notes.md"
check "файлы есть, решений ноль — отказ" 1 "$(run_checker "$D")"

# --- Находки ревью: каждая закрыта случаем --------------------------------

# 11. Файл DEC-* без шапки: раньше пропускался молча и занижал знаменатель.
D=$(make_dir); printf '# DEC-108: решение без frontmatter\n\nтекст\n' > "$D/DEC-108_headless.md"
check "решение без шапки — не пропуск, а находка" 1 "$(run_checker "$D")"

# 12. «n/a» и «...» проходили как адрес: белый список форм вместо «что-то с точкой».
D=$(make_dir); add_decision "$D" 109 2026-09-01 "n/a"
check "«n/a» адресом не является" 1 "$(run_checker "$D")"

# 13. Поле в теле документа, а не в шапке — закреплением не является.
D=$(make_dir)
printf -- '---\ndecision_id: "DEC-110"\ndate_proposed: "2026-09-01"\n---\n\nПример: enforced_by: "tests/test_x.py"\n' > "$D/DEC-110_t.md"
check "поле из тела не считается шапкой" 1 "$(run_checker "$D")"

# 14. Каталог решений есть, но пуст — законный тихий проход.
D=$(make_dir)
check "пустой каталог решений — тихо" 0 "$(run_checker "$D")"

# --- Гейт «DEC-NNN ⟹ файл»: упоминание без файла --------------------------
D=$(make_dir); add_decision "$D" 044 2026-09-01 "tests/test_a.py::test_b"
LEDGER_OVERRIDE=$(make_ledger "$D" 'Ратифицированы DEC-044 и DEC-032.')
check "упомянутое решение без файла" 1 "$(run_checker "$D")"
check "…и назван осиротевший номер" "да" "$(says "$(run_output "$D")" "DEC-032")"
check "…счётчик упомянутых печатается" "да" "$(says "$(run_output "$D")" "Упомянуто в ledger решений: 2. Без файла: 1.")"

D=$(make_dir); add_decision "$D" 044 2026-09-01 "tests/test_a.py::test_b"
LEDGER_OVERRIDE=$(make_ledger "$D" 'Ратифицировано DEC-044.')
check "упомянутое решение с файлом" 0 "$(run_checker "$D")"

# Набивка нулями не должна рождать ложную сироту.
D=$(make_dir); add_decision "$D" 044 2026-09-01 "tests/test_a.py::test_b"
LEDGER_OVERRIDE=$(make_ledger "$D" 'Ратифицировано DEC-44.')
check "DEC-44 и DEC-044 — одно решение" 0 "$(run_checker "$D")"

# Каталога решений нет вовсе — худший случай миграции, а не повод молчать.
D=$(make_dir); LEDGER_OVERRIDE=$(make_ledger "$D" 'Опираемся на DEC-050.')
check "решений нет, ledger упоминает" 1 "$(run_checker "$D/пусто")"

# Законная тишина: ledger не найден либо решений в нём не упомянуто.
D=$(make_dir); add_decision "$D" 044 2026-09-01 "tests/test_a.py::test_b"
LEDGER_OVERRIDE="$D/-нет-такого-"
check "ledger отсутствует — не роняет" 0 "$(run_checker "$D")"
LEDGER_OVERRIDE=$(make_ledger "$D" 'Фаза: пилот. Решений пока не принимали.')
check "в ledger нет упоминаний — тихо" 0 "$(run_checker "$D")"
unset LEDGER_OVERRIDE

# --- Решение закреплено документом, а не кодом --------------------------------
# Мир с дефектом: белый список расширений состоял из кода — .py, .ts, .sh, .go.
# Проект без кода закрепить решение не мог ничем и был вынужден писать «гарда
# нет», то есть неправду: гард есть, он документ. Сам фреймворк закрепляет свои
# решения правилами в `.claude/CLAUDE.md` и по собственной мерке был бы незакреплён.
D=$(make_dir); add_decision "$D" 201 2026-09-01 'project/requirements.md::FR-01'
check "документ с якорем — адрес" 0 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 202 2026-09-01 'docs/rules.md#deadline-section'
check "якорь решёткой тоже адрес" 0 "$(run_checker "$D")"

# Граница: файл целиком адресом не является — иначе отписка вернулась бы через
# другую дверь, только с расширением .md.
D=$(make_dir); add_decision "$D" 203 2026-09-01 'README.md'
check "документ без якоря — не адрес" 1 "$(run_checker "$D")"

D=$(make_dir); add_decision "$D" 204 2026-09-01 'project/requirements.md'
check "путь к документу без места — не адрес" 1 "$(run_checker "$D")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s — тест проверил не всё, что обязан\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi

printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
