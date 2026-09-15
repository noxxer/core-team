#!/bin/bash
# Память роли, переросшая предел чтения, перестаёт быть памятью — молча.
#
# ТИР: стоп — роль начнёт следующую сессию вслепую
#
# Замер (боевой проект, 2026-08-26): у трёх самых нагруженных ролей файл памяти
# физически не открывается инструментом Read — dev 571.5 КБ, test 334.5 КБ,
# architect 303.5 КБ при жёстком пределе 256 КБ. Активационный ритуал предписывает
# им читать свою память первым делом; у трёх из одиннадцати этот шаг невыполним.
# Агент не падает — он работает без памяти.
#
# Термометр свежести в SessionStart на этих же данных печатал keeper/product/analyst
# и молчал про dev/test/architect: прибор мерил возраст и был слеп к объёму.
# Отсюда вторая работа этого проверщика — объём.
#
# Две работы над одним предметом «память роли пригодна к чтению»:
#   1) ЧИТАЕМОСТЬ — файл открывается целиком (жёсткий предел инструмента, 256 КБ);
#   2) КОНТРАКТ — файл остался СОСТОЯНИЕМ, а не разросся в журнал сессий.
# Журнал — корень: дописывать дешевле, чем переписывать, и дна у ленты нет.
# Место журнала во фреймворке уже занято — `project/sessions/`.
#
# ЗАПУСК: bash .claude/hooks/check-role-memory.sh [каталог-ролей]
#   exit 0 — вся память роли читается и держится в бюджете (или ролей нет вовсе)
#   exit 1 — хоть одна память нечитаема, за бюджетом, ведётся журналом, либо
#            разобрать каталог ролей не удалось
#
# Доказательство мутацией: .claude/hooks/check-role-memory.test.sh

set -uo pipefail

ROLES_DIR=${1:-${ROLES_DIR:-project/roles}}

# Жёсткий предел — свойство инструмента Read, а не настройка проекта: 256 КБ.
# Проверено зондом: файл 268 288 Б отвергается с текстом
# «File content (262KB) exceeds maximum allowed size (256KB)».
HARD_BYTES=${ROLE_MEMORY_HARD_BYTES:-262144}

# Порог тревоги — та же величина с запасом на одну сессию. Гард, который краснеет
# ровно в момент поломки, приходит поздно: файл уже надо разбирать руками.
WARN_BYTES=${ROLE_MEMORY_WARN_BYTES:-$((HARD_BYTES * 4 / 5))}

# Бюджет строк объявлен во фреймворке (`/self-service`, таблица лимитов): 200 строк.
# Проект вправе поднять его на конкретной роли полем `max_lines:` в шапке файла.
BUDGET_LINES=${ROLE_MEMORY_MAX_LINES:-200}

# Датированных заголовков больше этого числа — файл ведётся лентой, а не состоянием.
# Один-два заголовка с датой в документе состояния законны («последние решения»).
JOURNAL_HEADINGS=${ROLE_MEMORY_JOURNAL_HEADINGS:-3}
LEDGER=${LEDGER_FILE:-$(dirname "${ROLES_DIR}")/ledger.md}

# Дата амнистии унаследованного — одна на проект, в шапке ledger (`gates_enforced_since`).
# Ставится `/setup-project` датой заведения и `/upgrade` датой первого обновления;
# окружение GATES_ENFORCED_SINCE сильнее файла (для наборов). Замер аудита 2026-09-14:
# у проекта на 167 сессий 36 стоп-находок, большинство — записи, заведённые до правил.
gates_since() {  # $1 = ledger → дата либо пусто
  if [ -n "${GATES_ENFORCED_SINCE:-}" ]; then printf '%s' "${GATES_ENFORCED_SINCE}"; return 0; fi
  [ -f "$1" ] || return 0
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1" 2>/dev/null \
    | grep -m1 -E '^gates_enforced_since:' | sed -E 's/^gates_enforced_since:[[:space:]]*//; s/"//g' \
    | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true
}
SINCE=$(gates_since "${LEDGER}")

if [ ! -d "${ROLES_DIR}" ]; then
  printf 'каталога ролей нет (%s) — проверять нечего\n' "${ROLES_DIR}"
  exit 0
fi

# Бюджет строк читаем ТОЛЬКО из шапки: число, встреченное в теле, — это текст,
# а не настройка. Форма разбора шапки повторяет check-registry-ceiling.sh.
role_budget() {  # $1 = файл памяти
  local declared
  declared=$(awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1" \
             | grep -m1 -E '^max_lines:' | sed -E 's/^max_lines:[[:space:]]*//; s/[^0-9].*$//')
  case "${declared}" in
    ''|*[!0-9]*) printf '%s' "${BUDGET_LINES}" ;;
    *)           printf '%s' "${declared}" ;;
  esac
}

# `${arr[*]}` склеивает ПЕРВЫМ символом IFS, поэтому «, » им не получить: перечень
# слипается в «a,b,c» и перестаёт читаться. Прибор, который трудно читать, не читают.
join_list() { printf '%s, ' "$@" | sed 's/, $//'; }

examined=0
unreadable=()
approaching=()
over_budget=()
journals=()
legacy_journals=()
legacy_budget=()

for file in "${ROLES_DIR}"/*/context.md; do
  [ -f "${file}" ] || continue
  role=$(basename "$(dirname "${file}")")
  examined=$((examined + 1))

  bytes=$(wc -c < "${file}" | tr -d ' ')
  lines=$(wc -l < "${file}" | tr -d ' ')
  budget=$(role_budget "${file}")
  dated=$(grep -cE '^#{2,3} .*[0-9]{4}-[0-9]{2}-[0-9]{2}' "${file}" || true)

  if [ "${bytes}" -ge "${HARD_BYTES}" ]; then
    unreadable+=("${role} ($((bytes / 1024)) КБ)")
  elif [ "${bytes}" -ge "${WARN_BYTES}" ]; then
    approaching+=("${role} ($((bytes / 1024)) КБ)")
  fi

  # Унаследованный журнал: все датированные заголовки старше даты амнистии — память
  # была лентой до правила, и хук `memory-gate.sh` новых датированных разделов уже не
  # пропускает. Хоть один заголовок новее — лента продолжается, это не наследие.
  # Нечитаемость амнистии не подлежит: роль работает без памяти сегодня, а не в прошлом.
  legacy=no
  if [ -n "${SINCE}" ] && [ "${dated}" -gt 0 ]; then
    newest=$(grep -oE '^#{2,3} .*[0-9]{4}-[0-9]{2}-[0-9]{2}' "${file}" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -1)
    [ -n "${newest}" ] && [[ "${newest}" < "${SINCE}" ]] && legacy=yes
  fi
  if [ "${lines}" -gt "${budget}" ]; then
    if [ "${legacy}" = yes ]; then legacy_budget+=("${role} (${lines} стр.)"); else over_budget+=("${role} (${lines} стр. при бюджете ${budget})"); fi
  fi
  if [ "${dated}" -gt "${JOURNAL_HEADINGS}" ]; then
    if [ "${legacy}" = yes ]; then legacy_journals+=("${role} (заголовков с датой: ${dated}, последний ${newest})"); else journals+=("${role} (заголовков с датой: ${dated})"); fi
  fi
done

# Половина «найдено не ноль»: каталог ролей есть, а разобрано ноль файлов — это
# отказ разбора, а не здоровая команда. Молчаливый ноль читается как «всё чисто».
if [ "${examined}" -eq 0 ]; then
  printf 'ОШИБКА: в %s нет ни одного context.md — мерить нечего.\n' "${ROLES_DIR}" >&2
  printf 'Каталоги ролей без файла памяти означают, что память не заводилась ни разу.\n' >&2
  exit 1
fi

printf 'Память ролей: осмотрено %s, предел чтения %s КБ, бюджет %s строк.\n' \
  "${examined}" "$((HARD_BYTES / 1024))" "${BUDGET_LINES}"

[ ${#approaching[@]} -eq 0 ] || printf 'На подходе к пределу: %s.\n' "$(join_list "${approaching[@]}")"

failed=0

# Унаследованное — в обычный поток: сводка находок читает stderr, и напечатанное туда
# попало бы в «разбирается сейчас» независимо от кода возврата.
if [ ${#legacy_journals[@]} -gt 0 ] || [ ${#legacy_budget[@]} -gt 0 ]; then
  printf '\nУНАСЛЕДОВАННАЯ ПАМЯТЬ (лента до %s, перечислена, прогон не роняет):\n' "${SINCE}"
  [ ${#legacy_journals[@]} -eq 0 ] || printf '  журналом: %s.\n' "$(join_list "${legacy_journals[@]}")"
  [ ${#legacy_budget[@]} -eq 0 ] || printf '  за бюджетом: %s.\n' "$(join_list "${legacy_budget[@]}")"
  printf '  Переписывается срезом состояния при первом касании роли; хронику — в `project/sessions/`.\n'
fi

if [ ${#unreadable[@]} -gt 0 ]; then
  printf '\nПАМЯТЬ НЕ ЧИТАЕТСЯ: %s.\n' "$(join_list "${unreadable[@]}")" >&2
  printf 'Read отказывает выше %s КБ. Роль выполняет активационный ритуал вхолостую:\n' "$((HARD_BYTES / 1024))" >&2
  printf 'не падает, а молча работает без памяти — и дописывает в файл, которого не видела.\n' >&2
  failed=1
fi

if [ ${#journals[@]} -gt 0 ]; then
  printf '\nПАМЯТЬ ВЕДЁТСЯ ЖУРНАЛОМ: %s.\n' "$(join_list "${journals[@]}")" >&2
  printf '`context.md` — СОСТОЯНИЕ роли (фокус, рабочие знания, открытые вопросы), а не лента.\n' >&2
  printf 'Датированные записи о ходе работ живут в `project/sessions/`; у ленты нет дна.\n' >&2
  failed=1
fi

if [ ${#over_budget[@]} -gt 0 ]; then
  printf '\nЗА БЮДЖЕТОМ: %s.\n' "$(join_list "${over_budget[@]}")" >&2
  printf 'Свернуть в состояние, историю — в `project/sessions/`. Бюджет поднимается\n' >&2
  printf 'осознанно полем `max_lines:` в шапке файла, а не молчаливым ростом.\n' >&2
  failed=1
fi

[ "${failed}" -eq 0 ] || exit 1
exit 0
