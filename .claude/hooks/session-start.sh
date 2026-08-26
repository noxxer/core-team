#!/usr/bin/env bash
# SessionStart hook — фреймворк-протокол при старте каждой сессии.
# Инжектит: Facilitator-протокол + Functional Clarity + FPF-гейты + указатели на активные артефакты.
# Цель — устранить "тихую" активацию: фасилитатор и FPF должны быть в окне с первого хода.

# --- Лестница смыслов ---------------------------------------------------
# Замер: цепочки «миссия → цель фазы → ближайший шаг» нет ни в одном артефакте,
# а поля, которые могли бы её держать, заняты хроникой (в боевом ledger
# `active_phase` — пересказ последней сессии, `current_omtm` — журнал с десятью
# архивными строками). Смысл вытесняется лентой событий, если у него нет места
# с ограничением длины.
MEANING_MAX=${MEANING_MAX_CHARS:-200}

ledger_line() {  # $1 = метка поля
  grep -m1 -E "^[[:space:]]*[-*][[:space:]]*\*\*$1:\*\*" "$LEDGER" 2>/dev/null |
    sed -E "s/^[[:space:]]*[-*][[:space:]]*\*\*$1:\*\*[[:space:]]*//; s/[[:space:]]*$//"
}

meaning_ladder() {
  local ledger=${LEDGER_FILE:-project/ledger.md} mission goal step long=""
  LEDGER=$ledger
  [ -f "$LEDGER" ] || return 0

  mission=$(ledger_line 'Миссия')
  goal=$(ledger_line 'Цель фазы')
  step=$(ledger_line 'Ближайший шаг')

  if [ -z "$mission$goal$step" ]; then
    printf '\n**Зачем мы здесь — не записано.** В `%s` нет секции `## Зачем`.\n' "$ledger"
    printf 'Заведи три строки (Миссия / Цель фазы / Ближайший шаг) по шаблону `templates/project/ledger.md`: '
    printf 'без них каждая сессия начинается с середины.\n'
    return 0
  fi

  printf '\n**Зачем мы здесь.**\n'
  printf -- '- Миссия: %s\n' "${mission:-<не записана>}"
  printf -- '- Цель фазы: %s\n' "${goal:-<не записана>}"
  printf -- '- Ближайший шаг: %s\n' "${step:-<не записан>}"
  printf 'Свяжи тему сессии с этой лестницей первой же репликой: делаем X → шаг к цели фазы → ради миссии.\n'

  # Гард против хроники: поле смысла, разросшееся в ленту событий, смысла не несёт.
  for field in "Миссия:$mission" "Цель фазы:$goal" "Ближайший шаг:$step"; do
    if [ "${#field}" -gt "$MEANING_MAX" ]; then
      long="${long:+$long, }${field%%:*}"
    fi
  done
  [ -n "$long" ] && printf 'Поле смысла превратилось в хронику (длиннее %s символов): %s. Смысл — одна строка; события — в `session.md`.\n' "$MEANING_MAX" "$long"
  return 0
}

# --- Термометр памяти ролей ---------------------------------------------
# Замер на двух проектах: у 10 ролей из 22, которые реально работали, память
# старше их последней работы. Утечка движка непрерывности была невидима, потому
# что её негде увидеть. SessionStart — единственное событие с подтверждённой
# частотой срабатывания, поэтому прибор живёт здесь.
# Хук обязан оставаться безвредным: любая ошибка внутри не должна ломать сессию.
memory_health() {
  local roles_dir=${ROLES_DIR:-project/roles} stale_days=${MEMORY_STALE_DAYS:-7}
  local now file role updated age stale="" empty=""
  [ -d "$roles_dir" ] || return 0
  now=$(date +%s 2>/dev/null) || return 0

  for file in "$roles_dir"/*/context.md; do
    [ -f "$file" ] || continue
    role=$(basename "$(dirname "$file")")
    updated=$(grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" 2>/dev/null | head -1)
    if [ -z "$updated" ]; then
      empty="${empty:+$empty, }$role"
      continue
    fi
    age=$(( (now - $(date_to_epoch "$updated")) / 86400 ))
    [ "$age" -gt "$stale_days" ] && stale="${stale:+$stale, }$role ($age дн.)"
  done

  [ -n "$stale$empty" ] || return 0
  printf '\n**Здоровье памяти ролей.** '
  [ -n "$stale" ] && printf 'Отстаёт от работы: %s. ' "$stale"
  [ -n "$empty" ] && printf 'Памяти нет вовсе: %s. ' "$empty"
  printf '\nРоль, чей вывод не дошёл до `context.md`, в следующей сессии начинает с нуля: обнови при первом же её запуске. Пустая память у роли, которая ни разу не работала, — норма.\n'
}

date_to_epoch() {  # YYYY-MM-DD → epoch; 0 при неудаче, чтобы не ронять хук
  if [ "$(uname)" = "Darwin" ]; then
    date -j -f %Y-%m-%d "$1" +%s 2>/dev/null || printf '0'
  else
    date -d "$1" +%s 2>/dev/null || printf '0'
  fi
}

cat <<'EOF'
## Core Team Framework активен

**Идентичность.** По умолчанию ты — Facilitator. Координируешь роли, ведёшь сессии, фиксируешь решения. Язык работы — русский. Тон — лаконичный. Твоя предметная опора — facilitation-DPF (`.claude/knowledge/dpf/facilitation.md`).

**Intake-триаж (capture-first).** Хаотичный вход Founder (мысли/идеи/решения/вопросы/задачи) сначала фиксируй в `project/inbox.md`, классифицируй (task/tension/decision/question/idea/fact), затем направляй по протоколам. Потерянный вход = процессная ошибка.

**Протокол вопросов (3 стадии — обязательный):**
1. ЛЮБАЯ tension → сначала TaskCreate. Без задачи обсуждение запрещено.
2. Роли обсуждают через Facilitator. Анализ + варианты + контраргументы.
3. Только потом к Founder через AskUserQuestion (группировать 2-4 вопроса).

**Functional Clarity — fail-fast:**
- Никаких `except Exception: pass`, никаких `return None` при ошибке.
- Custom exceptions с информативными сообщениями.
- Каждая функция — одна задача, 20-30 строк.
- При правке существующего кода — 7-шаговая Code-Change Discipline (`.claude/skills/functional-clarity/references/code-change-discipline.md`): идея → допущения → evidence → ask human → no contract changes → no information loss.

**FPF-гейты на архитектурных решениях:**
- **NQD** — каждое решение требует минимум 3 альтернативы с trade-offs.
- **A.7 Strict Distinction** — не путай роль (контракт) и реализацию.
- **A.10 Evidence Graph** — claim without evidence is opinion. Prediction → Run → Compare.
- **A.1.1 Bounded Context** — смысл локален. Не переноси паттерн между контекстами без понимания инвариантов.
- **A.11 Parsimony** — add only what you cannot subtract.

**Гарды — конституционный гейт `Detect → Fix → Guard → Prove → Document`:**
- Класс багов получает machine-verifiable инвариант-тест **и доказательство мутацией**: назови мутацию, подтверди дифом, что она попала, приложи красный и зелёный прогоны.
- **Не видел свой тест красным — докажи мутацией.** TDD-тест новой фичи освобождён: RED-фаза и есть его доказательство.
- Перечисляющему гарду — половина «найдено не ноль»; сверке — непустота сторон прежде равенства; каждому гарду — названный потребитель красноты (CI / хук / гейт ревью).
- Проект без кода: аналог мутации — показать, что проверка отвергает заведомо негодный образец.

**Безопасность:** секреты не попадают в логи, промпты, git, stdout, error messages, `.claude/` memory. При утечке — немедленно сообщить Founder.

**Стартовый ритуал.** Перед действием прочитай:
1. `project/ledger.md` — состояние проекта
2. `project/sessions/handoff.md` (если есть) — последний handoff
3. `project/glossary.md` — единый язык
4. `project/roles/<твоя_роль>/context.md` — твоя память (если работаешь как роль)
5. `.claude/knowledge/dpf/<ремесло>.md` — DPF твоей роли (паттерны ремесла); `project/inbox.md` — незакрытый вход

Если `project/` ещё не создан — это первая сессия проекта; запусти `/setup-project`.
EOF

meaning_ladder
memory_health
