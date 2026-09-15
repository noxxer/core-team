#!/bin/bash
# Бюджет поставки: фреймворк меряет собственный вес теми же потолками, что накладывает на потребителя.
#
# ТИР: копия — предмет прибора сама поставка, а не проект
#
# ЗАМЕР, ИЗ КОТОРОГО ВЫРОС ПРИБОР (аудит по этапам жизни, 2026-09-14). У фреймворка семь
# потолков для артефактов потребителя — ledger 300 строк, память роли 200 строк и 256 КБ,
# `artifacts/` 40 файлов, счёт находок 20, отгрузка 20 коммитов / 14 дней, очередь требований
# 5 — и ни одного для себя. Итог за двенадцать тегов: `CLAUDE.md` 30 → 152 КБ, слов
# «ОБЯЗАТЕЛЬНО» в `/end-session` 2 → 17, приборов 0 → 25, `UPGRADING.md` 0 → 66 КБ, и ни
# один релиз не уменьшил ни один из этих артефактов. Читает это потребитель: `CLAUDE.md`
# читается каждой ролью в каждой сессии. Правило «внимание конечно» было применено к находкам
# проекта и не применено к самому фреймворку — эта ирония уже записана в `CLAUDE.md` про
# реестры, и здесь она закрывается уровнем выше.
#
# ЧТО МЕРИТСЯ — четыре числа, потолки объявлены в шапке `knowledge/delivery-budget.md`:
#   session_bytes         байты, которые роль читает в каждой сессии независимо от проекта:
#                         `CLAUDE.md` + `output-styles/*.md` + `hooks/session-start.sh`;
#   mandatory_steps       слов «ОБЯЗАТЕЛЬНО» в `commands/end-session.md` — каждое требует внимания;
#   stop_gates            приборов тира «стоп» — каждый умеет остановить сессию;
#   claude_measurements   слов «Замер» в `CLAUDE.md` — история прибора живёт в каталоге, а не в контракте.
#
# КРАСНЫЙ даёт автору тот же выбор из трёх, что фреймворк даёт потребителю на реестре:
# убрать · объявить «не чиним» с причиной · поднять потолок в шапке с причиной. Потолок
# растёт только осознанно — в этом и смысл. Половина «найдено не ноль»: файла потолков нет
# или потолок не объявлен — отказ, а не «мерить нечего».
#
# ЗАПУСК: bash .claude/hooks/check-delivery-budget.sh [корень копии]
#   exit 0 — поставка в бюджете
#   exit 1 — хоть одна мера выше потолка, либо потолки не объявлены
#
# Доказательство мутацией: .claude/hooks/check-delivery-budget.test.sh

set -uo pipefail

ROOT=${1:-.}
CLAUDE_DIR="${ROOT}/.claude"
BUDGET=${DELIVERY_BUDGET_FILE:-${CLAUDE_DIR}/knowledge/delivery-budget.md}

[ -d "${CLAUDE_DIR}" ] || { printf 'ОШИБКА: нет %s — это не копия фреймворка.\n' "${CLAUDE_DIR}" >&2; exit 1; }
[ -f "${BUDGET}" ] || {
  printf 'ОШИБКА: потолки поставки не объявлены — нет %s.\n' "${BUDGET}" >&2
  printf 'Половина «найдено не ноль»: поставка без бюджета не «в норме», а не измерена.\n' >&2
  exit 1
}

ceiling_of() {  # $1 = имя поля шапки → число или пусто
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "${BUDGET}" \
    | grep -m1 -E "^$1:" | sed -E "s/^$1:[[:space:]]*//; s/[[:space:]]+#.*$//; s/\"//g" | tr -cd '0-9'
}

bytes_of() { local total=0 f; for f in "$@"; do [ -f "${f}" ] && total=$((total + $(wc -c < "${f}" | tr -d ' '))); done; printf '%s' "${total}"; }

# --- Меры -----------------------------------------------------------------------
session_bytes=$(bytes_of "${CLAUDE_DIR}/CLAUDE.md" "${CLAUDE_DIR}"/output-styles/*.md "${CLAUDE_DIR}/hooks/session-start.sh")
mandatory_steps=$(grep -c 'ОБЯЗАТЕЛЬНО' "${CLAUDE_DIR}/commands/end-session.md" 2>/dev/null || printf '0')
stop_gates=0
for tool in "${CLAUDE_DIR}"/hooks/*.sh; do
  case "$(basename "${tool}")" in *.test.sh|lib-*.sh) continue ;; esac
  grep -qE '^# ТИР:[[:space:]]*стоп' "${tool}" 2>/dev/null && stop_gates=$((stop_gates + 1))
done
claude_measurements=$(grep -o 'Замер' "${CLAUDE_DIR}/CLAUDE.md" 2>/dev/null | wc -l | tr -d ' ')

# --- Сверка -----------------------------------------------------------------------
failed=0; declared=0
report() {  # $1 = мера, $2 = значение, $3 = единица
  local ceiling; ceiling=$(ceiling_of "$1")
  if [ -z "${ceiling}" ]; then
    printf 'ПОТОЛОК НЕ ОБЪЯВЛЕН: %s (сейчас %s %s) — допиши в шапку %s.\n' "$1" "$2" "$3" "${BUDGET}" >&2
    failed=1; return
  fi
  declared=$((declared + 1))
  if [ "$2" -gt "${ceiling}" ]; then
    printf 'ВЫШЕ ПОТОЛКА: %s = %s %s при потолке %s.\n' "$1" "$2" "$3" "${ceiling}" >&2
    failed=1
  else
    printf '  %-22s %8s / %-8s %s\n' "$1" "$2" "${ceiling}" "$3"
  fi
}

printf 'Бюджет поставки (%s):\n' "${BUDGET}"
report session_bytes "${session_bytes}" "байт в каждой сессии"
report mandatory_steps "${mandatory_steps}" "«ОБЯЗАТЕЛЬНО» в /end-session"
report stop_gates "${stop_gates}" "приборов тира «стоп»"
report claude_measurements "${claude_measurements}" "«Замер» в CLAUDE.md"

if [ "${declared}" -eq 0 ]; then
  printf 'ОШИБКА: в %s не объявлен ни один потолок — сверять нечего.\n' "${BUDGET}" >&2
  exit 1
fi

if [ "${failed}" -ne 0 ]; then
  printf '\nПоставка выросла за объявленный потолок. Одно из трёх, явно:\n' >&2
  printf '  1) убрать — вынести историю в `knowledge/hooks-catalog.md`, шаг — в сводку, прибор — в счёт;\n' >&2
  printf '  2) объявить «не чиним» с причиной в CHANGELOG;\n' >&2
  printf '  3) поднять потолок в шапке %s — с причиной рядом с числом.\n' "${BUDGET}" >&2
  printf 'Замер: CLAUDE.md 30 → 152 КБ за двенадцать тегов без единого уменьшения; потребитель читал это каждую сессию.\n' >&2
  exit 1
fi
printf 'Поставка в бюджете.\n'
exit 0
