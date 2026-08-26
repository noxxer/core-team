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
  local body=$1 line in_hint=0
  while IFS= read -r line; do
    # Подсказка шаблона занимает СКОЛЬКО УГОДНО строк: `[` открывает, `]` закрывает.
    # Продолжение подсказки со скобки не начинается — и раньше считалось содержимым.
    # Замер: сессия, скопированная из шаблона один в один, показывала «Заполнено: 1»
    # из четырёх, потому что у слота «Ловушки сессии» подсказка в две строки.
    if [ "$in_hint" -eq 1 ]; then
      case "$line" in *']'*) in_hint=0 ;; esac
      continue
    fi
    case "$line" in
      ''|'>'*) continue ;;
      \[*\]) continue ;;
      \[*) in_hint=1; continue ;;
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

# --- Вторая работа: контракт сессии ------------------------------------------
# Замер: сессия без объявленного условия выхода заканчивается там, где кончилось
# внимание, а не там, где готов результат. Проверяем не формулировку, а факт:
# условие заявлено и по нему вынесен вердикт. Подсказка шаблона в квадратных
# скобках заполнением не считается — как и у слотов смыслов.
exit_problems=()
if grep -qF -- 'Условие выхода' "$latest"; then
  for field in 'Заявлено' 'Достигнуто'; do
    value=$(grep -m1 -E "^[[:space:]]*[-*][[:space:]]*\*\*${field}:\*\*" "$latest" \
            | sed -E "s/^[[:space:]]*[-*][[:space:]]*\*\*${field}:\*\*[[:space:]]*//")
    case "${value}" in
      ''|\[*) exit_problems+=("${field}") ;;
    esac
  done
else
  exit_problems+=('раздела нет')
fi

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

# Унаследованную сессию (шаблон до обновления) не роняем дважды: если слотов нет
# ни одного, раздела условия выхода там тоже быть не может.
if [ ${#missing[@]} -ne ${#SLOTS[@]} ] && [ ${#exit_problems[@]} -gt 0 ]; then
  printf '\nУСЛОВИЕ ВЫХОДА НЕ ЗАПИСАНО (%s): %s\n' "${#exit_problems[@]}" "$(printf '«%s» ' "${exit_problems[@]}")" >&2
  printf 'Сессия без объявленного условия заканчивается там, где кончилось внимание.\n' >&2
  printf 'Условие называется В НАЧАЛЕ и проверяемо: «ревью clean и коммит», а не «поработать над фичей».\n' >&2
  status=1
fi
exit $status
