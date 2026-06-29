#!/usr/bin/env bash
# fetch-fpf-spec.sh — скачать полную спецификацию FPF по требованию.
#
# FPF-Spec.md (~8.7MB) НЕ бандлится в Core Team. Этот скрипт качает её из
# апстрима ailev/FPF в ГЛОБАЛЬНЫЙ кеш (~/.claude/knowledge/fpf/), который
# шарится между всеми проектами — скачать достаточно один раз.
#
# Идея и подход — из i-m-senior-developer (@spumer), MIT.
#
# Использование:
#   ./fetch-fpf-spec.sh            # → ~/.claude/knowledge/fpf/FPF-Spec.md (глобально)
#   ./fetch-fpf-spec.sh --project  # → .claude/knowledge/fpf/FPF-Spec.md (в текущем проекте)
#   ./fetch-fpf-spec.sh --force    # перекачать, даже если файл уже есть
#   ./fetch-fpf-spec.sh --help

set -euo pipefail

SPEC_URL="https://raw.githubusercontent.com/ailev/FPF/main/FPF-Spec.md"
MIN_BYTES=1000000  # 1MB — порог валидности (меньше = скачали страницу ошибки)

target_dir="${HOME}/.claude/knowledge/fpf"
force=0

for arg in "$@"; do
  case "$arg" in
    --project) target_dir=".claude/knowledge/fpf" ;;
    --force)   force=1 ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Неизвестный флаг: $arg (см. --help)" >&2; exit 2 ;;
  esac
done

command -v curl >/dev/null 2>&1 || { echo "Ошибка: нужен curl." >&2; exit 1; }

spec_path="${target_dir}/FPF-Spec.md"
version_path="${target_dir}/FPF-Spec.version"

if [[ -f "$spec_path" && "$force" -eq 0 ]]; then
  echo "FPF-Spec.md уже на месте: $spec_path (--force чтобы перекачать)."
  exit 0
fi

mkdir -p "$target_dir"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

echo "Качаю FPF-Spec.md из ailev/FPF…"
curl -fsSL "$SPEC_URL" -o "$tmp"

size=$(wc -c < "$tmp" | tr -d ' ')
if [[ "$size" -lt "$MIN_BYTES" ]]; then
  echo "Ошибка: скачано $size байт (< ${MIN_BYTES}). Похоже на страницу ошибки, не спека." >&2
  exit 1
fi

mv "$tmp" "$spec_path"
trap - EXIT

# Записываем коммит апстрима рядом со спекой, чтобы skill мог сравнить «живой»
# SHA с тем, на котором построен наш lite-индекс (index_built_against), и
# детектить дрейф номеров строк / переименований терминов.
INDEX_BUILT_AGAINST="40b232f11ed950ed34082273c57ff4f6c45b7f06"  # см. UPSTREAM-SYNC.md
sha=""
if command -v curl >/dev/null 2>&1; then
  sha="$(curl -fsSL "https://api.github.com/repos/ailev/FPF/commits/main" 2>/dev/null \
        | grep -m1 '"sha"' | sed -E 's/.*"sha"[: ]+"([0-9a-f]+)".*/\1/')"
fi
{
  printf 'url=%s\nbytes=%s\nfetched_from=ailev/FPF@main\n' "$SPEC_URL" "$size"
  [[ -n "$sha" ]] && echo "upstream_commit=$sha"
  echo "index_built_against=${INDEX_BUILT_AGAINST}"
} > "$version_path"
echo "Готово: $spec_path ($size байт). Навигация — через fpf-integration skill (tasks-lookup → grep-patterns)."
if [[ -n "$sha" && "${sha#"$INDEX_BUILT_AGAINST"}" == "$sha" ]]; then
  echo "⚠ Дрейф: апстрим на ${sha:0:12}, lite-индекс построен на ${INDEX_BUILT_AGAINST:0:12}." >&2
  echo "  Номера строк в sections-map могут не совпасть. См. UPSTREAM-SYNC.md → ре-индексация." >&2
fi
