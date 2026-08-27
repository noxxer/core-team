#!/bin/bash
# Доказательство мутацией для subagent-arrival.sh.
# Мир с дефектом — хук, который отпускает роль всегда. Ровно так работа роли
# уходила вместе с её контекстом: отчёт без блока памяти, дорожка без файла.

set -uo pipefail

GUARD=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/subagent-arrival.sh"}
[ -f "$GUARD" ] || { printf 'нет файла гарда: %s\n' "$GUARD" >&2; exit 1; }
LANE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-lane-acceptance.sh

EXPECTED_CASES=26
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=7
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

STAND=$(mktemp -d); TRASH+=("$STAND")
mkdir -p "$STAND/agents"
printf -- '---\nname: dev\n---\n' > "$STAND/agents/dev.md"

payload() {  # $1 = роль, $2 = отчёт, $3 = stop_hook_active, $4 = путь стенограммы
  jq -nc --arg r "$1" --arg m "$2" --argjson s "$3" --arg t "${4:-}" \
    '{agent_type:$r, last_assistant_message:$m, stop_hook_active:$s}
     + (if $t == "" then {} else {agent_transcript_path:$t} end)'
}

transcript_with() {  # $1 = имя стенограммы, $2 = текст брифа — печатает путь
  local f="$STAND/transcript-$1.jsonl"
  jq -nc --arg c "$2" '{type:"user", message:{role:"user", content:$c}}' > "$f"
  printf '%s' "$f"
}

run_code() { ( printf '%s' "$1" | AGENTS_DIR="$STAND/agents" LANE_CHECK="$LANE" bash "$GUARD" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( printf '%s' "$1" | AGENTS_DIR="$STAND/agents" LANE_CHECK="$LANE" bash "$GUARD" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

WITH_MEMORY='Готово.

## Для памяти роли
2026-08-26 — сделано то-то.'

# --- Роль отпускается законно ------------------------------------------------
check "блок памяти на месте" 0 "$(run_code "$(payload dev "$WITH_MEMORY" false)")"
check "встроенный агент под правило не подпадает" 0 "$(run_code "$(payload Explore 'Нашёл.' false)")"
check "повторный вход не зацикливается" 0 "$(run_code "$(payload dev 'Готово.' true)")"
check "пустой agent_type — тихо" 0 "$(run_code "$(payload '' 'Готово.' false)")"
check "имя роли с путём внутрь не пускается" 0 "$(run_code "$(payload '../../etc/passwd' 'Готово.' false)")"

# --- Реальный дефект: отчёт без памяти ---------------------------------------
NO_MEMORY=$(payload dev 'Готово, всё исправил.' false)
check "отчёт без блока памяти" 2 "$(run_code "$NO_MEMORY")"
check "…раздел назван дословно" "да" "$(says "$(run_out "$NO_MEMORY")" 'Для памяти роли')"
check "…роль названа" "да" "$(says "$(run_out "$NO_MEMORY")" 'роли dev')"

# Упоминание строки в тексте разделом не является — иначе проверка ложно-зелёная.
MENTION=$(payload dev 'Готово. Раздел Для памяти роли добавлю в следующий раз.' false)
check "упоминание вместо раздела" 2 "$(run_code "$MENTION")"
check "звёздочки вместо решётки — засчитано" 0 "$(run_code "$(payload dev 'Готово.

**Для памяти роли**
2026-08-26 — сделано.' false)")"

# --- Приёмка, названная в брифе ----------------------------------------------
GOOD="$STAND/приёмка-есть.md"; printf 'вердикт дорожки\n' > "$GOOD"
EMPTY="$STAND/приёмка-пуста.md"; : > "$EMPTY"
MISSING="$STAND/приёмки-нет.md"

T_OK=$(transcript_with ok "ЗАДАЧА. Проверь X.
ПРИЁМКА. $GOOD
ГРАНИЦА. Не трогай прод.")
check "приёмка доехала" 0 "$(run_code "$(payload dev "$WITH_MEMORY" false "$T_OK")")"

T_MISS=$(transcript_with miss "ПРИЁМКА. $MISSING")
P_MISS=$(payload dev "$WITH_MEMORY" false "$T_MISS")
check "приёмка не доехала" 2 "$(run_code "$P_MISS")"
check "…путь приёмки назван" "да" "$(says "$(run_out "$P_MISS")" "$MISSING")"

T_EMPTY=$(transcript_with empty "ПРИЁМКА. $EMPTY")
check "файл приёмки пуст" 2 "$(run_code "$(payload dev "$WITH_MEMORY" false "$T_EMPTY")")"

T_QUOTED=$(transcript_with quoted "ПРИЁМКА. \`$GOOD\`")
check "путь в обратных кавычках разобран" 0 "$(run_code "$(payload dev "$WITH_MEMORY" false "$T_QUOTED")")"

T_NONE=$(transcript_with none "ЗАДАЧА. Разовый lookup, файла приёмки нет.")
check "бриф без приёмки — только память" 0 "$(run_code "$(payload dev "$WITH_MEMORY" false "$T_NONE")")"

check "стенограммы нет — память всё равно проверяется" 2 "$(run_code "$(payload dev 'Готово.' false "$STAND/нет-такой.jsonl")")"

# --- Оба дефекта сразу -------------------------------------------------------
BOTH=$(payload dev 'Готово.' false "$T_MISS")
check "два дефекта — одна блокировка" 2 "$(run_code "$BOTH")"
BOTH_OUT=$(run_out "$BOTH")
check "…назван блок памяти" "да" "$(says "$BOTH_OUT" 'Для памяти роли')"
check "…назван и путь приёмки" "да" "$(says "$BOTH_OUT" "$MISSING")"

# --- Неисправность гарда не роняет работу ------------------------------------
check "вход не JSON" 0 "$(run_code 'это не json')"
check "пустой вход" 0 "$(run_code '')"
check "вход — массив, а не объект" 0 "$(run_code '[1,2,3]')"
check "…и о неисправности сказано" "да" "$(says "$(run_out '[1,2,3]')" 'без проверки')"
check "jq отсутствует — роль не заперта" 0 "$( ( printf '%s' "$NO_MEMORY" | PATH=/nonexistent AGENTS_DIR="$STAND/agents" /bin/bash "$GUARD" >/dev/null 2>&1 ); printf '%s' "$?")"
check "каталога ролей нет — тихо" 0 "$( ( printf '%s' "$NO_MEMORY" | AGENTS_DIR="$STAND/нет-каталога" bash "$GUARD" >/dev/null 2>&1 ); printf '%s' "$?")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nгард: %s\nслучаев: %s, провалено: %s\n' "$GUARD" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
