#!/bin/bash
# Миграция на 5.3.5: объявленный code_path должен быть доступен инструменту
# (permissions.additionalDirectories). Права машины в git не едут — только вручную.
set -uo pipefail
cd "${ROOT}" || exit 1
[ -f project/ledger.md ] || { mig_already "ledger нет — code_path объявлять некому"; exit 0; }
cp=$(awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' project/ledger.md \
     | grep -m1 -E '^code_path:' | sed -E 's/^code_path:[[:space:]]*//; s/[[:space:]]+#.*$//; s/^"//; s/"[[:space:]]*$//')
case "${cp}" in ''|.|./) mig_already "code_path не объявлен или равен корню"; exit 0 ;; esac
if grep -qsF "${cp}" .claude/settings.json .claude/settings.local.json 2>/dev/null; then
  mig_already "code_path «${cp}» назван в настройках"
else
  mig_manual "code_path «${cp}» не назван в permissions.additionalDirectories — добавьте в .claude/settings.local.json, иначе правки кода пойдут обходом через Bash"
fi
exit 0
