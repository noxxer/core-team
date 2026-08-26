#!/bin/bash
# Доказательство мутацией для check-version-sync.sh.
# Мир с дефектом — сверка, которая смотрит на источник и молчит про объявления.
# Ровно так plugin.json прожил два релиза с версией 4.5.0 при VERSION 5.0.0.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-version-sync.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=15
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_repo() {  # $1 = версия в .claude/VERSION, $2 = версия в plugin.json, $3 = версия бейджа
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude" "$d/.claude-plugin"
  [ "$1" = "-" ] || printf '%s\n' "$1" > "$d/.claude/VERSION"
  [ "$2" = "-" ] || printf '{\n  "name": "core-team",\n  "version": "%s"\n}\n' "$2" > "$d/.claude-plugin/plugin.json"
  [ "$3" = "-" ] || printf '![version](https://img.shields.io/badge/version-%s-blue)\n' "$3" > "$d/README.md"
  printf '%s' "$d"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-48s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-48s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Законный зелёный --------------------------------------------------------
R=$(make_repo 5.0.0 5.0.0 5.0.0)
check "всё сходится" 0 "$(run_code "$R")"
check "число объявлений названо" "да" "$(says "$(run_out "$R")" "Объявлений сверено: 2")"
R=$(make_repo "5.0.0  " 5.0.0 5.0.0)
check "пробелы в VERSION не мешают" 0 "$(run_code "$R")"

# --- Реальный дефект: манифест отстал ---------------------------------------
R=$(make_repo 5.0.0 4.5.0 5.0.0)
check "plugin.json отстал" 1 "$(run_code "$R")"
check "…и назван поимённо" "да" "$(says "$(run_out "$R")" "plugin.json: 4.5.0")"

# --- Бейдж в README ----------------------------------------------------------
R=$(make_repo 5.0.0 5.0.0 4.5.1)
check "бейдж README разошёлся" 1 "$(run_code "$R")"
check "…назван файл README" "да" "$(says "$(run_out "$R")" "README.md: 4.5.1")"
R=$(make_repo 5.0.0 5.0.0 5.0.0)
printf '![version](https://img.shields.io/badge/version-4.0.0-blue)\n' > "$R/README.en.md"
check "второй README тоже сверяется" 1 "$(run_code "$R")"
check "…и это именно README.en.md" "да" "$(says "$(run_out "$R")" "README.en.md: 4.0.0")"

# --- Источника нет или он пуст ----------------------------------------------
R=$(make_repo - 5.0.0 5.0.0)
check "нет .claude/VERSION" 1 "$(run_code "$R")"
check "…сказано, что обещание в CLAUDE.md" "да" "$(says "$(run_out "$R")" "копирует только .claude/")"
R=$(make_repo "" 5.0.0 5.0.0)
check "VERSION пуст" 1 "$(run_code "$R")"

# --- Копия потребителя: законная тишина -------------------------------------
R=$(make_repo 5.0.0 - -)
check "нет манифеста плагина — тихо" 0 "$(run_code "$R")"
check "…и сказано почему" "да" "$(says "$(run_out "$R")" "не репозиторий фреймворка")"

# --- Разбор сломался: ноль объявлений не зелёный ----------------------------
R=$(make_repo 5.0.0 - -)
printf '{\n  "name": "core-team"\n}\n' > "$R/.claude-plugin/plugin.json"
check "манифест есть, объявлений ноль" 1 "$(run_code "$R")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
