#!/bin/bash
# Миграция на 5.2.0: четыре артефакта больше не возятся (scorecard, assumptions,
# experiment-board, tech-radar) — их содержимое живёт в полях решений. Файлы потребителя
# не трогаются: разнести по решениям может только человек.
set -uo pipefail
cd "${ROOT}" || exit 1
found=""
for a in scorecard.md assumptions.md experiment-board.md tech-radar.md; do
  [ -f "project/artifacts/${a}" ] && found="${found} project/artifacts/${a}"
done
if [ -n "${found}" ]; then
  mig_manual "артефакты без шаблона в поставке:${found} — разнести живое по решениям (kill_criteria, metric_for_revisit, review_due), остальное в artifacts/archive/; прогон: bash .claude/hooks/check-decision-decay.sh"
else
  mig_already "снятых с поставки артефактов в project/artifacts нет"
fi
exit 0
