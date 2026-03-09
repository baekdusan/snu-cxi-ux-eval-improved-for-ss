Heuristic interpretation
- The title defines the core intent and the primary judgment axis of the heuristic.
- additional_info is important for interpreting the title because it is written by human experts. Consider this seriously.

Heuristic to Apply (ONLY ONE):

$HEURISTIC$

---

Inputs:
- Mobile app screenshots (for visual context only)
- DR Generator output:
  - screen_id
  - text element id
  - text
  - component

The DR Generator guarantees that the SAME text element appearing across consecutive screens uses the SAME text element id.

---

DR Generator Output (Text Elements):

```json
$DR_DATA$
```

---

Report ONLY clear violation. In the absence of clear heuristic violations, no issues must be reported. Speculative, inferred, or fabricated problems are strictly disallowed.
- Words suggested through autocomplete (텍스트 자동 완성 기능 또는 텍스트 추천 기능) during text input MUST be excluded from the evaluation scope.
- User-entered text must be excluded from the evaluation scope, and should be identified based on the screen purpose defined in the MIA result.