---
dpf_id: "code-review"
type: "role"
subject: "test"
bounded_context: "Код-ревью и QA в dev/hybrid проектах: безопасность (OWASP), дефекты, прод-путь, контрактный дрейф"
maturity: "draft"
created: "2026-06-29"
last_modified: "2026-06-29"
based_on_fpf: "40b232f11ed950ed34082273c57ff4f6c45b7f06"
channels_covered: 11
sources_count: 15
sources:
  - "OWASP Code Review Guide v2.0 (2017), owasp.org/www-project-code-review-guide"
  - "OWASP Secure Code Review Cheat Sheet (2024), cheatsheetseries.owasp.org"
  - "OWASP Top 10 2025, owasp.org/Top10/2025"
  - "Google Engineering Practices — Code Review (2024), google.github.io/eng-practices"
  - "Software Engineering at Google, Chapter 9: Code Review (2020), abseil.io/resources/swe-book"
  - "Steve McConnell, Code Complete 2 (2004), Ch.20 — Software Quality Landscape"
  - "Michaela Greiler, 30 Proven Code Review Best Practices from Microsoft (2023), michaelagreiler.com"
  - "ISTQB CTFL v4.0 Syllabus (2024) — Chapter 3: Static Testing"
  - "Pact Documentation — Consumer-Driven Contract Testing (2024), docs.pact.io"
  - "2024 DORA State of DevOps Report, cloud.google.com/blog/products/devops-sre"
  - "Semgrep vs CodeQL vs SonarQube comparison (2025), rafter.so/blog"
  - "IBM Cost of Data Breach 2024, ibm.com/security/data-breach"
  - "Postmortem: Equifax Breach (CVE-2017-5638), Log4Shell (CVE-2021-44228)"
  - "Shopify Engineering: Great Code Reviews (2022), shopify.engineering"
  - "AWS Well-Architected Framework: SEC11-BP04 Conduct code reviews, docs.aws.amazon.com"
---

# DPF: Код-ревью и QA (роль test)

> Предметный учебник для AI-агента (Domain Principles Framework). Идёт **после FPF**:
> FPF даёт общие принципы работы, DPF — SoTA-ходы, термины, ошибки и границы этого домена.
> Паттерны — декларативный метод мышления, **не** инструкция на выполнение (E.8).

## 0. Scope & Bounded Context (FPF A.1.1)

- **В фокусе:** Ревью чужого кода в роли test: поиск дефектов безопасности (OWASP Top 10), функциональных ошибок, нарушений качества, проверка прод-пути (CHK-WIRE/CHK-ORPHAN), обнаружение контрактного/wire-дрейфа. Роль **не правит код** — только выносит REVIEW с находками.
- **Вне фокуса:** написание тестов (это dev), архитектурные решения (architect), инфраструктурная безопасность (guardian), CI/CD pipeline design. Функциональное тестирование как QA-инженер (ручное/автоматическое E2E) — смежно, но отдельный bounded context.
- **Перевод терминов:** «ревью» = code review (не peer review в академическом смысле), «прод-путь» = production code path, «wire-дрейф» = contract/API drift, «дефект» = defect (не bug — bug = дефект в рантайме).
- **Maturity:** refined — 11 каналов Collection Protocol пройдено через web-research; провенанс-пробелы закрыты в E.21-цикле от 2026-06-29 (атрибуция McConnell исправлена, голословные цифры помечены, CHK-WIRE идентифицирован как framework-native, dead-sources процитированы).

## 1. Глоссарий домена

| RU | EN (для кода/поиска) | Определение | Не является |
|----|----------------------|-------------|-------------|
| Дефект | Defect | Отклонение кода от ожидаемого поведения, требования или контракта | Bug в рантайме — дефект может быть обнаружен статически до запуска |
| Ревью | Code Review | Систематическая проверка кода с целью обнаружения дефектов, нарушений стандартов, уязвимостей | Апрув (LGTM) — ревью ≠ одобрение; одобрение — возможный результат ревью |
| Статический анализ | Static Analysis / SAST | Анализ кода без его выполнения: паттерн-матчинг, data flow, taint analysis | Динамический анализ (DAST) — тот требует запущенного приложения |
| OWASP Top 10 | OWASP Top 10 | Стандартный список топ-10 критических рисков веб-приложений, обновляется OWASP раз в несколько лет | Полный список всех уязвимостей — Top 10 это рейтинг по распространённости, не исчерпывающий |
| Прод-путь | Production Code Path | Реальный путь выполнения кода в продакшне: от публичного entry point до ответа, включая все слои | Happy path в тестах — тесты могут покрывать код, который никогда не вызывается в прод-сборке |
| CHK-WIRE | CHK-WIRE Check | Проверка: каждая публичная функция имеет реальный вызов в прод-коде (не только в тестах) | Unit-тест покрытие — тест может вызывать функцию напрямую, минуя реальный прод-стек |
| CHK-ORPHAN | CHK-ORPHAN Check | Проверка: форма данных на границе (API, DB, queue) сверена с реальностью через curl/diff, не только с моками | Контрактный тест — CHK-ORPHAN требует живой верификации, не только согласия двух моков |
| Контрактный дрейф | Contract Drift / API Drift | Расхождение между ожидаемым (spec/mock) и реальным (runtime) интерфейсом сервиса | Баг в реализации — дрейф = эволюционная несогласованность, не разовая ошибка |
| Плотность дефектов | Defect Density | Число дефектов на единицу кода (обычно дефекты/1000 LOC) | Число багов в трекере — DD нормализована по размеру кодовой базы |
| Escape Rate | Defect Escape Rate | Доля дефектов, прошедших в прод без обнаружения на ревью/QA | False positive rate SAST — escape rate меряет пропущенные дефекты, не ложные тревоги |
| Формальная инспекция | Fagan Inspection | Структурированное ревью с ролями (модератор, читатель, инспекторы), метриками входа/выхода, собранием | PR review — Fagan требует синхронного собрания и формальных метрик; PR асинхронен |
| Taint Analysis | Taint Analysis | Отслеживание «заражённых» (untrusted) данных от источника до приёмника для обнаружения injection | Валидация — валидация обезвреживает данные; taint analysis проверяет, прошли ли они через валидацию |
| Дрейф мока | Mock Drift | Рассинхронизация мок-объекта с реальным поведением зависимости | Технический долг — mock drift активно вводит в заблуждение, это не просто устаревший код |
| Бизнес-логика дефект | Business Logic Flaw | Уязвимость в логике приложения, не в технической реализации: обход потока, некорректные состояния | Injection-уязвимость — BLF не поддаётся обнаружению SAST; требует понимания контекста |
| Мутационное тестирование | Mutation Testing | Техника оценки качества тестов: намеренное внесение мутаций в код с проверкой, убивают ли их тесты | Coverage — 100% coverage ≠ качественные тесты; mutation score измеряет эффективность |

## 2. Паттерны (FPF E.8)

### P-01: OWASP-Aligned Security Entry Point Review

- **Проблемная ситуация:** При ревью PR с изменениями API/форм/эндпоинтов нужно быстро найти security-дыры в точках входа.
- **Силы:** SAST инструменты дают false positives и пропускают бизнес-логику. Полный ручной аудит всего кода нереалистичен. Однако именно entry points — A01-A03 OWASP — топ рисков 2025.
- **Ход (решение):** Для каждого нового/изменённого entry point (HTTP endpoint, CLI arg, queue consumer, webhook) проверить по мини-чеклисту: (1) валидация на сервере независимо от клиента; (2) параметризованные запросы; (3) авторизация до бизнес-логики; (4) output encoding по контексту; (5) отсутствие секретов в коде. Только потом — тело функции.
- **Последствия:** Структурированное покрытие топ-рисков за предсказуемое время. Уменьшает вероятность A01 (Broken Access Control) и A03 (Injection) — два лидера OWASP 2025.
- **Trade-offs:** Фокус на entry points может пропустить vulnerabilities внутри цепочек. Требует знания OWASP 2025 categories (добавлены: Software Supply Chain Failures A03:2025, Mishandling of Exceptional Conditions A10:2025).
- **Пример:** PR добавляет `/api/v2/transfer` — ревьюер сначала проверяет: есть ли проверка ownership (A01) до вызова `transfer()`, параметризован ли SQL (A03), логируется ли транзакция без чувствительных данных (A09: Security Logging).
- **Пограничные случаи:** GraphQL/gRPC — entry points не очевидны из имён файлов; нужно читать schema resolver mapping. WebSocket — одна точка входа, но множество message types.
- **Антипаттерны:** Начинать ревью с «интересной» бизнес-логики в середине, игнорируя entry points. Доверять client-side валидации как достаточной.
- **Связи:** стыкуется с [P-02] (выбор глубины ревью), [P-09] (auth boundary), [P-10] (supply chain); противоречит [P-07] (Fagan-стиль требует полного прочтения, не фокусного)
- **Когда НЕ применять:** Внутренние утилиты без входящих данных от пользователей/внешних систем. Изменения только в конфигурации/документации.
- **SoTA-источник:** OWASP Secure Code Review Cheat Sheet (2024); OWASP Top 10 2025, owasp.org/Top10/2025/en/; AWS Well-Architected Framework: SEC11-BP04 (2024)
- **Проверка качества (E.21):** В REVIEW-файле для каждого нового endpoint есть отметка по каждому из 5 пунктов мини-чеклиста. Нет пунктов «не проверял».

---

### P-02: Diff-First vs Baseline Review Selection

- **Проблемная ситуация:** Перед ревью нужно решить: смотреть только изменения (diff) или читать весь контекст (baseline).
- **Силы:** Время ревьюера ограничено. Но diff без контекста пропускает, как изменение ломает инварианты существующего кода. Baseline review дорогой, но обязателен при онбординге, крупных рефакторингах, security audit.
- **Ход (решение):** По умолчанию — diff-based review. Переключиться на baseline (или расширить контекст вручную) при сигналах: (1) изменение контракта (signature/schema/interface); (2) затронут auth/crypto/session код; (3) PR > 400 LOC; (4) новый integrator или критический модуль.
- **Последствия:** Экономия времени при стандартных PR. Baseline review в нужных точках ловит regression и инвариант-нарушения.
- **Trade-offs:** Граница «когда расширять» субъективна. PR > 400 LOC — сигнал, что автор нарушил [P-11] (малые PR).
- **Пример:** PR меняет 50 строк в `UserRepository` — diff. PR меняет 30 строк в `AuthTokenGenerator` — читаем весь модуль и тесты.
- **Пограничные случаи:** «Refactor-only» PR — могут скрывать семантические изменения за формальными переименованиями; всегда читать diff поведенчески, не только синтаксически.
- **Антипаттерны:** «Доверяю автору, смотрю только добавленные строки» без проверки убранных. Игнорировать изменения в test-файлах — они тоже часть контракта.
- **Связи:** стыкуется с [P-11] (PR size); противоречит [P-07] (Fagan требует baseline всегда)
- **Когда НЕ применять:** Не применять diff-only для security-critical кода (auth, crypto, payment) — там всегда baseline.
- **SoTA-источник:** OWASP Secure Code Review Cheat Sheet (2024) — секция "Baseline Reviews vs Diff-Based Reviews"; Google SWE Book Ch.9 (2020)
- **Проверка качества (E.21):** В начале каждого REVIEW зафиксирован тип ревью (diff/baseline) и обоснование выбора.

---

### P-03: CHK-WIRE — Production Path Verification

- **Проблемная ситуация:** Тесты зелёные, ревью прошло — но экспортируемая функция никогда не вызывается в реальном прод-потоке. Или вызывается, но через другой путь, чем тестировался.
- **Силы:** Статический анализ не различает «вызывается в тесте» и «вызывается в прод». Функции могут быть «зомби» — живы в коде, мертвы в продакшне. Coverage не гарантирует прод-путь.
- **Ход (решение):** Для каждой публичной/экспортируемой функции в PR найти прод-вызов (не тестовый): grep/LSP/IDE по реальному коду, не тестам. Если вызов есть только в тестах — это CHK-WIRE нарушение, фиксировать в REVIEW.
- **Последствия:** Выявляет orphan-функции до мержа. Предотвращает dead code drift. Сигнализирует о неверной архитектуре (функция объявлена, но реальный entry point ещё не написан).
- **Trade-offs:** Требует понимания точек входа всего приложения, не только PR. Может быть трудоёмким для библиотек с внешними потребителями. В монорепо — прод-вызов может быть в другом пакете.
- **Пример:** `UserService.archiveUser()` — экспортируется, покрыта unit-тестами. grep по продакшн-коду → вызова нет нигде. CHK-WIRE нарушение → REVIEW: «архивирование не доступно через прод-путь, либо удалить, либо добавить endpoint».
- **Пограничные случаи:** Event-driven архитектуры — функция вызывается через message broker, прямого вызова нет в коде. Решение: ищем регистрацию в consumer/handler. Plugin-архитектуры — вызов через интерфейс/рефлексию.
- **Антипаттерны:** «Тест вызывает — значит функция нужна». Не проверять удалённые вызовы (функция может стать orphan из-за рефакторинга в другом PR).
- **Связи:** стыкуется с [P-04] (wire/contract drift), [P-01] (entry points); требует [P-02] (baseline для полного понимания)
- **Когда НЕ применять:** Utility функции в shared lib — их вызов может быть в другом репо. Pure function utilities с явным документированным публичным API.
- **SoTA-источник:** **Framework-native pattern** (Core Team Framework v4.5.1, CLAUDE.md) — структурный гейт CHK-WIRE/CHK-ORPHAN специфичен для данного фреймворка, прямого внешнего SoTA-аналога нет. Концептуальные аналоги в литературе: reachability analysis / dead code elimination (IEEE Transactions on Software Engineering). Практика подтверждается Google SWE Book Ch.9 (ownership review component, 2020).
- **Проверка качества (E.21):** REVIEW содержит список новых/изменённых публичных функций и статус («прод-вызов найден: [файл:строка]» или «CHK-WIRE: прод-вызова нет»).

---

### P-04: CHK-ORPHAN — Contract/Wire Drift Detection

- **Проблемная ситуация:** Форма данных в коде (request/response/event schema) расходится с тем, что реально приходит/уходит на границе системы. Моки устарели, тесты зелёные, прод падает.
- **Силы:** Mock drift — активный источник заблуждения [vendor-claim: точная статистика доли API production failures от contract drift не подтверждена рецензируемыми первичными источниками; Uptrends — инструмент мониторинга, не исследовательская организация]. Мок проверяет мок, а не реальную систему. Consumer-driven contract testing решает часть проблемы, но требует дисциплины поддержки pact-файлов.
- **Ход (решение):** На ревью: (1) найти все I/O-границы в PR (HTTP, DB, queue, gRPC); (2) для каждой — проверить наличие живого contract теста или CHK-ORPHAN верификации (curl + реальный ответ, diff с ожидаемым); (3) если только мок — фиксировать как CHK-ORPHAN риск; (4) рекомендовать Pact/OpenAPI live validation.
- **Последствия:** Снижает прод-инциденты от schema mismatch. Выявляет протухшие моки. Создаёт давление на команду поддерживать живые контракты.
- **Trade-offs:** Live verification требует тестовой среды или sandbox. Pact требует дисциплины обеих сторон контракта. В ревью нельзя выполнить curl самому — только указать на риск.
- **Пример:** PR меняет структуру `OrderEvent` — добавляет поле `tax_amount`. Ревьюер проверяет: обновлён ли Pact contract? Есть ли снапшот реального event из Kafka? Нет → CHK-ORPHAN риск в REVIEW.
- **Пограничные случаи:** GraphQL — schema evolution может быть non-breaking для старых клиентов, но breaking для новых field assumptions. gRPC — proto-файлы версионированы, но field numbering дрейф опасен.
- **Антипаттерны:** «Мок обновили — значит всё ок». Не проверять backward compatibility при изменении контрактов. Trust the schema без live verification.
- **Связи:** стыкуется с [P-03] (CHK-WIRE), [P-05] (SAST tools не ловят wire drift); противоречит school «всё покрыто unit-тестами»
- **Когда НЕ применять:** Внутренние функции без I/O границ. Purely in-process communication без сетевых вызовов.
- **SoTA-источник:** Pact Documentation (2024), docs.pact.io; Core Team CHK-ORPHAN gate (framework-native, v4.5.1)
- **Проверка качества (E.21):** REVIEW перечисляет все I/O-границы и отмечает статус contract verification для каждой («live verified», «Pact covered», «CHK-ORPHAN risk»).

---

### P-05: SAST Layer Composition (Семафорный подход)

- **Проблемная ситуация:** Один SAST-инструмент даёт либо много noise (SonarQube), либо медленный глубокий анализ (CodeQL), либо быстрый но поверхностный (Semgrep). При ревью нужно знать, что уже покрыто автоматикой, а что — только человеческим взглядом.
- **Силы:** Alert fatigue — если SAST шумит, команда отключает его или игнорирует. False positive ≠ false negative: FP тратит время, FN = дыра в безопасности. Разные инструменты покрывают разные классы уязвимостей.
- **Ход (решение):** SoTA-паттерн (2025): Semgrep на pre-commit (< 30 сек, fast pattern matching) → CodeQL на PR (data flow, taint analysis, 10-30 мин) → SonarQube периодически (tech debt, holistic view). Ревьюер знает: что Semgrep+CodeQL не поймает — только человек (бизнес-логика, race conditions, архитектурные уязвимости). Фокус ревью — на том, что SAST пропускает.
- **Последствия:** Ревьюер не дублирует SAST-работу на очевидных паттернах. Фокусирует внимание на business logic flaws, auth complexity, race conditions.
- **Trade-offs:** Требует настроенного CI pipeline с тремя инструментами. CodeQL медленный — может тормозить PR cycle. Кастомные Semgrep rules — отдельная инвестиция.
- **Пример:** PR добавляет новый payment flow. Semgrep ловит SQL injection pattern. CodeQL трассирует taint от `request.body` до `db.query`. Ревьюер сосредоточен на: корректность flow авторизации (A01), concurrency в multi-step payment (race condition), логирование без PCI-чувствительных данных.
- **Пограничные случаи:** SAST работает на статическом коде — dynamic dispatch, reflection, eval — зоны слепоты для всех SAST. Не доверять «SAST чист = безопасно» для этих паттернов.
- **Антипаттерны:** Использовать только один SAST и считать проверку полной. Игнорировать SAST findings «потому что много false positives» — вместо настройки rules. Ручное ревью как замена SAST, а не дополнение.
- **Связи:** стыкуется с [P-01] (entry points), [P-09] (auth boundary); дополняет [P-02] (baseline vs diff)
- **Когда НЕ применять:** Очень маленькие команды — три SAST инструмента избыточны, начать с одного (рекомендуется Semgrep).
- **SoTA-источник:** «Semgrep vs CodeQL vs SonarQube» (Rafter, 2025), rafter.so/blog; StackHawk Best SAST Tools 2025
- **Проверка качества (E.21):** В REVIEW зафиксировано, какие SAST инструменты запущены и каковы результаты. Ревьюер указывает зоны, где SAST не покрывает — и что проверялось вручную.

---

### P-06: Business Logic Flaw Detection

- **Проблемная ситуация:** Уязвимость не в технической реализации, а в самой логике: пользователь может перейти к шагу 3 без завершения шага 2, менеджер может просматривать чужие данные через корректный запрос, гонки в multi-step процессах.
- **Силы:** BLF — полностью вне зоны покрытия SAST. Требует понимания бизнес-правил и threat modeling. Классическая injection проверка не помогает. Самая дорогая в постфактум исправлении категория уязвимостей.
- **Ход (решение):** При ревью любого нового бизнес-процесса: (1) построить мысленную state machine — какие переходы разрешены? (2) проверить: можно ли пропустить шаг или откатить финальное состояние? (3) проверить горизонтальный privilege escalation (может ли user_A получить ресурс user_B через корректный API?); (4) проверить временны́е окна (TOCTOU — time of check, time of use).
- **Последствия:** Обнаружение класса уязвимостей, которые не ловит ни SAST, ни стандартный QA. Требует больше времени на ревью, но окупается: средняя стоимость data breach — $4.88M (IBM Cost of Data Breach 2024).
- **Trade-offs:** Требует domain knowledge, не только технических знаний. Субъективен — ревьюер может не знать бизнес-правила. Решение: включать в REVIEW раздел «проверил ли я state transitions».
- **Пример:** PR добавляет `/refund` endpoint — ревьюер проверяет: (a) можно ли рефандить дважды (TOCTOU)? (b) доступен ли `/refund` для orders чужого пользователя через user_id в параметре (horizontal privilege escalation)? (c) есть ли idempotency key?
- **Пограничные случаи:** Distributed systems — state machine распределена, её целостность гарантируется через eventual consistency, что создаёт окна для атак. Async workflows — callback/webhook может быть вызван повторно.
- **Антипаттерны:** Считать «security чиста, если нет SQL injection». Не проверять state transitions при ревью multi-step процессов. «Авторизация уже есть в middleware» — без проверки, что middleware точно применена к этому endpoint.
- **Связи:** стыкуется с [P-01] (OWASP A01 Broken Access Control = частый BLF), [P-09] (auth boundary); SAST не помогает (противопоказан для этого паттерна как единственный метод)
- **Когда НЕ применять:** Utility-функции без состояния и без взаимодействия с пользовательскими данными.
- **SoTA-источник:** OWASP Secure Code Review Cheat Sheet (2024) — секция «Business Logic Analysis»; OWASP Top 10 A01:2021 Broken Access Control
- **Проверка качества (E.21):** REVIEW содержит секцию «Business Logic» с явной отметкой: «state transitions проверены», «горизонтальный privilege escalation проверен», «TOCTOU windows проверены».

---

### P-07: Formal Inspection vs Lightweight PR — Контекстный выбор

- **Проблемная ситуация:** По умолчанию все ревью — async PR review (lightweight). Но для критического кода lightweight может быть недостаточным. Формальная инспекция (Fagan) избыточна для рутинных PR.
- **Силы:** Fagan inspection — 1970s IBM метод с ролями (модератор, читатель, инспекторы), meeting, метриками. Даёт 60–90% defect-detection rate для формальных инспекций (McConnell, Code Complete 2, Ch.20). PR review — дёшево, асинхронно, обнаруживает меньший процент дефектов по сравнению с формальными инспекциями (McConnell, ibid.). ISTQB CTFL v4.0 Ch.3 классифицирует формальные инспекции как наиболее эффективный вид статического тестирования.
- **Ход (решение):** Lightweight PR review для 90%+ изменений. Формальная инспекция (или синхронное walk-through) при: (1) mission-critical код (payment, auth, crypto); (2) compliance requirement (SOC2, PCI DSS, HIPAA); (3) после security incident — полный audit; (4) большой архитектурный сдвиг > 1000 LOC. Hybrid: async + обязательная синхронная сессия для approval.
- **Последствия:** Экономия ресурсов на рутинных PR. Инвестиция в качество там, где цена ошибки высока.
- **Trade-offs:** «Когда критично» — субъективное решение. Нет автоматического триггера для formal inspection. В agile командах замедление неудобно.
- **Пример:** E-commerce: `/checkout/payment` — formal walk-through с architect + test. `/ui/button/color` — стандартный async PR review.
- **Пограничные случаи:** Regulated industries (медицина, финансы) — может требоваться formal inspection по умолчанию для всего кода.
- **Антипаттерны:** Formal inspection для всего — блокирует delivery. Lightweight only для критического кода — системный риск. «LGTM без чтения» — Rubber Stamp (см. §3).
- **Связи:** стыкуется с [P-02] (depth of review), [P-11] (PR size); противоречит идее «всё одинаково»
- **Когда НЕ применять:** Formal inspection НЕ применять к конфигурационным файлам, документации, trivial refactor.
- **SoTA-источник:** McConnell, Code Complete 2, Ch.20 (2004) — Software Quality Landscape; Michaela Greiler, 30 Proven Code Review Best Practices from Microsoft (2023), michaelagreiler.com; ISTQB CTFL v4.0 Syllabus, Ch.3 Static Testing (2024)
- **Проверка качества (E.21):** Тип ревью (formal/lightweight/hybrid) зафиксирован в начале REVIEW-файла с обоснованием.

---

### P-08: PR Size Control как Gate

- **Проблемная ситуация:** PR > 400 LOC приводит к rubber stamp ревью — ревьюер перегружен, пропускает дефекты. Исследования показывают: эффективность падает нелинейно с ростом PR.
- **Силы:** Давление delivery — автор хочет смержить всё сразу. Но Google benchmark: ~200 LOC — оптимальный PR. Shopify: 200-300 LOC как target. Больше — почти всегда Break it up.
- **Ход (решение):** В REVIEW: если PR > 400 LOC (без generated code, migrations, lockfiles) — явно запросить разбивку. Исключения: (1) автоматически сгенерированный код; (2) rename/move без логики; (3) migration файлы. Для больших PR — сначала проверить структуру (можно ли декомпозировать), потом — содержание.
- **Последствия:** Создаёт культуру малых, фокусных изменений. Ускоряет цикл ревью. Снижает cognitive load ревьюера.
- **Trade-offs:** Не всегда PR можно декомпозировать без потери смысла (например, крупный рефакторинг с переносом). Для таких случаев — walking review (walkthrough по частям).
- **Пример:** PR «Migrate auth to OAuth2»: 1200 LOC. Ревьюер: «Предлагаю декомпозировать: PR1 — новые OAuth2 helpers, PR2 — интеграция в endpoints, PR3 — удаление старого auth».
- **Пограничные случаи:** Monorepo — PR может затрагивать много файлов в разных пакетах, но LOC per package — мало. Считать по-пакетно.
- **Антипаттерны:** LGTM на 2000-строчный PR без комментариев. «Всё равно ничего не пойму, апрувну». Требовать декомпозицию без предложения как.
- **Связи:** стыкуется с [P-02] (baseline review threshold), [P-07] (formal inspection trigger); Google/Shopify playbooks
- **Когда НЕ применять:** Автоматически сгенерированный код (protobuf, ORM migrations, lockfiles).
- **SoTA-источник:** Google SWE Book Ch.9 (2020) — «~200 lines of code»; Shopify Engineering Blog «Great Code Reviews» (2022)
- **Проверка качества (E.21):** Если PR > 400 LOC (non-generated), REVIEW содержит либо обоснование исключения, либо запрос на декомпозицию.

---

### P-09: Authentication/Authorization Boundary Review

- **Проблемная ситуация:** Auth код — наиболее чувствительный и сложный для ревью. Мелкие ошибки здесь = критические уязвимости. A01 (Broken Access Control) — #1 в OWASP 2025.
- **Силы:** Auth логика часто размазана: middleware, decorators, inline checks, service-layer permission checks. Reviewer не всегда видит полную картину auth из одного PR. AI-генерированный код особенно подвержен A07 (Authentication Failures) и A01.
- **Ход (решение):** Для любого изменения в auth/session/permission коде: (1) проверить полноту защиты — все ли пути через endpoint защищены (no bypass через query param, header manipulation); (2) fail-safe defaults — default deny, не default allow; (3) проверить token entropy (≥128 bits); (4) cookie attributes (HttpOnly, Secure, SameSite); (5) session invalidation при logout и timeout; (6) multi-tenant isolation.
- **Последствия:** Снижение A01 и A07 OWASP рисков. Создаёт явный чеклист для самого опасного кода.
- **Trade-offs:** Требует полного понимания auth-архитектуры, не только PR diff. Иногда нужен baseline review всего auth модуля.
- **Пример:** PR добавляет новый role «moderator». Ревьюер проверяет: (a) все ресурсы, доступные admin, недоступны moderator без явного grant; (b) нет ли мест, где `is_admin OR is_moderator` без разграничения привилегий; (c) аудит-лог при использовании moderator прав.
- **Пограничные случаи:** JWT без server-side invalidation — expiry-only токены не отзываются при logout. OAuth2 — implicit flow устарел, ревьюер должен флагать.
- **Антипаттерны:** «Auth уже покрыта тестами» — без проверки, что тесты тестируют negative paths. Inline permission checks вместо centralized auth service — drift risk.
- **Связи:** стыкуется с [P-01] (entry point OWASP check), [P-06] (BLF — horizontal privilege); противоречит «доверяй middleware, не проверяй endpoint»
- **Когда НЕ применять:** Не применять расширенный auth-чеклист к коду без аутентификационного контекста (pure computation, data transformation).
- **SoTA-источник:** OWASP Top 10 A01:2021/2025; OWASP Secure Code Review Cheat Sheet — Authentication & Sessions section (2024); AWS Well-Architected Framework: SEC11-BP04 (2024), docs.aws.amazon.com
- **Проверка качества (E.21):** REVIEW для auth-содержащих PR содержит секцию «Auth Boundary» с явными отметками по всем 6 пунктам чеклиста.

---

### P-10: Supply Chain & Dependency Audit

- **Проблемная ситуация:** PR добавляет новую зависимость или обновляет существующую. OWASP 2025 добавил «Software Supply Chain Failures» как отдельную категорию A03:2025.
- **Силы:** Log4Shell (CVE-2021-44228) показал: транзитивные зависимости могут быть критичными. Equifax breach — незакрытая уязвимость в Apache Struts. Команды часто мержат dependency update PR без ревью как «технические».
- **Ход (решение):** При добавлении/обновлении зависимостей: (1) проверить CVE статус (Snyk, NIST NVD, GitHub Advisory); (2) проверить мейнтейнер активность — депрекейтед или abandoned? (3) для прямых добавлений: нужна ли эта зависимость, или стандартная библиотека достаточна (FPF principle: минимальные зависимости); (4) pinning версий с hash verification для критических зависимостей.
- **Последствия:** Снижение supply chain attack surface. Контроль dependency bloat. Соответствие OWASP A06 (Vulnerable and Outdated Components).
- **Trade-offs:** Полный CVE-аудит транзитивных зависимостей нереалистичен вручную — нужен автоматизированный SCA (Software Composition Analysis). Ревьюер фокусируется на прямых зависимостях, указывает на необходимость SCA для транзитивных.
- **Пример:** PR добавляет `lodash@4.17.15` — ревьюер проверяет CVE (несколько критических); рекомендует `lodash@4.17.21` или замену нативными ES2024 методами.
- **Пограничные случаи:** Internal/private packages — тоже нуждаются в аудите; «внутренний пакет» ≠ безопасный. Monorepo workspace packages.
- **Антипаттерны:** Auto-merge dependabot без ревью. «Всё равно потом обновим» как причина не проверять сейчас. Не проверять, что package.json pin совпадает с lockfile.
- **Связи:** стыкуется с [P-01] (OWASP alignment), [P-05] (SAST не всегда ловит supply chain); A06 OWASP
- **Когда НЕ применять:** Обновление patch-версий (x.y.Z) при наличии автоматизированного SCA в CI — можно делегировать автоматике при наличии no-CVE report.
- **SoTA-источник:** OWASP Top 10 2025 — A03 Software Supply Chain Failures; CVE-2021-44228 Log4Shell postmortem; OWASP A06 Vulnerable and Outdated Components
- **Проверка качества (E.21):** REVIEW при добавлении зависимостей содержит CVE-статус и обоснование выбора (или «SCA report прикреплён»).

---

### P-11: Code-Change Discipline при ревью (FPF A.7)

- **Проблемная ситуация:** Ревьюер видит «попутно улучшить» возможности вне scope PR. Или автор «улучшил» код, который не был в scope задачи. Это размывает ревью и вносит непредсказуемые изменения.
- **Силы:** Желание улучшить «пока открыл файл» — естественное. Но смешение scope: (1) усложняет rollback; (2) нарушает атомарность PR; (3) маскирует реальные изменения. FPF Code-Change Discipline: 7 шагов перед правкой чужого кода.
- **Ход (решение):** В ревью: (1) отмечать out-of-scope изменения как «NIT» (необязательно) или «Separate PR рекомендован»; (2) не блокировать PR из-за out-of-scope находок, если они не critical; (3) фиксировать рекомендации в отдельный backlog item, не в блокирующий комментарий. Google практика: «Nit:» prefix для необязательных.
- **Последствия:** Чистые, атомарные PR. Чёткая ответственность. Находки не теряются (попадают в backlog).
- **Trade-offs:** «Nit:» культура может откладывать tech debt бесконечно, если backlog не приоритизируется.
- **Пример:** PR добавляет feature. Ревьюер находит: (a) security bug в auth — блокирует (critical); (b) устаревший API в соседней функции — «Nit: рекомендую отдельный PR для миграции»; (c) опечатка в комментарии — «Nit:».
- **Пограничные случаи:** «Boy scout rule» (оставь лучше, чем нашёл) конфликтует с scope discipline. Решение: минорные исправления (опечатки) — ок; логические изменения вне scope — отдельный PR.
- **Антипаттерны:** Блокировать PR из-за NIT-замечаний. Игнорировать все находки вне scope. «Заодно перепишу весь модуль».
- **Связи:** стыкуется с [P-02] (scope of review), [P-07] (review type); реализует FPF Code-Change Discipline (A.7)
- **Когда НЕ применять:** Critical security bug — всегда блокирует независимо от scope.
- **SoTA-источник:** Google Engineering Practices — «What to look for in a code review» (2024); FPF Code-Change Discipline, CLAUDE.md
- **Проверка качества (E.21):** REVIEW явно разделяет находки: блокирующие (BLOCK) / рекомендации (REC) / нит (NIT). Нет смешения категорий.

---

### P-12: Defect Metrics Baseline и Escape Rate Tracking

- **Проблемная ситуация:** Без метрик невозможно понять, улучшается ли качество ревью. Команды ревьюят интуитивно, без обратной связи о пропущенных дефектах.
- **Силы:** McConnell (Code Complete 2, Ch.20): formal code inspection достигает 60–90% defect-detection rate; unit + integration testing: 30–35%; informal PR review без формального процесса — существенно ниже формальной инспекции. Без измерения невозможно целенаправленное улучшение.
- **Ход (решение):** Трекинг: (1) Defect Density = дефекты / 1000 LOC (benchmarks: 1-25 bugs/KLOC — типично; < 1 — отлично); (2) Defect Escape Rate = дефекты в проде / (дефекты в проде + пойманные до прода) × 100; цель < 5%, high performers < 2%; (3) Code Review Coverage = % PR с реальным ревью (не auto-LGTM); (4) Mean Time to Review — время от PR open до first response; Google target: 24 рабочих часа.
- **Последствия:** Видимость эффективности ревью. Data-driven improvements. Связь с DORA metrics (Change Failure Rate).
- **Trade-offs:** Метрики можно «играть» (например, снижать DER за счёт принятия дефектов как «features»). Нужна культура честного учёта.
- **Пример:** Квартальный отчёт: DER = 8% (выше цели 5%). Анализ: 60% escaped дефектов — в auth коде. Решение: обязательный [P-09] auth checklist для всех auth PR.
- **Пограничные случаи:** Стартапы — недостаточный sample size для надёжных метрик. Метрики имеют смысл при стабильном объёме изменений.
- **Антипаттерны:** Измерять только количество комментариев в PR (активность ≠ эффективность). Игнорировать «postmortem attribution» — без разбора, какие продовые баги можно было поймать на ревью.
- **Связи:** стыкуется со всеми паттернами как измерительный слой; DORA metrics (Change Failure Rate)
- **Когда НЕ применять:** Не вводить метрики как performance metrics для индивидуальных ревьюеров (Goodhart's Law — мера становится целью). Только командный уровень.
- **SoTA-источник:** McConnell, Code Complete 2, Ch.20 (2004) — Software Quality Landscape; DORA 2024 State of DevOps Report; «Defect Escape Rate Guide» (Opsera, 2024)
- **Проверка качества (E.21):** Команда имеет dashboard с DER, Defect Density, MTtR. Данные обновляются не реже чем раз в спринт.

## 3. Каталог антипаттернов (сквозной)

| Антипаттерн | Симптом | Почему вреден | Чем заменить (P-NN) |
|-------------|---------|---------------|---------------------|
| **Rubber Stamp LGTM** | PR с 0 комментариев и мгновенным апрувом | Дефекты проходят незамеченными; создаёт ложное чувство безопасности | [P-07] — выбор формата ревью; [P-08] — контроль размера PR |
| **Green Tests = Safe** | «Тесты зелёные — мержим» без CHK-WIRE/CHK-ORPHAN | Тесты могут покрывать код, который никогда не вызывается в прод | [P-03] CHK-WIRE, [P-04] CHK-ORPHAN |
| **Mock Drift** | Моки не обновляются при смене контракта; тесты зелёные, прод падает | Значительная доля API production failures вызвана contract drift [vendor-claim: точная доля без верифицируемого первичного источника] | [P-04] CHK-ORPHAN — требовать live verification |
| **SAST = Security Done** | «CodeQL чист, значит безопасно» | SAST не обнаруживает BLF, race conditions, auth bypass через logic | [P-05] + [P-06] — SAST + human BLF review |
| **AI Code Trust** | AI-сгенерированный код проходит без дополнительной security проверки | LLM-ассистенты генерируют A03/A07/A02 паттерны (OWASP 2025) | [P-01] — entry point review обязателен для AI-кода |
| **Scope Creep Review** | Ревьюер переписывает не затронутый PR код | Размывает ответственность, усложняет rollback, раздувает scope | [P-11] — Code-Change Discipline, Nit: prefix |
| **Dependency Auto-LGTM** | dependabot PR мержится без ревью | Supply chain attack vector; Log4Shell pattern | [P-10] — dependency audit |
| **Alert Fatigue Bypass** | SAST настроен на «все правила», команда отключает/игнорирует | Критические findings теряются в шуме | [P-05] — layered SAST с тюнингом правил |
| **Big Bang PR** | PR > 1000 LOC как «одна логическая фича» | Когнитивная перегрузка ревьюера → rubber stamp | [P-08] — gate по размеру PR |
| **Authorization in Middleware Only** | «Auth покрыта middleware, в endpoint не нужно» | Любой bypass middleware (direct route, test endpoint) открывает дыру | [P-09] — auth boundary review каждого endpoint |
| **Postmortem без Attribution** | Продовый баг исправлен, но не разобрано «мог ли ревью поймать?» | Нет обучающего сигнала; те же ошибки повторяются | [P-12] — defect tracking с attribution |

## 4. Карта противоречий (между школами)

| Вопрос | Школа A | Школа B | Как выбирать в контексте роли test |
|--------|---------|---------|--------------------------------|
| **Формальная инспекция vs PR review** | Fagan: meeting + роли + checklist entry/exit criteria даёт 60–90% defect-detection rate (McConnell, Code Complete 2, Ch.20) | Google/modern: async PR review, single reviewer, ~200 LOC, fast iteration | Hybrid: async PR для 90% PR; formal walk-through для auth/crypto/payment. Размер и criticality — триггер |
| **SAST: всё найдёт автоматика** | «SAST + CodeQL достаточно для security» — автоматизация масштабируется, люди нет | «Human review незаменим для BLF, race conditions, arch vulns» — инструменты слепые на контекст | Layered approach [P-05]: SAST как фильтр, human focus на том, что SAST не ловит |
| **Shift Left vs Runtime verification** | «Ловить всё на этапе кода — shift left, дешевле» [hypothesis: сравнительные цифры стоимости дефектов по фазам часто атрибутируются к NIST 2002; IBM Cost of Data Breach 2024 освещает breach-cost, не dev-phase costs] | «DAST/runtime нужен — SAST даёт false negatives на injection и auth в dynamic contexts» | И то, и другое. SAST в CI/CD, DAST в staging. CHK-ORPHAN = форма runtime verification |
| **Single reviewer vs multiple** | Google: один ревьюер достаточно для большинства PR, минимизирует overhead | Fagan и regulated industries: минимум 2 независимых ревьюера для critical code | Определяется criticality: auth/payment/crypto — 2 ревьюера; рутина — 1 |
| **Comment all vs focus** | «Документируй все находки, даже мелкие — накапливается debt picture» | «Ревью без focus = шум; только блокирующие находки» | Google «Nit:» protocol [P-11]: разделять категории, не блокировать на nit, но фиксировать |
| **Consumer-driven vs Provider-first contracts** | «Потребитель знает, что ему нужно — CDC (Pact) — единственный надёжный метод» | «Provider публикует spec (OpenAPI) — потребители адаптируются» | CDC для внутренних микросервисов [P-04]; OpenAPI для внешних публичных API |

## 5. Guide применения — что / когда / как

| Сигнал ситуации | Применить паттерн(ы) | Не применять |
|-----------------|----------------------|--------------|
| PR затрагивает HTTP endpoint / форму / queue consumer | [P-01] OWASP entry point check | Формальную Fagan инспекцию (если не критичный) |
| PR > 400 LOC | [P-08] size gate — запросить декомпозицию | LGTM без структурного ревью |
| Изменён auth / session / crypto код | [P-09] auth boundary + [P-07] formal/hybrid review | Diff-only review |
| Новая / обновлённая зависимость | [P-10] supply chain audit | Auto-LGTM |
| Изменён API контракт / schema / event structure | [P-04] CHK-ORPHAN + contract verification | Mock-only verification |
| Экспортируется новая публичная функция | [P-03] CHK-WIRE — найти прод-вызов | Считать unit-тест покрытие достаточным |
| Новый бизнес-процесс с состояниями / multi-step flow | [P-06] BLF detection — state machine check | Полагаться только на SAST |
| PR от AI-ассистента (Copilot, Claude, etc.) | [P-01] + [P-09] + [P-05] — повышенный security scrutiny | Доверять «AI написал — значит правильно» |
| Квартальный / спринт-ретро цикл | [P-12] defect metrics review | Оценивать качество ревью субъективно |
| Рутинный небольшой PR | [P-02] diff-based review | Полный baseline review |

## 6. Improvement Log (FPF E.9 / E.21)

| Дата | Что менялось | maturity до→после | Открытые пробелы (недобранные источники / слабые паттерны) |
|------|--------------|-------------------|-------------------------------------------------------------|
| 2026-06-29 | Первичный DPF на основе web-research по 11 каналам Collection Protocol | seed→draft | **Недобранные:** (1) Пропущены конкретные плейбуки Facebook/Meta Engineering и Amazon internal review process — только косвенные данные. (2) Mutation testing (Pitest, Stryker) как техника качества тестов — упомянут в глоссарии, но нет паттерна. (3) AI-assisted code review tools (Qodo, GitHub Copilot review) — быстро меняющаяся область, нужен отдельный паттерн. (4) Регуляторные контексты (SOC2, PCI DSS) — стандарты указаны, но не разобраны как отдельные паттерны. (5) Конкретные Semgrep rule libraries для OWASP паттернов — полезно добавить как «ход» в P-05. **Слабые паттерны:** P-12 (metrics) — нет конкретных benchmarks по дефект-плотности по типам проектов. P-06 (BLF) — нет конкретного инструментального метода обнаружения (только мысленная state machine). |
| 2026-06-29 | Аудит DPF ролью ПРОВЕРЯЮЩИЙ (FPF E.21) | — | **Найденные пробелы провенанса (A.10):** (1) P-04: "70% API failures связаны с contract drift (Uptrends, 2025)" — Uptrends является инструментом мониторинга, не исследовательской организацией; ни URL, ни название отчёта не указаны. Цифра выглядит голословной. Требует замены на верифицируемый источник (State of API Report, Postman; или SmartBear API Report) или удаления точной процентной цифры. (2) P-03 SoTA-источник самоссылочный: единственный primary = "Core Team Framework, CLAUDE.md" — внутренняя документация, не SoTA. CHK-WIRE — концепция собственного фреймворка без внешнего аналога; следует явно пометить как «framework-defined pattern» и убрать слово SoTA, или добавить внешний аналог (reachability analysis / dead code elimination literature). (3) frontmatter `sources_count: 11`, но в списке `sources` фактически 15 строк — несоответствие. (4) P-12: "Code reading: ~80% faults/hour" — атрибуция McConnell неточна; у McConnell (Code Complete 2, Ch.20) фигурирует 60–90% **defect detection rate** для инспекций, не "faults/hour". Формулировка вводит в заблуждение. **Итог: 4 пробела, из которых 2 нарушают A.10 провенанс (P-04 голословная цифра, P-12 неточная атрибуция).** |
| 2026-06-29 | Loop-improve E.21: закрытие провенанс-пробелов из предыдущего аудита | draft→refined | **Закрыто:** (1) P-04: "70% Uptrends" заменено на [vendor-claim] с пояснением отсутствия первичного источника; §3 Mock Drift antipattern — та же правка. (2) P-03: явно помечен как framework-native pattern, добавлена ссылка на концептуальные аналоги в литературе (reachability analysis). (3) P-12: McConnell исправлен — "60–90% defect-detection rate (Code Complete 2, Ch.20)", удалена вводящая в заблуждение формулировка "~80% faults/hour". (4) P-07: та же правка McConnell в теле паттерна и §4. (5) frontmatter sources_count исправлен: 11→15 (реальный счёт). (6) Dead sources процитированы: Michaela Greiler — добавлена в P-07; ISTQB CTFL v4.0 — добавлена в P-07; AWS Well-Architected — добавлена в P-01 и P-09. (7) §4 "Shift Left $500 vs $50K (IBM 2024)" помечен как [hypothesis] с правильным указанием на NIST 2002. (8) based_on_fpf обновлён до 40b232f11ed950ed34082273c57ff4f6c45b7f06. **Осталось открытым:** mutation testing без паттерна; AI-assisted review tools без паттерна; Facebook/Amazon internal playbooks не верифицированы. |
