# Architecture Experiment Audit

Use before preregistration, execution review, result analysis, or paper-claim review.

## Preregistration audit

### Claim mapping

- Give every experiment one primary claim, insight, assumption, or boundary.
- Explain why the measurement distinguishes the frozen hypothesis from alternatives.
- Remove experiments that repeat a visual pattern without resolving a new claim.

### Baseline fairness

- Use the strongest relevant baseline, not only the easiest implementation.
- Match hardware generation, software stack, compiler flags, precision, batch size, memory capacity, and optimization effort when applicable.
- Separate algorithmic gains from implementation maturity.
- Explain any baseline limitation that cannot be equalized.

### Workload validity

- Include representative workloads for the claimed use case.
- Include a stress or boundary workload when the claim depends on scale or pressure.
- Avoid selecting only cases known to favor the design.
- Record datasets, inputs, seeds, preprocessing, warmup, and termination conditions.

### Metrics and units

- Define numerator, denominator, measurement window, and aggregation.
- Pair relative improvements with absolute values.
- Include end-to-end metrics when component speedups may be hidden elsewhere.
- Account for energy, area, storage, metadata, preprocessing, conversion, synchronization, and transfer overheads when relevant.

### Controls

- Change one target factor at a time when it isolates the mechanism. Use factorial designs or joint ablations for interaction hypotheses, recording main and interaction effects as appropriate.
- Record every variable that cannot be held fixed.
- Use ablations to isolate insights where possible and explicit interaction experiments where effects are coupled.
- Validate functional and numerical correctness before performance.

### Stability

- Define repetitions, warmups, confidence or variability reporting, and outlier handling before runs.
- Check deterministic versus stochastic sources of variation.
- Use enough runs to distinguish the expected effect from measurement noise.

### Falsification

- State the expected direction and meaningful effect threshold.
- State a result that would reject or narrow the hypothesis.
- State stop conditions for invalid, unsafe, or prohibitively expensive runs.
- Freeze these conditions before confirmatory execution.

### Reproducibility

- Record code revision, environment, dependencies, compiler, flags, hardware, firmware, driver, configuration, commands, and raw output locations.
- Preserve scripts that regenerate figures and tables from raw data.
- Avoid manual transformations that cannot be replayed.

## Execution audit

- Confirm the executed configuration matches the preregistered one.
- Log deviations before inspecting outcome implications.
- Check correctness on small, interpretable cases.
- Monitor saturation, throttling, caching, frequency, thermal state, background activity, and resource contention.
- Preserve raw results, error logs, and failed runs.
- Do not silently discard unfavorable or unstable measurements.

## Analysis audit

### Quantitative first

- State measured facts before causal interpretation.
- Report absolute and relative values with uncertainty.
- Recompute derived metrics independently.

### Mechanism check

- Trace each result back to the insight and hypothesis.
- Verify intermediate signals predicted by the mechanism, not only the final speedup.
- Search for an alternative cause that predicts the same endpoint.

### Generalization

- Limit the claim to tested systems, workloads, scales, and conditions.
- Identify architecture-specific and workload-specific dependencies.
- Test whether the bottleneck moves after the proposed optimization.

### Negative and mixed results

- Preserve failed predictions.
- Distinguish hypothesis failure, design failure, implementation failure, and invalid measurement.
- Return to Theory for a new mechanism rather than editing the frozen story.

## Claim audit

Require a trace:

`Evidence -> Observation -> Insight evaluation -> Hypothesis status -> Claim`

Reject or narrow a claim when:

- a required insight lacks a distinguishing experiment;
- gains disappear after full overhead accounting;
- only weak or outdated baselines are beaten;
- workloads are selected post hoc;
- the causal mechanism lacks intermediate evidence.

Assess user understanding separately from evidence validity. Explain gaps in understanding or offer a teach-back when useful; inability to explain is not itself evidence against a claim. User approval is still required to record the final claim as accepted.

## Independent adversarial roles

For consequential claims, assign independent reviews when available:

- baseline attacker: find a stronger or fairer comparison;
- workload attacker: find a representative case where the claim may fail;
- measurement attacker: find artifacts, hidden overhead, and configuration drift;
- mechanism attacker: construct a competing explanation;
- reproducibility attacker: attempt to rerun the result from recorded artifacts.

A repaired experiment or claim must be audited again.
