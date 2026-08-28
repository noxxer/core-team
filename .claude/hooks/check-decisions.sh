#!/bin/bash
# Проверщик решений. Две работы над одним предметом:
#
# ТИР: стоп — обоснование решения теряется навсегда
#   1) СУЩЕСТВОВАНИЕ: каждый DEC-NNN, упомянутый в ledger, имеет файл решения.
#   2) ЗАКРЕПЛЕНИЕ: у каждого решения назван адрес проверки, делающей его
#      нарушение красным (поле `enforced_by` в шапке файла).
#
# Замер, из которого выросла проверка: 113 решений в двух проектах, слова
# «тест/гард/CI» — в 111, конкретный путь до проверки — в 8. При этом 75 записей
# реестра дрейфа из 108 (69%) — класс «решение ↔ код».
#
# Второй замер: при переупаковке фреймворка v0 → v5 три решения остались
# упомянутыми в ledger, а файлов не появилось — обоснование утрачено
# безвозвратно. Гейт «DEC-NNN ⟹ файл» был правилом без проверки и срабатывал
# только на новых решениях; импорт состояния при миграции не смотрел никто.
#
# ЗАПУСК: bash .claude/hooks/check-decisions.sh [каталог-решений]
#   exit 0 — упомянутые решения существуют и закреплены (или честно помечены)
#   exit 1 — есть осиротевшее упоминание, решение без адреса, либо отказ проверки
#
# Наследие: решения старше ENFORCED_SINCE перечисляются отдельно и НЕ роняют
# проверку — они заполняются при первом касании (цитирование, пересмотр, дрейф).
#
# Доказательство мутацией: .claude/hooks/check-decisions.test.sh

set -uo pipefail

DECISIONS_DIR=${1:-${DECISIONS_DIR:-project/decisions}}
ENFORCED_SINCE=${DECISIONS_ENFORCED_SINCE:-2026-08-25}

# Значение поля принимается по БЕЛОМУ списку форм, не по чёрному:
# чёрный список пропускает любую новую расплывчатую формулировку.
value_is_acceptable() {
  local value=${1:-} path=${1:-}
  case "$value" in
    'гарда нет'*|'неприменимо'*) return 0 ;;
  esac
  # Адрес — путь до файла проверки, при желании с ::именем_теста.
  # Белый список расширений, а не «что-то с точкой»: иначе адресом
  # становятся "n/a" и "..." — проверено, обе формы проходили.
  # Документ — тоже адрес, но ТОЛЬКО с указанием места внутри него. Белый список
  # состоял из расширений кода, и решение, закреплённое правилом в тексте, признать
  # было нечем: проект без кода мог написать лишь «гарда нет», то есть неправду —
  # гард есть, он документ. Сам фреймворк закрепляет свои решения правилами в
  # `.claude/CLAUDE.md`, и по собственной мерке его решения были бы незакреплены.
  #
  # Якорь обязателен, потому что файл целиком адресом не является: «README.md»
  # вернуло бы отписку через другую дверь. `requirements.md::FR-01` называет место,
  # где нарушение станет видно, — это и есть работа поля.
  #
  # Проверка стоит ДО фильтра символов: `#` в белый набор не входит, и якорь
  # решёткой отсекался раньше, чем до него доходило дело.
  case "$value" in
    *.md::?*|*.md#?*) return 0 ;;
  esac
  path=${value%%::*}
  case "$path" in
    *[!A-Za-z0-9._/-]*|'') return 1 ;;
  esac
  case "$path" in
    *.py|*.ts|*.tsx|*.js|*.jsx|*.sh|*.yml|*.yaml|*.rb|*.go|*.rs|*.java|*.kt|*.sql) return 0 ;;
  esac
  return 1
}

# Шапка (frontmatter) — только первый блок между --- и ---.
# Поле, найденное в теле документа (цитата, пример), закреплением не является.
frontmatter_of() {
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1" 2>/dev/null
}

# Разбор вынесен в библиотеку: комментарий после значения оставался частью
# значения, а шаблон решения комментарии содержит на каждом втором поле.
_lib_fm="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/lib-frontmatter.sh"
if [ -f "${_lib_fm}" ]; then
  # shellcheck source=/dev/null
  . "${_lib_fm}"
  field_of() { fm_field "$1" "$2"; }
else
  field_of() {  # $1 = файл, $2 = имя поля шапки
    frontmatter_of "$1" | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//; s/^\"//; s/\"[[:space:]]*$//"
  }
fi

LEDGER=${LEDGER_FILE:-project/ledger.md}

# Номера существующих файлов решений, нормализованные: DEC-044 и DEC-44 —
# одно решение, и расхождение в набивке нулями не должно рождать ложную сироту.
decision_numbers() {
  local file base
  shopt -s nullglob
  for file in "${DECISIONS_DIR}"/DEC-*.md; do
    base=$(basename "${file}")
    printf ' %s ' "$(printf '%s' "${base}" | sed -E 's/^DEC-0*([0-9]+).*/\1/')"
  done
}

ledger_check() {
  [ -f "${LEDGER}" ] || { printf 'ledger не найден (%s) — сверка упомянутых решений пропущена\n' "${LEDGER}"; return 0; }
  local ids existing mentioned num orphans=() count=0
  ids=$(grep -oE 'DEC-[0-9]+' "${LEDGER}" 2>/dev/null | sort -u)
  if [ -z "${ids}" ]; then
    printf 'В ledger не упомянуто ни одного решения — сверять нечего\n'
    return 0
  fi
  existing=$(decision_numbers)
  while IFS= read -r mentioned; do
    [ -n "${mentioned}" ] || continue
    count=$((count + 1))
    num=$(printf '%s' "${mentioned}" | sed -E 's/^DEC-0*([0-9]+)$/\1/')
    case "${existing}" in *" ${num} "*) ;; *) orphans+=("${mentioned}") ;; esac
  done <<< "${ids}"
  printf 'Упомянуто в ledger решений: %s. Без файла: %s.\n' "${count}" "${#orphans[@]}"
  [ "${#orphans[@]}" -eq 0 ] && return 0
  printf '\nУПОМЯНУТО В LEDGER, ФАЙЛА НЕТ (%s):\n' "${#orphans[@]}" >&2
  printf '  %s\n' "${orphans[@]}" >&2
  printf 'Сжатая строка ledger решением не является — обоснование теряется безвозвратно.\n' >&2
  printf 'Либо заведи файл по adr-template.md, либо убери упоминание из ledger.\n' >&2
  return 1
}

ledger_check; ledger_status=$?

[ -d "$DECISIONS_DIR" ] || { printf 'решений нет (%s отсутствует) — файлы не проверяются\n' "$DECISIONS_DIR"; exit "$ledger_status"; }

shopt -s nullglob
files=("$DECISIONS_DIR"/*.md)
if [ ${#files[@]} -eq 0 ]; then
  printf 'решений пока нет — файлы не проверяются\n'
  exit "$ledger_status"
fi

scanned=0; ok=0; legacy=(); missing=(); vague=(); headless=()

for file in "${files[@]}"; do
  id=$(field_of "$file" decision_id)
  name=$(basename "$file")
  if [ -z "$id" ]; then
    # Файл с именем DEC-* и без шапки — это решение, которое проверка не видит.
    # Молчаливый `continue` занижал знаменатель: «проверено 22» при 25 файлах.
    case "$name" in DEC-*) headless+=("$name") ;; esac
    continue
  fi
  scanned=$((scanned + 1))
  proposed=$(field_of "$file" date_proposed)
  value=$(field_of "$file" enforced_by)

  if value_is_acceptable "$value"; then
    ok=$((ok + 1))
    continue
  fi
  if [ -n "$proposed" ] && [ "$proposed" \< "$ENFORCED_SINCE" ]; then
    legacy+=("$name")
  elif [ -z "$value" ]; then
    missing+=("$name")
  else
    vague+=("$name → «${value}»")
  fi
done

# Половина «найдено не ноль»: файлы есть, а разобрано ноль решений — это отказ
# инструмента, а не чистая система. Молчаливый ноль хуже найденного нарушения.
if [ "$scanned" -eq 0 ]; then
  printf 'ОШИБКА: в %s есть %s файлов, но ни одного решения не разобрано.\n' "$DECISIONS_DIR" "${#files[@]}" >&2
  printf 'Проверка не может подтвердить закрепление — считаем это отказом, а не успехом.\n' >&2
  exit 1
fi

printf 'Файлов: %s. Решений разобрано: %s. Закреплено: %s. Унаследованных (до %s): %s.\n' \
  "${#files[@]}" "$scanned" "$ok" "$ENFORCED_SINCE" "${#legacy[@]}"

# На 88 решениях список в одну строку давал 3132 символа — нечитаемо.
list_briefly() {  # $1 = заголовок, далее — элементы
  local title=$1 shown=5
  shift
  printf '%s (%s): %s' "$title" "$#" "$(printf '%s ' "${@:1:$shown}")"
  [ "$#" -gt "$shown" ] && printf '…и ещё %s' "$(( $# - shown ))"
  printf '\n'
}

if [ ${#legacy[@]} -gt 0 ]; then
  list_briefly 'Унаследованные без адреса — заполнить при первом касании' "${legacy[@]}"
fi

status=0
if [ ${#headless[@]} -gt 0 ]; then
  printf '\nФАЙЛ-РЕШЕНИЕ БЕЗ ШАПКИ — проверка его не видит (%s):\n' "${#headless[@]}" >&2
  printf '  %s\n' "${headless[@]}" >&2
  printf 'Заведи frontmatter по adr-template.md: без decision_id решение невидимо для всех проверок.\n' >&2
  status=1
fi
if [ ${#missing[@]} -gt 0 ]; then
  printf '\nНЕТ АДРЕСА ПРОВЕРКИ (%s):\n' "${#missing[@]}" >&2
  printf '  %s\n' "${missing[@]}" >&2
  status=1
fi
if [ ${#vague[@]} -gt 0 ]; then
  printf '\nЗНАЧЕНИЕ НЕ ЯВЛЯЕТСЯ АДРЕСОМ (%s):\n' "${#vague[@]}" >&2
  printf '  %s\n' "${vague[@]}" >&2
  status=1
fi
if [ "$status" -ne 0 ]; then
  printf '\nenforced_by принимает: путь до проверки (tests/test_x.py::test_y),\n' >&2
  printf '«гарда нет — держится на внимании роли <role>» или «неприменимо — <почему>».\n' >&2
  printf 'Пустое и расплывчатое («покрыто тестами») — не адрес.\n' >&2
fi
[ "$ledger_status" -eq 0 ] || status=1
exit $status
