#!/bin/bash
# Миграция на 5.3.0: ремесло уехало в плагин core-team-dev; таблица подключений обязательна.
set -uo pipefail
cd "${ROOT}" || exit 1

# 1. Команды и навыки, переехавшие в плагин: остатки в копии — версия ремесла, которую
#    перестали развивать. Удаляются только если у поставки их нет (иначе это не остаток).
left=""
for p in commands/plan-feat.md commands/plan.md commands/plan-do.md commands/plan-reflect.md \
         skills/planner skills/planner-reflect skills/tdd-master skills/functional-clarity knowledge/stacks; do
  [ -e ".claude/${p}" ] && [ ! -e "${SRC}/.claude/${p}" ] && left="${left} ${p}"
done
if [ -n "${left}" ]; then
  if [ "${APPLY}" = 1 ]; then
    for p in ${left}; do rm -rf ".claude/${p}"; done
    mig_done "убраны остатки ремесла, уехавшего в плагин:${left}"
  else
    mig_will "убрать остатки ремесла, уехавшего в плагин:${left}"
  fi
  uses=$(grep -rlE 'plan-feat|/plan-do|tdd-master|planner' project/sessions 2>/dev/null | wc -l | tr -d ' ')
  [ "${uses:-0}" -gt 0 ] && mig_manual "конвейер фич упоминается в ${uses} записях сессий — поставьте плагин: claude plugin install core-team-dev@core-team --scope project"
else
  mig_already "остатков ремесла, уехавшего в плагин, нет"
fi

# 2. Таблица подключений — единственный артефакт 5.3, который обязан существовать:
#    без неё роли считают инструменты установленными.
if [ -d project ]; then
  if [ -f project/connection-points.md ]; then
    mig_already "project/connection-points.md есть"
  elif [ -f "${SRC}/.claude/templates/project/connection-points.md" ]; then
    if [ "${APPLY}" = 1 ]; then
      cat "${SRC}/.claude/templates/project/connection-points.md" > project/connection-points.md
      mig_created "project/connection-points.md"
      mig_done "заведена project/connection-points.md из шаблона — заполните, чем закрыт каждый слой (проверка: bash .claude/hooks/check-connection-points.sh)"
    else
      mig_will "завести project/connection-points.md из шаблона"
    fi
  fi
fi
exit 0
