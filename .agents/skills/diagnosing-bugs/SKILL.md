---
name: diagnosing-bugs
description: Diagnosis loop for hard bugs and performance regressions. Use for unclear, intermittent, or difficult bugs and performance regressions, or when the user asks for a structured diagnosis.
---

# Diagnosing hard bugs

Use this loop for unclear, intermittent, or difficult bugs and performance regressions. A localized fix with clear evidence can use a shorter loop. Read relevant domain vocabulary and architectural decisions when present.

## Establish the observed failure

Record the expected outcome, actual outcome, environment, and intended entry point. Use existing UI behavior, logs, traces, or a user report as evidence; distinguish observation from inference. Improve reproducibility while inspecting relevant code and forming hypotheses. A deterministic command is useful, but is not a prerequisite for reasoning or independent progress.

Choose the closest practical existing interface that preserves the real control flow. A focused test, CLI command, browser interaction, or recorded trace can tighten feedback. Mocks and harnesses can isolate a cause but cannot prove the requested capability works. The optional `scripts/hitl-loop.template.sh` is a helper for suitable shell environments, not a required runtime.

## Narrow and explain

Reduce the failing case enough to discriminate plausible causes without losing the original behavior. Rank hypotheses against evidence; test the most informative ones. Share material findings without waiting for approval of routine diagnostic steps. For intermittent failures, choose repetitions and measurements appropriate to the observed rate and cost, and report the uncertainty rather than imposing a universal threshold.

If access or evidence is missing, state exactly what cannot be verified and request the smallest missing input. Continue code inspection and other independent investigation. Do not claim a fix on the strength of an unverified hypothesis.

## Fix and verify

When implementation is authorized, make the smallest complete correction that preserves the accepted architecture and outcome. Add the smallest meaningful regression test reproducing the failure at an appropriate existing interface; establish that it fails for the original defect when practical. If automated reproduction is unavailable, retain direct failure evidence and state the coverage limitation.

Use [verification evidence](../code-review/references/verification-evidence.md) for retries and result freshness. Retain the original failure and distinguish a failing check from a check that never ran.

Verify the same representative flow again, then run affected and repository-required checks. Remove temporary instrumentation introduced for diagnosis. Explain the cause, change, evidence, and remaining limits. Report any broader architectural opportunity separately; do not expand this fix into a redesign without authorization.
