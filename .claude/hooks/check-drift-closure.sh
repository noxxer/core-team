#!/bin/bash
# Закрытая запись дрейфа не должна вернуться.
#
# Класс A («решение ↔ код») — 70% реестра боевого проекта: 52 открытых и 23 закрытых
# из 107 записей за 24 дня. Ловец для него спроектирован в 5.1 — поле `enforced_by`
# в решении, адрес проверки, делающей нарушение красным. Прогон по 88 решениям того
# же проекта: заполнен у НУЛЯ.
#
# Причина структурная, а не небрежность. Мягкое правило говорило «заполним при первом
# касании», но `project/decisions/**` append-only, и в развёрнутой копии `Edit` по нему
# закрыт `permissions.deny`. Касания не будет никогда — путь недостижим для того
# артефакта, к которому применён. Запись дрейфа остаётся единственным моментом, когда
# решение трогают ПО ДЕЛУ.
#
# Один предмет — «закрытая запись не вернётся». Три отказа:
#   1) ИСТОЧНИК НЕ НАЗВАН — класс A закрыт, а решение, от которого разошлись, не указано;
#   2) ИСТОЧНИК В НИКУДА — назван `DEC-NNN`, файла решения нет;
#   3) ИСТОЧНИК БЕЗ АДРЕСА ПРОВЕРКИ — `enforced_by` пуст: тот же дрейф вернётся.
#
# УСКОРЕНИЕ ВСТРОЕНО, а не приложено:
#   · очередь разблокировки — какие решения освобождают БОЛЬШЕ ВСЕГО открытых записей
#     (замер: одно решение УПОМИНАЕТСЯ в 15 записях реестра — столько же и разблокирует,
#     когда колонка «Источник» заполнена). Заполнил одно поле — закрыл многие;
#   · граница `enforced_since_id:` в шапке — унаследованное перечисляется числом и
#     прогон не роняет: очередь конечна и объявлена;
#   · разбор идёт по КОЛОНКАМ таблицы, а не по прозе: записи длинные, прогон стоит
#     миллисекунды, а не чтение реестра целиком;
#   · осматриваются только те решения, что НАЗВАНЫ в записях, а не все 88;
#   · дешёвая форма адреса законна — «гарда нет — держится на внимании роли <role>»
#     и «неприменимо — <почему>»: одна строка, ноль кода.
#
# ЗАПУСК: bash .claude/hooks/check-drift-closure.sh [реестр] [каталог-решений]
#   exit 0 — закрытые записи класса A закреплены (или реестра нет)
#   exit 1 — есть отказ, либо разобрать реестр не удалось
#
# Доказательство мутацией: .claude/hooks/check-drift-closure.test.sh

set -uo pipefail

REGISTRY=${1:-${REGISTRY_FILE:-project/artifacts/drift-registry.md}}
DECISIONS_DIR=${2:-${DECISIONS_DIR:-project/decisions}}
GUARDED_CLASS=${DRIFT_GUARDED_CLASS:-A}

[ -f "${REGISTRY}" ] || { printf 'реестра дрейфа нет (%s) — проверять нечего\n' "${REGISTRY}"; exit 0; }

header() { awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "${REGISTRY}"; }

since=$(header | grep -m1 -E '^enforced_since_id:' | sed -E 's/^enforced_since_id:[[:space:]]*//; s/[^0-9].*$//')
case "${since}" in ''|*[!0-9]*) since=1 ;; esac

# Половина «найдено не ноль» стоит на разборе: без раздела «Закрытые» мерить нечем.
if ! grep -qE '^## Закрытые' "${REGISTRY}"; then
  printf 'ОШИБКА: в %s нет раздела «Закрытые» — разобрать нечем.\n' "${REGISTRY}" >&2
  printf 'Имя раздела — контракт с этим прибором: переименовали, и он ослеп.\n' >&2
  exit 1
fi

trim() { printf '%s' "$1" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*$//; s/\*+//g; s/`//g'; }
join_list() { printf '%s, ' "$@" | sed 's/, $//'; }

rows_of() {  # $1 = имя раздела; печатает строки-записи по колонкам
  awk -v want="## $1" '
    /<!--/ {c=1} c {if (/-->/) c=0; next}
    $0 == want {inside=1; next}
    /^## / {inside=0}
    inside && /^\|[[:space:]]*\**DR-/ {print}
  ' "${REGISTRY}"
}

# Адрес проверки у решения: читаем только шапку файла решения.
enforced_of() {  # $1 = DEC-NNN
  local num file value
  num=$(printf '%s' "$1" | sed -E 's/^DEC-0*//')
  file=$(ls "${DECISIONS_DIR}"/DEC-0*"${num}"*.md "${DECISIONS_DIR}"/DEC-"${num}"*.md 2>/dev/null | head -1)
  [ -n "${file}" ] || { printf 'НЕТ_ФАЙЛА'; return; }
  value=$(awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "${file}" \
          | grep -m1 -E '^enforced_by:' | sed -E 's/^enforced_by:[[:space:]]*//' | tr -d '"'"'" | sed 's/#.*//; s/[[:space:]]*$//')
  printf '%s' "${value}"
}

no_source=()
dead_source=()
unenforced=()
inherited=0
examined=0

while IFS= read -r row; do
  [ -n "${row}" ] || continue
  id=$(trim "$(printf '%s' "${row}" | cut -d'|' -f2)")
  cls=$(trim "$(printf '%s' "${row}" | cut -d'|' -f3)")
  src=$(trim "$(printf '%s' "${row}" | cut -d'|' -f4)")
  [ "${cls}" = "${GUARDED_CLASS}" ] || continue
  examined=$((examined + 1))

  num=$(printf '%s' "${id}" | sed -E 's/^DR-0*//; s/[^0-9].*$//')
  case "${num}" in ''|*[!0-9]*) num=0 ;; esac
  if [ "${num}" -lt "${since}" ]; then inherited=$((inherited + 1)); continue; fi

  dec=$(printf '%s' "${src}" | grep -oE 'DEC-[0-9]+' | head -1)
  if [ -z "${dec}" ]; then no_source+=("${id}"); continue; fi

  value=$(enforced_of "${dec}")
  case "${value}" in
    'НЕТ_ФАЙЛА') dead_source+=("${id} → ${dec}") ;;
    ''|'-'|'—'|\<*|*\>) unenforced+=("${id} → ${dec}") ;;
  esac
done < <(rows_of 'Закрытые')

# --- Очередь разблокировки: планирование до работы, а не после ---------------
queue=$(while IFS= read -r row; do
  cls=$(trim "$(printf '%s' "${row}" | cut -d'|' -f3)")
  [ "${cls}" = "${GUARDED_CLASS}" ] || continue
  printf '%s' "${row}" | cut -d'|' -f4 | grep -oE 'DEC-[0-9]+'
done < <(rows_of 'Открытые') | sort | uniq -c | sort -rn | head -5)

printf 'Дрейф %s: закрытых класса %s — %s (унаследованных %s), правило с DR-%s.\n' \
  "${REGISTRY}" "${GUARDED_CLASS}" "${examined}" "${inherited}" "${since}"

if [ -n "${queue}" ]; then
  printf '\nОчередь разблокировки — заполни `enforced_by` здесь, и закроются сразу многие:\n'
  printf '%s\n' "${queue}" | while read -r cnt dec; do
    printf '  %-10s разблокирует открытых записей: %s\n' "${dec}" "${cnt}"
  done
fi

failed=0

if [ ${#no_source[@]} -gt 0 ]; then
  printf '\nИСТОЧНИК НЕ НАЗВАН (%s): %s.\n' "${#no_source[@]}" "$(join_list "${no_source[@]}")" >&2
  printf 'Класс %s — это расхождение решения с кодом. Если решения нет, это не класс %s:\n' "${GUARDED_CLASS}" "${GUARDED_CLASS}" >&2
  printf 'смени класс либо напиши в колонке «Источник» причину — «источника нет: дефект\n' >&2
  printf 'без решения за спиной». Пустая ячейка ответом не является.\n' >&2
  failed=1
fi

if [ ${#dead_source[@]} -gt 0 ]; then
  printf '\nИСТОЧНИК ВЕДЁТ В НИКУДА (%s): %s.\n' "${#dead_source[@]}" "$(join_list "${dead_source[@]}")" >&2
  printf 'Названо решение, файла которого нет. Заведи файл по `adr-template.md` или\n' >&2
  printf 'поправь номер: указатель в никуда дороже пустой ячейки — он выглядит как ответ.\n' >&2
  failed=1
fi

if [ ${#unenforced[@]} -gt 0 ]; then
  printf '\nИСТОЧНИК БЕЗ АДРЕСА ПРОВЕРКИ (%s): %s.\n' "${#unenforced[@]}" "$(join_list "${unenforced[@]}")" >&2
  printf 'Запись закрыта, а `enforced_by` у решения пуст: починили один раз, и тот же\n' >&2
  printf 'дрейф вернётся — в этом реестре он уже возвращался.\n' >&2
  printf 'Заполнение стоит одну строку и НЕ обязано быть тестом. Законные формы:\n' >&2
  printf '  · путь до проверки — `tests/test_x.py::test_y`;\n' >&2
  printf '  · «гарда нет — держится на внимании роли <role>»;\n' >&2
  printf '  · «неприменимо — <почему>».\n' >&2
  failed=1
fi

[ "${failed}" -eq 0 ] || exit 1
exit 0
