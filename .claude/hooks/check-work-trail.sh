#!/bin/bash
# След работы: у построенного есть записанный замысел и запись сессии.
#
# ТИР: счёт — пропущенная запись не ломает следующую сессию, но копится
#
# Все гейты стоят на артефактах и потому слепы к отсутствию: файла нет — проверять
# нечего. Замер боевого прогона: пройден путь от идеи до снимков, написан код,
# сняты снимки — и ни одной записи в лентах работы, ни одной записи сессии.
# Прогон вёл тот, кто знает систему; короткий путь ничем не отмечен, и его
# выбирают именно потому, что он всегда доступен.
#
# Один предмет — «работа оставила след», два отказа:
#   1. код есть, а замысла нет: пусты `features/`, `ideas/`, `deliveries/`;
#   2. работа шла (есть код или решения), а `sessions/` пуст.
#
# Что НЕ проверяется намеренно: проект без кода — исследование, документация,
# аналитика; там прибор молчит, потому что мерить нечего.
#
# ЗАПУСК: bash .claude/hooks/check-work-trail.sh [корень проекта]
#   exit 0 — след есть либо мерить нечего
#   exit 1 — построено без записанного замысла или без записи сессии
#
# Доказательство мутацией: .claude/hooks/check-work-trail.test.sh

set -uo pipefail

ROOT=${1:-.}
PROJECT="${ROOT}/project"

[ -d "${PROJECT}" ] || { printf 'каталога project нет — проект ещё не заведён\n'; exit 0; }

# Код — файлы известных расширений вне служебных каталогов. Каталог снимков и
# зависимостей исключены: там чужое и производное.
count_code() {
  find "${ROOT}" -type f \
    \( -name '*.py' -o -name '*.js' -o -name '*.mjs' -o -name '*.ts' -o -name '*.tsx' \
       -o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java' -o -name '*.rb' \
       -o -name '*.php' -o -name '*.vue' -o -name '*.svelte' \) \
    -not -path '*/.claude/*' -not -path '*/project/*' -not -path '*/node_modules/*' \
    -not -path '*/.git/*' -not -path '*/deck/output/*' -not -path '*/.trial/*' \
    2>/dev/null | wc -l | tr -d ' '
}

count_files_in() {  # $1 = каталог → число файлов, 0 если каталога нет
  [ -d "$1" ] || { printf '0'; return 0; }
  find "$1" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' '
}

code=$(count_code)
ideas=$(count_files_in "${PROJECT}/ideas")
deliveries=$(count_files_in "${PROJECT}/deliveries")
features=$(count_files_in "${PROJECT}/features")
sessions=$(count_files_in "${PROJECT}/sessions")
decisions=$(count_files_in "${PROJECT}/decisions")
plan=$((ideas + deliveries + features))

# Проект без кода прибор не трогает: исследованию, документации и аналитике
# мерить этим нечем, и молчание здесь — не пропуск, а граница применимости.
if [ "${code}" -eq 0 ]; then
  printf 'файлов кода нет — след работы этим прибором не измеряется\n'
  exit 0
fi

failures=0

if [ "${plan}" -eq 0 ]; then
  printf 'КРАСНОЕ: файлов кода %s, а замысел не записан — пусты ideas/, deliveries/, features/.\n' "${code}" >&2
  printf '  Построено без записанного «зачем»: через месяц причину будет негде прочитать.\n' >&2
  printf '  Закрывается одной записью: `/plan-feat` заводит идею и её исход.\n' >&2
  failures=$((failures + 1))
fi

if [ "${sessions}" -eq 0 ] && { [ "${code}" -gt 0 ] || [ "${decisions}" -gt 0 ]; }; then
  printf 'КРАСНОЕ: работа шла (кода %s, решений %s), а записей сессий нет.\n' "${code}" "${decisions}" >&2
  printf '  Летопись пишется в конце сессии: без неё следующая начинается с нуля.\n' >&2
  failures=$((failures + 1))
fi

printf 'След работы: кода %s, замысел %s, сессий %s, решений %s.\n' \
  "${code}" "${plan}" "${sessions}" "${decisions}"
[ "${failures}" -eq 0 ] || { printf '\nпропусков следа: %s\n' "${failures}" >&2; exit 1; }
exit 0
