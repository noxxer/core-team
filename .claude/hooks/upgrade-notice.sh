#!/bin/bash
# Уведомление об обновлении: копия знает, что поставка ушла вперёд.
#
# ТИР: показ — печатает одну строку, ничего не требует и не блокирует
#
# ЗАМЕР, ИЗ КОТОРОГО ВЫРОС ПРИБОР (аудит по этапам жизни, 2026-09-14): из 17 установок
# фреймворка на одной машине 11 стояли на версиях не выше 5.0, среди них три самых
# нагруженных проекта (105, 99 и 55 сессий), у одного — коммит в день аудита. Ни одна
# копия не была на текущей версии. Копия не знала, что есть версия новее: единственный
# способ узнать — открыть репозиторий фреймворка руками. Уведомление при старте сессии —
# единственное событие с подтверждённой частотой срабатывания, поэтому прибор живёт там.
#
# ЧТО ДЕЛАЕТ. Раз в сутки (UPGRADE_CHECK_TTL) спрашивает у публичного репозитория список
# тегов (`git ls-remote`, без авторизации), берёт старшую СТАБИЛЬНУЮ версию и сравнивает с
# `.claude/VERSION`. Поставка новее — печатает одну строку с обеими версиями и указателем
# на `/upgrade`. Иначе молчит.
#
# ГРАНИЦЫ, НАЗВАННЫЕ ВСЛУХ:
#   · наружу не уходит ничего о проекте — только запрос списка тегов публичного репозитория;
#   · сеть недоступна, вышло время (UPGRADE_CHECK_TIMEOUT, умолчание 2 с) или нет `git` —
#     прибор молчит и завершается успехом: SessionStart работает около секунды, и делать
#     его зависимым от GitHub нельзя;
#   · ответ кэшируется вне репозитория (каталог временных файлов), чтобы не трогать
#     `.gitignore` потребителя; свежий кэш читается без обращения в сеть;
#   · предрелизные теги (`v6.0.0-alpha.1`) не считаются доступной версией: незрелость
#     объявляется, но не предлагается; копия на предрелизе считается впереди своей базы;
#   · отключается ключом `"upgrade": {"check": false}` в `.claude/settings.json` — для
#     тех, кто обновляется своим порядком;
#   · копия без `VERSION` (старше 5.1) получает уведомление всегда, с пометкой о возрасте.
#
# ЗАПУСК: bash .claude/hooks/upgrade-notice.sh [корень копии]
#   exit 0 всегда — прибор безвреден по построению
#
# Доказательство мутацией: .claude/hooks/upgrade-notice.test.sh

set -uo pipefail

ROOT=${1:-.}
VERSION_FILE=${VERSION_FILE:-${ROOT}/.claude/VERSION}
SETTINGS=${SETTINGS_FILE:-${ROOT}/.claude/settings.json}
REMOTE=${UPGRADE_SOURCE:-https://github.com/noxxer/core-team.git}
TTL=${UPGRADE_CHECK_TTL:-86400}
TIMEOUT=${UPGRADE_CHECK_TIMEOUT:-2}

# Кэш — вне репозитория: файл внутри `.claude/` потребовал бы строки в чужом `.gitignore`.
cache_default() {
  local key
  key=$(cd "${ROOT}" 2>/dev/null && pwd -P | cksum | cut -d' ' -f1)
  printf '%s/core-team-upgrade-%s' "${TMPDIR:-/tmp}" "${key:-0}"
}
CACHE=${UPGRADE_CACHE:-$(cache_default)}

# --- Отключено настройкой? -----------------------------------------------------
# Читается без jq: нужен один ключ внутри одного объекта.
check_disabled() {
  [ -f "${SETTINGS}" ] || return 1
  awk '/"upgrade"[[:space:]]*:/{f=1} f{print} f&&/}/{exit}' "${SETTINGS}" 2>/dev/null \
    | grep -qE '"check"[[:space:]]*:[[:space:]]*false'
}
check_disabled && exit 0

# --- Версии -------------------------------------------------------------------
strip_pre() { printf '%s' "$1" | sed -E 's/[-+].*$//'; }   # 6.0.0-alpha.1 → 6.0.0

# 0 — первая версия строго новее второй. Сравнение по трём числам, не `sort -V`
# (его нет на macOS).
newer() {
  awk -v a="$(strip_pre "$1")" -v b="$(strip_pre "$2")" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= 3; i++) { xi = (i <= n) ? x[i] + 0 : 0; yi = (i <= m) ? y[i] + 0 : 0
      if (xi > yi) exit 0; if (xi < yi) exit 1 }
    exit 1 }'
}

max_stable() {  # stdin: версии по одной в строке → старшая стабильная
  grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | awk -F. '{ printf "%09d%09d%09d %s\n", $1, $2, $3, $0 }' \
    | sort | tail -1 | cut -d' ' -f2
}

local_version=""
[ -f "${VERSION_FILE}" ] && local_version=$(tr -d '[:space:]' < "${VERSION_FILE}")

# --- Кэш ----------------------------------------------------------------------
now=$(date +%s 2>/dev/null) || exit 0
latest=""
if [ -f "${CACHE}" ]; then
  checked=$(sed -n 's/^checked=//p' "${CACHE}" | head -1)
  cached=$(sed -n 's/^latest=//p' "${CACHE}" | head -1)
  case "${checked}" in ''|*[!0-9]*) checked=0 ;; esac
  [ $((now - checked)) -lt "${TTL}" ] && [ -n "${cached}" ] && latest=${cached}
fi

# --- Сеть, под присмотром таймаута ---------------------------------------------
# `timeout` — GNU coreutils, на macOS его нет; сторож пишется руками.
fetch_latest() {
  local out pid waited=0 limit
  command -v git >/dev/null 2>&1 || return 1
  out=$(mktemp) || return 1
  ( git ls-remote --tags --refs "${REMOTE}" > "${out}" 2>/dev/null ) &
  pid=$!
  limit=$((TIMEOUT * 10))
  while kill -0 "${pid}" 2>/dev/null && [ "${waited}" -lt "${limit}" ]; do
    sleep 0.1; waited=$((waited + 1))
  done
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null; wait "${pid}" 2>/dev/null
    rm -f "${out}"; return 1
  fi
  wait "${pid}" || { rm -f "${out}"; return 1; }
  sed -n 's|.*refs/tags/v||p' "${out}" | max_stable
  rm -f "${out}"
}

if [ -z "${latest}" ]; then
  latest=$(fetch_latest) || exit 0
  [ -n "${latest}" ] || exit 0
  printf 'checked=%s\nlatest=%s\n' "${now}" "${latest}" > "${CACHE}" 2>/dev/null || true
fi

# --- Вывод ---------------------------------------------------------------------
if [ -z "${local_version}" ]; then
  printf '\n**Обновление Core Team.** У копии нет файла `.claude/VERSION` — она старше 5.1, доступна %s. ' "${latest}"
  printf '`/upgrade` сначала покажет, что изменится, и ничего не тронет без подтверждения.\n'
  exit 0
fi

newer "${latest}" "${local_version}" || exit 0
printf '\n**Обновление Core Team.** Установлена %s, доступна %s. ' "${local_version}" "${latest}"
printf '`/upgrade` сначала покажет, что изменится, и ничего не тронет без подтверждения.\n'
exit 0
