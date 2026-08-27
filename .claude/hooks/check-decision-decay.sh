#!/bin/bash
# Распад решений: действующее решение обязано остаться проверяемым.
#
# Замер (4 боевых проекта, 2026-08-26), 177 решений:
#   · 32 просрочили `review_due` — решение числится действующим, а срок проверки
#     его релевантности прошёл (cracked-lens: 24 из 59);
#   · 85 не имеют `review_due` вовсе — механизма распада (FPF DRR) у них нет,
#     они будут действовать вечно по инерции (healthstat: 56 из 88);
#   · 45 назвали `kill_criteria` и не назвали `metric_for_revisit` — порог отмены
#     объявлен, а мерить его нечем (healthstat 28, wushu 13).
#
# ТРЕТИЙ ВИД КРАСНОГО. Красное бывает трёх видов: снимается прогоном · требует
# правки · **принято как долг человеком, с датой**. Поле `accepted_until` — форма
# третьего: решение признано не лучшим и принято до названной даты. Дата прошла —
# красное вернулось. Долг без даты долгом не является.
#
# Эту работу до 5.2 делал `artifacts/scorecard.md` — таблица порогов, ведомая
# вручную. Он существовал в 2 проектах из 4 и устарел на 30 и 98 дней, потому что
# дублировал поля, которые уже лежат в самих файлах решений. Обход дешевле копии.
#
# Одна работа над одним предметом «решение не протухло молча». Три находки —
# три состояния одного и того же: срок прошёл · срока нет · порог без прибора.
#
# ЗАПУСК: bash .claude/hooks/check-decision-decay.sh [каталог-решений] [дата]
#   exit 0 — все действующие решения проверяемы (или решений нет вовсе)
#   exit 1 — хоть одно протухло, либо разобрать каталог не удалось
#
# Унаследованные решения (принятые до DECAY_ENFORCED_SINCE) перечисляются
# отдельно и прогон не роняют: правило вводится вперёд, а не назад.
#
# Доказательство мутацией: .claude/hooks/check-decision-decay.test.sh

set -uo pipefail

DECISIONS_DIR=${1:-${DECISIONS_DIR:-project/decisions}}
TODAY=${2:-${DECAY_TODAY:-$(date +%F)}}
ENFORCED_SINCE=${DECAY_ENFORCED_SINCE:-2026-08-26}

if [ ! -d "${DECISIONS_DIR}" ]; then
  printf 'каталога решений нет (%s) — проверять нечего\n' "${DECISIONS_DIR}"
  exit 0
fi

# Поле читаем ТОЛЬКО из шапки: та же строка в теле — текст, а не настройка.
field() {  # $1=файл $2=имя поля
  awk 'NR==1 && $0!="---" {exit} NR==1 {next} /^---[[:space:]]*$/ {exit} {print}' "$1" \
    | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//" | tr -d '"'"'" | sed 's/[[:space:]]*$//'
}

# Подсказка шаблона заполнением не считается: иначе гард зеленеет на копии формы.
# Класс пойман на самом шаблоне: `kill_criteria` в нём заполнен фразой-подсказкой.
is_placeholder() {  # $1=значение
  case "$1" in
    ''|'-'|'—'|'TBD'|'tbd') return 0 ;;
    \<*\>|\[*\]) return 0 ;;
    *'Условие, при котором'*|*'DRR — FPF decay'*|*'обязательно если'*) return 0 ;;
    *) return 1 ;;
  esac
}

join_list() { printf '%s, ' "$@" | sed 's/, $//'; }

examined=0
overdue=()
no_review=()
expired_debt=()
threshold_blind=()
undated_list=()
inherited=()

for file in "${DECISIONS_DIR}"/*.md; do
  [ -f "${file}" ] || continue
  name=$(basename "${file}" .md)
  examined=$((examined + 1))

  status=$(field "${file}" status)
  # Считаем только действующие: вытесненное и отклонённое протухнуть не может.
  case "${status}" in
    superseded|deprecated|rejected|proposed) continue ;;
  esac

  proposed=$(field "${file}" date_proposed)
  legacy=false
  undated=false
  if is_placeholder "${proposed}"; then
    # Не уводим в унаследованные: иначе стереть дату станет способом обойти гард.
    undated=true
  elif [[ "${proposed}" < "${ENFORCED_SINCE}" ]]; then
    legacy=true
  fi

  due=$(field "${file}" review_due)
  debt=$(field "${file}" accepted_until)
  kill_cond=$(field "${file}" kill_criteria)
  metric=$(field "${file}" metric_for_revisit)

  findings=()
  if [ "${undated}" = true ]; then
    findings+=("нет даты принятия")
  fi
  if is_placeholder "${due}"; then
    findings+=("нет даты проверки")
  elif [[ "${due}" < "${TODAY}" ]]; then
    findings+=("проверка просрочена с ${due}")
  fi
  if ! is_placeholder "${kill_cond}" && is_placeholder "${metric}"; then
    findings+=("порог отмены назван, метрика — нет")
  fi
  if ! is_placeholder "${debt}" && [[ "${debt}" < "${TODAY}" ]]; then
    findings+=("долг просрочен с ${debt}")
  fi

  [ ${#findings[@]} -eq 0 ] && continue

  if [ "${legacy}" = true ]; then
    inherited+=("${name}")
    continue
  fi

  for f in "${findings[@]}"; do
    case "${f}" in
      'нет даты проверки')            no_review+=("${name}") ;;
      'нет даты принятия')            undated_list+=("${name}") ;;
      'долг просрочен'*)              expired_debt+=("${name} (${f#долг просрочен с })") ;;
      'проверка просрочена'*)         overdue+=("${name} (${f#проверка просрочена с })") ;;
      *)                              threshold_blind+=("${name}") ;;
    esac
  done
done

# Половина «найдено не ноль»: каталог есть, а файлов решений ноль — это отказ
# разбора, а не здоровый проект. Молчаливый ноль читается как «всё чисто».
if [ "${examined}" -eq 0 ]; then
  printf 'ОШИБКА: в %s нет ни одного файла решения — мерить нечего.\n' "${DECISIONS_DIR}" >&2
  printf 'Каталог решений без файлов означает, что решения не фиксировались ни разу.\n' >&2
  exit 1
fi

printf 'Распад решений: осмотрено %s, дата отсчёта %s, правило с %s.\n' \
  "${examined}" "${TODAY}" "${ENFORCED_SINCE}"

if [ ${#inherited[@]} -gt 0 ]; then
  # Прибор, который трудно читать, не читают: печатаем число и первые пять.
  printf 'Унаследованных (заполняются при первом касании): %s. Первые: %s.\n' \
    "${#inherited[@]}" "$(join_list "${inherited[@]:0:5}")"
fi

failed=0

if [ ${#overdue[@]} -gt 0 ]; then
  printf '\nПРОВЕРКА РЕЛЕВАНТНОСТИ ПРОСРОЧЕНА (%s): %s.\n' "${#overdue[@]}" "$(join_list "${overdue[@]}")" >&2
  printf 'Решение числится действующим, а срок его пересмотра прошёл. Либо продли `review_due`\n' >&2
  printf 'с причиной, либо вытесни решение новым — «действует по инерции» третьим вариантом не является.\n' >&2
  failed=1
fi

if [ ${#no_review[@]} -gt 0 ]; then
  printf '\nНЕТ ДАТЫ ПРОВЕРКИ (%s): %s.\n' "${#no_review[@]}" "$(join_list "${no_review[@]}")" >&2
  printf 'Решение без `review_due` действует вечно: механизма распада (FPF DRR) у него нет.\n' >&2
  printf 'Замер: 85 решений из 177 в четырёх проектах — то есть почти половина.\n' >&2
  failed=1
fi

if [ ${#expired_debt[@]} -gt 0 ]; then
  printf '\nДОЛГ ПРОСРОЧЕН (%s): %s.\n' "${#expired_debt[@]}" "$(join_list "${expired_debt[@]}")" >&2
  printf 'Решение было принято как долг до названной даты, и дата прошла — красное\n' >&2
  printf 'вернулось. Пересмотреть решение либо продлить `accepted_until` с причиной.\n' >&2
  failed=1
fi

if [ ${#undated_list[@]} -gt 0 ]; then
  printf '\nНЕТ ДАТЫ ПРИНЯТИЯ (%s): %s.\n' "${#undated_list[@]}" "$(join_list "${undated_list[@]}")" >&2
  printf 'Без `date_proposed` распад посчитать нечем, и решение нельзя отнести к унаследованным.\n' >&2
  failed=1
fi

if [ ${#threshold_blind[@]} -gt 0 ]; then
  printf '\nПОРОГ БЕЗ ПРИБОРА (%s): %s.\n' "${#threshold_blind[@]}" "$(join_list "${threshold_blind[@]}")" >&2
  printf '`kill_criteria` назван, `metric_for_revisit` пуст — отменять решение по чему?\n' >&2
  printf 'Порог, который нечем измерить, отменит решение никогда. Замер: 45 из 177.\n' >&2
  failed=1
fi

[ "${failed}" -eq 0 ] || exit 1
exit 0
