---
artifact_id: "infrastructure-principles"
created: "{{date}}"
last_modified: "{{date}}"
last_modified_by: "cto"
version: 1
status: "active"
---

# Infrastructure & Engineering Principles — {{project_name}}

> Источники: 12-Factor App, 15-Factor App, индустриальные best practices.
> Адаптируется при `/setup-project` под конкретный стек и фазу проекта.

---

## Универсальные принципы (все проекты)

### 1. Единая точка входа

**Вся инфраструктура поднимается одной командой.**

- Одна команда для запуска локально и в production
- Конфигурация среды отделена от запуска

### 2. Dev/Prod паритет

**Локальная среда максимально близка к production.**

- Одни и те же backing services локально и на проде
- Критерий: если работает локально и проходит тесты — работает в production

### 3. Конфигурация через окружение

**Все секреты и настройки — в переменных окружения, не в коде.**

- `.env` — локальные значения (gitignored)
- `.env.example` — шаблон с плейсхолдерами (в репо)
- Валидация конфигурации при старте (fail-fast)
- Секреты не попадают в логи, промпты LLM, git, Docker image layers

### 4. Версионирование и релизы

**Каждая сборка знает свою версию.**

- Conventional Commits: `feat:` → minor, `fix:` → patch
- Health/status endpoint возвращает версию
- Semantic versioning

### 5. API/Contract First

**Контракт фиксируется до написания кода.**

- FEAT README + PLAN = контракт
- Внешние API specs в `project/artifacts/api-specs/`

### 6. Минимально достаточная инфраструктура

**Простейший инструмент, который решает текущие задачи.**

- Не добавляй инфраструктуру "на вырост"
- Документируй триггеры перехода к следующему уровню

### 7. Security в архитектуре

**Безопасность встроена, не прикручена позже.**

- Валидация входных данных на границе системы
- Rate limiting на API
- Секреты не попадают в логи, промпты LLM, git
- Ошибки для пользователя — без технических деталей

### 8. Git Workflow

**Trunk-Based Development — минимум церемоний, максимум скорости.**

- `main` всегда deployable
- Feature branch живёт не более 1-2 дней
- Conventional Commits
- Никаких force push в main

---

## Dev-принципы (dev, hybrid)

### 9. TDD с первого дня

**Тесты пишутся до кода.**

- Red → Green → Refactor
- Coverage не самоцель, но ключевые пути покрыты

### 10. Реальные сервисы в тестах

**Интеграционные тесты работают с настоящими backing services.**

- Не мокаем БД и хранилища — моки скрывают реальные проблемы
- Внешние API: первый прогон реальный, ответ сохраняется как fixture

### 11. Structured logging

**Структурированные логи, не print().**

- Каждый запрос: request_id, timestamp, duration_ms
- Health endpoints
- На старте НЕ нужно: OpenTelemetry, Prometheus, Grafana

### 12. CI/CD pipeline

**Push = тесты + деплой.**

- CI (каждый push): lint → tests → build
- CD (merge в main): deploy → health check

### 13. Database backups с первого дня

**Автоматические ежедневные бэкапы.**

- Retention: 7 ежедневных + 4 еженедельных
- Тестировать восстановление

### 14. Зрелые библиотеки

**Массовые, поддерживаемые инструменты.**

- Один инструмент на домен
- Lock-файл фиксирует точные версии

### 15. Resource limits в production

**Каждый процесс/контейнер имеет лимит CPU и RAM.**

---

## Backend Python — рекомендуемые дефолты

> Рекомендация для backend-проектов на Python. Обсуждается при setup.

### 16. Менеджер зависимостей: uv

- `pyproject.toml` (PEP 621) — единственный файл зависимостей
- `uv.lock` — фиксация версий, коммитится в git
- `uv sync`, `uv run`, `uv add` — единые команды

### 17. Тестирование: pytest

- pytest + pytest-asyncio
- Тест для каждого модуля, сервиса, endpoint
- SQLite in-memory для unit/integration на ранних фазах

### 18. Multi-stage Docker builds

- Production images на основе slim
- Layer caching: зависимости ДО исходного кода
- Non-root user в production
- Pinned versions для base images

### 19. Self-Healing by Design

- Sweeper для застрявших задач (retry + max attempts → failed + alert)
- Background processing: webhook отвечает немедленно, обработка асинхронно
- Для каждого фонового процесса: что если crash? что видит клиент? как восстановиться?

### 20. Semantic-release

- Conventional commits → автоматический bump → tag → CHANGELOG
- Health endpoint возвращает версию
- Деплой только при новом релизе

---

## Frontend — рекомендуемые дефолты

> Рекомендация для frontend-проектов. Обсуждается при setup.

### 21. Frontend строится в Docker (при наличии)

- Node.js, npm, node_modules — только внутри контейнера
- Multi-stage build: `node` (сборка) → `nginx` (раздача static)

### 22. Resilient frontend

- Error Boundaries на уровне route
- Graceful degradation

---

## Проектно-специфичные принципы

> Добавляются CTO при setup или в ходе работы.

_Пока пусто — заполняется при `/setup-project`._

---

## Что НЕ нужно на старте

_Заполняется при setup — явный список того, что откладывается и триггер когда добавить._

---

## Источники

- [The Twelve-Factor App](https://12factor.net/)
- [Beyond the Twelve-Factor App](https://www.oreilly.com/library/view/beyond-the-twelve-factor/9781492042631/)
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Martin Fowler — Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
