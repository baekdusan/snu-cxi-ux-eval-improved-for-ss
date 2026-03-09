Heuristic interpretation
- The title defines the core intent and the primary judgment axis of the heuristic.
- additional_info is important for interpreting the title because it is written by human experts. Consider this seriously.
- Visual consistency evaluation must be based strictly on visual evidence.

Heuristic to Apply (ONLY ONE):

$HEURISTIC$

---

Inputs:
- Mobile app screenshots (for visual context only)
- DR Generator structured output:
  - screen_id
  - screen_level attributes
  - elements with layout, shape, color, typography, visual_effect, text

The DR Generator guarantees that the SAME visible UI element appearing across consecutive screens uses the SAME element id.
The DR structure should be treated as the primary reference for understanding visual inconsistency.

---

DR Generator Output (Text Elements):

```json
$DR_DATA$
```

---

Report ONLY clear violation. In the absence of clear heuristic violations, no issues must be reported. Speculative, inferred, or fabricated problems are strictly disallowed.