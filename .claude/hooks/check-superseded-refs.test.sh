#!/bin/bash
# Доказательство мутацией для check-superseded-refs.sh (класс дрейфа C).
#
# Мир с дефектом — артефакт, пересказывающий вытесненное решение. Замер боевого
# проекта: `DEC-044` со статусом `superseded` упоминается в 11 артефактах; в том же
# проекте это уже стоило «два формально живых противоречащих решения, промпт
# полгода на старом правиле».

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-superseded-refs.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=21
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=9
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_project() {
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/decisions" "$d/artifacts" "$d/sessions"
  printf '%s' "$d"
}
dec() {  # $1=проект $2=id $3=status $4=superseded_by («-»)
  { printf -- '---\ndecision_id: "%s"\nstatus: "%s"\n' "$2" "$3"
    [ "$4" = "-" ] || printf 'superseded_by: "%s"\n' "$4"
    printf -- '---\n\n# %s\n\nтекст решения\n' "$2"
  } > "$1/decisions/$2.md"
}
art() { printf '%s\n' "$3" > "$1/artifacts/$2"; }

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Живых пересказов нет ----------------------------------------------------
P=$(new_project); dec "$P" DEC-001 accepted -; art "$P" plan.md "опираемся на DEC-001"
check "все решения действующие" 0 "$(run_code "$P")"
check "…и число вытесненных названо" "да" "$(says "$(run_out "$P")" "вытесненных 0")"

# --- Пересказ мёртвого решения — сердце проверки -----------------------------
P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
art "$P" vision.md "коридор берём по DEC-044"
check "артефакт пересказывает вытесненное" 1 "$(run_code "$P")"
check "…и назван файл с решением" "да" "$(says "$(run_out "$P")" "artifacts/vision.md → DEC-044")"
check "…и назван замер 11 артефактов" "да" "$(says "$(run_out "$P")" "в 11 артефактах")"

P=$(new_project); dec "$P" DEC-050 deprecated -
art "$P" plan.md "правило DEC-050 действует"
check "статус deprecated тоже считается" 1 "$(run_code "$P")"

# --- Что законно -------------------------------------------------------------
P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
art "$P" vision.md "DEC-044 вытеснено DEC-147, теперь коридор по нему"
check "заменитель на строке — законно" 0 "$(run_code "$P")"

P=$(new_project); dec "$P" DEC-044 superseded -
art "$P" vision.md "DEC-044 устарело, оставлено для истории"
check "признание словом — законно" 0 "$(run_code "$P")"

P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
printf 'в тот день опирались на DEC-044\n' > "$P/sessions/2026-05-01_работа.md"
check "хроника сессий пересказом не считается" 0 "$(run_code "$P")"
check "…и это сказано вслух" "да" "$(says "$(run_out "$P")" "Живых пересказов нет")"

P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
printf -- '---\ndecision_id: "DEC-200"\nstatus: "accepted"\nsupersedes: "DEC-044"\n---\n\nотменяет DEC-044\n' > "$P/decisions/DEC-200.md"
check "сами решения пересказом не считаются" 0 "$(run_code "$P")"

# --- Статус читается только из шапки -----------------------------------------
P=$(new_project); dec "$P" DEC-060 accepted -
printf '\nВ тексте написано status: superseded — это рассказ о чужом решении.\n' >> "$P/decisions/DEC-060.md"
art "$P" plan.md "опираемся на DEC-060"
check "слово в теле статусом не является" 0 "$(run_code "$P")"

# Шапки без статуса недостаточно: слово в теле статусом не становится.
P=$(new_project)
printf -- '---\ndecision_id: "DEC-061"\n---\n\nЦитата чужой шапки в теле:\nstatus: superseded\n' > "$P/decisions/DEC-061.md"
art "$P" plan.md "опираемся на DEC-061"
check "статус только из шапки, тела мало" 0 "$(run_code "$P")"

# Заменитель на строке без слова-признания — тоже законно.
P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
art "$P" plan.md "теперь действует DEC-147 вместо DEC-044"
check "заменитель без слова-признания — законно" 0 "$(run_code "$P")"

# --- Масштаб: одно решение во многих артефактах ------------------------------
P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
for n in a b c; do art "$P" "$n.md" "берём DEC-044"; done
check "три артефакта — три находки" 1 "$(run_code "$P")"
check "…и число названо" "да" "$(says "$(run_out "$P")" "МЁРТВОГО РЕШЕНИЯ (3)")"

# Один файл, два упоминания одного решения — одна пара «файл→решение».
P=$(new_project); dec "$P" DEC-044 superseded DEC-147; dec "$P" DEC-147 accepted -
art "$P" plan.md "DEC-044 говорит одно
и ещё раз DEC-044 говорит то же"
check "повтор в одном файле не удваивает находку" "да" "$(says "$(run_out "$P")" "МЁРТВОГО РЕШЕНИЯ (1)")"

# --- Разбор ------------------------------------------------------------------
# Свежий проект: каталог создан, решений нет — пересказывать нечего.
P=$(new_project)
check "каталог есть, решений нет — законно" 0 "$(run_code "$P")"
check "…и это сказано" "да" "$(says "$(run_out "$P")" "пересказывать нечего")"

check "каталога решений нет вовсе — тихо" 0 "$(run_code "/nonexistent-project-$$")"

# --- Ложное срабатывание: похожий номер --------------------------------------
P=$(new_project); dec "$P" DEC-04 superseded -; dec "$P" DEC-044 accepted -
art "$P" plan.md "работаем по DEC-044"
check "DEC-04 и DEC-044 не путаются" 0 "$(run_code "$P")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
