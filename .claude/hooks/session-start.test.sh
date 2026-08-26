#!/bin/bash
# Доказательство мутацией для термометра памяти ролей в session-start.sh.
#
# Прибор заменил собой блокирующий гейт, поэтому обязан быть доказан так же:
#   bash .claude/hooks/session-start.test.sh                       # текущий хук
#   git show <до-правки>:.claude/hooks/session-start.sh > /tmp/old.sh
#   bash .claude/hooks/session-start.test.sh /tmp/old.sh           # обязан упасть
#
# Полнота: у каждой ветки вывода есть случай, плюс защита от ложного
# срабатывания (свежая память молчит) и от вреда (хук не падает).

set -uo pipefail

HOOK=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/session-start.sh"}
[ -f "$HOOK" ] || { printf 'нет файла хука: %s\n' "$HOOK" >&2; exit 1; }

EXPECTED_CASES=12
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

make_roles() {  # печатает путь к каталогу ролей
  local dir
  dir=$(mktemp -d)
  TRASH+=("$dir")
  printf '%s' "$dir"
}

add_role() {  # $1 = каталог ролей, $2 = роль, $3 = дата или "-" для пустой памяти
  mkdir -p "$1/$2"
  if [ "$3" = "-" ]; then
    printf 'last_updated: null\nПамять не заводилась.\n' > "$1/$2/context.md"
  else
    printf 'last_updated: "%s"\nЗапись роли.\n' "$3" > "$1/$2/context.md"
  fi
}

days_ago() {
  if [ "$(uname)" = "Darwin" ]; then date -v-"$1"d +%Y-%m-%d; else date -d "$1 days ago" +%Y-%m-%d; fi
}

run_hook() {  # $1 = каталог ролей (пусто = не задан)
  local roles=${1:-}
  ROLES_DIR="$roles" bash "$HOOK" 2>/dev/null
}

check() {  # $1 = случай, $2 = ожидание, $3 = факт
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then
    printf 'PASS  %-42s ожидание %s\n' "$1" "$2"
  else
    printf 'FAIL  %-42s ожидание %s, получено %s\n' "$1" "$2" "$3"
    failed=$((failed + 1))
  fi
}

says() {  # $1 = вывод, $2 = искомое → «да»/«нет»
  case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac
}

# 1. Контракт фреймворка печатается всегда — прибор не должен его вытеснить.
R=$(make_roles); add_role "$R" dev "$(days_ago 0)"
OUT=$(run_hook "$R")
check "контракт сессии на месте" "да" "$(says "$OUT" "Core Team Framework активен")"

# 2. Конституционный гейт назван в контракте. Правило, живущее только в CLAUDE.md,
#    доезжает не всегда: хук — единственное место с подтверждённой частотой исполнения.
R=$(make_roles); add_role "$R" dev "$(days_ago 0)"
OUT=$(run_hook "$R")
check "гейт Guard → Prove в контракте" "да" "$(says "$OUT" "Guard → Prove")"

# 3. МИР С ДЕФЕКТОМ: память роли старше порога — прибор обязан её назвать.
R=$(make_roles); add_role "$R" keeper "$(days_ago 30)"
OUT=$(run_hook "$R")
check "отставшая роль названа" "да" "$(says "$OUT" "keeper")"

# 4. МИР С ДЕФЕКТОМ: памяти нет вовсе — отдельный диагноз, не «отстаёт».
R=$(make_roles); add_role "$R" guardian -
OUT=$(run_hook "$R")
check "пустая память названа" "да" "$(says "$OUT" "Памяти нет вовсе: guardian")"

# 5. Ложное срабатывание: свежая память молчит. Прибор-паникёр не читают.
R=$(make_roles); add_role "$R" dev "$(days_ago 1)"; add_role "$R" test "$(days_ago 0)"
OUT=$(run_hook "$R")
check "свежая память молчит" "нет" "$(says "$OUT" "Здоровье памяти ролей")"

# 6. Разделение диагнозов: отставшая и пустая роли не сливаются в один список.
R=$(make_roles); add_role "$R" keeper "$(days_ago 30)"; add_role "$R" analyst -
OUT=$(run_hook "$R")
check "два диагноза различены" "да" \
  "$(if [ "$(says "$OUT" "Отстаёт от работы: keeper")" = да ] && [ "$(says "$OUT" "Памяти нет вовсе: analyst")" = да ]; then printf 'да'; else printf 'нет'; fi)"

# 7. Безвредность: каталога ролей нет (проект ещё не развёрнут) — хук не падает
#    и не печатает диагноз. Сломанный SessionStart дороже любой находки.
OUT=$(run_hook "/nonexistent-$$"); code=$?
check "нет project/roles — тихо и без падения" "0/нет" "$code/$(says "$OUT" "Здоровье памяти ролей")"

# --- Лестница смыслов -------------------------------------------------------

make_ledger() {  # $1 = содержимое секции «Зачем» («-» = секции нет)
  local dir file
  dir=$(mktemp -d); TRASH+=("$dir"); mkdir -p "$dir/project"
  file="$dir/project/ledger.md"
  printf '# Ledger\n' > "$file"
  [ "$1" = "-" ] || printf '%s\n' "$1" >> "$file"
  printf '%s' "$file"
}

run_with_ledger() { LEDGER_FILE="$1" ROLES_DIR="/nonexistent-$$" bash "$HOOK" 2>/dev/null; }

FULL='## Зачем
- **Миссия:** понятный разбор анализов
- **Цель фазы:** довести пилот до 10 активированных
- **Ближайший шаг:** починить вёрстку карточек'

L=$(make_ledger "$FULL")
OUT=$(run_with_ledger "$L")
check "лестница напечатана" "да" "$(says "$OUT" "Цель фазы: довести пилот")"

L=$(make_ledger "-")
OUT=$(run_with_ledger "$L")
check "секции нет — просит завести" "да" "$(says "$OUT" "не записано")"

# Гард против хроники: измеренная болезнь — поле смысла вытесняется лентой событий.
LONG="## Зачем
- **Миссия:** коротко
- **Цель фазы:** $(printf 'событие %.0s' $(seq 1 40))
- **Ближайший шаг:** шаг"
L=$(make_ledger "$LONG")
OUT=$(run_with_ledger "$L")
check "поле-хроника названо" "да" "$(says "$OUT" "превратилось в хронику")"

L=$(make_ledger "$FULL")
OUT=$(run_with_ledger "$L")
check "короткие поля хроникой не считаются" "нет" "$(says "$OUT" "превратилось в хронику")"

# Ledger нет вовсе (проект ещё не развёрнут): хук молчит и не падает.
OUT=$(run_with_ledger "/nonexistent-$$/ledger.md"); code=$?
check "ledger отсутствует — тихо и без падения" "0/нет" "$code/$(says "$OUT" "Зачем мы здесь")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s — тест проверил не всё, что обязан\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi

printf '\nхук: %s\nслучаев: %s, провалено: %s\n' "$HOOK" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
