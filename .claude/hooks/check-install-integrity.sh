#!/bin/bash
# Целостность развёрнутой копии: доехал ли инструмент рабочим, а не просто файлами.
#
# Замер, из которого выросла проверка: три класса дрейфа, найденные вручную,
# и все три — «объявлено ≠ подключено»:
#   · `VERSION` лежал в корне и не попадал в `.claude/` — потребитель не получал
#     его никогда, хотя CLAUDE.md обещал;
#   · `hooks.json` выглядел конфигом хуков и им не был;
#   · имена слотов в шаблоне сессии и в проверщике рефлексии живут в РАЗНЫХ
#     файлах, и разъехаться они могут молча.
# Плюс трижды за один MR устаревало число случаев, заявленное в документации.
#
# ЗАПУСК: bash .claude/hooks/check-install-integrity.sh [корень копии]
#   exit 0 — копия работоспособна
#   exit 1 — что-то объявлено и не подключено, либо проверять оказалось нечего
#
# Доказательство мутацией: .claude/hooks/check-install-integrity.test.sh

set -uo pipefail

ROOT=${1:-.}
CLAUDE_DIR="${ROOT}/.claude"

problems=()
checked=0

note() { problems+=("$1"); }

[ -d "${CLAUDE_DIR}" ] || { printf 'ОШИБКА: нет %s — это не развёрнутая копия фреймворка.\n' "${CLAUDE_DIR}" >&2; exit 1; }

# --- 1. Версия едет вместе с инструментом -----------------------------------
checked=$((checked + 1))
if [ ! -s "${CLAUDE_DIR}/VERSION" ]; then
  note "нет ${CLAUDE_DIR}/VERSION — CLAUDE.md обещает версию именно там"
fi

# --- 2. Хуки исполняемы -----------------------------------------------------
shopt -s nullglob
hooks=("${CLAUDE_DIR}"/hooks/*.sh)
if [ "${#hooks[@]}" -eq 0 ]; then
  printf 'ОШИБКА: в %s/hooks не найдено ни одного скрипта.\n' "${CLAUDE_DIR}" >&2
  printf 'Перечисляющая проверка на пустом множестве проходит по построению — считаем отказом.\n' >&2
  exit 1
fi
for hook in "${hooks[@]}"; do
  checked=$((checked + 1))
  [ -x "${hook}" ] || note "не исполняем: ${hook}"
done

# --- 3. Объявленные хуки существуют ------------------------------------------
settings="${CLAUDE_DIR}/settings.json"
if [ ! -f "${settings}" ]; then
  note "нет ${settings} — событийные хуки не объявлены, значит не вызываются"
elif command -v jq >/dev/null 2>&1; then
  if ! jq -e 'type == "object"' "${settings}" >/dev/null 2>&1; then
    note "${settings} не разбирается как объект"
  else
    declared=0
    while IFS= read -r command_line; do
      [ -n "${command_line}" ] || continue
      declared=$((declared + 1))
      checked=$((checked + 1))
      target=${command_line%% *}
      # Путь ищем ТОЛЬКО внутри проверяемой копии. Запасной поиск относительно
      # текущего каталога давал ложно-зелёное: файл соседней установки
      # удовлетворял проверке копии, в которой его нет.
      case "${target}" in
        /*) [ -f "${target}" ] || note "хук объявлен, файла нет: ${target}" ;;
        *)  [ -f "${ROOT}/${target}" ] || note "хук объявлен, файла нет: ${target}" ;;
      esac
    done < <(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' "${settings}" 2>/dev/null)
    [ "${declared}" -gt 0 ] || note "в ${settings} нет ни одного объявленного хука — «файл лежит» ≠ «хук вызывается»"
  fi
fi

# --- 4. Слоты шаблона сессии ↔ слоты проверщика рефлексии --------------------
template="${CLAUDE_DIR}/templates/project/session-template.md"
checker="${CLAUDE_DIR}/hooks/check-session-reflection.sh"
if [ -f "${template}" ] && [ -f "${checker}" ]; then
  slots=$(grep -m1 '^SLOTS=(' "${checker}" | sed -E "s/^SLOTS=\(//; s/\)$//; s/' '/\n/g; s/'//g")
  if [ -z "${slots}" ]; then
    note "не удалось прочитать список слотов из ${checker}"
  else
    while IFS= read -r slot; do
      [ -n "${slot}" ] || continue
      checked=$((checked + 1))
      grep -qF -- "${slot}" "${template}" || note "проверщик ждёт слот «${slot}», в шаблоне сессии его нет"
    done <<< "${slots}"
  fi
fi

# --- 5. Навыки, объявленные ролями, существуют ------------------------------
# `skills:` вливает содержимое навыка в контекст роли при старте. Объявленный
# и отсутствующий навык — это роль, которая молча стартует без своего ремесла.
for role_file in "${CLAUDE_DIR}"/agents/*.md; do
  skills_line=$(grep -m1 '^skills:' "${role_file}" 2>/dev/null)
  [ -n "${skills_line}" ] || continue
  names=$(printf '%s' "${skills_line}" | sed -E 's/^skills:[[:space:]]*\[([^]]*)\].*/\1/' | tr ',' ' ')
  for name in ${names}; do
    name=$(printf '%s' "${name}" | tr -d '"'"'"' ')
    [ -n "${name}" ] || continue
    checked=$((checked + 1))
    [ -f "${CLAUDE_DIR}/skills/${name}/SKILL.md" ] \
      || note "$(basename "${role_file}") объявляет навык «${name}», в копии его нет"
  done
done

# --- 6. Заявленное число случаев ↔ фактическое ------------------------------
# Класс, случившийся трижды за один MR: набор растёт, число в документации нет.
claude_md="${CLAUDE_DIR}/CLAUDE.md"
if [ -f "${claude_md}" ]; then
  while IFS='|' read -r suite claimed; do
    [ -n "${suite}" ] || continue
    checked=$((checked + 1))
    actual=$(grep -m1 '^EXPECTED_CASES=' "${CLAUDE_DIR}/hooks/${suite}" 2>/dev/null | cut -d= -f2)
    if [ -z "${actual}" ]; then
      note "в документации назван набор ${suite}, а файла или его счётчика нет"
    elif [ "${actual}" != "${claimed}" ]; then
      note "${suite}: документация говорит ${claimed} случаев, в наборе ${actual}"
    fi
  done < <(grep -oE '`[a-z-]+\.test\.sh` \([0-9]+ случа' "${claude_md}" \
           | sed -E 's/`([a-z-]+\.test\.sh)` \(([0-9]+) случа/\1|\2/')
fi

printf 'Проверено пунктов: %s. Расхождений: %s.\n' "${checked}" "${#problems[@]}"
[ "${#problems[@]}" -eq 0 ] && exit 0

printf '\nКОПИЯ НЕ РАБОТОСПОСОБНА (%s):\n' "${#problems[@]}" >&2
printf '  %s\n' "${problems[@]}" >&2
exit 1
