#!/bin/bash
# Доказательство мутацией для memory-gate.sh.
#
# Мир с дефектом — проверщик памяти, которого никто не обязан слушать. Ровно так
# числа 571.5 / 334.5 / 303.5 КБ, записанные в CLAUDE.md как повод завести
# check-role-memory.sh, за месяц стали 644 / 340 / 320: правило, проверщик и
# доказательство мутацией были на месте, а потребителя красноты не было.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK=${1:-"${HERE}/memory-gate.sh"}
[ -f "$HOOK" ] || { printf 'нет файла хука: %s\n' "$HOOK" >&2; exit 1; }

export MEMORY_CHECK="${HERE}/check-role-memory.sh"

EXPECTED_CASES=30
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=8
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

run_code() { printf '%s' "$1" | ( bash "$HOOK" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { printf '%s' "$1" | ( bash "$HOOK" 2>&1 ); }

edit_json() {  # $1=путь $2=старое $3=новое
  jq -nc --arg f "$1" --arg o "$2" --arg n "$3" \
     '{tool_name:"Edit", tool_input:{file_path:$f, old_string:$o, new_string:$n}}'
}
write_json() { jq -nc --arg f "$1" '{tool_name:"Write", tool_input:{file_path:$f}}'; }

new_roles() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }

add_role() {  # $1=каталог $2=роль $3=строк $4=датированных заголовков
  local dir=$1 role=$2 lines=$3 dated=$4 f i
  mkdir -p "${dir}/${role}"
  f="${dir}/${role}/context.md"
  {
    printf -- '---\nrole: "%s"\nlast_updated: "2026-08-26"\n---\n\n# Private Context\n\n' "${role}"
    for ((i = 1; i <= dated; i++)); do printf '## Сессия 2026-08-%02d — за день\n\nчто было\n\n' "$((i + 9))"; done
    for ((i = 1; i <= lines; i++)); do printf -- '- строка состояния %s\n' "${i}"; done
  } > "$f"
  printf '%s' "$f"
}

MEM=project/roles/dev/context.md
STATE=$'## Текущий фокус\n\n- разбор сущностей ядра'
DATED=$'\n\n## Сессия 2026-08-26 — что сделано\n\n- прочитал ledger'

# --- 1. Причина: приземление лентой ------------------------------------------
J=$(edit_json "$MEM" "$STATE" "${STATE}${DATED}")
check "дописан датированный раздел" 2 "$(run_code "$J")"
check "…назван предмет: состояние, а не журнал" "да" "$(says "$(run_out "$J")" "состояние, а не журнал")"
check "…назван дом хроники" "да" "$(says "$(run_out "$J")" "project/sessions/")"
check "…названа цена ленты" "да" "$(says "$(run_out "$J")" "нет дна")"

J=$(edit_json "$MEM" "$STATE" $'## Текущий фокус\n\n- новый срез после сессии')
check "перезапись раздела проходит" 0 "$(run_code "$J")"

J=$(edit_json "$MEM" "$STATE" "${STATE}"$'\n- ещё один пункт состояния')
check "дописано без датированного заголовка" 0 "$(run_code "$J")"

J=$(edit_json "$MEM" "$STATE" "${STATE}"$'\n- решено 2026-08-26: брать sonnet')
check "дата в строке тела, не заголовком" 0 "$(run_code "$J")"

OLDDATED=$'## Сессия 2026-08-19 — старое\n\nтекст'
J=$(edit_json "$MEM" "$OLDDATED" $'## Сессия 2026-08-26 — новое\n\nтекст')
check "перезапись датированного блока другим" 0 "$(run_code "$J")"

J=$(edit_json "$MEM" "" "${STATE}${DATED}")
check "пустой old_string — создание содержимого" 0 "$(run_code "$J")"

J=$(edit_json "project/artifacts/notes.md" "$STATE" "${STATE}${DATED}")
check "не память роли — не наше дело" 0 "$(run_code "$J")"

J=$(edit_json "$MEM" "$STATE" "${STATE}"$'\n\n### 2026-08-26 итоги\n\nтекст')
check "заголовок третьего уровня с датой" 2 "$(run_code "$J")"

GLOB=$'## Фокус\n\n- пункт *важно* и [скобка]'
J=$(edit_json "$MEM" "$GLOB" "${GLOB}${DATED}")
check "глоб-символы в старом тексте не ломают сравнение" 2 "$(run_code "$J")"

J=$(jq -nc --arg f "$MEM" '{tool_name:"Read", tool_input:{file_path:$f}}')
check "чтение памяти не трогаем" 0 "$(run_code "$J")"

# --- 2. Накопленное: запись сессии по красной памяти --------------------------
D=$(new_roles); add_role "$D" facilitator 40 0 >/dev/null; export ROLES_DIR="$D"
S=$(write_json "project/sessions/2026-08-26_разбор.md")
check "запись сессии при здоровой памяти" 0 "$(run_code "$S")"

export ROLE_MEMORY_HARD_BYTES=4096
D=$(new_roles); F=$(add_role "$D" dev 20 0); head -c 4096 </dev/zero | tr '\0' 'x' >> "$F"
export ROLES_DIR="$D"
check "запись сессии при нечитаемой памяти" 2 "$(run_code "$S")"
check "…диагноз проверщика процитирован" "да" "$(says "$(run_out "$S")" "ПАМЯТЬ НЕ ЧИТАЕТСЯ")"
check "…названо, чем разбирать файл выше предела" "да" "$(says "$(run_out "$S")" "Bash")"
check "…названа цена закрытия вслепую" "да" "$(says "$(run_out "$S")" "начнётся вслепую")"
unset ROLE_MEMORY_HARD_BYTES

D=$(new_roles); add_role "$D" dev 30 8 >/dev/null; export ROLES_DIR="$D"; JOURNAL_DIR="$D"
check "запись сессии при памяти-журнале" 2 "$(run_code "$S")"

H=$(write_json "project/sessions/handoff.md")
check "handoff тоже продукт сессии" 2 "$(run_code "$H")"

check "запись вне sessions/ не трогаем" 0 "$(run_code "$(write_json project/ledger.md)")"

# Ранний выход первой ветки уводил правку существующей сессии из-под гарда:
# `Write` в sessions/ бывает только в первый раз, дальше идёт `Edit`.
E=$(edit_json "project/sessions/2026-08-26_разбор.md" "старый текст" "новый текст")
check "правка существующей записи сессии тоже под гардом" 2 "$(run_code "$E")"
check "…и это не спутано с памятью роли" "да" "$(says "$(run_out "$E")" "Сессию нельзя записать")"

D=$(new_roles); add_role "$D" facilitator 40 0 >/dev/null; export ROLES_DIR="$D"
check "правка сессии при здоровой памяти проходит" 0 "$(run_code "$E")"
export ROLES_DIR="$JOURNAL_DIR"

# --- 3. Неисправность гарда не блокирует работу -------------------------------
MEMORY_CHECK=/nonexistent-checker-$$ 
export MEMORY_CHECK
check "проверщика нет — правка проходит" 0 "$(run_code "$S")"
check "…и сказано, что пропущена без проверки" "да" "$(says "$(run_out "$S")" "без проверки")"
export MEMORY_CHECK="${HERE}/check-role-memory.sh"

check "вход не JSON — проходит" 0 "$(run_code 'не json вовсе')"
check "…и сказано, что пропущена" "да" "$(says "$(run_out 'не json вовсе')" "без проверки")"
check "нет tool_name — проходит" 0 "$(run_code '{"tool_input":{"file_path":"project/roles/dev/context.md"}}')"
check "нет file_path — проходит" 0 "$(run_code '{"tool_name":"Edit","tool_input":{}}')"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nхук: %s\nслучаев: %s, провалено: %s\n' "$HOOK" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
