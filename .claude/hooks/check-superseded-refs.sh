#!/bin/bash
# Артефакт не пересказывает вытесненное решение. Класс дрейфа C: «артефакт ↔ решение».
#
# ТИР: счёт — пересказ отстал; правится вместе с артефактом
#
# Замер (боевой проект, 2026-08-27): `DEC-044` имеет статус `superseded` — и
# **упоминается в 11 артефактах**. Одиннадцать документов строят рассуждение на
# мёртвом правиле. В том же проекте это уже стоило дорого: «два формально живых
# противоречащих решения, промпт полгода на старом правиле».
#
# ПОЧЕМУ БЕЗ ОТПЕЧАТКА. Отпечаток обязательства нужен там, где узел ПРАВЯТ.
# Решения не правят — `decisions/**` append-only, они **вытесняются**. Значит
# статус решения даёт то же, что дал бы хеш, и ловится это без единого хеша.
#
# Один предмет — «пересказ не отстал от решения». Один отказ:
#   ПЕРЕСКАЗ МЁРТВОГО РЕШЕНИЯ — артефакт называет вытесненное решение и не говорит,
#   что оно вытеснено.
#
# ЧТО ЗАКОННО, а потому находкой не считается:
#   · хроника (`project/sessions/`) — она про то, что было правдой тогда;
#   · сами решения (`project/decisions/`) — там `superseded_by` и есть ответ;
#   · строка, называющая заменителя рядом: «DEC-044 вытеснено DEC-147»;
#   · строка со словом «вытеснено», «устарело», «отменено» — признание без замены.
#
# ЗАПУСК: bash .claude/hooks/check-superseded-refs.sh [каталог-проекта]
#   exit 0 — живых пересказов мёртвых решений нет (или решений нет)
#   exit 1 — есть пересказ, либо разобрать каталог решений не удалось
#
# Доказательство мутацией: .claude/hooks/check-superseded-refs.test.sh

set -uo pipefail

PROJECT=${1:-${PROJECT_DIR:-project}}
DECISIONS_DIR=${DECISIONS_DIR:-${PROJECT}/decisions}

[ -d "${DECISIONS_DIR}" ] || { printf 'каталога решений нет (%s) — проверять нечего\n' "${DECISIONS_DIR}"; exit 0; }

header() { awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1"; }

# Собираем вытесненные решения и их заменителей. Статус читаем ТОЛЬКО из шапки:
# слово `superseded` в теле — это рассказ о чужом решении, а не статус своего.
dead_ids=()
declare -a replacements=()
examined=0
for file in "${DECISIONS_DIR}"/*.md; do
  [ -f "${file}" ] || continue
  examined=$((examined + 1))
  status=$(header "${file}" | grep -m1 -E '^status:' | tr -d '"'"'" | sed -E 's/^status:[[:space:]]*//; s/[[:space:]]*$//')
  case "${status}" in superseded|deprecated) ;; *) continue ;; esac
  id=$(header "${file}" | grep -m1 -E '^decision_id:' | tr -d '"'"'" | sed -E 's/^decision_id:[[:space:]]*//' \
       | grep -oE 'DEC-[0-9]+' | head -1)
  [ -n "${id}" ] || id=$(basename "${file}" | grep -oE '^DEC-[0-9]+' | head -1)
  [ -n "${id}" ] || continue
  by=$(header "${file}" | grep -m1 -E '^superseded_by:' | grep -oE 'DEC-[0-9]+' | head -1)
  dead_ids+=("${id}")
  replacements+=("${by}")
done

# Половина «найдено не ноль» стоит на РАЗБОРЕ: ноль решений у только что
# развёрнутого проекта законен — пересказывать просто нечего.
if [ "${examined}" -eq 0 ]; then
  printf 'Решений ноль — пересказывать нечего.\n'
  exit 0
fi

printf 'Пересказы решений %s: решений %s, вытесненных %s.\n' "${PROJECT}" "${examined}" "${#dead_ids[@]}"

if [ "${#dead_ids[@]}" -eq 0 ]; then
  printf 'Вытесненных решений нет — пересказывать нечего.\n'
  exit 0
fi

findings=()
for i in "${!dead_ids[@]}"; do
  id="${dead_ids[$i]}"
  by="${replacements[$i]}"
  while IFS= read -r hit; do
    [ -n "${hit}" ] || continue
    path=${hit%%:*}
    rest=${hit#*:}
    line=${rest#*:}
    # Признание вытеснения на той же строке делает пересказ законным.
    if printf '%s' "${line}" | grep -qiE 'вытеснен|устарел|отменен|отменён|superseded|deprecated'; then continue; fi
    if [ -n "${by}" ] && printf '%s' "${line}" | grep -q "${by}"; then continue; fi
    findings+=("${path#"${PROJECT}"/} → ${id}")
  # Граница справа обязательна: без неё `DEC-04` совпадает с `DEC-044`, и
  # действующее решение объявляется мёртвым. Поймано собственным набором.
  done < <(grep -rnE --include='*.md' "${id}([^0-9]|$)" "${PROJECT}" 2>/dev/null \
           | grep -v "^${DECISIONS_DIR}/" | grep -v "^${PROJECT}/sessions/")
done

if [ "${#findings[@]}" -eq 0 ]; then
  printf 'Живых пересказов нет: каждое упоминание либо в хронике, либо признаёт вытеснение.\n'
  exit 0
fi

# Один файл может пересказывать одно решение много раз — считаем пары «файл→решение».
unique=$(printf '%s\n' "${findings[@]}" | sort -u)
count=$(printf '%s\n' "${unique}" | grep -c . || true)

{
  printf '\nПЕРЕСКАЗ МЁРТВОГО РЕШЕНИЯ (%s):\n' "${count}"
  printf '%s\n' "${unique}" | while IFS= read -r pair; do printf '  %s\n' "${pair}"; done
  printf 'Артефакт называет вытесненное решение и не говорит, что оно вытеснено — роли\n'
  printf 'читают пересказ и рассуждают на отменённом правиле. Замер: одно вытесненное\n'
  printf 'решение упоминалось в 11 артефактах, и промпт полгода стоял на старом правиле.\n'
  printf 'Одно из двух: обновить артефакт под действующее решение, либо назвать вытеснение\n'
  printf 'прямо в строке — «DEC-NNN вытеснено DEC-MMM». Хроника в `sessions/` не считается.\n'
} >&2
exit 1
