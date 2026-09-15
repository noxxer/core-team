#!/bin/bash
# Миграция на 5.4.2: амнистия унаследованного. Одна дата на проект — `gates_enforced_since`
# в шапке ledger: записи старше неё приборы тира «стоп» перечисляют, не роняя прогон.
# Ставится датой ПЕРВОГО обновления и назад не сдвигается. Реестру дрейфа — граница по
# номеру `enforced_since_id`, если её нет: строки до неё унаследованы (механизм 5.2).
set -uo pipefail
cd "${ROOT}" || exit 1
today=$(date +%F)
L=project/ledger.md
if [ -f "${L}" ]; then
  if awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "${L}" | grep -qE '^gates_enforced_since:[[:space:]]*"?[0-9]{4}'; then
    mig_already "gates_enforced_since в шапке ledger есть"
  elif [ "$(head -1 "${L}")" = "---" ]; then
    if [ "${APPLY}" = 1 ]; then
      tmp=$(mktemp)
      awk -v line="gates_enforced_since: \"${today}\"   # дата первого обновления: старше — унаследованное, не роняет прогон" \
        'NR==1 {print; next} !done && /^---[[:space:]]*$/ {print line; done=1} {print}' "${L}" > "${tmp}" && cat "${tmp}" > "${L}"; rm -f "${tmp}"
      mig_done "в шапку ledger добавлено gates_enforced_since: ${today} — записи старше перечисляются как унаследованные"
    else
      mig_will "добавить в шапку ledger gates_enforced_since: ${today}"
    fi
  else
    mig_manual "у ledger нет шапки — добавьте поле gates_enforced_since: \"${today}\" сами"
  fi
fi
R=project/artifacts/drift-registry.md
if [ -f "${R}" ]; then
  if awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "${R}" | grep -qE '^enforced_since_id:'; then
    mig_already "у реестра дрейфа есть граница enforced_since_id"
  else
    maxid=$(grep -oE 'DR-[0-9]+' "${R}" | sed 's/DR-0*//' | sort -n | tail -1)
    next=$(( ${maxid:-0} + 1 ))
    if [ "${APPLY}" = 1 ] && [ "$(head -1 "${R}")" = "---" ]; then
      tmp=$(mktemp)
      awk -v line="enforced_since_id: ${next}   # записи до этой — унаследованные: заведены до правила об адресе проверки" \
        'NR==1 {print; next} !done && /^---[[:space:]]*$/ {print line; done=1} {print}' "${R}" > "${tmp}" && cat "${tmp}" > "${R}"; rm -f "${tmp}"
      mig_done "реестру дрейфа поставлена граница enforced_since_id: ${next} — ${maxid:-0} записей унаследованы"
    else
      mig_will "поставить реестру дрейфа границу enforced_since_id: ${next} (${maxid:-0} записей станут унаследованными)"
    fi
  fi
fi
exit 0
