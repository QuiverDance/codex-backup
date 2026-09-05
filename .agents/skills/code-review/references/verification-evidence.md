# Verification evidence

Use existing test output, CI artifacts, and task notes to connect a result to the work it actually checked. Scale the record to the task; a concise note is enough. This guidance adds no runtime, hook, approval gate, mandatory metadata schema, or command allowlist.

## Record what happened

For a meaningful check, retain the command or intended interaction, working directory or target artifact, relevant code state, material environment and inputs, result, and location of supporting output when available. A commit alone does not identify uncommitted changes. Record only what is needed to assess applicability; never copy secrets or full environment dumps.

Distinguish planned, running, passed, failed, interrupted, and not-run checks. Mark a reused result as reused and identify its original run and why it still applies. Starting a command, listing a test plan, or receiving one successful browser call does not establish the requested outcome. Separate observed results from another person's report and from your inference.

## Decide what remains applicable

Reuse a successful result only when the checked behavior and its relevant inputs remain unchanged: source, test code, configuration, dependencies, generated inputs, runtime or toolchain, and relevant external state. Use repository knowledge, existing dependency information, or trustworthy execution records; no universal hashing or tracing system is required.

Inspect the actual change before declaring it unrelated. A documentation edit can affect doctests or a build. A matching commit or unchanged named file does not establish that all dependencies and external state are unchanged. When evidence of applicability is insufficient, rerun the affected check or state that it remains unverified. Reuse never overrides repository-required checks or an explicit request for a fresh run.

## Recover from partial execution

If a batch stops at a failure, later checks are not-run unless output proves they executed. Preserve independently completed results. After a fix, rerun failed, interrupted, stale, and still-required unexecuted checks; retain earlier successes only when the fix did not invalidate them. Do not split an existing suite merely to claim partial success: use its actual result boundaries and preserve setup, ordering, and integration coverage.

## Preserve the outcome standard

A passing check supports only the behavior it observes. Focused regression tests and verification through the intended user flow can be complementary; neither a cache hit nor a narrow test substitutes for required orchestration, authorization, persistence, or external effects. Choose sufficient evidence without a fixed number of sources or forced approval contract. Use existing practical tools, including project scripts.

At completion, report material failures and missing coverage, and distinguish actual fresh execution from justified reuse. Report time savings only when measured against a meaningful comparable baseline; label estimates and do not infer product speedups from avoided commands or synthetic examples. Ordinary tasks do not need timing instrumentation or a new report file.
