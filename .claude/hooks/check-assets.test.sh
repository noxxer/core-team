#!/bin/bash
# Доказательство мутацией для check-assets.sh.
#
# Мир с дефектом — реестр активов без прибора. Файл `resources.md` был заведён
# в 1 проекте из 4, содержал 27 строк и не правился 56 дней: у него не было ни
# одного читателя. При этом правило «секреты не попадают в артефакты» существует
# в security-rules.md с самого начала и до 5.2 не имело ни одной проверки.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-assets.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=37
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

TODAY=2026-08-26
export ASSETS_TODAY="$TODAY"

new_file() { local d; d=$(mktemp -d); TRASH+=("$d"); printf '%s/resources.md' "$d"; }

head_of() {  # $1=файл $2=предупреждение («-» = поля нет)
  local f=$1 warn=$2
  { printf -- '---\nartifact_id: "resources"\n'
    [ "${warn}" = "-" ] || printf 'expiry_warning_days: %s\n' "${warn}"
    printf -- '---\n\n# Активы\n\n## Активы\n\n'
    printf '| ID | Что | Адрес | Тип | Владелец | Оплачено до | Стоимость | Секрет | Как работать |\n'
    printf '|----|-----|-------|-----|----------|-------------|-----------|--------|--------------|\n'
  } > "$f"
}
row() { printf '| %s | что | адрес | тип | %s | %s | 100 | — | %s |\n' "$2" "$3" "$4" "${5:--}" >> "$1"; }

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-54s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-54s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

# --- Здоровый реестр ---------------------------------------------------------
F=$(new_file); head_of "$F" 30; row "$F" ASSET-01 founder 2027-01-01
check "владелец есть, срок далеко" 0 "$(run_code "$F")"
check "…и разобранное названо" "да" "$(says "$(run_out "$F")" "разобрано 1")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-02 facilitator "—"
check "бессрочный актив срока не имеет" 0 "$(run_code "$F")"

# --- Срок --------------------------------------------------------------------
F=$(new_file); head_of "$F" 30; row "$F" ASSET-03 founder 2026-08-25
check "срок прошёл на день" 1 "$(run_code "$F")"
check "…и названа дата" "да" "$(says "$(run_out "$F")" "ASSET-03 (до 2026-08-25)")"
check "…и сказано, что отключается молча" "да" "$(says "$(run_out "$F")" "отключается молча")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-04 founder "$TODAY"
check "срок ровно сегодня — ещё не прошёл" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-05 founder 2026-09-10
check "срок в пределах предупреждения не роняет" 0 "$(run_code "$F")"
check "…но печатается" "да" "$(says "$(run_out "$F")" "Срок наступает: ASSET-05")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-06 founder 2026-10-15
check "срок за пределами предупреждения — тихо" "нет" "$(says "$(run_out "$F")" "Срок наступает")"

# Граница считается от ДАТЫ ОТСЧЁТА, а не от настоящего «сегодня».
F=$(new_file); head_of "$F" 30; row "$F" ASSET-07 founder 2026-09-10
check "при отсчёте в прошлом тот же срок не предупреждает" "нет" \
  "$(says "$(ASSETS_TODAY=2026-07-01 bash "$CHECKER" "$F" 2>&1)" "Срок наступает")"

F=$(new_file); head_of "$F" 5; row "$F" ASSET-08 founder 2026-09-10
check "предупреждение сужается полем шапки" "нет" "$(says "$(run_out "$F")" "Срок наступает")"

F=$(new_file); head_of "$F" -; row "$F" ASSET-09 founder 2026-09-10
check "поля нет — умолчание 30 дней" "да" "$(says "$(run_out "$F")" "Срок наступает")"

# --- Владелец ----------------------------------------------------------------
F=$(new_file); head_of "$F" 30; row "$F" ASSET-10 "" 2027-01-01
check "владельца нет" 1 "$(run_code "$F")"
check "…и сказано, кто такой владелец" "да" "$(says "$(run_out "$F")" "платит и продлевает")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-11 "<роль>" 2027-01-01
check "подсказка формы владельцем не считается" 1 "$(run_code "$F")"

# --- Секрет ------------------------------------------------------------------
F=$(new_file); head_of "$F" 30; row "$F" ASSET-12 founder 2027-01-01
printf '| ASSET-13 | ключ | api_key=sk-live-9f3ab21c77de | услуга | founder | — | 0 | — |\n' >> "$F"
check "значение ключа в реестре" 1 "$(run_code "$F")"
check "…и названо инцидентом с ротацией" "да" "$(says "$(run_out "$F")" "ротируй")"

F=$(new_file); head_of "$F" 30
printf '| ASSET-14 | сервер | 10.0.0.1 | сервер | founder | — | 0 | переменная окружения PROVIDER_KEY |\n' >> "$F"
check "адрес хранилища секретом не считается" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30
printf '| ASSET-15 | сервер | 10.0.0.1 | сервер | founder | — | 0 | менеджер паролей, запись prod-ssh |\n' >> "$F"
check "имя записи в менеджере паролей — не секрет" 0 "$(run_code "$F")"

# Комментарий утечку не оправдывает: файл в git, история помнит и комментарий.
F=$(new_file); head_of "$F" 30; row "$F" ASSET-16 founder 2027-01-01
printf '<!--\n| ASSET-17 | ключ | password: hunter2-very-long-value | услуга | founder | — | 0 | — |\n-->\n' >> "$F"
check "секрет в комментарии тоже находка" 1 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-18 founder 2027-01-01
printf '\nПравило: значение токена в реестре = инцидент.\n' >> "$F"
check "слово «токен» без значения находкой не является" 0 "$(run_code "$F")"

# Имя переменной — это адрес, а не значение. Находка требует ЗНАЧЕНИЯ после имени.
F=$(new_file); head_of "$F" 30
printf '| ASSET-23 | платный вызов | api.provider.tld | услуга | founder | — | 0 | переменная окружения API_KEY |\n' >> "$F"
check "имя переменной API_KEY без значения — не находка" 0 "$(run_code "$F")"

# --- Инструкция к активу -----------------------------------------------------
# Указатель в удалённый файл дороже пустой ячейки: он выглядит как ответ.
F=$(new_file); head_of "$F" 30; row "$F" ASSET-24 founder 2027-01-01 ".claude/hooks/check-assets.sh"
check "инструкция ведёт в существующий файл" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-25 founder 2027-01-01 ".claude/skills/нет-такого/SKILL.md"
check "инструкция ведёт в никуда" 1 "$(run_code "$F")"
check "…и назван адрес" "да" "$(says "$(run_out "$F")" "ASSET-25 → .claude/skills/нет-такого/SKILL.md")"
check "…и сказано, почему это хуже пустой" "да" "$(says "$(run_out "$F")" "выглядит как ответ")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-26 founder 2027-01-01 "—"
check "пустая инструкция находкой не является" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-27 founder 2027-01-01 "ssh prod && make deploy"
check "команда указателем не считается" 0 "$(run_code "$F")"

# --- Разбор ------------------------------------------------------------------
F=$(new_file)
printf -- '---\nexpiry_warning_days: 30\n---\n\n# Активы\n\nбез раздела\n' > "$F"
check "раздела нет — разобрать нечем" 1 "$(run_code "$F")"
check "…и сказано, что имя раздела — контракт" "да" "$(says "$(run_out "$F")" "контракт с этим прибором")"

F=$(new_file); head_of "$F" 30
check "раздел есть, записей ноль — законно" 0 "$(run_code "$F")"
check "…и сказано, что проверить нечего ли" "да" "$(says "$(run_out "$F")" "нечего записать")"

# Число в теле настройкой не является: шапки нет, значение внизу игнорируется.
F=$(new_file); head_of "$F" -; row "$F" ASSET-20 founder 2026-09-10
printf '\nexpiry_warning_days: 1\n' >> "$F"
check "число в теле при пустой шапке не сужает порог" "да" "$(says "$(run_out "$F")" "Срок наступает")"

# Строка внутри комментария записью не является — иначе снятое требование краснеет.
F=$(new_file); head_of "$F" 30; row "$F" ASSET-21 founder 2027-01-01
printf '<!--\n| ASSET-22 | что | адрес | тип |  | 2020-01-01 | 0 | — |\n-->\n' >> "$F"
check "строка в комментарии записью не является" 0 "$(run_code "$F")"

F=$(new_file); head_of "$F" 30; row "$F" ASSET-19 founder 2027-01-01
printf '\n## Снятые\n\n| ASSET-90 | старый | | | | 2026-01-01 | | |\n' >> "$F"
check "соседний раздел не считается" 0 "$(run_code "$F")"

check "файла нет вовсе — тихо" 0 "$(run_code "/nonexistent-assets-$$")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi
printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
