#!/bin/bash
# Доказательство мутацией для check-filled.sh.
#
# Мир с дефектом — проверка, которая смотрит на структуру и молчит о содержании.
# Ровно так `ledger.md` прошёл боевой прогон с подсказками в квадратных скобках,
# а прибор структуры был зелёным: сессия стартует без ответа «где мы».

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-filled.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=27
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=10  # девятая — артефакты с `artifact_path` в шаблоне не осматриваются;
              # десятая — маркер в обратных кавычках считается подсказкой (пояснение формы краснеет)
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Пара «шаблоны + проект»: подсказки живут в шаблоне, проект их либо заполнил, либо нет.
make_pair() {  # $1..: «имя:содержимое проекта»
  local d entry name body; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/templates" "$d/project"
  # Шаблоны: у каждого своя подсказка и достаточно строк, чтобы diff был осмыслен.
  printf 'last_updated: "YYYY-MM-DD"\n# Состояние\n- Миссия: [зачем существует проект]\n- Цель: [что станет правдой]\n- Шаг: [что делаем]\n' > "$d/templates/ledger.md"
  printf '# Ценности\nСтрока раз\nСтрока два\nСтрока три\n' > "$d/templates/values.md"
  printf '# Словарь\n| Русский | Английский |\n| Термин | term |\n' > "$d/templates/glossary.md"
  printf '# Факты\n- **Тезис:** [утверждение о реальности]\n' > "$d/templates/domain.md"
  # Шаблон реестра объявляет, куда кладётся у потребителя: осмотр идёт по этой карте.
  printf -- '---\nartifact_path: "project/artifacts/risk-registry.md"   # куда кладётся\ncreated: "YYYY-MM-DD"\n---\n# Реестр рисков\n| ID | Статус | Сверка |\n| RISK-001 | Открыт | YYYY-MM-DD |\n' > "$d/templates/risk-registry-template.md"
  mkdir -p "$d/project/artifacts"
  for entry in "$@"; do
    name=${entry%%:*}; body=${entry#*:}
    printf '%b\n' "$body" > "$d/project/$name"
  done
  printf '%s' "$d"
}

run_code() { ( TEMPLATES_DIR="$1/templates" bash "$CHECKER" "$1/project" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( TEMPLATES_DIR="$1/templates" bash "$CHECKER" "$1/project" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

FILLED_LEDGER='last_updated: "2026-08-28"\n# Состояние\n- Миссия: список дел без настройки\n- Цель: первый человек закрыл задачу\n- Шаг: снять ленту'
FILLED_VALUES='# Ценности\nПравда важнее удобства\nОтказ — законный ответ\nПроверка вместо мнения'
FILLED_GLOSSARY='# Словарь\n| Русский | Английский |\n| Задача | task |\n| Отметка | done mark |'
FILLED_DOMAIN='# Факты\n- **Тезис:** три коллеги ведут дела в заметках, а не в трекере'

# --- Здоровое ----------------------------------------------------------------
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
check "все обязательные заполнены" 0 "$(run_code "$P")"
check "число осмотренных названо" "да" "$(says "$(run_out "$P")" "осмотрено: 4")"

# --- Мутация 1: подсказка шаблона осталась на месте ---------------------------
P=$(make_pair "ledger.md:last_updated: \"YYYY-MM-DD\"\n# Состояние\n- Миссия: [зачем существует проект]\n- Цель: своя\n- Шаг: свой" \
              "values.md:$FILLED_VALUES" "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
check "подсказка осталась в ledger" 1 "$(run_code "$P")"
check "…и названо число подсказок" "да" "$(says "$(run_out "$P")" "подсказок не заполнено")"
check "…и указано место — номер строки" "да" "$(says "$(run_out "$P")" "Первая: 1: last_updated")"

# --- Мутация 2: файл скопирован и не тронут (подсказок в нём нет) -------------
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:# Ценности\nСтрока раз\nСтрока два\nСтрока три" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
check "values не отличается от шаблона" 1 "$(run_code "$P")"
check "…и сказано «строк своих: 0»" "да" "$(says "$(run_out "$P")" "строк своих: 0")"
check "…и назван смысл" "да" "$(says "$(run_out "$P")" "прочитает форму вместо содержания")"

# --- Мутация 3: отсутствующий артефакт пропускается ---------------------------
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" "glossary.md:$FILLED_GLOSSARY")
check "обязательного domain.md нет" 1 "$(run_code "$P")"
check "…и сказано, что роль начнёт без него" "да" "$(says "$(run_out "$P")" "начнёт работу без него")"

# --- Мутация 4: данные в скобках приняты за подсказку ------------------------
# `[низкий]`, `[CLM-01]`, `[закрыт → DEC-019]` — данные. Их нет в шаблоне,
# значит подсказками они не являются ни при какой форме.
P=$(make_pair "ledger.md:last_updated: \"2026-08-28\"\n# Состояние\n- Миссия: своя\n- Цель: **OQ-007** [низкий] и holds: [CLM-01]\n- Шаг: [закрыт → DEC-019]" \
              "values.md:$FILLED_VALUES" "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
check "данные в скобках подсказкой не считаются" 0 "$(run_code "$P")"

# --- Мутация 5: образцы в комментарии шаблона считаются подсказками -----------
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
printf '\n<!--\n- **Тезис:** [образец в комментарии]\n-->\n' >> "$P/templates/domain.md"
printf '\n<!--\n- **Тезис:** [образец в комментарии]\n-->\n' >> "$P/project/domain.md"
check "образец в комментарии шаблона не считается" 0 "$(run_code "$P")"

# --- Образец формы в ограждении кода ------------------------------------------
# Мир с дефектом: прибор знал про HTML-комментарий и не знал про ``` — а в Markdown
# ограждение кода и есть привычный способ показать форму. Пять шаблонов фреймворка
# держат образец так. Замер прогона: `domain.md` с разделом «Формат тезиса» краснел
# четырьмя подсказками, которые обязаны там остаться.
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
printf '\n## Формат\n\n```\n- **Тезис:** [утверждение о реальности]\n  **Дата:** YYYY-MM-DD\n```\n' >> "$P/templates/domain.md"
printf '\n## Формат\n\n```\n- **Тезис:** [утверждение о реальности]\n  **Дата:** YYYY-MM-DD\n```\n' >> "$P/project/domain.md"
check "образец в ограждении кода не считается" 0 "$(run_code "$P")"

# Граница: подсказка ВНЕ ограждения ловится по-прежнему — ограждение закрывает
# образец, а не весь файл.
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
printf '\n```\n[образец внутри]\n```\n\n- **Тезис:** [не заполнено]\n' >> "$P/templates/domain.md"
printf '\n```\n[образец внутри]\n```\n\n- **Тезис:** [не заполнено]\n' >> "$P/project/domain.md"
check "подсказка вне ограждения ловится" 1 "$(run_code "$P")"

# --- Мутация 6: нет шаблона — молчание вместо честного «не измерено» ---------
D=$(mktemp -d); TRASH+=("$D"); mkdir -p "$D/templates" "$D/project"
printf '%b\n' "$FILLED_LEDGER" > "$D/project/ledger.md"
printf '%b\n' "$FILLED_VALUES" > "$D/project/values.md"
printf '%b\n' "$FILLED_GLOSSARY" > "$D/project/glossary.md"
printf '%b\n' "$FILLED_DOMAIN" > "$D/project/domain.md"
OUT=$(run_out "$D")
check "шаблонов нет — сказано «не сверено»" "да" "$(says "$OUT" "НЕ СВЕРЕНО")"
check "…и это не «всё в порядке»" "да" "$(says "$OUT" "заполненность не измерена")"

# --- Чекбокс из шаблона подсказкой не считается -------------------------------
# Замер: чеклист первых шагов `- [ ] Провести первую сессию` краснел как
# незаполненная подсказка, хотя его отмечают, а не заполняют.
P=$(make_pair "ledger.md:$FILLED_LEDGER\n- [ ] Провести первую рабочую сессию" \
              "values.md:$FILLED_VALUES" "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
printf -- '- [ ] Провести первую рабочую сессию\n' >> "$P/templates/ledger.md"
check "чекбокс шаблона не считается подсказкой" 0 "$(run_code "$P")"

# --- Половина «найдено не ноль» ----------------------------------------------
E=$(mktemp -d); TRASH+=("$E"); mkdir -p "$E/templates" "$E/project"
check "каталог есть, артефактов ноль" 1 "$(run_code "$E")"
check "…и назван отказ разбора" "да" "$(says "$(run_out "$E")" "не осмотрено ни одного")"

# --- Законная тишина ---------------------------------------------------------
check "каталога проекта нет вовсе" 0 "$(run_code "/nonexistent-$$")"

# --- Необязательный артефакт: осматривается, только если заведён -------------
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN" \
              "claims.md:# Утверждения\n| CLM-01 | своя ставка | замер | опровержение | паспорт | 2026-08-28 |")
check "заведённый необязательный не мешает" 0 "$(run_code "$P")"

# --- Артефакт с шаблоном, у которого объявлен artifact_path ------------------
# Мир с дефектом: прибор смотрел четыре обязательных и молчал о реестрах. Замер
# с мест (ve-health-team, 2026-09-10): строка-образец `RISK-001 … YYYY-MM-DD`
# простояла единственной записью реестра рисков, прибор потолка счёл её открытым
# риском, прибор заполненности был зелёным.
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN" \
              "artifacts/risk-registry.md:---\nartifact_path: \"project/artifacts/risk-registry.md\"\ncreated: \"2026-09-10\"\n---\n# Реестр рисков\n| ID | Статус | Сверка |\n| RISK-001 | Открыт | YYYY-MM-DD |")
check "образец в заведённом реестре — находка" 1 "$(run_code "$P")"
check "…и назван путь от каталога project" "да" "$(says "$(run_out "$P")" "artifacts/risk-registry.md заведён, но остался шаблоном")"
check "…и назван смысл: образец неотличим от записи" "да" "$(says "$(run_out "$P")" "неотличима от записи")"

P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN" \
              "artifacts/risk-registry.md:---\nartifact_path: \"project/artifacts/risk-registry.md\"\ncreated: \"2026-09-10\"\n---\n# Реестр рисков\n| ID | Статус | Сверка |\n| RISK-001 | Открыт | 2026-10-01 |")
check "заполненный реестр проходит и считается осмотренным" "да" "$(says "$(run_out "$P")" "осмотрено: 5")"

# --- Маркер в обратных кавычках — пояснение формы, не подсказка -----------------
# Мир с дефектом: любая строка шаблона с `YYYY-MM-DD` — подсказка. Замер с мест
# (ve-health-team): «дата в форме `YYYY-MM-DD`» из шаблона реестра активов обязана
# остаться в файле дословно, а прибор назвал её незаполненной подсказкой.
P=$(make_pair "ledger.md:$FILLED_LEDGER" "values.md:$FILLED_VALUES" \
              "glossary.md:$FILLED_GLOSSARY" "domain.md:$FILLED_DOMAIN")
printf '%s\n' '# Реестр' '**«Оплачено до»:** дата в форме `YYYY-MM-DD`, либо `—` если бессрочно' '| RISK-001 | Открыт | YYYY-MM-DD |' > "$P/templates/risk-registry-template.md"
sed -i.bak '1i\
---\
artifact_path: "project/artifacts/risk-registry.md"\
---' "$P/templates/risk-registry-template.md" && rm -f "$P/templates/risk-registry-template.md.bak"
printf '%s\n' '---' 'artifact_path: "project/artifacts/risk-registry.md"' '---' '# Реестр' '**«Оплачено до»:** дата в форме `YYYY-MM-DD`, либо `—` если бессрочно' '| RISK-001 | Открыт | 2026-10-01 |' > "$P/project/artifacts/risk-registry.md"
check "маркер в обратных кавычках подсказкой не считается" 0 "$(run_code "$P")"
printf '%s\n' '---' 'artifact_path: "project/artifacts/risk-registry.md"' '---' '# Реестр' '**«Оплачено до»:** дата в форме `YYYY-MM-DD`, либо `—` если бессрочно' '| RISK-001 | Открыт | YYYY-MM-DD |' > "$P/project/artifacts/risk-registry.md"
check "…а тот же маркер без кавычек — подсказка" 1 "$(run_code "$P")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
