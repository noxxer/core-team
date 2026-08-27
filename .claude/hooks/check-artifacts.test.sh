#!/bin/bash
# Доказательство мутацией для check-artifacts.sh.
#
# Мир с дефектом — каталог, в который оседает работа, у которой дом уже есть.
# Замер (4 боевых проекта): 215 файлов, 19 с хозяином среди узлов, 59 результатов
# сессий — каждый третий лежит не у себя. И обратная зависимость: 45 фич против
# 19 файлов в одном проекте, 10 фич против 123 в другом.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-artifacts.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=27
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

new_dir() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }
put() { local d=$1; shift; for n in "$@"; do printf 'текст\n' > "${d}/${n}"; done; }
index() {  # $1=каталог $2=ёмкость («-» = поля нет)
  { printf -- '---\nartifact_id: "artifacts-index"\n'
    [ "$2" = "-" ] || printf 'ceiling: %s\n' "$2"
    printf -- '---\n\n# artifacts\n'
  } > "$1/README.md"
}
fill() { local d=$1 n=$2 i; for ((i = 1; i <= n; i++)); do printf 'x\n' > "${d}/заметка-${i}.md"; done; }

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровый каталог --------------------------------------------------------
D=$(new_dir); put "$D" biomarker-registry.md competitors.md
check "обычные файлы — всё дома" 0 "$(run_code "$D")"
check "…и число названо" "да" "$(says "$(run_out "$D")" "записей 2 при ёмкости 40")"

D=$(new_dir)
check "пустой каталог — законно" 0 "$(run_code "$D")"
check "…и это сказано" "да" "$(says "$(run_out "$D")" "ещё ничего не заводила")"

check "каталога нет вовсе — тихо" 0 "$(run_code "/nonexistent-artifacts-$$")"

# --- У файла есть хозяин -----------------------------------------------------
D=$(new_dir); put "$D" feat0042-completion-plan.md
check "имя называет фичу" 1 "$(run_code "$D")"
check "…и назван настоящий дом" "да" "$(says "$(run_out "$D")" "features/FEAT-NNNN")"
check "…и назван сам файл" "да" "$(says "$(run_out "$D")" "feat0042-completion-plan.md")"

D=$(new_dir); put "$D" dec140-guardian-review.md
check "имя называет решение" 1 "$(run_code "$D")"
D=$(new_dir); put "$D" dr-85-panic-boundary.md
check "имя называет запись дрейфа" 1 "$(run_code "$D")"

# Граница: «dec» внутри слова хозяином не делает.
D=$(new_dir); put "$D" decoder-notes.md deck-map.md
check "«dec» внутри слова — не хозяин" 0 "$(run_code "$D")"

# --- Результат сессии --------------------------------------------------------
D=$(new_dir); put "$D" audit-2026-07-02.md
check "дата в имени — результат сессии" 1 "$(run_code "$D")"
check "…и назван дом с ротацией" "да" "$(says "$(run_out "$D")" "project/sessions/")"

D=$(new_dir); put "$D" deck-review-170.md
check "номер сессии в имени — тоже результат" 1 "$(run_code "$D")"
check "…и это не спутано с хозяином" "да" "$(says "$(run_out "$D")" "РЕЗУЛЬТАТЫ СЕССИЙ")"

D=$(new_dir); put "$D" biomarker-registry.md
check "имя без даты и номера — законный жилец" 0 "$(run_code "$D")"

# Хозяин важнее даты: файл едет к решению, а не в сессии.
D=$(new_dir); put "$D" dec137-evidence-reverify-2026-07-27.md
check "хозяин важнее даты" "да" "$(says "$(run_out "$D")" "У ЭТИХ ЕСТЬ ХОЗЯИН")"
check "…и в результаты сессий не попал" "нет" "$(says "$(run_out "$D")" "РЕЗУЛЬТАТЫ СЕССИЙ")"

# --- Потолок -----------------------------------------------------------------
D=$(new_dir); index "$D" 5; fill "$D" 6
check "записей больше ёмкости" 1 "$(run_code "$D")"
check "…и названы обе величины" "да" "$(says "$(run_out "$D")" "записей 6 при ёмкости 5")"
check "…и назван выбор из трёх" "да" "$(says "$(run_out "$D")" "archive")"

D=$(new_dir); index "$D" 50; fill "$D" 6
check "ёмкость из README поднимает потолок" 0 "$(run_code "$D")"

D=$(new_dir); index "$D" -; fill "$D" 6
check "README без ceiling — умолчание 40" 0 "$(run_code "$D")"

D=$(new_dir); index "$D" 5; printf '\nceiling: 999\n' >> "$D/README.md"; fill "$D" 6
check "число в теле README ёмкостью не является" 1 "$(run_code "$D")"

# Шапки нет вовсе, а в теле есть число: если читать весь файл, гард позеленеет.
D=$(new_dir); index "$D" -; printf '\nceiling: 999\n' >> "$D/README.md"; fill "$D" 45
check "число в теле при пустой шапке не поднимает ёмкость" 1 "$(run_code "$D")"

# README, архив и скрытые файлы записями не являются.
D=$(new_dir); index "$D" 2; mkdir -p "$D/archive"; put "$D" .DS_Store заметка.md
check "README, архив и скрытые в счёт не идут" 0 "$(run_code "$D")"
check "…и счётчик их не видит" "да" "$(says "$(run_out "$D")" "записей 1 при ёмкости 2")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
