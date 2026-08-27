#!/bin/bash
# Доказательство мутацией для check-shipped.sh (класс дрейфа B).
#
# Мир с дефектом — аудит по рабочему дереву. Замер боевого проекта: 196 коммитов
# не отгружено, последний отгруженный 70 дней назад; два дефекта класса B нашлись
# только при явной сверке с отгруженной ветвью, а рабочее дерево показывало
# защищённость, которой в отгруженном коде нет.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-shipped.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=19
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

export SHIP_TODAY=2026-08-27
export GIT_AUTHOR_NAME=проба GIT_AUTHOR_EMAIL=t@t
export GIT_COMMITTER_NAME=проба GIT_COMMITTER_EMAIL=t@t

q() { git -C "$1" "${@:2}" >/dev/null 2>&1; }

# $1=число коммитов сверх отгруженного $2=дата отгруженного («-» = сегодня)
make_repo() {
  local d bare ahead=$1 when=$2 i
  d=$(mktemp -d); TRASH+=("$d")
  bare="$d/remote.git"; git init -q --bare "$bare"
  git init -q "$d/work"; q "$d/work" remote add origin "$bare"
  q "$d/work" config user.email t@t; q "$d/work" config user.name проба
  printf 'x\n' > "$d/work/f.txt"; q "$d/work" add -A
  if [ "$when" = "-" ]; then q "$d/work" commit -m base
  else GIT_AUTHOR_DATE="${when}T12:00:00" GIT_COMMITTER_DATE="${when}T12:00:00" q "$d/work" commit -m base; fi
  q "$d/work" push -u origin HEAD:master
  q "$d/work" branch --set-upstream-to=origin/master
  for ((i = 1; i <= ahead; i++)); do
    printf 'x%s\n' "$i" >> "$d/work/f.txt"; q "$d/work" add -A; q "$d/work" commit -m "правка $i"
  done
  printf '%s/work' "$d"
}

make_ledger() {  # $1=ship_max_ahead («-») $2=ship_max_days («-») $3=code_path («-»)
  local f; f=$(mktemp -d); TRASH+=("$f")
  { printf -- '---\nlast_updated: "2026-08-27"\n'
    [ "$1" = "-" ] || printf 'ship_max_ahead: %s\n' "$1"
    [ "$2" = "-" ] || printf 'ship_max_days: %s\n' "$2"
    [ "$3" = "-" ] || printf 'code_path: "%s"\n' "$3"
    printf -- '---\n\n# Ledger\n'
  } > "$f/ledger.md"
  printf '%s/ledger.md' "$f"
}

run_code() { ( bash "$CHECKER" "$1" "${2:-/nonexistent-ledger}" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" "${2:-/nonexistent-ledger}" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Разрыва нет -------------------------------------------------------------
R=$(make_repo 0 -)
check "всё отгружено" 0 "$(run_code "$R")"
check "…и обе величины названы" "да" "$(says "$(run_out "$R")" "не отгружено 0 коммитов (порог 20)")"

R=$(make_repo 5 -)
check "пять коммитов при пороге 20" 0 "$(run_code "$R")"

# --- Не отгружено слишком много ----------------------------------------------
R=$(make_repo 21 -)
check "коммитов больше порога" 1 "$(run_code "$R")"
check "…и назван класс дефекта" "да" "$(says "$(run_out "$R")" "НЕ ОТГРУЖЕНО СЛИШКОМ МНОГО")"
check "…и назван замер 196" "да" "$(says "$(run_out "$R")" "196 коммитов")"

L=$(make_ledger 50 - -)
check "порог из ledger поднимает" 0 "$(run_code "$R" "$L")"

L=$(make_ledger - - -); printf '\nship_max_ahead: 50\n' >> "$L"
check "число в теле ledger порогом не является" 1 "$(run_code "$R" "$L")"

# --- Отгрузка отстала --------------------------------------------------------
R=$(make_repo 1 2026-07-01)
check "отгружено 57 дней назад при пороге 14" 1 "$(run_code "$R")"
check "…и назван возраст" "да" "$(says "$(run_out "$R")" "ОТГРУЗКА ОТСТАЛА")"
L=$(make_ledger - 100 -)
check "порог дней из ledger поднимает" 0 "$(run_code "$R" "$L")"

R=$(make_repo 1 2026-08-20)
check "отгружено 7 дней назад — в пределах" 0 "$(run_code "$R")"

# --- Отгружать некуда --------------------------------------------------------
R=$(make_repo 0 -); q "$R" branch --unset-upstream
check "удалённые есть, upstream нет" 1 "$(run_code "$R")"
check "…и это названо классом B" "да" "$(says "$(run_out "$R")" "ОТГРУЖАТЬ НЕКУДА")"

# --- Законная тишина и отказ разбора -----------------------------------------
D=$(mktemp -d); TRASH+=("$D"); git init -q "$D/solo"
check "репозиторий без удалённых — мерить нечего" 0 "$(run_code "$D/solo")"
check "…и это сказано вслух" "да" "$(says "$(run_out "$D/solo")" "отгрузка через git не ведётся")"

D=$(mktemp -d); TRASH+=("$D")
check "каталог есть, но это не git" 1 "$(run_code "$D")"
check "каталога нет вовсе — тихо" 0 "$(run_code "/nonexistent-repo-$$")"

# --- code_path из ledger -----------------------------------------------------
R=$(make_repo 21 -); L=$(make_ledger - - "$R")
check "путь к коду берётся из ledger" 1 "$( ( bash "$CHECKER" "" "$L" >/dev/null 2>&1 ); printf '%s' "$?")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
