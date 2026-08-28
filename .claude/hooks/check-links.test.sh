#!/bin/bash
# Доказательство мутацией для check-links.sh.
#
# Мир с дефектом — проверка, которая верит тексту на слово. Ровно так после
# переименования десять документов продолжают называть путь, которого нет:
# читатель идёт по указателю и не находит ничего.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-links.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=16
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=6
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Копия: .claude с одним документом и целями ссылок по требованию.
make_copy() {  # $1 = текст документа; далее — пути, которые СУЩЕСТВУЮТ
  local d target; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude/knowledge" "$d/plugins"
  printf '%s\n' "$1" > "$d/.claude/knowledge/doc.md"
  shift
  for target in "$@"; do
    mkdir -p "$d/$(dirname "$target")"
    printf 'x\n' > "$d/$target"
  done
  printf '%s' "$d"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровое ----------------------------------------------------------------
C=$(make_copy 'Смотри `.claude/knowledge/other.md` — там правила.' ".claude/knowledge/other.md")
check "ссылка ведёт в существующий файл" 0 "$(run_code "$C")"
check "число ссылок названо" "да" "$(says "$(run_out "$C")" "проверено: 1")"

# --- Мутация 1: битая ссылка не замечается -----------------------------------
C=$(make_copy 'Смотри `.claude/knowledge/gone.md` — там правила.')
check "файла по ссылке нет" 1 "$(run_code "$C")"
check "…и назван документ и путь" "да" "$(says "$(run_out "$C")" "doc.md называет .claude/knowledge/gone.md")"

# --- Мутация 2: ссылки в плагинах не осматриваются ---------------------------
# Живая ссылка в ядре нужна, чтобы разбор не был пустым: иначе случай пройдёт
# по неверной причине — «ссылок ноль» тоже даёт отказ.
D=$(make_copy 'Смотри `.claude/knowledge/other.md`.' ".claude/knowledge/other.md")
mkdir -p "$D/plugins/p/commands"
printf 'Читай `plugins/p/missing.md`.\n' > "$D/plugins/p/commands/cmd.md"
check "битая ссылка внутри плагина" 1 "$(run_code "$D")"
check "…и назван путь плагина" "да" "$(says "$(run_out "$D")" "plugins/p/missing.md")"

# --- Мутация 3: подстановки принимаются за пути ------------------------------
C=$(make_copy 'Форма: `.claude/roles/<role>/context.md` и `.claude/features/FEAT-NNNN/README.md`.')
check "путь с подстановкой — не ссылка" 1 "$(run_code "$C")"
check "…и это отказ разбора, а не находка" "да" "$(says "$(run_out "$C")" "не разобрано ни одной ссылки")"

C=$(make_copy 'Есть `.claude/knowledge/other.md` и форма `.claude/roles/<role>/context.md`.' ".claude/knowledge/other.md")
check "подстановка рядом с живой ссылкой" 0 "$(run_code "$C")"

# --- Мутация 4: рантайм потребителя считается битой ссылкой ------------------
C=$(make_copy 'Память: `.claude/planner-context.md`.')
printf '.claude/planner-context.md\n' > "$C/.gitignore"
check "рантайм из .gitignore — законная ссылка" 1 "$(run_code "$C")"
check "…и это отказ разбора, а не «файла нет»" "нет" \
  "$(says "$(run_out "$C")" "файла нет")"

C=$(make_copy 'Есть `.claude/knowledge/other.md` и память `.claude/planner-context.md`.' ".claude/knowledge/other.md")
printf '.claude/planner-context.md\n' > "$C/.gitignore"
check "рантайм не мешает живой ссылке" 0 "$(run_code "$C")"

# Наложение `.claude/` не приносит .gitignore фреймворка — у потребителя его нет.
# Замер на боевом прогоне: два ложных красных в чистом проекте.
C=$(make_copy 'Есть `.claude/knowledge/other.md` и память `.claude/planner-context.md`.' ".claude/knowledge/other.md")
check "рантайм опознан без .gitignore" 0 "$(run_code "$C")"

# --- Мутация 5: пустое множество принято за успех ----------------------------
C=$(make_copy 'Текст без единой ссылки на файл.')
check "ссылок нет вовсе — отказ" 1 "$(run_code "$C")"
check "…и сказано про пустое множество" "да" "$(says "$(run_out "$C")" "пустому множеству")"

# --- Законная тишина ---------------------------------------------------------
E=$(mktemp -d); TRASH+=("$E")
check "нет каталога .claude — отказ" 1 "$(run_code "$E")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
