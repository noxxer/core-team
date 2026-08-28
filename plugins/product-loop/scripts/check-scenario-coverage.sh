#!/bin/bash
# Покрытие сценариев кадрами: путь описан — и доказан ли он.
#
# ТИР: стоп — сценарий без кадров не доказан, а выглядит готовым
#
# Описание пути и его прогон живут в разных инструментах: описание — здесь,
# кадры снимает стенд (`smotrovaya`). Связь — по номеру шага. Расхождение
# считает этот прибор, а не глаз: «сценарий готов» и «сценарий проходится» —
# разные утверждения, и второе доказывается только кадром.
#
# Один предмет — «шаги сценария доказаны снимками и честно засчитаны», пять отказов:
#   1. шаг без кадра — путь не доказан;
#   2. кадр без шага — описание отстало от прогона;
#   3. сценарий не прогонялся вовсе (`deck` пуст) при непустых шагах;
#   4. `status: checked` при шаге без исполнителя — сверка не доведена;
#   5. `checks` называет требования, хотя есть шаг с прочерком — покрытие завышено.
#
# ЗАПУСК: bash check-scenario-coverage.sh [каталог сценариев] [каталог ленты]
#   exit 0 — покрытие честное (или сценариев ещё нет)
#   exit 1 — расхождение либо разобрать сценарии нечем
#
# Доказательство мутацией: check-scenario-coverage.test.sh

set -uo pipefail

SCENARIOS=${1:-${SCENARIOS_DIR:-project/scenarios}}
DECK=${2:-${DECK_OUTPUT_DIR:-}}

[ -d "${SCENARIOS}" ] || { printf 'каталога сценариев нет (%s) — проверять нечего\n' "${SCENARIOS}"; exit 0; }

header() {  # $1 = файл, $2 = поле → значение поля шапки
  awk -v want="^$2:" '
    NR==1 && $0!="---" {exit}
    NR==1 {next}
    /^---[[:space:]]*$/ {exit}
    $0 ~ want {sub(/^[^:]*:[[:space:]]*/, ""); print; exit}
  ' "$1"
}

# Шаг — строка таблицы, чьё первое поле есть число. Заголовок и разделитель
# шагами не являются, строка прозы с вертикальной чертой — тоже.
step_rows() { grep -E '^\|[[:space:]]*[0-9]+[[:space:]]*\|' "$1" || true; }

field() {  # $1 = строка, $2 = номер колонки
  printf '%s\n' "$1" | awk -F'|' -v n="$2" '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $(n+1)); print $(n+1)}'
}

is_empty() {  # прочерк и пустая ячейка — одно: исполнитель не назван
  case "$(printf '%s' "$1" | tr -d '[:space:]')" in
    ''|'—'|'-'|'–'|'?') return 0 ;;
    *) return 1 ;;
  esac
}

# Номера шагов, у которых есть кадр: имя кадра несёт номер четвёртым полем,
# разделённым двойным подчёркиванием. Берётся САМАЯ СВЕЖАЯ версия ленты,
# где этот прогон вообще присутствует: сравнивать описание с позапрошлым
# прогоном значит мерить продукт вчерашним прибором.
frames_for() {  # $1 = идентификатор прогона
  local version dir
  [ -d "${DECK}" ] || return 0
  while IFS= read -r version; do
    dir="${DECK}/${version}/$1"
    [ -d "${dir}" ] || continue
    for shot in "${dir}"/*.png; do
      [ -f "${shot}" ] || continue
      basename "${shot}"
    done | awk -F'__' 'NF>=4 {n=$4+0; if (n>0) print n}' | sort -n | uniq
    return 0
  done < <(ls -1t "${DECK}" 2>/dev/null)
  return 0
}

failures=0
checked=0
note() { printf 'КРАСНОЕ: %s\n' "$1" >&2; failures=$((failures + 1)); }

for file in "${SCENARIOS}"/*.md; do
  [ -f "${file}" ] || continue
  [ "$(header "${file}" kind)" = "scenario" ] || continue
  checked=$((checked + 1))

  name=$(basename "${file}" .md)
  id=$(header "${file}" id)
  [ -n "${id}" ] || id="${name}"
  status=$(header "${file}" status)
  checks=$(header "${file}" checks)
  deck=$(header "${file}" deck)

  rows=$(step_rows "${file}")
  if [ -z "${rows}" ]; then
    note "сценарий «${id}» не содержит ни одного шага — путь не описан"
    continue
  fi

  described=""
  orphan_step=""
  while IFS= read -r row; do
    [ -n "${row}" ] || continue
    num=$(field "${row}" 1 | tr -d '[:space:]')
    owner=$(field "${row}" 5)
    described="${described} ${num}"
    if is_empty "${owner}"; then
      orphan_step="${orphan_step} ${num}"
    fi
  done <<< "${rows}"

  # --- Прогона нет вовсе ----------------------------------------------------
  if is_empty "${deck}"; then
    note "сценарий «${id}» описан, но ни разу не прогонялся (поле deck пусто) — путь не доказан"
  else
    shot=$(frames_for "${deck}")
    if [ -z "${shot}" ]; then
      note "сценарий «${id}» называет прогон «${deck}», а кадров этого прогона в ленте нет"
    else
      for num in ${described}; do
        case " $(printf '%s' "${shot}" | tr '\n' ' ') " in
          *" ${num} "*) ;;
          *) note "сценарий «${id}»: шаг ${num} не имеет кадра — путь на этом шаге не доказан" ;;
        esac
      done
      while IFS= read -r num; do
        [ -n "${num}" ] || continue
        case " ${described} " in
          *" ${num} "*) ;;
          *) note "сценарий «${id}»: кадр шага ${num} есть в ленте, а в описании такого шага нет — описание отстало от прогона" ;;
        esac
      done <<< "${shot}"
    fi
  fi

  # --- Статус и покрытие честны ---------------------------------------------
  if [ -n "${orphan_step}" ]; then
    if [ "${status}" = "checked" ]; then
      note "сценарий «${id}»: статус checked, а шаги${orphan_step} не имеют исполнителя — сверка не доведена"
    fi
    case "$(printf '%s' "${checks}" | tr -d '[:space:]')" in
      ''|'[]'|'-'|'—') ;;
      *) note "сценарий «${id}»: checks называет ${checks}, хотя шаги${orphan_step} без исполнителя — покрытие завышено" ;;
    esac
  fi
done

# Половина «найдено не ноль»: каталог есть, а разобрано ноль сценариев — это
# отказ разбора, а не полное покрытие. Молчаливый ноль читается как «всё честно».
if [ "${checked}" -eq 0 ]; then
  printf 'ОШИБКА: в %s не разобрано ни одного сценария (нужен `kind: scenario` в шапке).\n' "${SCENARIOS}" >&2
  exit 1
fi

printf 'Сценариев разобрано: %s.\n' "${checked}"
if [ -n "${DECK}" ] && [ ! -d "${DECK}" ]; then
  printf 'ПРОГОН НЕ СВЕРЕН: каталога ленты нет (%s).\n' "${DECK}" >&2
  printf '  Проверена только форма описания. Это не «покрытие полное», это «не измерено».\n' >&2
fi
[ "${failures}" -eq 0 ] || { printf '\nрасхождений описания и прогона: %s\n' "${failures}" >&2; exit 1; }
exit 0
