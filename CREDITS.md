# Благодарности и источники

Core Team стоит на плечах нескольких проектов и методологий. Здесь — явная атрибуция.

## Прямые предки инструментов

- **[i-m-senior-developer](https://github.com/spumer/i-m-senior-developer)** — Святослав Посохин ([@spumer](https://github.com/spumer)).
  Skills `functional-clarity`, `tdd-master`, `llms-keeper`, `planner` в Core Team — развитие идей и формулировок из этого проекта. Пайплайн ролей (architect → dev → test) перекликается с его плагином `sdlc`. Если нужны эти тулы как самостоятельные плагины — бери их из апстрима spumer (в Core Team они встроены и заточены под фреймворк; **смешивать не рекомендуется** — см. README).

## Методологические основы

- **First Principles Framework (FPF)** — Анатолий Левенчук. Репозиторий спецификации: [github.com/ailev/FPF](https://github.com/ailev/FPF). Операционные принципы FPF (NQD, Evidence Graph A.10, Strict Distinction A.7, Parsimony A.11, Bounded Context A.1.1, Decay Review Rule) встроены в `knowledge/fpf/`, роли `architect`/`cto` и skill `fpf-integration`. См. работы по системному мышлению и онтологике (ailev.ru, Школа системного менеджмента).
- **Functional Clarity** — авторская методология (22 принципа надёжного кода), формализованная в `skills/functional-clarity/`.
- **Core Protocols** — McCarthy (Core Protocols), Holacracy 5.0, Six Thinking Hats (Edward de Bono) — лёгли в `knowledge/core-protocols.md`.
- **TDD** — Kent Beck (Test-Driven Development), Robert C. Martin — основа `skills/tdd-master/`.
- **Navigator** — Cynefin (Dave Snowden), Iceberg Model, Ladder of Abstraction, System Operator (ТРИЗ) — диагностика «кружения».
- **llms.txt** — стандарт [llmstxt.org](https://llmstxt.org) для контекста AI-агентов.

## Контрибьюторы

- [@spumer](https://github.com/spumer) — инструментальные предки
- @FinProduct
