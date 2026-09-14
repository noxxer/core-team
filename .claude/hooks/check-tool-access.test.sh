#!/bin/bash
# Доказательство мутацией для check-tool-access.sh.
#
# Мир с дефектом — проект, который объявил адрес кода и команды доступа к активам, и
# инструмент, которому об этом никто не сказал. Агент не падает: двенадцать правок кода
# уходят обходом через Bash, замер боевой базы состоится на сорок минут позже другим
# путём. Набор обязан быть красным на проверщике, который считает объявление правом.

set -uo pipefail

CHECKER=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-tool-access.sh"}
[ -f "$CHECKER" ] || { printf 'нет файла проверщика: %s\n' "$CHECKER" >&2; exit 1; }

EXPECTED_CASES=27
# Читается снаружи: число случаев сверяется с документацией.
# shellcheck disable=SC2034
MUTATIONS=6   # права считаются выданными без сверки · «.» не исключается из проверки ·
              # шестая — фильтр исполняемого имени снят: проза и имя узла в кавычках читаются как команда
              # образец в HTML-комментарии читается как актив · названная в allow команда
              # всё равно показывается · комментарий jsonc читается как элемент массива
ran=0
failed=0
TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

# Проект: ledger с code_path, файлы настроек, реестр активов — каждое по требованию.
make_project() {  # $1 = строка code_path в шапке («-» = поля нет)
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/project" "$d/.claude"
  {
    printf -- '---\nledger_version: 1\n'
    [ "$1" = "-" ] || printf 'code_path: %s\n' "$1"
    printf -- '---\n# Ledger\n'
  } > "$d/project/ledger.md"
  printf '%s' "$d"
}

settings() {  # $1 = каталог, $2 = имя файла, $3 = содержимое
  printf '%s\n' "$3" > "$1/.claude/$2"
}

assets() {  # $1 = каталог, $2.. = строки таблицы активов
  local d=$1; shift
  {
    printf -- '---\nartifact_id: "resources"\n---\n# Активы\n\n## Активы\n\n'
    printf '| ID | Что это | Адрес | Тип | Владелец | Оплачено до | Стоимость | Где секрет | Как работать |\n'
    printf '|----|---------|-------|-----|----------|-------------|-----------|------------|--------------|\n'
    printf '%s\n' "$@"
    printf '\n## Снятые\n'
  } > "$d/project/resources.md"
}

run_code() { ( bash "$CHECKER" "$1" >/dev/null 2>&1 ); printf '%s' "$?"; }
run_out()  { ( bash "$CHECKER" "$1" 2>&1 ); }

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-56s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-56s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { case "$1" in *"$2"*) printf 'да' ;; *) printf 'нет' ;; esac; }

GRANT='{ "permissions": { "additionalDirectories": ["../code"] } }'
NOGRANT='{ "permissions": { "deny": ["Write(.claude/hooks/**)"] } }'

# --- Здоровое ----------------------------------------------------------------
P=$(make_project '"../code"'); settings "$P" settings.json "$GRANT"
check "code_path назван в settings.json" 0 "$(run_code "$P")"
check "…и объявленный путь напечатан" "да" "$(says "$(run_out "$P")" "code_path «../code»")"

P=$(make_project '"../code"'); settings "$P" settings.json "$NOGRANT"; settings "$P" settings.local.json "$GRANT"
check "code_path назван только в settings.local.json" 0 "$(run_code "$P")"

# --- Мутация 1: объявление принимается за право ---------------------------------
P=$(make_project '"../code"'); settings "$P" settings.json "$NOGRANT"
check "code_path объявлен, прав нет" 1 "$(run_code "$P")"
check "…и назван ключ additionalDirectories" "да" "$(says "$(run_out "$P")" "additionalDirectories")"
check "…и названа цена — правки обходом" "да" "$(says "$(run_out "$P")" "обходом")"

P=$(make_project '"../code"')
check "файлов настроек нет вовсе — прав нет" 1 "$(run_code "$P")"

# --- Половина «найдено не ноль» и корень ------------------------------------------
P=$(make_project '""'); settings "$P" settings.json "$NOGRANT"
check "code_path пуст, команд нет — проверять нечего" 0 "$(run_code "$P")"
check "…и это сказано, а не «в порядке»" "да" "$(says "$(run_out "$P")" "проверять нечего")"

P=$(make_project '-')
check "поля code_path нет вовсе" 0 "$(run_code "$P")"

# --- Мутация 2: корень проекта не исключён ---------------------------------------
P=$(make_project '"."'); settings "$P" settings.json "$NOGRANT"
check "code_path «.» — корень доступен и так" 0 "$(run_code "$P")"

# --- Форма значения -------------------------------------------------------------
P=$(make_project '"../code"   # код лежит рядом'); settings "$P" settings.json "$GRANT"
check "комментарий после значения не мешает" 0 "$(run_code "$P")"

P=$(make_project '"../code/"'); settings "$P" settings.json '{ "permissions": { "additionalDirectories": ["./../code"] } }'
check "хвостовой слэш и ./ — один адрес" 0 "$(run_code "$P")"

# --- Мутация 5: комментарий jsonc читается как элемент --------------------------
P=$(make_project '"../code"')
settings "$P" settings.json '{
  "permissions": {
    "additionalDirectories": [
      // "../code",
      "../other"
    ]
  }
}'
check "закомментированный путь правом не является" 1 "$(run_code "$P")"

# --- Команды доступа в активах ----------------------------------------------------
SSH_ROW='| ASSET-03 | Прод-сервер | 10.0.0.1 | сервер | founder | — | 900 ₽/мес | менеджер паролей | `ssh kulikov@10.0.0.1` |'

P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"; assets "$P" "$SSH_ROW"
check "команда без allow — не отказ" 0 "$(run_code "$P")"
check "…но показана" "да" "$(says "$(run_out "$P")" "ДОСТУП БЕЗ РАЗРЕШЕНИЯ ИНСТРУМЕНТА (1): ASSET-03 → ssh")"
check "…и назван settings.local.json" "да" "$(says "$(run_out "$P")" "settings.local.json")"

# --- Мутация 4: разрешённая команда всё равно показывается -----------------------
P=$(make_project '-'); settings "$P" settings.local.json '{ "permissions": { "allow": ["Bash(ssh:*)"] } }'; assets "$P" "$SSH_ROW"
check "команда названа в allow — показа нет" "нет" "$(says "$(run_out "$P")" "ДОСТУП БЕЗ РАЗРЕШЕНИЯ")"
check "…а счётчик команд назван" "да" "$(says "$(run_out "$P")" "команд доступа в активах 1")"

P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '| ASSET-05 | Стенд | staging.example.ru | стенд | facilitator | — | — | — | `project/artifacts/stand-runbook.md` |'
check "путь в «Как работать» командой не считается" "да" "$(says "$(run_out "$P")" "проверять нечего")"

# --- Мутация 3: образец в комментарии читается как актив -------------------------
P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '<!-- Образцы формы' "$SSH_ROW" '-->'
check "строка в HTML-комментарии активом не является" "да" "$(says "$(run_out "$P")" "проверять нечего")"

# --- Оба предмета разом -------------------------------------------------------------
P=$(make_project '"../code"'); settings "$P" settings.json "$NOGRANT"; assets "$P" "$SSH_ROW"
OUT=$(run_out "$P")
check "код без прав и команда без allow — отказ и показ" "дада" "$(says "$OUT" "CODE_PATH БЕЗ ПРАВ")$(says "$OUT" "ДОСТУП БЕЗ РАЗРЕШЕНИЯ")"

# --- Безвредность --------------------------------------------------------------------
E=$(mktemp -d); TRASH+=("$E")
check "каталога project нет вовсе" 0 "$(run_code "$E")"

# --- Команда узнаётся по имени и аргументам, а не по первым кавычкам ------------
# Мир с дефектом: «первое слово в кавычках» — и боевой прогон по lotus-pro-team дал
# четыре показа из четырёх ложными: «лендинг», «Выкладка», «нужна», `ns1.gcorelabs.net`.
P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '| ASSET-20 | Лендинг | example.ru | домен | founder | — | — | — | Поднят как `лендинг на статике`, правится в репозитории |'
check "кириллица в кавычках — не команда" "да" "$(says "$(run_out "$P")" "проверять нечего")"

P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '| ASSET-21 | DNS | example.ru | домен | founder | — | — | — | Зона у GCore (`ns1.gcorelabs.net, ns2.gcdn.services`), записи правятся там |'
check "имя узла в кавычках — не команда" "да" "$(says "$(run_out "$P")" "проверять нечего")"

P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '| ASSET-22 | DNS | example.ru | домен | founder | — | — | — | Зона у GCore (`ns1.gcorelabs.net`). Проверка: `dig +short @ns1.gcorelabs.net example.ru A` |'
check "команда второй кавычкой в ячейке прочитана" "да" "$(says "$(run_out "$P")" "ASSET-22 → dig")"

P=$(make_project '-'); settings "$P" settings.json "$NOGRANT"
assets "$P" '| ASSET-23 | База | db.internal | база | founder | — | — | — | Вход: `psql` с машины стенда |'
check "имя без аргументов из списка — команда" "да" "$(says "$(run_out "$P")" "ASSET-23 → psql")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s — тест проверил не всё, что обязан\n' "$ran" "$EXPECTED_CASES"
  failed=$((failed + 1))
fi

printf '\nпроверщик: %s\nслучаев: %s, провалено: %s\n' "$CHECKER" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
