#!/bin/bash
# Доказательство мутацией для check-decision-decay.sh.
#
# Мир с дефектом — таблица порогов, ведомая руками рядом с файлами решений.
# Ровно так `artifacts/scorecard.md` существовал в 2 проектах из 4 и устарел на
# 30 и 98 дней, пока в самих решениях 32 просрочили проверку релевантности,
# 85 не имели её вовсе, а 45 назвали порог отмены без прибора.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-decision-decay.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=34
# Читается снаружи: `check-install-integrity.sh` сверяет это число с документацией.
# shellcheck disable=SC2034
MUTATIONS=10
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

TODAY=2026-08-26
export DECAY_TODAY="$TODAY"
export DECAY_ENFORCED_SINCE=2026-08-26

new_dir() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s' "$d"; }

# $1=каталог $2=имя $3=status $4=date_proposed $5=review_due $6=kill $7=metric
add_dec() {
  local dir=$1 name=$2
  { printf -- '---\n'
    printf 'decision_id: "%s"\n' "$name"
    printf 'status: "%s"\n' "$3"
    printf 'date_proposed: "%s"\n' "$4"
    printf 'review_due: "%s"\n' "$5"
    printf 'kill_criteria: "%s"\n' "$6"
    printf 'metric_for_revisit: "%s"\n' "$7"
    printf -- '---\n\n# %s\n\nтекст решения\n' "$name"
  } > "${dir}/${name}.md"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровые решения --------------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-001 accepted 2026-08-26 2026-12-01 "отток выше 20%" "недельный отток"
check "срок в будущем, порог с прибором" 0 "$(run_code "$D")"
check "…и осмотренное названо" "да" "$(says "$(run_out "$D")" "осмотрено 1")"

D=$(new_dir); add_dec "$D" DEC-002 accepted 2026-08-26 "$TODAY" "" ""
check "срок ровно сегодня — не просрочен" 0 "$(run_code "$D")"

D=$(new_dir); add_dec "$D" DEC-003 superseded 2026-08-26 "" "" ""
check "вытесненное решение устареть не может" 0 "$(run_code "$D")"
D=$(new_dir); add_dec "$D" DEC-004 proposed 2026-08-26 "" "" ""
check "предложенное ещё не действует" 0 "$(run_code "$D")"

# --- Просроченная проверка ---------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-005 accepted 2026-08-26 2026-08-25 "" "недельный отток"
check "проверка просрочена на день" 1 "$(run_code "$D")"
check "…и названа дата" "да" "$(says "$(run_out "$D")" "DEC-005 (2026-08-25)")"
check "…и назван третий вариант как несуществующий" "да" "$(says "$(run_out "$D")" "по инерции")"

# --- Нет даты проверки -------------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-006 accepted 2026-08-26 "" "" ""
check "review_due пуст" 1 "$(run_code "$D")"
check "…и назван механизм распада" "да" "$(says "$(run_out "$D")" "НЕТ ДАТЫ ПРОВЕРКИ")"

D=$(new_dir); add_dec "$D" DEC-007 accepted 2026-08-26 "<YYYY-MM-DD>" "" ""
check "подсказка шаблона заполнением не считается" 1 "$(run_code "$D")"

# --- Порог без прибора -------------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-008 accepted 2026-08-26 2026-12-01 "отток выше 20%" ""
check "порог назван, метрика пуста" 1 "$(run_code "$D")"
check "…и назван вопрос «отменять по чему»" "да" "$(says "$(run_out "$D")" "ПОРОГ БЕЗ ПРИБОРА")"

D=$(new_dir); add_dec "$D" DEC-009 accepted 2026-08-26 2026-12-01 "Условие, при котором решение отменяется (DRR — FPF decay)" ""
check "порог из шаблона порогом не считается" 0 "$(run_code "$D")"

D=$(new_dir); add_dec "$D" DEC-010 accepted 2026-08-26 2026-12-01 "отток выше 20%" "<метрика>"
check "метрика-подсказка прибором не считается" 1 "$(run_code "$D")"

# --- Третий вид красного: долг с датой ---------------------------------------
add_debt() { printf 'accepted_until: "%s"\n' "$2" >> "$1"; }

D=$(new_dir); add_dec "$D" DEC-020 accepted 2026-08-26 2026-12-01 "" ""
sed -i.bak "s/^review_due:/accepted_until: \"2026-12-01\"\nreview_due:/" "$D/DEC-020.md" && rm -f "$D/DEC-020.md.bak"
check "долг с будущей датой не роняет" 0 "$(run_code "$D")"

D=$(new_dir); add_dec "$D" DEC-021 accepted 2026-08-26 2026-12-01 "" ""
sed -i.bak "s/^review_due:/accepted_until: \"2026-08-25\"\nreview_due:/" "$D/DEC-021.md" && rm -f "$D/DEC-021.md.bak"
check "долг с прошедшей датой роняет" 1 "$(run_code "$D")"
check "…и назван как долг" "да" "$(says "$(run_out "$D")" "ДОЛГ ПРОСРОЧЕН")"
check "…и названа дата" "да" "$(says "$(run_out "$D")" "DEC-021 (2026-08-25)")"

# --- Нет даты принятия: обходной путь закрыт ---------------------------------
D=$(new_dir); add_dec "$D" DEC-011 accepted "" "" "" ""
check "дата принятия стёрта — не уходит в унаследованные" 1 "$(run_code "$D")"
check "…и сказано, чего посчитать нечем" "да" "$(says "$(run_out "$D")" "НЕТ ДАТЫ ПРИНЯТИЯ")"

# --- Унаследованные ----------------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-012 accepted 2026-07-01 "" "" ""
check "решение до введения правила не роняет" 0 "$(run_code "$D")"
check "…и названо унаследованным" "да" "$(says "$(run_out "$D")" "Унаследованных (заполняются")"

D=$(new_dir); for i in 1 2 3 4 5 6 7; do add_dec "$D" "DEC-10$i" accepted 2026-07-01 "" "" ""; done
check "семь унаследованных — всё ещё тихо" 0 "$(run_code "$D")"
check "…и печатается число, а не все имена" "да" "$(says "$(run_out "$D")" "касании): 7.")"
add_dec "$D" DEC-200 accepted 2026-08-26 "" "" ""
check "одно новое среди унаследованных роняет" 1 "$(run_code "$D")"

# --- Шапка, а не тело --------------------------------------------------------
D=$(new_dir); add_dec "$D" DEC-013 accepted 2026-08-26 "" "" ""
printf '\nreview_due: 2026-12-01\n' >> "$D/DEC-013.md"
check "review_due в теле настройкой не является" 1 "$(run_code "$D")"

# --- Половина «найдено не ноль» ----------------------------------------------
# Свежий проект: каталог решений создан, решений ещё нет — это законно.
# Замер: прежняя версия краснела на первом же `/end-session` нового проекта.
D=$(new_dir)
check "каталог есть, решений нет — законно" 0 "$(run_code "$D")"
check "…и сказано, что проект только развёрнут" "да" "$(says "$(run_out "$D")" "только развёрнут")"
check "каталога нет вовсе — тихо" 0 "$(run_code "/nonexistent-decisions-$$")"

# --- YAML-комментарий не является значением -----------------------------------
# Мир с дефектом: шаблон решения комментирует почти каждое поле, а разбор брал
# строку целиком. Замер прогона: решение, заведённое из штатного `adr-template.md`,
# дало две ложных находки подряд — пустое `accepted_until: ""  # ТРЕТИЙ ВИД…`
# сочлось заполненным и объявлено просроченным долгом, а заполненное
# `metric_for_revisit: "ставка…"  # обязательно если…` — пустым.
D=$(new_dir)
{ printf -- '---\n'
  printf 'decision_id: "DEC-301"\n'
  printf 'status: "accepted"\n'
  printf 'date_proposed: "2026-09-01"\n'
  printf 'review_due: "2027-01-01"\n'
  printf 'accepted_until: ""        # ТРЕТИЙ ВИД КРАСНОГО. Заполняется, если решение принято\n'
  printf 'kill_criteria: "ставка выше 32 000 за м²"\n'
  printf 'metric_for_revisit: "ставка аренды за м² в год"  # обязательно если решение выбирает инвариант\n'
  printf -- '---\n\n# DEC-301\n'
} > "$D/DEC-301.md"
check "комментарий не делает пустое поле заполненным" 0 "$(run_code "$D")"
check "…и заполненное — пустым" "нет" "$(says "$(run_out "$D")" "ПОРОГ БЕЗ ПРИБОРА")"
check "…и долг не объявляется просроченным" "нет" "$(says "$(run_out "$D")" "ДОЛГ ПРОСРОЧЕН")"

# Граница: настоящий просроченный долг ловится по-прежнему.
D=$(new_dir)
{ printf -- '---\ndecision_id: "DEC-302"\nstatus: "accepted"\ndate_proposed: "2026-09-01"\n'
  printf 'review_due: "2027-01-01"\naccepted_until: "2026-01-01"  # взяли долг\n'
  printf 'kill_criteria: "-"\nmetric_for_revisit: "-"\n---\n\n# DEC-302\n'
} > "$D/DEC-302.md"
check "настоящий просроченный долг ловится" 1 "$(run_code "$D")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
