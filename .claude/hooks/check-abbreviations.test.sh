#!/bin/bash
# Доказательство мутацией для check-abbreviations.sh.
#
# Мир с дефектом — поставка, в которой одна аббревиатура значит разное в разных
# файлах, и спросить «сколько у нас расшифровок» негде. Замер: `DRR` расшифрован
# четырьмя способами в 13 файлах, самый частый смысл взят из чужого словаря.
# Читатель встречает расхождение каждую сессию и каждый раз решает заново.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-abbreviations.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=30
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=9
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_copy() { local d; d=$(mktemp -d); TRASH+=("$d"); mkdir -p "$d/.claude/knowledge"; printf '%s' "$d"; }
put() {  # $1=корень $2=путь под корнем $3…=строки файла
  local d=$1 rel=$2; shift 2
  mkdir -p "$d/$(dirname "$rel")"
  printf '%s\n' "$@" > "$d/$rel"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-56s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-56s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое ----------------------------------------------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'Решение пишется как DRR (Design-Rationale Record).'
put "$C" ".claude/knowledge/b.md" 'Опора — DRR (Design-Rationale Record) из FPF.'
check "одна расшифровка в двух местах" 0 "$(run_code "$C")"
check "…и число разобранных названо" "да" "$(says "$(run_out "$C")" "разобрано")"

# Дефис — разделитель слов, а не отдельная расшифровка: иначе канон FPF
# («Design-Rationale Record») и наша прежняя запись разошлись бы на ровном месте.
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — запись обоснования.'
put "$C" ".claude/knowledge/b.md" 'DRR (Design Rationale Record) — то же самое.'
check "дефис и пробел — одна расшифровка" 0 "$(run_code "$C")"

C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DPF (Domain Principles Framework).'
put "$C" ".claude/knowledge/b.md" 'DPF (domain principles framework).'
check "регистр не создаёт вторую расшифровку" 0 "$(run_code "$C")"

# Признак начальных букв — определение расшифровки, а не эвристика. Без него
# пояснение рядом («кто автор», «в каком виде») станет второй расшифровкой,
# и прибор покраснеет там, где болезни нет.
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'TDD (Test-Driven Development) — цикл.' 'Автор термина — TDD (Kent Beck).' 'Форма цикла — TDD (Red-Green-Refactor).'
check "глосса рядом расшифровкой не считается" 0 "$(run_code "$C")"

C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'ADR (append-only) правится только шапкой.' 'ADR (Architecture Decision Record) — форма решения.'
check "пояснение в скобках не спорит с расшифровкой" 0 "$(run_code "$C")"

# Служебное слово в нижнем регистре пропускается, иначе законные расшифровки
# выпадут из разбора и прибор ослепнет тихо.
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'Шкала SHRM (Society for Human Resource Management).' 'Кеш TTL (time-to-live) в секундах.'
check "служебное слово и дефис не мешают разбору" 0 "$(run_code "$C")"
check "…и такие расшифровки разобраны" "да" "$(says "$(run_out "$C")" "разобрано 2")"

C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record).' 'DRR (Design-Rationale Record).' 'DRR (Design-Rationale Record).'
check "повтор одной расшифровки — не расхождение" 0 "$(run_code "$C")"

C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — запись обоснования решения.' 'Распад подтверждения зовётся Evidence Decay, а не DRR.'
check "кириллица рядом разбор не ломает" 0 "$(run_code "$C")"

# --- Мутация 1: расхождение в скобочной форме не замечается -------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — канон FPF E.9.'
put "$C" ".claude/knowledge/b.md" 'DRR (Decision Relevance Rate) — доля актуальных решений.'
check "две расшифровки одной аббревиатуры" 1 "$(run_code "$C")"
OUT=$(run_out "$C")
check "…названа аббревиатура" "да" "$(says "$OUT" "DRR")"
check "…названа первая расшифровка" "да" "$(says "$OUT" "Design Rationale Record")"
check "…названа вторая расшифровка" "да" "$(says "$OUT" "Decision Relevance Rate")"
check "…назван адрес находки" "да" "$(says "$OUT" "b.md:1")"
check "…названо лечение" "да" "$(says "$OUT" "переименовать")"

# --- Мутация 2: форма с тире не осматривается ---------------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — канон.'
put "$C" ".claude/knowledge/b.md" '## DRR — Decay Review Rule (FPF)'
check "расшифровка после тире" 1 "$(run_code "$C")"
check "…и она названа" "да" "$(says "$(run_out "$C")" "Decay Review Rule")"

# --- Мутация 3: обратная форма «Расшифровка (АББР)» не осматривается ----------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'Design-Rationale Record (DRR)'
put "$C" ".claude/knowledge/b.md" 'DRR (Decision Revision Request) — механизм пересмотра.'
check "аббревиатура в скобках после расшифровки" 1 "$(run_code "$C")"
check "…и обе стороны названы" "да" "$(says "$(run_out "$C")" "Decision Revision Request")"

# --- Мутация 4: плагины не осматриваются -------------------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — канон.'
put "$C" "plugins/p/README.md" 'DRR (Decision Relevance Rate) — метрика.'
check "расхождение приехало из плагина" 1 "$(run_code "$C")"

# --- Мутация 5: «разобрано ноль» считается успехом ---------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'Здесь нет ни одной расшифровки аббревиатур.'
check "разбирать оказалось нечего" 1 "$(run_code "$C")"
check "…и это названо половиной «найдено не ноль»" "да" "$(says "$(run_out "$C")" "найдено не ноль")"

# --- Мутация 6: нет каталога .claude — прибор молчит успехом ------------------
# Код возврата тут ничего не доказывает: без каталога разбор пуст, и отказ придёт
# сам собой — по другой причине. Проверяем ПРИЧИНУ, иначе случай пройдёт вхолостую.
D=$(mktemp -d); TRASH+=("$D")
check "нет каталога .claude" 1 "$(run_code "$D")"
check "…и причина названа именно так" "да" "$(says "$(run_out "$D")" "нет каталога .claude")"

# --- Мутация 7: не-md файлы затягиваются в разбор ------------------------------
# Код и наборы тестов сами цитируют расшифровки как образцы формы: разбирая их,
# прибор нашёл бы собственное объяснение и покраснел на себе.
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record) — канон.'
put "$C" ".claude/hooks/x.sh" 'echo "DRR (Decision Relevance Rate)"'
check "образец в коде записью не является" 0 "$(run_code "$C")"

# --- Мутация 8: индекс OWASP принят за аббревиатуру ---------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'A01 (Broken Access Control) и A03 (Injection).' 'A01 (Нарушение контроля доступа) по-русски.'
check "номер раздела расшифровкой не является" 1 "$(run_code "$C")"
check "…потому что разбирать нечего" "да" "$(says "$(run_out "$C")" "найдено не ноль")"

# --- Мутация 9: три расшифровки печатаются как две ----------------------------
C=$(new_copy)
put "$C" ".claude/knowledge/a.md" 'DRR (Design-Rationale Record).'
put "$C" ".claude/knowledge/b.md" 'DRR (Decision Relevance Rate).'
put "$C" ".claude/knowledge/c.md" 'DRR (Decision Revision Request).'
check "три расшифровки" 1 "$(run_code "$C")"
check "…и счётчик называет три" "да" "$(says "$(run_out "$C")" "расшифровок: 3")"

printf '\n'
if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s — набор усох\n' "$ran" "$EXPECTED_CASES"
  exit 1
fi
if [ "$failed" -gt 0 ]; then
  printf 'FAIL  провалов %s из %s\n' "$failed" "$ran"
  exit 1
fi
printf 'OK    %s случаев, %s мутаций\n' "$ran" "$MUTATIONS"
