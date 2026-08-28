#!/bin/bash
# Доказательство мутацией для check-scenario-coverage.sh.
#
# Мир с дефектом — проверка, которая считает описанный путь доказанным. Ровно
# так сценарий числится готовым, пока его половина не снималась ни разу, а
# «checked» стоит впереди сверки и закрывает работу на бумаге.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-scenario-coverage.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=25
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Сценарий: шапка + таблица шагов. Шаг задаётся как «номер:исполнитель».
make_scenarios() {  # $1 = status, $2 = checks, $3 = deck, далее шаги
  local d f status checks deck entry num owner
  d=$(mktemp -d); TRASH+=("$d"); f="$d/put.md"
  status=$1; checks=$2; deck=$3; shift 3
  {
    printf -- '---\nid: product.put\nkind: scenario\nproduct: product\nstatus: %s\nscope: v0.1\ntouches: []\nchecks: %s\nquestions: []\ndeck: %s\nwalked: -\n---\n\n' \
      "$status" "$checks" "$deck"
    printf '# Путь\n\n## Шаги\n\n| № | Что делает человек | Экран | Состояние | Кто отвечает |\n|---|---|---|---|---|\n'
    for entry in "$@"; do
      num=${entry%%:*}; owner=${entry##*:}
      printf '| %s | делает | screen | state | %s |\n' "$num" "$owner"
    done
  } > "$f"
  printf '%s' "$d"
}

# Лента кадров: версия/прогон/кадры с номерами шагов.
make_deck() {  # $1 = имя прогона, далее номера снятых шагов
  local d run num; d=$(mktemp -d); TRASH+=("$d"); run=$1; shift
  mkdir -p "$d/abc123.0827-1200/$run"
  for num in "$@"; do
    printf 'png' > "$(printf '%s/abc123.0827-1200/%s/screen__state__owner__%02d__desktop.png' "$d" "$run" "$num")"
  done
  printf '%s' "$d"
}

run_code() { ( bash "$CHECKER" "$1" "${2:-}" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" "${2:-}" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое ----------------------------------------------------------------
S=$(make_scenarios checked '[FR-01]' put "1:spec.a" "2:spec.b")
D=$(make_deck put 1 2)
check "каждый шаг доказан кадром" 0 "$(run_code "$S" "$D")"
check "число сценариев названо" "да" "$(says "$(run_out "$S" "$D")" "разобрано: 1")"

# --- Мутация 1: шаг без кадра принят за доказанный ---------------------------
D=$(make_deck put 1)
check "второй шаг не снимался" 1 "$(run_code "$S" "$D")"
check "…и назван номер шага" "да" "$(says "$(run_out "$S" "$D")" "шаг 2 не имеет кадра")"

# --- Мутация 2: лишний кадр не замечается ------------------------------------
D=$(make_deck put 1 2 3)
check "кадр есть, шага в описании нет" 1 "$(run_code "$S" "$D")"
check "…и сказано, что описание отстало" "да" "$(says "$(run_out "$S" "$D")" "описание отстало от прогона")"

# --- Мутация 3: сценарий без прогона считается готовым -----------------------
S=$(make_scenarios draft '[]' - "1:spec.a")
D=$(make_deck put 1)
check "поле deck пусто" 1 "$(run_code "$S" "$D")"
check "…и сказано, что путь не доказан" "да" "$(says "$(run_out "$S" "$D")" "ни разу не прогонялся")"

S=$(make_scenarios draft '[]' put "1:spec.a")
D=$(make_deck other 1)
check "прогон назван, кадров его нет" 1 "$(run_code "$S" "$D")"

# --- Мутация 4: checked при шаге без исполнителя ------------------------------
S=$(make_scenarios checked '[]' put "1:spec.a" "2:—")
D=$(make_deck put 1 2)
check "статус checked при шаге с прочерком" 1 "$(run_code "$S" "$D")"
check "…и сказано, что сверка не доведена" "да" "$(says "$(run_out "$S" "$D")" "сверка не доведена")"
S=$(make_scenarios draft '[]' put "1:spec.a" "2:—")
check "draft с прочерком — законно" 0 "$(run_code "$S" "$D")"

# --- Мутация 5: покрытие завышено --------------------------------------------
S=$(make_scenarios draft '[FR-01, FR-02]' put "1:spec.a" "2:—")
check "checks при шаге без исполнителя" 1 "$(run_code "$S" "$D")"
check "…и названо завышение" "да" "$(says "$(run_out "$S" "$D")" "покрытие завышено")"
S=$(make_scenarios draft '[]' put "1:spec.a" "2:—")
check "пустой checks при прочерке — законно" 0 "$(run_code "$S" "$D")"

# Узел выше уровня модуля исполнителем не считается — но это правило разбора
# дерева, а не формы: прочерк и пустая ячейка равны, что и проверяется.
S=$(make_scenarios checked '[]' put "1:spec.a" "2: ")
check "пустая ячейка равна прочерку" 1 "$(run_code "$S" "$D")"

# --- Мутация 6: ноль разобранных сценариев принят за успех -------------------
D2=$(mktemp -d); TRASH+=("$D2"); printf -- '---\nkind: note\n---\n\n# Не сценарий\n' > "$D2/x.md"
check "каталог есть, сценариев ноль" 1 "$(run_code "$D2" "$D")"
check "…и назван отказ разбора" "да" "$(says "$(run_out "$D2" "$D")" "не разобрано ни одного")"

# Строка прозы с чертой шагом не является.
D3=$(mktemp -d); TRASH+=("$D3")
printf -- '---\nid: p.x\nkind: scenario\nproduct: p\nstatus: draft\nscope: v0.1\ntouches: []\nchecks: []\nquestions: []\ndeck: put\nwalked: -\n---\n\n| нет | номера | в | первом | поле |\n' > "$D3/x.md"
check "строка без номера шагом не считается" 1 "$(run_code "$D3" "$D")"
check "…и сказано, что путь не описан" "да" "$(says "$(run_out "$D3" "$D")" "путь не описан")"

# --- Мутация 7: отсутствие ленты выдаётся за полное покрытие -----------------
S=$(make_scenarios draft '[]' put "1:spec.a")
OUT=$(run_out "$S" "/nonexistent-deck-$$")
check "каталога ленты нет — сказано «не измерено»" "да" "$(says "$OUT" "ПРОГОН НЕ СВЕРЕН")"
check "…и это не «покрытие полное»" "да" "$(says "$OUT" "не измерено")"

# --- Законная тишина ---------------------------------------------------------
check "каталога сценариев нет вовсе" 0 "$(run_code "/nonexistent-scenarios-$$" "$D")"

# Свежесть ленты: сравнение идёт с самым свежим ПРОГОНОМ, а не с последним по
# алфавиту. Лексикографический порядок ставит первым тот прогон, чей хэш начинается
# с буквы поближе к концу алфавита, — и описание сверяется с позапрошлой лентой.
# Здесь `zzz000` лексикографически больше, но состарен: свежий — `abc123`.
FRESH=$(make_deck put 1 2)
mkdir -p "$FRESH/zzz000.0827-0900/put"
printf 'png' > "$FRESH/zzz000.0827-0900/put/screen__state__owner__01__desktop.png"
touch -t 202601010000 "$FRESH/zzz000.0827-0900/put" "$FRESH/zzz000.0827-0900"
S=$(make_scenarios draft '[]' put "1:spec.a" "2:spec.b")
check "берётся свежий прогон, а не последний по алфавиту" 0 "$(run_code "$S" "$FRESH")"
# И обратно: если свежайшая лента неполна, это красное — прибор не ищет ленту,
# в которой всё сошлось, он смотрит в последнюю.
touch -t 203001010000 "$FRESH/zzz000.0827-0900/put" "$FRESH/zzz000.0827-0900"
check "неполный свежий прогон — красное" 1 "$(run_code "$S" "$FRESH")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
