#!/bin/bash
# Сборщик кандидатов наверх: находит места, где проект дописал в файлы
#
# ТИР: счёт — кандидаты наверх копятся и отправляются пачкой
# фреймворка правило, которого upstream не привёз.
#
# Сигнал сильный и машинный: проект, дописавший правило себе в `.claude/`,
# уже проголосовал руками — ему не хватило того, что приехало.
# Замер: два проекта дописали 7 правил уровня фреймворка, ни одно не вернулось.
# Словесный критерий («нет слов предметной области») давал 132 кандидата
# из 176 уроков при 7 настоящих — он необходимый, но не отбирающий.
#
# МАРКЕР (ставится рядом с локальной добавкой):
#   <!-- upstream-candidate: ядро — почему это верно для любого проекта -->
#   <!-- upstream-candidate: stacks/backend-python — почему это верно для стека -->
#
# Предметное наверх не едет: его дом — project/dpf/.
#
# ЗАПУСК: bash .claude/hooks/collect-upstream-candidates.sh [каталог]
#   exit 0 — сбор прошёл (кандидаты найдены или их нет)
#   exit 1 — сбор невозможен либо маркер оформлен неверно
#
# Доказательство мутацией: collect-upstream-candidates.test.sh

set -uo pipefail

ROOT=${1:-${FRAMEWORK_DIR:-.claude}}
MARKER='upstream-candidate:'

# Корзина — по белому списку. «dpf» наверх не едет и не является опечаткой:
# это осознанно другое место, и сказать об этом надо явно.
basket_is_valid() {
  case "${1:-}" in
    'ядро') return 0 ;;
    stacks/?*) return 0 ;;
  esac
  return 1
}

[ -d "$ROOT" ] || {
  printf 'сборщик: каталога %s нет — собирать неоткуда.\n' "$ROOT" >&2
  printf 'Это отказ инструмента, а не отсутствие кандидатов.\n' >&2
  exit 1
}

scanned=0
found=0
status=0
report=()
problems=()

while IFS= read -r file; do
  # Дом формата пропускается: иначе прибор считает собственные примеры
  # маркерами и показывает свою настройку вместо реальности.
  case "$(basename "$file")" in collect-upstream-candidates*) continue ;; esac
  scanned=$((scanned + 1))
  in_fence=no
  while IFS=: read -r line text; do
    [ -n "${line:-}" ] || continue

    # Документация формата — не находка. Прибор, считающий собственные примеры,
    # показывает свою настройку вместо реальности (поймано на ревью: 5 ложных
    # кандидатов из шаблона и промптов самого фреймворка).
    # Признак документации: маркер внутри блока кода или внутри обратных кавычек.
    case "$text" in
      *'```'*) [ "$in_fence" = yes ] && in_fence=no || in_fence=yes; continue ;;
    esac
    [ "$in_fence" = yes ] && continue
    case "$text" in
      *'`'*"$MARKER"*) continue ;;
    esac

    found=$((found + 1))
    payload=${text#*"$MARKER"}
    payload=${payload%%-->*}
    # Разделитель обязателен: без него причины нет, а маркер без причины
    # наверху бесполезен — тот, кто его прочитает, не поймёт, что чинить.
    case "$payload" in
      *—*) ;;
      *)
        problems+=("$file:$line — не названа причина: нужен формат «корзина — почему»")
        status=1
        continue
        ;;
    esac
    basket=$(printf '%s' "$payload" | sed -E 's/^[[:space:]]*//; s/[[:space:]]*—.*$//; s/[[:space:]]*$//')
    reason=$(printf '%s' "$payload" | sed -E 's/^[^—]*—[[:space:]]*//; s/[[:space:]]*$//')
    if ! basket_is_valid "$basket"; then
      problems+=("$file:$line — корзина «${basket}» недопустима (ядро | stacks/<стек>)")
      status=1
      continue
    fi
    if [ -z "$reason" ]; then
      problems+=("$file:$line — причина пуста после «—»")
      status=1
      continue
    fi
    report+=("[$basket] $file:$line — $reason")
  done < <(grep -n -e "$MARKER" -e '^[[:space:]>]*```' "$file" 2>/dev/null)
done < <(find "$ROOT" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' \) 2>/dev/null)

# Половина «найдено не ноль»: каталог есть, а просмотрено ноль файлов — отказ
# инструмента. Пустой обход неотличим от чистоты, пока его не назвать.
if [ "$scanned" -eq 0 ]; then
  printf 'сборщик: в %s не просмотрено ни одного файла — обход пуст.\n' "$ROOT" >&2
  printf 'Считаем это отказом, а не отсутствием кандидатов.\n' >&2
  exit 1
fi

printf 'Просмотрено файлов: %s. Кандидатов наверх: %s.\n' "$scanned" "$found"

if [ ${#report[@]} -gt 0 ]; then
  printf '\nКандидаты:\n'
  printf '  %s\n' "${report[@]}"
  printf '\nДальше: перенести в project/framework-feedback.md, затем issue по шаблону\n'
  printf '(.github/ISSUE_TEMPLATE/feature_request.md) — канал наверх уже открыт.\n'
fi

if [ ${#problems[@]} -gt 0 ]; then
  printf '\nМАРКЕРЫ ОФОРМЛЕНЫ НЕВЕРНО (%s):\n' "${#problems[@]}" >&2
  printf '  %s\n' "${problems[@]}" >&2
  printf 'Формат: <!-- upstream-candidate: ядро — почему это верно для любого проекта -->\n' >&2
  printf 'Предметное наверх не едет: его дом — project/dpf/.\n' >&2
fi

exit $status
