#!/bin/bash
# Аббревиатура означает одно и то же во всех текстах поставки.
#
# ТИР: копия — про целостность поставки, а не про проект
#
# Замер, из которого вырос прибор (отчёт с мест, lotus-pro-team + ai_learn, 5.3.1,
# воспроизведён дословно на 5.3.3): `DRR` был расшифрован ЧЕТЫРЬМЯ способами в
# 13 файлах — `Design-Rationale Record` (канон FPF E.9), `Decision Revision Request`,
# `Decision Relevance Rate` и `Decay Review Rule`. Самое частое значение взято из
# чужого словаря: распад подтверждения в FPF зовётся `Evidence Decay` (B.3.4), а
# не `DRR`. Нарушение A.1.1 внутри инструмента, который A.1.1 проповедует; читатель
# встречает расхождение каждую сессию, а спросить «сколько у нас расшифровок» негде.
#
# Один предмет — «у аббревиатуры одна расшифровка», два отказа:
#   1. у одной аббревиатуры найдено ≥2 разных расшифровки;
#   2. разобрано ноль расшифровок — половина «найдено не ноль».
#
# ЧТО СЧИТАЕТСЯ РАСШИФРОВКОЙ. Текст сразу за аббревиатурой — в скобках `DRR (…)`,
# после тире `DRR — …` или перед скобкой `… (DRR)`, — **начальные буквы которого
# складываются в саму аббревиатуру**. Это определение расшифровки, а не эвристика,
# и оно снимает нужду в белых списках: `TDD (Kent Beck)`, `ADR (append-only)`,
# `SQL (Django)` — пояснения рядом, а не расшифровки, и прибор их не трогает.
# Короткое служебное слово в нижнем регистре пропускается: `Society for Human
# Resource Management` = SHRM. Дефис читается как пробел: `Design-Rationale Record`
# и `Design Rationale Record` — одна расшифровка, а не две.
#
# ГРАНИЦА. Глосса на другом языке («DRR — распад решений») распознан не будет:
# у кириллической фразы начальные буквы в латинскую аббревиатуру не складываются
# по устройству. Это объявленный предел, а не пропуск: прибор ловит расхождение
# РАСШИФРОВОК, и трёх латинских расшифровок DRR хватило, чтобы покраснеть.
# Лечение расхождения — переименовать, а не завести исключение: две расшифровки
# одной аббревиатуры и есть болезнь, белый список её узаконил бы.
#
# ЗАПУСК: bash .claude/hooks/check-abbreviations.sh [корень]
#   exit 0 — каждая аббревиатура расшифрована одинаково
#   exit 1 — расшифровки разошлись, либо разбирать оказалось нечего
#
# Доказательство мутацией: .claude/hooks/check-abbreviations.test.sh

set -uo pipefail

ROOT=${1:-.}
[ -d "${ROOT}/.claude" ] || { printf 'нет каталога .claude в %s — проверять нечего\n' "${ROOT}"; exit 1; }

SCAN=("${ROOT}/.claude")
[ -d "${ROOT}/plugins" ] && SCAN+=("${ROOT}/plugins")

# Три формы кандидата. Латиница в расшифровке — намеренно (см. ГРАНИЦА выше).
candidates() {
  grep -rnoE '\b[A-Z][A-Z0-9]{1,5} \([A-Za-z][A-Za-z -]{3,60}\)' --include='*.md' "${SCAN[@]}" 2>/dev/null
  grep -rnoE '\b[A-Z][A-Z0-9]{1,5} — [A-Za-z][A-Za-z -]{3,60}' --include='*.md' "${SCAN[@]}" 2>/dev/null
  grep -rnoE '\b[A-Z][A-Za-z -]{3,60} \([A-Z][A-Z0-9]{1,5}\)' --include='*.md' "${SCAN[@]}" 2>/dev/null
}

report=$(candidates | awk -F':' '
  # Начальные буквы слов. Считаются ДВЕ формы, и годится любая: служебное слово
  # в нижнем регистре то входит в аббревиатуру, то нет, и одной формулы не хватает.
  #   строгая  — все слова: "time to live" = TTL
  #   с пропуском короткого служебного — "Society for Human Resource Management" = SHRM
  # Обе должны совпасть ТОЧНО, поэтому «Decay of Decisions» (DOD либо DD) не станет
  # расшифровкой DRR ни по одной из форм — глосса остаётся глоссой.
  function initials(words, skip,   n, i, w, out, parts) {
    n = split(words, parts, " ")
    out = ""
    for (i = 1; i <= n; i++) {
      w = parts[i]
      if (w == "") continue
      if (skip && i > 1 && length(w) <= 3 && w == tolower(w)) continue
      out = out toupper(substr(w, 1, 1))
    }
    return out
  }
  function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
  {
    file = $1; line = $2
    text = $0
    sub(/^[^:]*:[^:]*:/, "", text)

    abbr = ""; rest = ""
    if (match(text, /^[A-Z][A-Z0-9]+ \(/)) {                    # DRR (Design-Rationale Record)
      abbr = substr(text, 1, RLENGTH - 2)
      rest = substr(text, RLENGTH + 1)
      sub(/\).*$/, "", rest)
    } else if (match(text, /^[A-Z][A-Z0-9]+ — /)) {             # DRR — Design-Rationale Record
      abbr = substr(text, 1, RLENGTH - 5)
      rest = substr(text, RLENGTH + 1)
    } else if (match(text, / \([A-Z][A-Z0-9]+\)$/)) {           # Design-Rationale Record (DRR)
      abbr = substr(text, RSTART + 2, RLENGTH - 3)
      rest = substr(text, 1, RSTART - 1)
    } else next

    gsub(/-/, " ", rest)
    gsub(/  +/, " ", rest)
    rest = trim(rest)
    if (rest == "" || index(rest, " ") == 0) next
    if (initials(rest, 0) != toupper(abbr) && initials(rest, 1) != toupper(abbr)) next

    key = toupper(abbr) SUBSEP tolower(rest)
    if (key in seen) next
    seen[key] = 1
    count[toupper(abbr)]++
    where[key] = file ":" line
    text_of[toupper(abbr)] = text_of[toupper(abbr)] "    · «" rest "» — " file ":" line "\n"
    parsed++
  }
  END {
    printf "РАЗОБРАНО %d\n", parsed
    for (a in count) if (count[a] > 1) printf "РАСХОЖДЕНИЕ %s %d\n%s", a, count[a], text_of[a]
  }
')

parsed=$(printf '%s\n' "${report}" | awk '/^РАЗОБРАНО /{print $2; exit}')
[ -n "${parsed}" ] || parsed=0

if [ "${parsed}" -eq 0 ]; then
  printf 'Разобрано ноль расшифровок — проверять оказалось нечего.\n' >&2
  printf 'Половина «найдено не ноль»: пустой разбор это отказ, а не здоровая поставка.\n' >&2
  printf 'Смотри, дошли ли до прибора файлы: %s\n' "${SCAN[*]}" >&2
  exit 1
fi

divergent=$(printf '%s\n' "${report}" | grep -c '^РАСХОЖДЕНИЕ ' || true)

if [ "${divergent}" -gt 0 ]; then
  printf 'РАСШИФРОВКИ РАЗОШЛИСЬ: %s аббревиатур(ы)\n\n' "${divergent}" >&2
  printf '%s\n' "${report}" | awk '/^РАСХОЖДЕНИЕ /{printf "  %s — расшифровок: %s\n", $2, $3; next} /^    · /{print}' >&2
  printf '\nЛечение: выбрать одну расшифровку и переименовать остальные.\n' >&2
  printf 'Аббревиатура из чужого словаря (FPF, OWASP) берётся в его значении:\n' >&2
  printf 'канон — `.claude/knowledge/fpf/glossary.md`, проектный — `project/glossary.md`.\n' >&2
  printf 'Белого списка нет намеренно: две расшифровки одной аббревиатуры и есть болезнь.\n' >&2
  exit 1
fi

printf 'Расшифровки не расходятся: разобрано %s, аббревиатур с двумя значениями нет.\n' "${parsed}"
exit 0
