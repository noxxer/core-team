#!/bin/bash
# Миграция на 5.1.0: `hooks/hooks.json` Claude Code не читает — хуки живут в settings.json.
# Вызывается upgrade.sh с ROOT, APPLY (0 предпросмотр / 1 применение), SRC (поставка).
set -uo pipefail
cd "${ROOT}" || exit 1
f=.claude/hooks/hooks.json
if [ -f "${f}" ]; then
  if [ "${APPLY}" = 1 ]; then rm -f "${f}"; mig_done "удалён ${f} — Claude Code его не читает, хуки объявлены в settings.json"
  else mig_will "удалить ${f} — Claude Code его не читает"; fi
else
  mig_already "${f} отсутствует"
fi
exit 0
