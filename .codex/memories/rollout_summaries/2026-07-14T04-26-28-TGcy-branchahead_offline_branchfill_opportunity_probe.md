thread_id: 019f5ee0-58c9-7fc2-9e28-165392fe575a
updated_at: 2026-07-14T04:48:05+00:00
rollout_path: /home/pjw7200/.codex/sessions/2026/07/14/rollout-2026-07-14T04-26-28-019f5ee0-58c9-7fc2-9e28-165392fe575a.jsonl
cwd: /home/pjw7200

# BranchFill/BranchAhead idea was stress-tested as a trace-only offline research question and found to have limited SWE-bench decode opportunity.

Rollout context: the user wanted to know whether the idea was worth pursuing offline, especially on SWE-bench Verified traces, and whether there was room to extend BranchFill beyond prefill into response/action speculation. The existing `token_timing.py` trace instrumentation was the main data source because it already records tool timing and output timing.

## Task 1: Initial BranchFill-style offline opportunity study

Outcome: success

Preference signals:

- The user repeatedly said they wanted to "동의해" on narrowing the first study to offline, causal, trace-based analysis and explicitly said they wanted to "일단 offline으로 비용을 생각하지 않고 기회가 얼마나 있을 수 있는지를 보고싶어". This suggests that in similar research discussions, the default should be to start with an offline upper-bound / opportunity analysis before any runtime-cost implementation.
- When asked about the scope, the user accepted the distinction between causal candidates and oracle upper bounds, implying they want research questions sharpened into measurable offline metrics before system-building.

Key steps:

- Confirmed that existing SWE-bench Verified traces already contained sufficient signal to measure tool output prefix reuse.
- Verified that `token_timing.py`/trace format already carries tool output timing and raw output information.
- Established a causal offline metric: only earlier completed outputs in the same trajectory count as candidates; future and cross-trajectory outputs are excluded.
- Measured exact token-prefix reuse with the target tokenizer, while keeping raw output and model-visible output separate.
- Collected per-call and summary artifacts for reuse analysis rather than jumping straight to implementation.

Failures and how to do differently:

- No code changes were needed in the repo for the research phase; the main caution is to keep the default workflow trace-first and offline-first when the question is about opportunity sizing.

Reusable knowledge:

- The SWE-bench Verified trace set already has enough structure for exact-prefix studies: raw output, rendered output, tool timing, returncode, and model timing are present in the saved trajectories.
- For exact KV-reuse reasoning, the important boundary is the actual prompt-visible token stream, not just raw output text.
- The repo already has `token_timing.py`-style instrumentation that records `time_to_first_output_s`, `duration_s`, `output_events`, and raw tool output, which is enough for many offline analyses without rerunning benchmarks.

References:

- [1] `token_timing.py` already records `tool_calls` with `duration_s`, `time_to_first_output_s`, `returncode`, `raw_output_chars`, `raw_output_bytes`, and `output_events`.
- [2] SWE-bench Verified trace count observed in repo: `500` trajectories for the Qwen36 token-timing run.
- [3] Offline opportunity result from the first probe: `any_prior` oracle reuse on SWE-bench Verified was about `0.982%` of response tokens; command-similarity `k=4` was about `0.668%` response-token coverage, with `3.13%` next-action exact hit and `2.32%` next-tool-time coverage.

## Task 2: BranchAhead / response-draft and action speculation feasibility check

Outcome: partial

Preference signals:

- The user’s idea explicitly broadened from prefill-only to a more ambitious “tool output + next response + next action” speculation story, but the rollout evidence shows the user was mainly interested in whether the idea had offline legs at all, not in committing to implementation.
- The user accepted a trace-only feasibility check, which suggests that in similar cases they value a falsification pass before engineering work.

Key steps:

- Probed the trace structure to see whether each tool output is followed by an assistant response and then another tool call; confirmed this exists densely in both SWE-bench and AnalysisBench traces.
- Reconstructed assistant completion tokens from the saved trajectory using the model chat template, then compared candidate next-response prefixes against actual next responses.
- Separated three effects: observation prefix reuse, next-response prefix reuse, and next-tool exact hit.
- Ran a second offline probe on AnalysisBench traces to see whether tool-time hiding might be larger there.
- Compared the apparent wins against benchmark composition and found that a large portion of AnalysisBench “tool time” was just polling/sleep/package-install artifacts rather than substantive long-running analysis.

Failures and how to do differently:

- The initial longer-running probe hit practical resource issues when trying to compute across all traces in one shot; the successful pivot was to split the analysis into smaller slices / lighter-weight scripts and aggregate results.
- Exact response-token measurement required careful reconstruction of assistant completions from the saved trajectory format; naive use of `content` alone was not enough.
- On AnalysisBench, the headline tool-time coverage was misleading until the polling/sleep commands were separated out. Future similar studies should always classify `sleep`, `kill -0` polling, package installation, and other infrastructure waits separately from substantive tool work before making claims about speculation utility.

Reusable knowledge:

- On SWE-bench Verified, the “future response reuse” signal is weak:
  - response-token coverage for the best causal `k=4` policy was about `0.668%`
  - even the oracle exact-prefix reuse was only about `0.982%`
  - the practical consequence is that response-draft speculation looks much weaker than observation-only reuse on this benchmark.
- The response-draft story is still not empty: in many cases the candidate with no observation prefix match still had a small positive response LCP, but these LCPs were usually very short.
- Full observation exact matches are present but not dominant enough to justify broad speculative decoding without a stronger retrieval signal.
- AnalysisBench looked more promising superficially, but once waits/polling were separated from substantive work, the remaining speculative-action opportunity shrank sharply.

References:

- [1] SWE-bench Verified trace analysis on 26,269 sequential tool turns (93 parallel tool-call cases excluded from sequential accounting): `any_prior` response-token coverage `0.982%`, `k=4` `0.668%`, `k=8` `0.784%`.
- [2] SWE-bench next-action exact hit on `k=4` was about `3.13%`; next-tool-time coverage about `2.32%`.
- [3] Full-observation subset on SWE-bench: about `8.1%` of calls had an exact full observation match within top-4 candidates, with about `1.58%` response-token coverage and about `10.3%` next-action exact hit in that subset.
- [4] AnalysisBench trace probe used 35 trajectories / 2,410 sequential turns; `k=4` showed about `7.59%` character coverage and `13.63%` tool-time coverage, but most covered tool time came from `sleep`/polling (`~84.5%` of covered time), plus package installs and builds.
- [5] The repo’s `token_timing.py` is a useful anchor for future offline studies because it already captures tool duration, first-output timing, and raw output event streams.
