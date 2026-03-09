Heuristic interpretation
- The title defines the core intent and the primary judgment axis of the heuristic.
- additional_info is important for interpreting the title because it is written by human experts. Consider this seriously.

Heuristic to Apply (ONLY ONE):

$HEURISTIC$

---

Inputs:
- Mobile app screenshots (for visual context only)
- DR Generator structured output:
1. Input constraints (입력)
2. Confirmation elements (확인)
3. Error Warning / Feedback messages (오류 경고/피드백)
4. Recovery controls (제어)
5. Navigation escape routes (네비게이션 이탈)

During evaluation, infer the interaction flow and UI state transitions within each screenshot based on the DR Generator output.
The DR structure should be treated as the primary reference for understanding interaction intent and behavioral changes across screens.

---

DR Generator Output (Text Elements):

```json
$DR_DATA$
```

---

Report ONLY clear violation. In the absence of clear heuristic violations, no issues must be reported. Speculative, inferred, or fabricated problems are strictly disallowed.