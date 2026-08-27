#!/bin/bash
# Сверка версии: один источник правды против всех мест, где версия объявлена.
#
# ТИР: копия — про объявления версии, а не про проект
#
# Замер, из которого выросла проверка: `.claude-plugin/plugin.json` объявлял
# 4.5.0, когда `VERSION` уже был 5.0.0 — два релиза расхождения, никто не
# заметил. Плюс сам `VERSION` лежал в корне и не доезжал до потребителя,
# который копирует только `.claude/`, хотя `CLAUDE.md` обещал его наличие.
#
# ЗАПУСК: bash .claude/hooks/check-version-sync.sh [корень репозитория]
#   exit 0 — все объявления совпали с .claude/VERSION (или это копия потребителя)
#   exit 1 — расхождение, либо проверять оказалось нечего
#
# Доказательство мутацией: .claude/hooks/check-version-sync.test.sh

set -uo pipefail

ROOT=${1:-.}
SOURCE="${ROOT}/.claude/VERSION"
PLUGIN="${ROOT}/.claude-plugin/plugin.json"

# Копия потребителя не содержит манифеста плагина, а её README — не наш.
# Проверять там нечего, и это законная тишина, а не пропуск по недосмотру.
if [ ! -f "${PLUGIN}" ]; then
  printf 'манифест плагина не найден (%s) — это не репозиторий фреймворка, сверка версий не применима\n' "${PLUGIN}"
  exit 0
fi

if [ ! -f "${SOURCE}" ]; then
  printf 'ОШИБКА: нет источника версии %s.\n' "${SOURCE}" >&2
  printf 'CLAUDE.md обещает версию именно там, и потребитель копирует только .claude/.\n' >&2
  exit 1
fi

version=$(tr -d '[:space:]' < "${SOURCE}")
if [ -z "${version}" ]; then
  printf 'ОШИБКА: %s пуст.\n' "${SOURCE}" >&2
  exit 1
fi

claims=0
mismatch=()

claim() {  # $1 = что за место, $2 = найденное значение (пусто = места нет)
  [ -n "${2:-}" ] || return 0
  claims=$((claims + 1))
  [ "$2" = "${version}" ] || mismatch+=("$1: ${2}")
}

plugin_version=$(grep -m1 '"version"' "${PLUGIN}" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
claim "${PLUGIN}" "${plugin_version}"

for readme in "${ROOT}/README.md" "${ROOT}/README.en.md"; do
  [ -f "${readme}" ] || continue
  badge=$(grep -m1 -oE 'badge/version-[0-9]+\.[0-9]+\.[0-9]+' "${readme}" | sed 's|badge/version-||')
  claim "${readme}" "${badge}"
done

# Половина «найдено не ноль»: манифест на месте, а объявлений версии не нашлось —
# значит, разбор сломался (переименовали файл, сменили формат бейджа).
# Молчаливый ноль читается как «всё сходится» и опаснее найденного расхождения.
if [ "${claims}" -eq 0 ]; then
  printf 'ОШИБКА: это репозиторий фреймворка, но ни одного объявления версии не разобрано.\n' >&2
  printf 'Проверка не может подтвердить согласованность — считаем это отказом, а не успехом.\n' >&2
  exit 1
fi

printf 'Версия %s (%s). Объявлений сверено: %s. Расхождений: %s.\n' \
  "${version}" "${SOURCE}" "${claims}" "${#mismatch[@]}"

if [ "${#mismatch[@]}" -gt 0 ]; then
  printf '\nРАСХОЖДЕНИЕ С ИСТОЧНИКОМ (%s):\n' "${#mismatch[@]}" >&2
  printf '  %s\n' "${mismatch[@]}" >&2
  printf 'Источник правды — %s. Правь объявления по нему, а не наоборот.\n' "${SOURCE}" >&2
  exit 1
fi
exit 0
