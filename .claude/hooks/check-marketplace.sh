#!/bin/bash
# Маркетплейс: объявленное в витрине совпадает с тем, что лежит в репозитории.
#
# ТИР: копия — про поставку, а не про проект
#
# Витрина (`marketplace.json`) и манифесты плагинов — две записи об одном
# предмете, и расходятся они молча: установка идёт у потребителя, а он о
# расхождении не сообщает. Замер: витрина фреймворка не проходила схему CLI
# с самого заведения — `owner` строкой вместо объекта и источник ядра в
# непринимаемой форме, — то есть `/plugin marketplace add` мог не сработать
# вовсе, и узнать об этом было негде.
#
# Один предмет — «витрина и репозиторий говорят одно и то же», шесть отказов:
#   1. витрина не разбирается как JSON;
#   2. `owner` не объект с непустым `name` (форма, на которой падает схема CLI);
#   3. в витрине ноль плагинов;
#   4. запись указывает на каталог, которого нет, или без манифеста;
#   5. имя в витрине разошлось с именем в манифесте плагина;
#   6. каталог плагина лежит в репозитории, но в витрине не объявлен —
#      построено, но не поставляется (класс дрейфа E);
#   7. запись ведёт в каталог без единого компонента — установка проходит
#      успешно и даёт ноль.
#
# ЗАПУСК: bash .claude/hooks/check-marketplace.sh [корень репозитория]
#   exit 0 — витрина согласована с репозиторием (или витрины нет — копия потребителя)
#   exit 1 — расхождение либо разобрать витрину нечем
#
# Доказательство мутацией: .claude/hooks/check-marketplace.test.sh

set -uo pipefail

ROOT=${1:-.}
MARKET="${ROOT}/.claude-plugin/marketplace.json"
PLUGIN_DIR="${ROOT}/plugins"

# Копия потребителя витрины не содержит: там нечего поставлять.
[ -f "${MARKET}" ] || { printf 'витрины нет (%s) — это не репозиторий-маркетплейс\n' "${MARKET}"; exit 0; }

if ! command -v jq >/dev/null 2>&1; then
  printf 'ОШИБКА: нет jq — разобрать витрину нечем.\n' >&2
  printf 'Гард, не умеющий прочитать предмет, обязан сказать это, а не промолчать зелёным.\n' >&2
  exit 1
fi

if ! jq empty "${MARKET}" 2>/dev/null; then
  printf 'ОШИБКА: %s не разбирается как JSON.\n' "${MARKET}" >&2
  exit 1
fi

failures=0
note() { printf 'КРАСНОЕ: %s\n' "$1" >&2; failures=$((failures + 1)); }

# --- 1. Форма владельца: схема CLI требует объект ---------------------------
owner_kind=$(jq -r '.owner | type' "${MARKET}")
if [ "${owner_kind}" != "object" ]; then
  note "поле owner имеет тип ${owner_kind}, а схема требует объект — на этой форме падает \`claude plugin validate\`"
elif [ -z "$(jq -r '.owner.name // empty' "${MARKET}")" ]; then
  note "у owner пустое имя — витрина без владельца не устанавливается"
fi

# --- 2. Половина «найдено не ноль» ------------------------------------------
count=$(jq -r '.plugins | length' "${MARKET}" 2>/dev/null || printf '0')
if [ "${count}" -eq 0 ]; then
  printf 'ОШИБКА: в витрине ноль плагинов — перечисляющая проверка на пустом множестве успехом не считается.\n' >&2
  exit 1
fi

# --- 3. Каждая запись витрины ведёт в живой плагин --------------------------
declared=""
while IFS=$'\t' read -r name source; do
  [ -n "${name}" ] || { note "в витрине есть запись без имени"; continue; }
  declared="${declared} ${name}"

  case "${source}" in
    ./*)
      dir="${ROOT}/${source#./}"
      manifest="${dir%/}/.claude-plugin/plugin.json"
      # Корневой источник «./» — сам фреймворк: его манифест лежит там же, где витрина.
      if [ "${source}" = "./" ]; then
        manifest="${ROOT}/.claude-plugin/plugin.json"
      fi
      if [ ! -f "${manifest}" ]; then
        note "запись «${name}» указывает на ${source}, где нет манифеста плагина"
        continue
      fi
      real=$(jq -r '.name // empty' "${manifest}")
      if [ "${real}" != "${name}" ]; then
        note "витрина называет плагин «${name}», а его манифест — «${real}»"
      fi
      if [ -z "$(jq -r '.version // empty' "${manifest}")" ]; then
        note "у плагина «${name}» пустая версия — обновление не отличит новое от старого"
      fi
      # Манифест на месте, а компонентов нет: установка проходит успешно и даёт
      # НОЛЬ. Замер: запись ядра с источником «./» ставилась без ошибки и
      # показывала «Skills (0), Agents (0)» — файлы ядра лежат в `.claude/`, куда
      # плагинный загрузчик не смотрит. Успешная установка пустоты хуже отказа:
      # об отказе узнают сразу.
      root=$(dirname "$(dirname "${manifest}")")
      components=no
      for kind in skills agents commands hooks; do
        [ -d "${root}/${kind}" ] && { components=yes; break; }
      done
      if [ "${components}" = no ]; then
        note "запись «${name}» ведёт в каталог без единого компонента (нет skills/ agents/ commands/ hooks/) — установка пройдёт успешно и даст ноль"
      fi
      ;;
    '')
      note "у записи «${name}» нет источника"
      ;;
  esac
done < <(jq -r '.plugins[] | [(.name // ""), (if (.source|type) == "string" then .source else "" end)] | @tsv' "${MARKET}")

# --- 4. Плагин лежит, но не объявлен — построено, но не поставляется ---------
if [ -d "${PLUGIN_DIR}" ]; then
  for dir in "${PLUGIN_DIR}"/*/; do
    [ -d "${dir}" ] || continue
    plugin_name=$(basename "${dir}")
    case " ${declared} " in
      *" ${plugin_name} "*) ;;
      *) note "каталог plugins/${plugin_name} есть в репозитории, но в витрине не объявлен — до потребителя он не доедет" ;;
    esac
  done
fi

printf 'Витрина %s: записей %s.\n' "${MARKET}" "${count}"
[ "${failures}" -eq 0 ] || { printf '\nрасхождений витрины и репозитория: %s\n' "${failures}" >&2; exit 1; }
exit 0
