#!/bin/bash
# Проверщик рефлексии: последняя записанная сессия должна содержать непустые
# слоты Navigator-разбора.
#
# Замер, из которого выросла проверка: Navigator-анализ есть в 68-75% недавних
# сессий, а в итоговый отчёт Founder-у попадает в 27% (6 из 22). Плюс измеренная
# связь «слот в шаблоне → результат»: Iceberg (слот есть) — 36 и 26 сессий,
# Three Why (слота не было) — 4 и 7.
#
# ЗАПУСК: bash .claude/hooks/check-session-reflection.sh [каталог сессий]
#   exit 0 — слоты заполнены (или сессий ещё нет)
#   exit 1 — слот пуст, отсутствует, либо проверка не смогла отработать
#
# Доказательство мутацией: check-session-reflection.test.sh

set -uo pipefail

SESSIONS_DIR=${1:-${SESSIONS_DIR:-project/sessions}}
SLOTS=('Структура (Iceberg)' 'Три «Почему»' 'Слепые зоны (System Operator)' 'Ловушки сессии')

# Содержимое раздела: строки до следующего заголовка того же или высшего уровня.
section_body() {  # $1 = файл, $2 = заголовок
  awk -v want="$2" '
    /^#{2,4}[[:space:]]/ { inside = (index($0, want) > 0); next }
    inside { print }
  ' "$1" 2>/dev/null
}

# Слот считается заполненным, если в нём есть хоть одна содержательная строка:
# не пустая, не подсказка шаблона в квадратных скобках, не цитата-пояснение.
slot_is_filled() {
  local body=$1 line
  while IFS= read -r line; do
    case "$line" in
      ''|'>'*) continue ;;
      \[*\]) continue ;;
      \[*) continue ;;
    esac
    [ -n "$(printf '%s' "$line" | tr -d '[:space:]')" ] && return 0
  done <<< "$body"
  return 1
}

[ -d "$SESSIONS_DIR" ] || { printf 'сессий ещё нет (%s отсутствует) — проверять нечего\n' "$SESSIONS_DIR"; exit 0; }

shopt -s nullglob
files=("$SESSIONS_DIR"/*/session.md)
if [ ${#files[@]} -eq 0 ]; then
  printf 'записанных сессий пока нет — проверять нечего\n'
  exit 0
fi

# Последняя по имени каталога: каталоги именуются YYYY-MM-DD_тема.
latest=""
for file in "${files[@]}"; do
  [ -z "$latest" ] && latest=$file
  [[ "$file" > "$latest" ]] && latest=$file
done

missing=()
empty=()
for slot in "${SLOTS[@]}"; do
  if ! grep -qF -- "$slot" "$latest"; then
    missing+=("$slot")
    continue
  fi
  slot_is_filled "$(section_body "$latest" "$slot")" || empty+=("$slot")
done

printf 'Проверена сессия: %s. Слотов: %s. Заполнено: %s.\n' \
  "$(basename "$(dirname "$latest")")" "${#SLOTS[@]}" "$(( ${#SLOTS[@]} - ${#missing[@]} - ${#empty[@]} ))"

status=0
if [ ${#missing[@]} -gt 0 ]; then
  printf '\nСЛОТА НЕТ (%s): %s\n' "${#missing[@]}" "$(printf '«%s» ' "${missing[@]}")" >&2
  printf 'Шаблон: .claude/templates/project/session-template.md, раздел «Смыслы (Navigator)».\n' >&2
  if [ ${#missing[@]} -eq ${#SLOTS[@]} ]; then
    printf 'Ни одного слота — вероятно, сессия записана по шаблону до обновления. Для унаследованных это норма: слоты появляются со следующей сессией.\n' >&2
  fi
  status=1
fi
if [ ${#empty[@]} -gt 0 ]; then
  printf '\nСЛОТ ПУСТ (%s): %s\n' "${#empty[@]}" "$(printf '«%s» ' "${empty[@]}")" >&2
  printf 'Нечего сказать — так и напиши («не обнаружены»). Пустой слот неотличим от пропущенного шага.\n' >&2
  status=1
fi
exit $status
