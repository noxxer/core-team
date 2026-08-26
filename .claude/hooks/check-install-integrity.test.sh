#!/bin/bash
# Доказательство мутацией для check-install-integrity.sh.
# Мир с дефектом — проверка, которая смотрит на наличие файлов и молчит про то,
# подключены ли они. Ровно так `VERSION` не доезжал до потребителя, `hooks.json`
# выглядел конфигом, а числа в документации отставали от наборов.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-install-integrity.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=19
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_copy() {  # печатает корень исправной копии
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude/hooks" "$d/.claude/templates/project"
  printf '5.0.0\n' > "$d/.claude/VERSION"
  printf '#!/bin/bash\nexit 0\n' > "$d/.claude/hooks/session-start.sh"
  chmod +x "$d/.claude/hooks/session-start.sh"
  printf 'SLOTS=(%s)\nEXPECTED_CASES=7\n' "'Структура (Iceberg)' 'Ловушки сессии'" > "$d/.claude/hooks/check-session-reflection.sh"
  chmod +x "$d/.claude/hooks/check-session-reflection.sh"
  printf 'EXPECTED_CASES=7\n' > "$d/.claude/hooks/check-session-reflection.test.sh"
  chmod +x "$d/.claude/hooks/check-session-reflection.test.sh"
  printf '### Структура (Iceberg)\n### Ловушки сессии (Trap Scan)\n' > "$d/.claude/templates/project/session-template.md"
  printf 'Доказательство мутацией — `check-session-reflection.test.sh` (7 случаев).\n' > "$d/.claude/CLAUDE.md"
  cat > "$d/.claude/settings.json" <<'JSON'
{ "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] } ] } }
JSON
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

# --- Исправная копия ---------------------------------------------------------
C=$(make_copy)
check "исправная копия проходит" 0 "$(run_code "$C")"
check "число проверенных пунктов названо" "да" "$(says "$(run_out "$C")" "Проверено пунктов:")"

# --- Версия не доехала -------------------------------------------------------
C=$(make_copy); rm -f "$C/.claude/VERSION"
check "нет .claude/VERSION" 1 "$(run_code "$C")"
check "…и сказано про обещание CLAUDE.md" "да" "$(says "$(run_out "$C")" "обещает версию именно там")"
C=$(make_copy); : > "$C/.claude/VERSION"
check "VERSION пуст" 1 "$(run_code "$C")"

# --- Хук лежит, но не исполняем ----------------------------------------------
C=$(make_copy); chmod -x "$C/.claude/hooks/session-start.sh"
check "хук не исполняем" 1 "$(run_code "$C")"
check "…и назван файл" "да" "$(says "$(run_out "$C")" "не исполняем")"

# --- Хук объявлен, файла нет --------------------------------------------------
C=$(make_copy); rm -f "$C/.claude/hooks/session-start.sh"
check "объявленного хука нет на диске" 1 "$(run_code "$C")"
check "…и назван путь" "да" "$(says "$(run_out "$C")" "хук объявлен, файла нет")"

# --- Хуки лежат, но не объявлены ---------------------------------------------
C=$(make_copy); printf '{}\n' > "$C/.claude/settings.json"
check "ни один хук не объявлен" 1 "$(run_code "$C")"
check "…и сказано «файл лежит» ≠ «вызывается»" "да" "$(says "$(run_out "$C")" "ни одного объявленного хука")"
C=$(make_copy); rm -f "$C/.claude/settings.json"
check "settings.json отсутствует" 1 "$(run_code "$C")"

# --- Слоты шаблона разъехались с проверщиком ---------------------------------
C=$(make_copy); printf '### Структура (Iceberg)\n' > "$C/.claude/templates/project/session-template.md"
check "слот проверщика пропал из шаблона" 1 "$(run_code "$C")"
check "…и назван именно он" "да" "$(says "$(run_out "$C")" "Ловушки сессии")"

# --- Число случаев в документации отстало ------------------------------------
C=$(make_copy); printf 'EXPECTED_CASES=9\n' > "$C/.claude/hooks/check-session-reflection.test.sh"
check "документация отстала от набора" 1 "$(run_code "$C")"
check "…названы оба числа" "да" "$(says "$(run_out "$C")" "документация говорит 7 случаев, в наборе 9")"

# --- Отказ инструмента, а не чистая система ----------------------------------
# Запасной путь отрезан: объявления хуков тоже сняты, иначе случай краснел бы
# из-за «объявлен, файла нет», а не из-за пустого перечня (выжившая мутация).
C=$(make_copy); rm -f "$C/.claude/hooks/"*.sh; printf '{}\n' > "$C/.claude/settings.json"
check "хуков нет вовсе — не зелёный" 1 "$(run_code "$C")"
check "…и это назван отказ перечисления" "да" "$(says "$(run_out "$C")" "не найдено ни одного скрипта")"
check "нет .claude вовсе" 1 "$(run_code "$(mktemp -d)")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
