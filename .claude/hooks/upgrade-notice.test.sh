#!/bin/bash
# Доказательство мутацией для upgrade-notice.sh.
#
#   bash .claude/hooks/upgrade-notice.test.sh                      # текущий прибор
#   bash .claude/hooks/upgrade-notice.test.sh /tmp/mutant.sh        # обязан упасть
#
# Мутации, каждая роняет хотя бы один случай:
#   M1 снят ключ отключения (`check_disabled`)           → «отключено настройкой — молчит»
#   M2 `newer` возвращает 0 при равенстве (>= вместо >)   → «поставка равна копии — молчит»
#   M3 кэш не читается (всегда сеть)                      → «свежий кэш при недоступной сети — печатает»
#   M4 предрелизные теги не отфильтрованы                 → «предрелизный тег не предлагается»
#   M5 сторож таймаута снят                               → «зависший remote не задерживает старт»
#
# Сеть в наборе не нужна: удалённым репозиторием служит локальный git с тегами.

set -uo pipefail

HOOK=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/upgrade-notice.sh"}
[ -f "$HOOK" ] || { printf 'нет файла прибора: %s\n' "$HOOK" >&2; exit 1; }

EXPECTED_CASES=16
# shellcheck disable=SC2034
MUTATIONS=5
ran=0; failed=0; TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

check() {  # $1 = случай, $2 = ожидание, $3 = факт
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-50s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-50s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}

make_remote() {  # $@ = теги → путь к репозиторию
  local d; d=$(mktemp -d); TRASH+=("$d")
  ( cd "$d" && git init -q && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
    && for t in "$@"; do git tag "$t"; done ) >/dev/null 2>&1
  printf '%s' "$d"
}

make_copy() {  # $1 = версия или "-" (без VERSION) → корень копии
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude"
  [ "$1" = "-" ] || printf '%s\n' "$1" > "$d/.claude/VERSION"
  printf '{ "env": {} }\n' > "$d/.claude/settings.json"
  printf '%s' "$d"
}

run() {  # $1 = копия, $2 = remote, $3 = кэш-файл (пусто = свой временный)
  local cache=${3:-}
  if [ -z "$cache" ]; then cache=$(mktemp -u); TRASH+=("$cache"); fi
  UPGRADE_SOURCE="$2" UPGRADE_CACHE="$cache" UPGRADE_CHECK_TIMEOUT=2 bash "$HOOK" "$1" 2>/dev/null
}

says() { grep -qF -- "$2" <<< "$1" && printf 'да' || printf 'нет'; }

# --- Сравнение версий ---------------------------------------------------------------
R=$(make_remote v5.3.6 v5.4.0)
C=$(make_copy 5.3.6)
OUT=$(run "$C" "$R"); code=$?
check "поставка новее — печатает обе версии" "0/да/да" "$code/$(says "$OUT" "Установлена 5.3.6")/$(says "$OUT" "доступна 5.4.0")"
check "строка ведёт к /upgrade" "да" "$(says "$OUT" '/upgrade')"

C=$(make_copy 5.4.0)
check "поставка равна копии — молчит" "" "$(run "$C" "$R")"

C=$(make_copy 5.5.0)
check "копия новее поставки — молчит" "" "$(run "$C" "$R")"

C=$(make_copy 5.3.10)
R2=$(make_remote v5.3.9)
check "сравнение числовое, не строковое (5.3.10 > 5.3.9)" "" "$(run "$C" "$R2")"

C=$(make_copy -)
OUT=$(run "$C" "$R")
check "копии без VERSION — уведомление с пометкой о возрасте" "да/да" "$(says "$OUT" "старше 5.1")/$(says "$OUT" "доступна 5.4.0")"

# --- Предрелизы ---------------------------------------------------------------------
R3=$(make_remote v5.4.0 v9.0.0-alpha.1)
C=$(make_copy 5.4.0)
check "предрелизный тег не предлагается" "" "$(run "$C" "$R3")"

C=$(make_copy 6.0.0-alpha.1)
check "копия на предрелизе считается впереди базы" "" "$(run "$C" "$R")"

# --- Отключение -----------------------------------------------------------------------
C=$(make_copy 5.3.6)
printf '{ "upgrade": { "check": false }, "env": {} }\n' > "$C/.claude/settings.json"
CACHE=$(mktemp -u); TRASH+=("$CACHE")
OUT=$(run "$C" "$R" "$CACHE")
check "отключено настройкой — молчит" "" "$OUT"
check "отключено — в сеть не ходит (кэш не создан)" "нет" "$([ -f "$CACHE" ] && printf 'да' || printf 'нет')"

# --- Кэш ---------------------------------------------------------------------------------
C=$(make_copy 5.3.6)
CACHE=$(mktemp -u); TRASH+=("$CACHE")
run "$C" "$R" "$CACHE" >/dev/null
check "после обращения кэш записан с версией" "да" "$(grep -q '^latest=5.4.0' "$CACHE" 2>/dev/null && printf 'да' || printf 'нет')"

printf 'checked=%s\nlatest=5.9.0\n' "$(date +%s)" > "$CACHE"
OUT=$(run "$C" "/nonexistent-remote-$$" "$CACHE")
check "свежий кэш при недоступной сети — печатает из кэша" "да" "$(says "$OUT" "доступна 5.9.0")"

printf 'checked=0\nlatest=5.9.0\n' > "$CACHE"
OUT=$(run "$C" "/nonexistent-remote-$$" "$CACHE"); code=$?
check "устаревший кэш и нет сети — молчит и не падает" "0/" "$code/$OUT"

# --- Безвредность ----------------------------------------------------------------------
C=$(make_copy 5.3.6)
OUT=$(UPGRADE_SOURCE="/nonexistent-remote-$$" UPGRADE_CACHE="$(mktemp -u)" bash "$HOOK" "$C" 2>&1); code=$?
check "сети нет и кэша нет — молчит, код 0, stderr пуст" "0/" "$code/$OUT"

FAKEBIN=$(mktemp -d); TRASH+=("$FAKEBIN")
printf '#!/bin/bash\nsleep 6\n' > "$FAKEBIN/git"; chmod +x "$FAKEBIN/git"
start=$(date +%s)
OUT=$(PATH="$FAKEBIN:$PATH" UPGRADE_CHECK_TIMEOUT=1 UPGRADE_CACHE="$(mktemp -u)" bash "$HOOK" "$C" 2>/dev/null); code=$?
elapsed=$(( $(date +%s) - start ))
check "зависший remote не задерживает старт дольше таймаута" "0//быстро" \
  "$code/$OUT/$([ "$elapsed" -le 3 ] && printf 'быстро' || printf "медленно(${elapsed}s)")"

C=$(make_copy 5.3.6); rm -f "$C/.claude/settings.json"
check "без settings.json работает как включённый" "да" "$(says "$(run "$C" "$R")" "доступна 5.4.0")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"; failed=$((failed + 1))
fi
printf '\nприбор: %s\nслучаев: %s, провалено: %s\n' "$HOOK" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
