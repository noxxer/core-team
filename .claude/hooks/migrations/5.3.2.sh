#!/bin/bash
# Миграция на 5.3.2: запрет Write(project/roles/*/context.md) снят из permissions.deny —
# защиту памяти держит хук memory-gate.sh, а запрет по пути закрывал и заведение памяти.
set -uo pipefail
cd "${ROOT}" || exit 1
s=.claude/settings.json
pat='Write(project/roles/*/context.md)'
if [ -f "${s}" ] && grep -qF "${pat}" "${s}"; then
  if [ "${APPLY}" = 1 ]; then
    if command -v jq >/dev/null 2>&1; then
      tmp=$(mktemp)
      if jq --arg p "${pat}" 'if .permissions.deny then .permissions.deny |= map(select(. != $p)) else . end' "${s}" > "${tmp}" 2>/dev/null && [ -s "${tmp}" ]; then
        cp "${tmp}" "${s}"; rm -f "${tmp}"
        mig_done "из permissions.deny убран ${pat} — стирание памяти теперь отклоняет memory-gate.sh"
      else
        rm -f "${tmp}"; mig_manual "удалите строку \"${pat}\" из permissions.deny в ${s} (jq не разобрал файл)"
      fi
    else
      mig_manual "удалите строку \"${pat}\" из permissions.deny в ${s} (jq не найден)"
    fi
  else
    mig_will "убрать ${pat} из permissions.deny в ${s}"
  fi
else
  mig_already "запрета ${pat} в permissions.deny нет"
fi
exit 0
