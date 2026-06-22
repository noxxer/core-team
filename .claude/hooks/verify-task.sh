#!/bin/bash
# Hook: TaskCompleted quality gate
# Проверяет, что teammate обновил свой context.md не более 5 минут назад.
# Если context.md устарел — задача блокируется с feedback teammate.
# Exit 0 = OK (задача закрывается)
# Exit 2 = блокировать + feedback teammate

INPUT=$(cat)
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // empty')
TEAMMATE=$(echo "$INPUT" | jq -r '.teammate_name // empty')

# Проверить что teammate обновил свой context.md
CONTEXT_FILE="project/roles/${TEAMMATE}/context.md"
if [ -f "$CONTEXT_FILE" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    MODIFIED=$(stat -f %m "$CONTEXT_FILE" 2>/dev/null)
  else
    MODIFIED=$(stat -c %Y "$CONTEXT_FILE" 2>/dev/null)
  fi
  NOW=$(date +%s)
  DIFF=$((NOW - MODIFIED))

  if [ "$DIFF" -gt 300 ]; then
    echo "Обнови свой context.md перед закрытием задачи: $TASK_SUBJECT" >&2
    exit 2
  fi
fi

exit 0
