#!/bin/bash
# Обновление копии Core Team: наложение поставки с сохранением своего, миграции, проверка, доклад.
#
# ТИР: копия — предмет прибора развёрнутая копия, а не проект
#
# ЗАМЕР, ИЗ КОТОРОГО ВЫРОС ПРИБОР (аудит по этапам жизни, 2026-09-14). Инструкция
# `UPGRADING.md` дошла до 797 строк и 47 заголовков; версионные шаги копились от релиза к
# релизу, и путь «с 4.5 на 5.3.6» был суммой всех. Итог на одной машине: 11 установок из 17
# не обновлялись ни разу; переход на 5.0 в июне сделан ПЕРЕСОЗДАНИЕМ проектов — каталоги
# `<проект>-v0` датированы днём релиза 5.0.0. Инструкция объясняла, код никто не написал.
#
# ЧТО ДЕЛАЕТ, по шагам, и на каждом можно остановиться:
#   1. Предусловия: копия в git, ветка не main/master, внутри `.claude/` нет незакоммиченного
#      (правки в `project/` обновление не трогает — на них не останавливаемся: замер боевого
#      прогона — 17 незакоммиченных файлов, все в `project/`, терять было нечего).
#   2. Поставка: клон репозитория (или локальный каталог) на старший стабильный тег,
#      либо на `--ref`. Половина «найдено не ноль»: поставка без `.claude/VERSION` — отказ.
#   3. Три колонки: приедет сверху · ваше и останется · ваше и будет перезаписано. Своё
#      определяется списком `upgrade.keep` в `settings.json` ПЛЮС автоматически — файлы ролей,
#      учебники DPF, правила и стили, которых в поставке нет; известный тег прежней версии
#      позволяет отличить вашу правку от чистого файла поставки. Неизвестный файл печатается
#      вопросом, а не перезаписывается и не удаляется молча.
#   4. Наложение (только с `--apply`). `CLAUDE.md` берётся из поставки, раздел «Текущий
#      проект» переносится из вашего. `settings.json` сливается: `hooks` и `env` — сверху,
#      остальное ваше; без `jq` файл не трогается, а блок хуков печатается для ручного слияния.
#      Файлы, убранные из поставки и не тронутые вами, удаляются: наложение само не удаляет,
#      и остатки прежних версий продолжают выглядеть частью инструмента (замер — 32 «своих»
#      пути в боевой копии, половина из них остатки).
#   5. Миграции: `hooks/migrations/<версия>.sh` поставки исполняются по порядку от вашей
#      версии до новой; каждая начинается с «уже сделано» и печатает СДЕЛАНО / БУДЕТ / УЖЕ /
#      ВРУЧНУЮ. Копия без `VERSION` считается 0.0.0 — проходит всё.
#   6. Проверка: целостность новой копии; красное — откат `.claude/` к состоянию до наложения.
#      Затем сводка находок проекта (показ, не отказ).
#   7. Доклад: что изменилось в контракте (записи CHANGELOG за пройденные версии), что
#      закрыто из вашего `framework-feedback.md` (строки `closes: #N` в CHANGELOG), что дальше.
#   8. Коммит остаётся за человеком: скрипт печатает строку сообщения, но не коммитит.
#
# ЗАПУСК: bash .claude/hooks/upgrade.sh [--apply] [--source <url|каталог>] [--ref <тег>] [--root <корень>]
#   без --apply — предпросмотр, файлы не трогаются
#   exit 0 — предпросмотр показан либо обновление применено и проверено
#   exit 1 — предусловие не выполнено, поставка не годится, либо откат после красной проверки
#
# Доказательство мутацией: .claude/hooks/upgrade.test.sh

set -uo pipefail

APPLY=0
SOURCE=${UPGRADE_SOURCE:-https://github.com/noxxer/core-team.git}
REF=""
ROOT=.
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --source) SOURCE=$2; shift ;;
    --ref) REF=$2; shift ;;
    --root) ROOT=$2; shift ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    *) printf 'неизвестный аргумент: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

cd "${ROOT}" 2>/dev/null || { printf 'ОТКАЗ: нет каталога %s\n' "${ROOT}" >&2; exit 1; }
say() { printf '%s\n' "$*"; }
fail() { printf 'ОТКАЗ: %s\n' "$*" >&2; exit 1; }

TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# --- Версии --------------------------------------------------------------------
strip_pre() { printf '%s' "$1" | sed -E 's/[-+].*$//'; }
ver_cmp() {  # печатает -1 / 0 / 1 для $1 относительно $2
  awk -v a="$(strip_pre "$1")" -v b="$(strip_pre "$2")" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, ".")
    for (i = 1; i <= 3; i++) { xi = (i <= n) ? x[i] + 0 : 0; yi = (i <= m) ? y[i] + 0 : 0
      if (xi > yi) { print 1; exit } if (xi < yi) { print -1; exit } }
    print 0 }'
}
ver_lt() { [ "$(ver_cmp "$1" "$2")" = "-1" ]; }
ver_le() { [ "$(ver_cmp "$1" "$2")" != "1" ]; }
max_stable() { grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | awk -F. '{ printf "%09d%09d%09d %s\n", $1, $2, $3, $0 }' | sort | tail -1 | cut -d' ' -f2; }

# --- 1. Предусловия -------------------------------------------------------------
[ -d .claude ] || fail "в ${PWD} нет каталога .claude — это не копия Core Team"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "копия не под git: откатить обновление было бы нечем"
branch=$(git symbolic-ref --short -q HEAD 2>/dev/null || printf 'HEAD')
case "${branch}" in
  main|master) [ "${APPLY}" -eq 0 ] || fail "ветка ${branch}: обновление идёт в отдельной ветке (git switch -c update-core-team), чтобы откат был одним движением" ;;
esac
dirty=$(git status --porcelain -- .claude 2>/dev/null)
if [ -n "${dirty}" ] && [ "${APPLY}" -eq 1 ]; then
  printf 'ОТКАЗ: внутри .claude есть незакоммиченное — обновление перезаписывает каталог, и потерянную правку восстановить будет нечем:\n%s\n' "${dirty}" >&2
  exit 1
fi

local_version=""
[ -f .claude/VERSION ] && local_version=$(tr -d '[:space:]' < .claude/VERSION)
from_version=${local_version:-0.0.0}

# --- 2. Поставка ---------------------------------------------------------------
if [ -d "${SOURCE}" ] && [ -f "${SOURCE}/.claude/VERSION" ]; then
  SRC=$(cd "${SOURCE}" && pwd -P)
else
  SRC=$(mktemp -d) || fail "не удалось создать временный каталог"
  TRASH+=("${SRC}")
  git clone --quiet "${SOURCE}" "${SRC}" 2>/dev/null || fail "не удалось получить поставку из ${SOURCE}"
  if [ -n "${REF}" ]; then
    git -C "${SRC}" checkout --quiet "${REF}" 2>/dev/null || fail "в поставке нет ссылки ${REF}"
  else
    latest_tag=$(git -C "${SRC}" tag 2>/dev/null | sed -n 's/^v//p' | max_stable)
    [ -n "${latest_tag}" ] && git -C "${SRC}" checkout --quiet "v${latest_tag}" 2>/dev/null
  fi
fi
[ -f "${SRC}/.claude/VERSION" ] || fail "у поставки нет .claude/VERSION — обновляться из неё нельзя"
new_version=$(tr -d '[:space:]' < "${SRC}/.claude/VERSION")
[ -n "${new_version}" ] || fail "VERSION поставки пуст"

if [ "${new_version}" = "${local_version}" ]; then
  say "Копия уже на версии ${new_version} — обновлять нечего."
  exit 0
fi
if [ -n "${local_version}" ] && ver_lt "${new_version}" "${local_version}"; then
  fail "поставка ${new_version} старше копии ${local_version} — понижение не делается"
fi

# Тег прежней версии — если он есть в поставке, свою правку можно отличить от файла поставки.
old_ref=""
if [ -n "${local_version}" ] && git -C "${SRC}" rev-parse -q --verify "v${local_version}^{commit}" >/dev/null 2>&1; then
  old_ref="v${local_version}"
fi
old_file() { [ -n "${old_ref}" ] && git -C "${SRC}" show "${old_ref}:.claude/$1" 2>/dev/null; }
old_has() { [ -n "${old_ref}" ] && git -C "${SRC}" cat-file -e "${old_ref}:.claude/$1" 2>/dev/null; }

transplant_project_section() {  # $1 = ваш CLAUDE.md, $2 = CLAUDE.md поставки → stdout
  local sec; sec=$(mktemp); TRASH+=("${sec}")
  awk '/^## Текущий проект/{f=1} f&&/^## /&&!/^## Текущий проект/{exit} f' "$1" > "${sec}"
  if [ ! -s "${sec}" ]; then cat "$2"; return 0; fi
  awk -v secfile="${sec}" '
    BEGIN { while ((getline l < secfile) > 0) sec = sec l "\n" }
    /^## Текущий проект/ { printf "%s", sec; skip = 1; next }
    skip && /^## / { skip = 0 }
    !skip { print }' "$2"
}

# --- 3. Что своё ----------------------------------------------------------------
# Умолчание — то, что `/setup-project` и роли пишут в `.claude/` у потребителя.
KEEP_DEFAULT='settings.local.json planner-context.md output-styles/* statusline.sh RESUME.md'
keep_user=""
if [ -f .claude/settings.json ]; then
  keep_user=$(awk '/"keep"[[:space:]]*:/{f=1} f{print} f&&/]/{exit}' .claude/settings.json 2>/dev/null \
    | tr ',' '\n' | sed -n 's/.*"\([^"]*\)".*/\1/p' | grep -v '^keep$' | tr '\n' ' ')
fi
KEEP="${KEEP_DEFAULT} ${keep_user}"

is_kept() {  # $1 = путь относительно .claude/
  local pat
  for pat in ${KEEP}; do
    # shellcheck disable=SC2254
    case "$1" in ${pat}) return 0 ;; esac
  done
  return 1
}
is_own_dir() {  # каталоги, где чужой файл — своё по определению
  case "$1" in agents/*|knowledge/dpf/*|rules/*|output-styles/*) return 0 ;; esac
  return 1
}
rel_files() { (cd "$1" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort); }

incoming=(); updated=(); overwritten=(); kept=(); removed=(); dropped=(); questions=(); unchanged=0
while IFS= read -r rel; do
  [ -n "${rel}" ] || continue
  case "${rel}" in settings.local.json) continue ;; esac
  if [ ! -f ".claude/${rel}" ]; then
    # Файл был в поставке вашей версии и у вас его нет — вы его убрали (setup чистит роли и
    # учебники неактивных ролей). Возвращать нельзя: замер боевого прогона — исследовательский
    # проект без ролей разработки получил бы обратно три роли, шесть учебников и два правила стека.
    if old_has "${rel}"; then dropped+=("${rel}"); else incoming+=("${rel}"); fi
    continue
  fi
  if cmp -s ".claude/${rel}" "${SRC}/.claude/${rel}"; then unchanged=$((unchanged + 1)); continue; fi
  case "${rel}" in
    CLAUDE.md)
      note="раздел «Текущий проект» переносится из вашего"
      if [ -n "${old_ref}" ] && old_has CLAUDE.md; then
        oldc=$(mktemp); TRASH+=("${oldc}"); old_file CLAUDE.md > "${oldc}"
        transplant_project_section .claude/CLAUDE.md "${oldc}" | cmp -s - .claude/CLAUDE.md \
          || note="${note}; ЕСТЬ ВАШИ ПРАВКИ ВНЕ ЭТОГО РАЗДЕЛА — они перезапишутся, смотрите git diff"
      fi
      updated+=("${rel} — ${note}") ;;
    settings.json) updated+=("${rel} — слияние: hooks и env сверху, остальное ваше") ;;
    *)
      if is_kept "${rel}"; then
        kept+=("${rel}")
      elif [ -n "${old_ref}" ] && old_has "${rel}" && old_file "${rel}" | cmp -s - ".claude/${rel}"; then
        updated+=("${rel}")
      elif [ -n "${old_ref}" ]; then
        overwritten+=("${rel}")
      else
        updated+=("${rel} — отличается; версия копии неизвестна, чья правка — не установить")
      fi ;;
  esac
done < <(rel_files "${SRC}/.claude")

while IFS= read -r rel; do
  [ -n "${rel}" ] || continue
  [ -f "${SRC}/.claude/${rel}" ] && continue
  case "${rel}" in settings.local.json) continue ;; esac
  if is_kept "${rel}" || is_own_dir "${rel}"; then
    kept+=("${rel}")
  elif [ -n "${old_ref}" ] && old_has "${rel}"; then
    if old_file "${rel}" | cmp -s - ".claude/${rel}"; then removed+=("${rel}")
    else questions+=("${rel} — убран из поставки, но у вас правлен: оставлен, решите сами"); fi
  else
    questions+=("${rel} — в поставке нет, чей он — неизвестно: не тронут")
  fi
done < <(rel_files .claude)

# --- Opt-in роли: файл роли потребителя, у которого в поставке есть шаблон ------------
# Шаблон opt-in роли — будущий файл роли; наложение до него не доходит (`agents/<роль>.md`
# у поставки нет), и роль тихо отстаёт от контракта. Замер боевого прогона: копия 5.3.0
# с пятью нетронутыми шаблонами 5.3.0 не прошла целостность 5.3.6 — обновление откатилось.
optin_refresh=(); optin_stale=()
while IFS= read -r rel; do
  [ -n "${rel}" ] || continue
  role=$(basename "${rel}")
  [ -f "${SRC}/.claude/agents/${role}" ] && continue          # ядровая роль — обычное наложение
  tpl="templates/roles/optional/${role}"
  [ -f "${SRC}/.claude/${tpl}" ] || continue                   # своя роль, шаблона нет
  cmp -s ".claude/${rel}" "${SRC}/.claude/${tpl}" && continue  # уже свежая
  if old_has "${tpl}" && old_file "${tpl}" | cmp -s - ".claude/${rel}"; then
    optin_refresh+=("${rel}")
  else
    optin_stale+=("${rel} — правлена вами, а шаблон в поставке изменился: сверьте с ${tpl}")
  fi
done < <(rel_files .claude | grep '^agents/')

# --- Доклад о составе -----------------------------------------------------------
say "Обновление Core Team: ${local_version:-<без VERSION, старше 5.1>} → ${new_version}. Поставка: ${SOURCE}."
[ -n "${old_ref}" ] || say "Тег прежней версии в поставке не найден: ваша правка и файл поставки неразличимы — смотрите колонку «обновится»."
say ""
list() { local title=$1; shift; [ $# -gt 0 ] || return 0; say "${title} (${#}):"; printf '  %s\n' "$@"; say ""; }
list "ПРИЕДЕТ СВЕРХУ — новых файлов" ${incoming[@]+"${incoming[@]}"}
list "ОБНОВИТСЯ — файлы поставки" ${updated[@]+"${updated[@]}"}
list "ВАШЕ И ОСТАНЕТСЯ — не трогается" ${kept[@]+"${kept[@]}"}
list "ВАША ПРАВКА БУДЕТ ПЕРЕЗАПИСАНА — файл поставки, изменённый у вас (вернуть: git diff по ветке)" ${overwritten[@]+"${overwritten[@]}"}
list "УБРАНО ИЗ ПОСТАВКИ — удалится, у вас не правлен" ${removed[@]+"${removed[@]}"}
list "УБРАНО У ВАС — было в поставке вашей версии, не возвращается (вернуть: скопировать из поставки)" ${dropped[@]+"${dropped[@]}"}
list "OPT-IN РОЛИ — нетронутый шаблон прежней версии, обновится из шаблона поставки" ${optin_refresh[@]+"${optin_refresh[@]}"}
list "OPT-IN РОЛИ — правлены вами, не трогаются" ${optin_stale[@]+"${optin_stale[@]}"}
list "ВОПРОС — не тронуто, решите сами" ${questions[@]+"${questions[@]}"}
say "Без изменений: ${unchanged} файлов."
say ""

# --- 5. Миграции (в предпросмотре — что будет; в apply — делают) -----------------
CREATED_LIST=$(mktemp) || fail "не удалось создать временный файл"; TRASH+=("${CREATED_LIST}")
mig_say() { printf '  %s: %s\n' "$1" "$2"; }
mig_done() { mig_say "СДЕЛАНО" "$1"; }
mig_will() { mig_say "БУДЕТ" "$1"; }
mig_already() { mig_say "УЖЕ" "$1"; }
mig_manual() { mig_say "ВРУЧНУЮ" "$1"; }
mig_created() { printf '%s\n' "$1" >> "${CREATED_LIST}"; }
export -f mig_say mig_done mig_will mig_already mig_manual mig_created
export CREATED_LIST

run_migrations() {  # $1 = 0 предпросмотр / 1 применение
  local dir="${SRC}/.claude/hooks/migrations" m v any=0
  [ -d "${dir}" ] || return 0
  for m in "${dir}"/*.sh; do
    [ -f "${m}" ] || continue
    v=$(basename "${m}" .sh)
    ver_lt "${from_version}" "${v}" || continue
    ver_le "${v}" "${new_version}" || continue
    [ "${any}" -eq 0 ] && { say "МИГРАЦИИ (${from_version} → ${new_version}):"; any=1; }
    say "  — ${v}"
    APPLY="$1" ROOT="${PWD}" SRC="${SRC}" bash "${m}" || say "  ОШИБКА: миграция ${v} завершилась с отказом"
  done
  [ "${any}" -eq 1 ] && say ""
  return 0
}


merge_settings() {  # $1 = каталог .claude назначения: settings.json ← hooks и env поставки
  local mine="$1/settings.json" theirs="${SRC}/.claude/settings.json" tmp
  [ -f "${theirs}" ] || return 0
  if [ ! -f "${mine}" ]; then cp "${theirs}" "${mine}"; return 0; fi
  if ! command -v jq >/dev/null 2>&1; then
    say "ВРУЧНУЮ: jq не найден — settings.json не тронут. Перенесите блок hooks (и env) из поставки:"
    awk '/"hooks"[[:space:]]*:/{f=1} f{print}' "${theirs}" | sed 's/^/    /'
    return 0
  fi
  tmp=$(mktemp); TRASH+=("${tmp}")
  # hooks берутся целиком сверху, не сливаются: устаревшее событие потребителя пережило бы
  # слияние и молча падало бы при каждом срабатывании (замер: TaskCompleted → удалённый хук).
  if jq -s '.[0] as $m | .[1] as $t | $m
            | (if $t.hooks then .hooks = $t.hooks else . end)
            | .env = (($m.env // {}) + ($t.env // {}))' "${mine}" "${theirs}" > "${tmp}" 2>/dev/null \
     && [ -s "${tmp}" ]; then
    cp "${tmp}" "${mine}"
  else
    say "ВРУЧНУЮ: settings.json не разобран как JSON — не тронут; перенесите hooks из поставки сами."
  fi
}

overlay_into() {  # $1 = каталог .claude назначения; печатает, что сделал; 1 — если копирование упало
  local dest=$1 rel count=0 tmp
  while IFS= read -r rel; do
    [ -n "${rel}" ] || continue
    case "${rel}" in settings.local.json|CLAUDE.md|settings.json) continue ;; esac
    [ -f "${dest}/${rel}" ] && is_kept "${rel}" && continue
    [ ! -f "${dest}/${rel}" ] && old_has "${rel}" && continue   # убрано у вас — не возвращается
    mkdir -p "$(dirname "${dest}/${rel}")"
    cp "${SRC}/.claude/${rel}" "${dest}/${rel}" || return 1
    case "${rel}" in *.sh) chmod +x "${dest}/${rel}" ;; esac
    count=$((count + 1))
  done < <(rel_files "${SRC}/.claude")
  say "  скопировано файлов: ${count}"
  if [ -f "${SRC}/.claude/CLAUDE.md" ]; then
    if [ -f "${dest}/CLAUDE.md" ]; then
      tmp=$(mktemp); TRASH+=("${tmp}")
      transplant_project_section "${dest}/CLAUDE.md" "${SRC}/.claude/CLAUDE.md" > "${tmp}" && cp "${tmp}" "${dest}/CLAUDE.md"
      say "  CLAUDE.md: взят из поставки, раздел «Текущий проект» ваш"
    else
      cp "${SRC}/.claude/CLAUDE.md" "${dest}/CLAUDE.md"
    fi
  fi
  merge_settings "${dest}"
  for rel in ${removed[@]+"${removed[@]}"}; do rm -f "${dest}/${rel}"; done
  [ ${#removed[@]} -gt 0 ] && say "  удалено остатков прежних версий: ${#removed[@]}"
  for rel in ${optin_refresh[@]+"${optin_refresh[@]}"}; do
    cp "${SRC}/.claude/templates/roles/optional/$(basename "${rel}")" "${dest}/${rel}"
  done
  [ ${#optin_refresh[@]} -gt 0 ] && say "  opt-in ролей обновлено из шаблонов: ${#optin_refresh[@]}"
  return 0
}

# --- Целостность после обновления — предсказывается на временной копии ----------
# Замер боевого прогона: применение прошло все шаги и откатилось по одному расхождению
# целостности, о котором предпросмотр не сказал ни слова. Дешевле показать это до, чем после.
integrity_cmd=${UPGRADE_INTEGRITY_CMD:-}
predict_integrity() {  # печатает предсказание; 0 — целостность зелёная
  local pre out
  pre=$(mktemp -d) || return 0
  TRASH+=("${pre}")
  cp -R .claude "${pre}/.claude" 2>/dev/null || return 0
  overlay_into "${pre}/.claude" >/dev/null 2>&1
  if [ -n "${integrity_cmd}" ]; then out=$(${integrity_cmd} 2>&1); else
    out=$(bash "${pre}/.claude/hooks/check-install-integrity.sh" "${pre}" 2>&1); fi
  if [ $? -eq 0 ]; then
    say "ЦЕЛОСТНОСТЬ ПОСЛЕ ОБНОВЛЕНИЯ: $(printf '%s\n' "${out}" | tail -1)"
    return 0
  fi
  say "ЦЕЛОСТНОСТЬ ПОСЛЕ ОБНОВЛЕНИЯ — КРАСНАЯ: --apply откатится, пока это не исправлено:"
  printf '%s\n' "${out}" | grep -vE '^[[:space:]]*$' | sed 's/^/  /'
  return 1
}

if [ "${APPLY}" -eq 0 ]; then
  run_migrations 0
  predict_integrity; say ""
  say "Это предпросмотр: файлы не тронуты."
  say "Применить: bash .claude/hooks/upgrade.sh --apply$([ "${SOURCE}" != "https://github.com/noxxer/core-team.git" ] && printf ' --source %s' "${SOURCE}")$([ -n "${REF}" ] && printf ' --ref %s' "${REF}")"
  exit 0
fi

# --- 4. Наложение ----------------------------------------------------------------
before=$(git rev-parse HEAD 2>/dev/null)
rollback() {
  git checkout -q -- .claude 2>/dev/null
  git clean -qfd -- .claude 2>/dev/null
  while IFS= read -r p; do [ -n "${p}" ] && rm -f "${p}"; done < "${CREATED_LIST}"
  printf 'ОТКАТ: .claude возвращён к состоянию %s. Причина: %s\n' "${before}" "$1" >&2
  exit 1
}

say "НАЛОЖЕНИЕ:"
overlay_into .claude || rollback "не удалось скопировать файл поставки"
say ""

run_migrations 1

# --- 6. Проверка -----------------------------------------------------------------
say "ПРОВЕРКА ЦЕЛОСТНОСТИ:"
if out=$(${integrity_cmd:-bash .claude/hooks/check-install-integrity.sh} 2>&1); then
  printf '%s\n' "${out}" | tail -1 | sed 's/^/  /'
else
  printf '%s\n' "${out}" | sed 's/^/  /' >&2
  rollback "копия после наложения не работоспособна"
fi
say ""

if [ -d project ] && [ -f .claude/hooks/check-findings-budget.sh ]; then
  say "СВОДКА НАХОДОК ПРОЕКТА (показ, обновление не роняет):"
  bash .claude/hooks/check-findings-budget.sh . 2>&1 | sed 's/^/  /' | head -20
  say ""
fi

# --- 7. Доклад -------------------------------------------------------------------
changelog="${SRC}/CHANGELOG.md"
if [ -f "${changelog}" ]; then
  say "ЧТО ИЗМЕНИЛОСЬ В КОНТРАКТЕ (${from_version} → ${new_version}):"
  awk -v from="${from_version}" -v to="${new_version}" '
    function ver(s) { gsub(/[^0-9.]/, "", s); split(s, p, "."); return sprintf("%09d%09d%09d", p[1], p[2], p[3]) }
    /^## \[/ { v = $2; gsub(/[][]/, "", v); inside = (ver(v) > ver(from) && ver(v) <= ver(to)); if (inside) print; next }
    inside && /^> / { print "   " $0 }
    inside && /closes:/ { print "   " $0 }
  ' "${changelog}" | sed 's/^/  /'
  say ""
  if [ -f project/framework-feedback.md ]; then
    closed=$(awk -v from="${from_version}" -v to="${new_version}" '
      function ver(s) { gsub(/[^0-9.]/, "", s); split(s, p, "."); return sprintf("%09d%09d%09d", p[1], p[2], p[3]) }
      /^## \[/ { v = $2; gsub(/[][]/, "", v); inside = (ver(v) > ver(from) && ver(v) <= ver(to)); next }
      inside && /closes:/ { s = $0; while (match(s, /#[0-9]+/)) { print substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) } }
    ' "${changelog}" | sort -u)
    hits=""
    for n in ${closed}; do grep -qF -- "${n}" project/framework-feedback.md && hits="${hits} ${n}"; done
    if [ -n "${hits}" ]; then
      say "ЗАКРЫТО ИЗ ВАШЕГО framework-feedback.md в этих версиях:${hits}"
      say "  отметьте исход в таблице «Отправлено наверх»."
      say ""
    fi
  fi
fi

say "ДАЛЬШЕ:"
say "  1. git diff — посмотрите перезаписанное и вопросы выше."
say "  2. Плагины обновляются отдельно: claude plugin update <имя>@core-team."
say "  3. Коммит одной строкой: git commit -am \"chore: обновление Core Team ${local_version:-<старая>} → ${new_version}\""
say "  4. Слияние ветки в основную — за вами."
exit 0
