# Review NN — FEAT-NNNN-<slug>

**Дата:** YYYY-MM-DD
**Reviewer:** test (subagent)
**Статус:** clean / needs-changes / blocked
**Покрытие тестами:** XX%

## Что рассмотрено

- ARCH-NN.md (соответствие)
- README.md (DoD)
- Код фичи: <список модулей/файлов>
- Тесты: <список тестов>

## P0 / Critical (блокирующие)

Безопасность, integrity, breaking change без обсуждения.

- **[ID-001]** [файл:строка] <описание>
  - **Правило:** <OWASP-NN | FC-N | FPF A.X>
  - **Рекомендация:** <конкретное действие>

## P1 / High (блокирующие merge)

Error Hiding, нарушение TDD (нет тестов на новое поведение), FPF-violation.

- **[ID-002]** [файл:строка] <описание>
  - **Правило:** <…>
  - **Рекомендация:** <…>

## P2 / Medium (не блокирующие)

Style, отсутствие docstring, неконсистентное именование.

- **[ID-003]** [файл:строка] <описание>
  - **Рекомендация:** <…>

## P3 / Low (suggestions)

Cosmetic, nice-to-have.

- **[ID-004]** [файл:строка] <описание>

## Соответствие

| Критерий | Статус | Комментарий |
|----------|--------|-------------|
| ARCH | ✓ / ✗ | <отклонения> |
| DoD (из README) | ✓ / ✗ | <не выполнено> |
| Functional Clarity | ✓ / ✗ | <Error Hiding, длина функций> |
| FPF (A.7/A.10/A.11/A.1.1) | ✓ / ✗ | <нарушения> |
| Code-Change Discipline | ✓ / ✗ | <нарушения 7-step> |
| Security (OWASP Top 10) | ✓ / ✗ | <issues> |
| Stack-specific (knowledge/stacks/<X>/review.md) | ✓ / ✗ | <issues> |

## Резюме

<2-3 предложения: основной вывод, что блокирует merge, что можно отложить.>

## Next steps

- Если P0/P1 → возврат к dev (стейдж 3 в /plan-do) с этим REVIEW-NN.md
- Если только P2/P3 → передача keeper-у (стейдж 6 в /plan-do)
