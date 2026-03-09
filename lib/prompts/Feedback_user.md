You are refining UX issues based on user feedback.

Review the existing UX issues below and update them according to the user's comment.
Use the DR Generator output and screenshots as ground truth for what is visible on-screen.

---

DR Generator Output:

```json
$DR_DATA$
```

---

Current UX Issues to Review:

```json
$ISSUES$
```

---

User Feedback:

$USER_COMMENT$

---

Instructions:
1. Carefully read the user's feedback and understand their intent.
2. For each issue, decide whether to modify, keep, or remove it based on the feedback.
3. If the feedback reveals a new problem not covered by existing issues, add it with a new issue_id using the prefix "$ID_PREFIX$".
4. Maintain the exact same JSON structure for each issue as the input.
5. Provide a "changes" array summarizing what was done to each issue.
6. All descriptive content must be in Korean.
