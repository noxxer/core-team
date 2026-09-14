#!/bin/bash
# Доказательство мутацией для upgrade.sh (и миграций, которые он исполняет).
#
#   bash .claude/hooks/upgrade.test.sh                      # текущий прибор
#   bash .claude/hooks/upgrade.test.sh /tmp/mutant.sh        # обязан упасть
#
# Мутации, каждая роняет хотя бы один случай:
#   M1 список «своего» игнорируется (is_kept → 1)          → «своё остаётся», «upgrade.keep»
#   M2 предпросмотр применяет (снята проверка APPLY)          → «предпросмотр ничего не трогает»
#   M3 откат снят (красная целостность игнорируется)          → «красная целостность — откат»
#   M4 миграции выше целевой версии исполняются (ver_le снят) → «миграция выше цели не идёт»
#   M5 раздел «Текущий проект» не переносится                 → «CLAUDE.md: новое сверху, проект ваш»
#   M6 остатки прежних версий не удаляются                    → «убранное из поставки удалено»
#   M7 settings.json не сливается (берётся ваш как есть)       → «settings: hooks сверху, ключи ваши»
#   M8 убранное потребителем возвращается как новое             → «убранное вами не возвращается»
#   M9 предпросмотр не предсказывает целостность                → «предпросмотр предсказывает красную целостность»
#   M10 нетронутые opt-in роли не обновляются из шаблона        → «нетронутая opt-in роль обновлена»
#
# Сеть не нужна: поставкой служит локальный git с тегами; миграции — настоящие, из репозитория.

set -uo pipefail

HOOK=${1:-"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/upgrade.sh"}
[ -f "$HOOK" ] || { printf 'нет файла прибора: %s\n' "$HOOK" >&2; exit 1; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

EXPECTED_CASES=43
# shellcheck disable=SC2034
MUTATIONS=10
ran=0; failed=0; TRASH=()
cleanup() { [ ${#TRASH[@]} -eq 0 ] || rm -rf "${TRASH[@]}"; }
trap cleanup EXIT

check() {
  ran=$((ran + 1))
  if [ "$3" = "$2" ]; then printf 'PASS  %-52s ожидание %s\n' "$1" "$2"
  else printf 'FAIL  %-52s ожидание %s, получено %s\n' "$1" "$2" "$3"; failed=$((failed + 1)); fi
}
says() { grep -qF -- "$2" <<< "$1" && printf 'да' || printf 'нет'; }
gitc() { git -C "$1" -c user.email=t@t -c user.name=t "${@:2}"; }
edit_inplace() {  # $1 = sed-выражение, $2 = файл — без `sed -i`, у BSD и GNU разная форма
  local tmp; tmp=$(mktemp); sed "$1" "$2" > "$tmp" && cat "$tmp" > "$2"; rm -f "$tmp"
}

# --- Поставка: v5.3.0 → v5.4.0 -----------------------------------------------------------
make_source() {
  local d; d=$(mktemp -d); TRASH+=("$d")
  mkdir -p "$d/.claude/hooks" "$d/.claude/agents" "$d/.claude/commands" "$d/.claude/output-styles" \
           "$d/.claude/knowledge/dpf" "$d/.claude/templates/project"
  printf '5.3.0\n' > "$d/.claude/VERSION"
  cat > "$d/.claude/CLAUDE.md" <<'MD'
# Core Team Framework

## Текущий проект

**Название:** _не настроен_
**Тип:** _не настроен_

## Роли

- старое правило
MD
  printf '#!/bin/bash\necho old\n' > "$d/.claude/hooks/session-start.sh"
  printf '#!/bin/bash\nprintf "Проверено пунктов: 1. Расхождений: 0.\\n"\n' > "$d/.claude/hooks/check-install-integrity.sh"
  chmod +x "$d/.claude/hooks/"*.sh
  cat > "$d/.claude/settings.json" <<'JSON'
{ "env": { "A": "1" }, "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] } ] } }
JSON
  printf 'facilitator v1\n' > "$d/.claude/agents/facilitator.md"
  printf 'plan v1\n' > "$d/.claude/commands/plan.md"
  printf 'style v1\n' > "$d/.claude/output-styles/core-team.md"
  printf 'dpf v1\n' > "$d/.claude/knowledge/dpf/facilitation.md"
  printf '| точка | чем закрыта |\n' > "$d/.claude/templates/project/connection-points.md"
  mkdir -p "$d/.claude/templates/roles/optional"
  printf 'guardian t1\n' > "$d/.claude/templates/roles/optional/guardian.md"
  printf 'product t1\n' > "$d/.claude/templates/roles/optional/product.md"
  printf '# Changelog\n\n## [5.3.0] — 2026-08-28 — «Язык системы»\n\n> старая запись\n' > "$d/CHANGELOG.md"
  gitc "$d" init -q; gitc "$d" add -A; gitc "$d" commit -q -m v530; gitc "$d" tag v5.3.0

  printf '5.4.0\n' > "$d/.claude/VERSION"
  printf -- '- новое правило 5.4\n' >> "$d/.claude/CLAUDE.md"
  printf '#!/bin/bash\necho new\n' > "$d/.claude/hooks/session-start.sh"
  printf '#!/bin/bash\necho notice\n' > "$d/.claude/hooks/upgrade-notice.sh"; chmod +x "$d/.claude/hooks/upgrade-notice.sh"
  cat > "$d/.claude/settings.json" <<'JSON'
{ "env": { "A": "1", "B": "2" }, "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] } ], "PreToolUse": [ { "matcher": "Edit|Write", "hooks": [ { "type": "command", "command": ".claude/hooks/memory-gate.sh" } ] } ] } }
JSON
  printf 'facilitator v2\n' > "$d/.claude/agents/facilitator.md"
  rm -f "$d/.claude/commands/plan.md"
  printf 'style v2\n' > "$d/.claude/output-styles/core-team.md"
  printf 'guardian t2\n' > "$d/.claude/templates/roles/optional/guardian.md"
  printf 'product t2\n' > "$d/.claude/templates/roles/optional/product.md"
  mkdir -p "$d/.claude/hooks/migrations"
  cp "$HERE"/migrations/*.sh "$d/.claude/hooks/migrations/"
  printf '#!/bin/bash\nmig_will "миграция из будущего"\n' > "$d/.claude/hooks/migrations/9.9.9.sh"
  chmod +x "$d/.claude/hooks/migrations/"*.sh
  cat >> "$d/CHANGELOG.md" <<'MD'

## [5.4.0] — 2026-09-15 — «Обновление приезжает само»

> Наложение делает скрипт. closes: #12, #7

**Как было.** …
MD
  gitc "$d" add -A; gitc "$d" commit -q -m v540; gitc "$d" tag v5.4.0
  printf '%s' "$d"
}

# --- Копия потребителя на 5.3.0 -------------------------------------------------------
make_copy() {  # $1 = поставка, $2 = вариант: plain | noversion | edited
  local src=$1 variant=${2:-plain} d
  d=$(mktemp -d); TRASH+=("$d")
  gitc "$d" init -q
  (cd "$src" && git archive v5.3.0 .claude) | tar -x -C "$d"
  mkdir -p "$d/project/roles/dev"
  printf -- '---\nfindings_ceiling: 20\n---\n# Ledger\n' > "$d/project/ledger.md"
  printf '# Фидбек\n\n| 1 | issue #12 | ждёт |\n' > "$d/project/framework-feedback.md"
  # своё, заведённое setup-ом и ролями
  edit_inplace 's/\*\*Название:\*\* _не настроен_/**Название:** Тест/' "$d/.claude/CLAUDE.md"
  cat > "$d/.claude/settings.json" <<'JSON'
{
  "env": { "A": "1", "MINE": "x" },
  "permissions": { "deny": [ "Edit(.claude/templates/**)", "Write(project/roles/*/context.md)" ] },
  "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/session-start.sh" } ] } ],
             "TaskCompleted": [ { "hooks": [ { "type": "command", "command": ".claude/hooks/verify-task.sh" } ] } ] },
  "outputStyle": "core-team",
  "language": "ru"
}
JSON
  printf 'custom role\n' > "$d/.claude/agents/custom.md"
  printf 'guardian t1\n' > "$d/.claude/agents/guardian.md"          # нетронутый шаблон 5.3.0
  printf 'product t1 + моё\n' > "$d/.claude/agents/product.md"      # правленый шаблон
  printf 'custom dpf\n' > "$d/.claude/knowledge/dpf/custom.md"
  printf 'style mine\n' > "$d/.claude/output-styles/core-team.md"
  printf 'planner memory\n' > "$d/.claude/planner-context.md"
  printf '#!/bin/bash\n' > "$d/.claude/hooks/leftover-old.sh"
  case "$variant" in
    noversion) rm -f "$d/.claude/VERSION"; printf '{}\n' > "$d/.claude/hooks/hooks.json" ;;
    edited) printf '#!/bin/bash\necho mine\n' > "$d/.claude/hooks/session-start.sh" ;;
    dropped) rm -f "$d/.claude/knowledge/dpf/facilitation.md" ;;
    claude-edited) printf -- '- моя правка вне раздела\n' >> "$d/.claude/CLAUDE.md" ;;
  esac
  gitc "$d" add -A; gitc "$d" commit -q -m copy; gitc "$d" switch -q -c update-core-team
  printf '%s' "$d"
}

run() { bash "$HOOK" --root "$1" --source "file://$2" "${@:3}" 2>&1; }

SRC=$(make_source)

# --- Предусловия -----------------------------------------------------------------------
C=$(make_copy "$SRC"); gitc "$C" switch -q main 2>/dev/null || gitc "$C" switch -q master
OUT=$(run "$C" "$SRC" --apply); code=$?
check "на main + apply — отказ" "1/да" "$code/$(says "$OUT" "ветка")"
OUT=$(run "$C" "$SRC"); code=$?
check "на main предпросмотр — работает" "0" "$code"

D=$(mktemp -d); TRASH+=("$D"); mkdir -p "$D/.claude"; printf '5.3.0\n' > "$D/.claude/VERSION"
OUT=$(run "$D" "$SRC"); code=$?
check "копия не под git — отказ" "1/да" "$code/$(says "$OUT" "не под git")"

C=$(make_copy "$SRC"); printf 'x\n' >> "$C/.claude/agents/custom.md"
OUT=$(run "$C" "$SRC" --apply); code=$?
check "незакоммиченное в .claude + apply — отказ" "1/да" "$code/$(says "$OUT" "незакоммиченное")"
OUT=$(run "$C" "$SRC"); code=$?
check "незакоммиченное в .claude, предпросмотр — работает" "0" "$code"

BAD=$(mktemp -d); TRASH+=("$BAD"); gitc "$BAD" init -q; mkdir -p "$BAD/.claude"; printf 'x\n' > "$BAD/.claude/CLAUDE.md"
gitc "$BAD" add -A; gitc "$BAD" commit -q -m x
C=$(make_copy "$SRC")
OUT=$(run "$C" "$BAD"); code=$?
check "поставка без VERSION — отказ (найдено не ноль)" "1/да" "$code/$(says "$OUT" "нет .claude/VERSION")"

OUT=$(run "$C" "$SRC" --ref v5.3.0); code=$?
check "поставка той же версии — «уже на версии», код 0" "0/да" "$code/$(says "$OUT" "уже на версии")"

printf '5.9.0\n' > "$C/.claude/VERSION"; gitc "$C" commit -qam bump
OUT=$(run "$C" "$SRC"); code=$?
check "поставка старше копии — отказ" "1/да" "$code/$(says "$OUT" "понижение")"

# --- Предпросмотр -------------------------------------------------------------------------
C=$(make_copy "$SRC")
OUT=$(run "$C" "$SRC"); code=$?
check "предпросмотр ничего не трогает" "0/5.3.0/чисто" \
  "$code/$(tr -d '[:space:]' < "$C/.claude/VERSION")/$([ -z "$(gitc "$C" status --porcelain)" ] && printf 'чисто' || printf 'грязно')"
check "предпросмотр: приедет новый файл" "да" "$(says "$OUT" "hooks/upgrade-notice.sh")"
check "предпросмотр: своё остаётся (роль, DPF, стиль, память планировщика)" "да/да/да/да" \
  "$(says "$OUT" "agents/custom.md")/$(says "$OUT" "knowledge/dpf/custom.md")/$(says "$OUT" "output-styles/core-team.md")/$(says "$OUT" "planner-context.md")"
check "предпросмотр: убранное из поставки названо" "да" "$(printf '%s' "$OUT" | grep -A3 'УБРАНО ИЗ ПОСТАВКИ' | grep -qF 'commands/plan.md' && printf 'да' || printf 'нет')"
check "предпросмотр: неизвестный файл — вопрос, не действие" "да" "$(printf '%s' "$OUT" | grep -A3 'ВОПРОС' | grep -qF 'hooks/leftover-old.sh' && printf 'да' || printf 'нет')"
check "предпросмотр: миграция 5.3.2 обещает убрать запрет" "да" "$(says "$OUT" "БУДЕТ: убрать Write(project/roles/*/context.md)")"
check "миграция выше цели не идёт" "нет" "$(says "$OUT" "миграция из будущего")"
check "предпросмотр подсказывает команду применения" "да" "$(says "$OUT" "--apply")"

C=$(make_copy "$SRC" edited)
OUT=$(run "$C" "$SRC")
check "своя правка файла поставки названа перезаписываемой" "да" "$(printf '%s' "$OUT" | grep -A3 'ПЕРЕЗАПИСАНА' | grep -qF 'hooks/session-start.sh' && printf 'да' || printf 'нет')"

C=$(make_copy "$SRC" dropped)
OUT=$(run "$C" "$SRC")
check "убранное вами не предлагается как новое" "да/нет" \
  "$(printf '%s' "$OUT" | grep -A3 'УБРАНО У ВАС' | grep -qF 'knowledge/dpf/facilitation.md' && printf 'да' || printf 'нет')/$(printf '%s' "$OUT" | grep -A6 'ПРИЕДЕТ СВЕРХУ' | grep -qF 'facilitation.md' && printf 'да' || printf 'нет')"
run "$C" "$SRC" --apply >/dev/null 2>&1
check "убранное вами не возвращается при apply" "нет" "$([ -f "$C/.claude/knowledge/dpf/facilitation.md" ] && printf 'да' || printf 'нет')"

C=$(make_copy "$SRC" claude-edited)
OUT=$(run "$C" "$SRC")
check "правка CLAUDE.md вне раздела проекта названа вслух" "да" "$(says "$OUT" "ЕСТЬ ВАШИ ПРАВКИ ВНЕ ЭТОГО РАЗДЕЛА")"
C=$(make_copy "$SRC")
OUT=$(run "$C" "$SRC")
check "CLAUDE.md только с разделом проекта — предупреждения нет" "нет" "$(says "$OUT" "ЕСТЬ ВАШИ ПРАВКИ ВНЕ ЭТОГО РАЗДЕЛА")"

C=$(make_copy "$SRC")
OUT=$(run "$C" "$SRC")
check "предпросмотр: opt-in роли разделены на нетронутые и правленые" "да/да" \
  "$(printf '%s' "$OUT" | grep -A2 'нетронутый шаблон' | grep -qF 'agents/guardian.md' && printf 'да' || printf 'нет')/$(printf '%s' "$OUT" | grep -A2 'правлены вами' | grep -qF 'agents/product.md' && printf 'да' || printf 'нет')"
check "предпросмотр предсказывает зелёную целостность" "да" "$(says "$OUT" "ЦЕЛОСТНОСТЬ ПОСЛЕ ОБНОВЛЕНИЯ: Проверено")"
OUT=$(UPGRADE_INTEGRITY_CMD=false run "$C" "$SRC"); code=$?
check "предпросмотр предсказывает красную целостность и откат, файлы не тронуты" "0/да/чисто" \
  "$code/$(says "$OUT" "откатится")/$([ -z "$(gitc "$C" status --porcelain)" ] && printf 'чисто' || printf 'грязно')"

# --- Применение --------------------------------------------------------------------------
C=$(make_copy "$SRC")
OUT=$(run "$C" "$SRC" --apply); code=$?
check "apply: код 0, VERSION обновлён" "0/5.4.0" "$code/$(tr -d '[:space:]' < "$C/.claude/VERSION")"
check "apply: файл поставки обновлён, своя роль и DPF остались" "facilitator v2/custom role/custom dpf" \
  "$(cat "$C/.claude/agents/facilitator.md")/$(cat "$C/.claude/agents/custom.md")/$(cat "$C/.claude/knowledge/dpf/custom.md")"
check "apply: свой стиль вывода не перезаписан" "style mine" "$(cat "$C/.claude/output-styles/core-team.md")"
check "apply: нетронутая opt-in роль обновлена из шаблона, правленая осталась" "guardian t2/product t1 + моё" \
  "$(cat "$C/.claude/agents/guardian.md")/$(cat "$C/.claude/agents/product.md")"
check "CLAUDE.md: новое сверху, проект ваш" "да/да/нет" \
  "$(says "$(cat "$C/.claude/CLAUDE.md")" "новое правило 5.4")/$(says "$(cat "$C/.claude/CLAUDE.md")" "**Название:** Тест")/$(says "$(cat "$C/.claude/CLAUDE.md")" "**Название:** _не настроен_")"
S=$(cat "$C/.claude/settings.json")
check "settings: hooks сверху, ключи ваши, env слит" "да/да/да/да/да" \
  "$(says "$S" "PreToolUse")/$(says "$S" '"outputStyle"')/$(says "$S" '"MINE"')/$(says "$S" '"B"')/$(says "$S" '"language"')"
check "settings: устаревшее событие хуков не переживает обновление" "нет" "$(says "$S" "TaskCompleted")"
check "settings: миграция 5.3.2 убрала запрет, чужой запрет остался" "нет/да" \
  "$(says "$S" "Write(project/roles/*/context.md)")/$(says "$S" "Edit(.claude/templates/**)")"
check "убранное из поставки удалено, неизвестное не тронуто" "нет/да" \
  "$([ -f "$C/.claude/commands/plan.md" ] && printf 'да' || printf 'нет')/$([ -f "$C/.claude/hooks/leftover-old.sh" ] && printf 'да' || printf 'нет')"
check "новый скрипт поставки приехал исполняемым" "да" "$([ -x "$C/.claude/hooks/upgrade-notice.sh" ] && printf 'да' || printf 'нет')"
closed_line=$(printf '%s\n' "$OUT" | grep 'ЗАКРЫТО ИЗ ВАШЕГО' || true)
check "доклад: запись CHANGELOG за пройденную версию и закрытый фидбек" "да/да/нет" \
  "$(says "$OUT" "## [5.4.0]")/$(says "$closed_line" "#12")/$(says "$closed_line" "#7")"
check "доклад называет строку коммита, но не коммитит" "да/грязно" \
  "$(says "$OUT" "chore: обновление Core Team 5.3.0 → 5.4.0")/$([ -n "$(gitc "$C" status --porcelain)" ] && printf 'грязно' || printf 'чисто')"
OUT=$(run "$C" "$SRC"); code=$?
check "повторный запуск — «уже на версии»" "0/да" "$code/$(says "$OUT" "уже на версии")"

# --- Копия без VERSION: путь целиком -------------------------------------------------------
C=$(make_copy "$SRC" noversion)
OUT=$(run "$C" "$SRC" --apply); code=$?
check "без VERSION: все миграции; hooks.json удалён, таблица подключений заведена" "0/нет/да" \
  "$code/$([ -f "$C/.claude/hooks/hooks.json" ] && printf 'да' || printf 'нет')/$([ -f "$C/project/connection-points.md" ] && printf 'да' || printf 'нет')"
check "без VERSION: доклад честен о неизвестной версии" "да" "$(says "$OUT" "старше 5.1")"

# --- Откат ---------------------------------------------------------------------------------
C=$(make_copy "$SRC" noversion)
OUT=$(UPGRADE_INTEGRITY_CMD=false run "$C" "$SRC" --apply); code=$?
check "красная целостность — откат: код 1, файлы прежние, созданное убрано" "1/да/facilitator v1/нет" \
  "$code/$(says "$OUT" "ОТКАТ")/$(cat "$C/.claude/agents/facilitator.md")/$([ -f "$C/project/connection-points.md" ] && printf 'да' || printf 'нет')"

# --- upgrade.keep ---------------------------------------------------------------------------
C=$(make_copy "$SRC" edited)
python3 - "$C/.claude/settings.json" <<'PY' 2>/dev/null || edit_inplace 's/"language": "ru"/"language": "ru", "upgrade": { "keep": ["hooks\/session-start.sh"] }/' "$C/.claude/settings.json"
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["upgrade"]={"keep":["hooks/session-start.sh"]}; json.dump(d,open(p,"w"),ensure_ascii=False,indent=1)
PY
gitc "$C" commit -qam keep
OUT=$(run "$C" "$SRC" --apply); code=$?
check "upgrade.keep: названный файл поставки не перезаписан" "0/mine" "$code/$(tail -1 "$C/.claude/hooks/session-start.sh" | sed 's/echo //')"

# --- Без jq ---------------------------------------------------------------------------------
C=$(make_copy "$SRC")
FAKEBIN=$(mktemp -d); TRASH+=("$FAKEBIN"); printf '#!/bin/bash\nexit 1\n' > "$FAKEBIN/jq"; chmod +x "$FAKEBIN/jq"
OUT=$(PATH="$FAKEBIN:$PATH" run "$C" "$SRC" --apply); code=$?
check "jq неисправен — settings.json не тронут, сказано ВРУЧНУЮ" "0/да/да" \
  "$code/$(says "$OUT" "ВРУЧНУЮ")/$(says "$(cat "$C/.claude/settings.json")" '"MINE"')"

# --- Поставка каталогом -----------------------------------------------------------------------
C=$(make_copy "$SRC")
OUT=$(bash "$HOOK" --root "$C" --source "$SRC" 2>&1); code=$?
check "поставка локальным каталогом — работает без клона" "0/да" "$code/$(says "$OUT" "→ 5.4.0")"

if [ "$ran" -lt "$EXPECTED_CASES" ]; then
  printf 'FAIL  прогнано случаев %s из %s\n' "$ran" "$EXPECTED_CASES"; failed=$((failed + 1))
fi
printf '\nприбор: %s\nслучаев: %s, провалено: %s\n' "$HOOK" "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
