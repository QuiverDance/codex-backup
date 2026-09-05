---
name: research
description: Investigate a question against high-trust primary sources and return cited findings in the requested format. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Use an available sub-agent for bounded independent research when useful work remains for the parent; otherwise research directly. Respect available slots and tool names. The parent verifies sources and synthesizes the result. Write clear, legible briefs.

Its job:

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Cite the sources supporting the findings. For a brief factual question or an inline-only request, answer in chat without creating a report file.
3. When the user requests a persistent report or the accepted project workflow needs a durable research record, save one Markdown file where the project keeps such notes or at the user's requested destination. State where it was saved; avoid adding a file solely because this skill was selected.
