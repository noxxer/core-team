# Правила безопасности — 12 правил защиты секретов

> Нарушение любого правила = critical incident.

## 1. Секреты не попадают в логи
- Никогда не логировать значения из `.env`
- В аудит-логах — только имена переменных, не значения
- Запрещено: `log(f"using token {token}")`

## 2. Секреты не попадают в промпты LLM
- Никогда не передавать секреты в промпты Claude/GPT/любой LLM
- API вызовы — из кода, не через LLM tool use
- Никогда не вставлять токены в `--prompt` аргументы
- Никогда не сохранять секреты в `.claude/` memory-файлах

## 3. Секреты не попадают в Sentry/мониторинг
- `before_send` hook: scrub все env vars из контекста исключений
- Фильтровать URL с токенами из `str(exc)`
- `send_default_pii=False`

## 4. Секреты не попадают в Git
- `.env` в `.gitignore`
- Перед коммитом: `git diff --cached` на паттерны TOKEN, KEY, PASSWORD, SECRET, DSN
- Если утекло: `git filter-repo` для удаления из истории

## 5. Секреты не попадают в Docker
- Никогда не копировать `.env` в образ
- Передавать через `--env-file` в runtime
- Не использовать `ENV` директиву для секретов в Dockerfile

## 6. Redis: обязательная защита
- `requirepass` всегда, даже на localhost
- `bind 127.0.0.1` — никогда 0.0.0.0
- Порт 6379 закрыт в firewall
- TLS если Redis по сети

## 7. SSH: укрепление
- Только ключи, `PasswordAuthentication no`
- `PermitRootLogin prohibit-password`
- fail2ban: 3 попытки → бан 1 час
- UFW: только 22/80/443

## 8. Защита истории терминала
- Пробел перед командой: ` export TOKEN=...`
- Или отключить: `set +o history`

## 9. Ошибки без секретов
- Запрещено: `raise ValueError(f"Bad token: {token}")`
- Правильно: `raise ValueError("Invalid API token for service X")`

## 10. Консоль/stdout без секретов
- Никогда не print секреты
- Максимум для отладки: первые 4 символа `token[:4]...`

## 11. URL без секретов
- Токены через HTTP headers (`Authorization: Bearer`)
- Никогда в URL `?token=xxx` — попадёт в access logs

## 12. Протокол реагирования на утечку
1. Немедленно ротировать скомпрометированный секрет
2. Сообщить основателю
3. Записать инцидент
4. Проверить git: `git log -p -S "leaked_value"`
5. Если найдено: `git filter-repo`
