#!/bin/bash
# Миграция на 5.3.1: точка boundary-contract в таблице подключений; блок памяти в opt-in ролях.
set -uo pipefail
cd "${ROOT}" || exit 1
if [ -f project/connection-points.md ]; then
  if grep -q 'boundary-contract' project/connection-points.md; then
    mig_already "точка boundary-contract в таблице подключений есть"
  else
    mig_manual "допишите строку точки boundary-contract в project/connection-points.md (проекту без кода — «неприменимо» с причиной); проверка: bash .claude/hooks/check-connection-points.sh"
  fi
fi
missing=""
for f in .claude/agents/*.md; do
  [ -f "${f}" ] || continue
  [ -f "${SRC}/${f}" ] && continue          # ядровая роль приезжает сверху
  grep -q 'Для памяти роли' "${f}" || missing="${missing} $(basename "${f}")"
done
if [ -n "${missing}" ]; then
  mig_manual "в своих ролях нет блока «Для памяти роли», хук SubagentStop не отпустит их:${missing} — перенесите блок из .claude/templates/roles/optional/ или из любой ядровой роли"
else
  mig_already "блок «Для памяти роли» есть во всех своих ролях"
fi
exit 0
