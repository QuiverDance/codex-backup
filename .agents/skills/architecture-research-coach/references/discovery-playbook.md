# Discovery Playbook

Use this playbook when the user has no research idea, only a broad field, or no evidence-grounded limitation.

## Entry diagnosis

Identify the earliest missing anchor:

| State | Needed next |
|---|---|
| No field | Compare 2-4 fields by interest, prerequisites, resources, and feedback speed |
| Field but no system | Select a concrete architecture, platform, simulator, or software stack |
| System but no workload | Select representative and stress workloads |
| Workload but no observation | Reproduce, profile, or perform a resource/latency breakdown |
| Observation but no problem | Test whether the effect is large, repeatable, general, and important |
| Problem but no cause | Enter Theory mode with competing mechanisms |

Do not ask "What is your novel idea?" when the user has no observation base.

## Beginner question set

Ask only the smallest relevant subset:

- Which topics or systems are interesting enough to study for weeks?
- Which tools can the user already use or realistically learn?
- What hardware, simulators, datasets, and time are available?
- Is the preferred work measurement, simulation, RTL/design, compiler, modeling, or mixed?
- How quickly can the user get a meaningful feedback signal?

Offer bounded choices and examples. Accept "I do not know" and convert it into a short comparison task.

## Build a literature-system map

Prefer primary papers, official architecture documentation, and reproducible artifacts. Record:

| Item | Questions |
|---|---|
| System | What architecture and execution path are studied? |
| Workload | What inputs, models, sizes, and access patterns matter? |
| Metric | Throughput, latency, energy, area, bandwidth, utilization, accuracy, or cost? |
| Baseline | What is the current comparison point? |
| Claimed mechanism | Why does the method work? |
| Boundary | Where does it stop working or become costly? |
| Artifact | Can the user reproduce or inspect it? |

Do not confuse a paper's future-work paragraph with evidence that the proposed topic is valuable or feasible.

## Observation tasks

Choose a task that produces evidence within the user's resources.

### Reproduction

- Reproduce one headline result.
- Explain every major configuration difference.
- Record deviations and unstable behavior.

### Bottleneck breakdown

- Decompose total time, instructions, traffic, energy, or area.
- Identify the dominant component and how it changes with scale.
- Check whether the named bottleneck is actually saturated.

### Scaling boundary

- Sweep workload size, batch size, precision, sparsity, locality, core count, or bandwidth.
- Find where the dominant regime changes.
- Explain the structural reason for the transition.

### Cross-system comparison

- Run the same workload on different architectures or execution paths.
- Normalize metrics and configurations.
- Search for a capability mismatch rather than merely ranking devices.

### Correctness-performance tension

- Identify optimizations that improve speed but harm accuracy, stability, determinism, or numerical range.
- Determine whether the tradeoff is fundamental or an implementation artifact.

### Software-hardware mismatch

- Trace a high-level operation to compiler output, instruction stream, memory traffic, and execution units.
- Look for conversions, synchronization, data movement, serialization, or unsupported primitives.

### Resource waste

- Measure idle units, redundant work, metadata overhead, overfetch, underutilization, or recomputation.
- Test whether removing the waste would change the end-to-end bottleneck.

## Generate candidate problems

Create candidates only from evidence or a clearly identified missing observation. Use:

`[Observation] -> [Limitation] -> [Impact] -> [Suspected causes] -> [First rejection test]`

Score candidates qualitatively:

- importance of the affected metric;
- strength and repeatability of evidence;
- availability of a mechanistic explanation;
- ability to design a structural change;
- feasibility with the user's resources;
- time to first falsifiable result;
- novelty risk and closest prior work.

Recommend a small lead candidate and one backup, but let the user choose.

## Discovery stop condition

Move to the Problem gate only when:

- the phenomenon is observable or supported by a primary source;
- the limitation is stated for a specific system, workload, metric, and condition;
- the user understands why it matters;
- the next step is cause analysis, not more unguided exploration.
