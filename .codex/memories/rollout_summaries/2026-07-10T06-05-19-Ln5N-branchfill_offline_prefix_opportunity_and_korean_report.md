thread_id: 019f4aa1-68ea-7db2-a40f-d46e7f7fcf4b
updated_at: 2026-07-10T08:15:45+00:00
rollout_path: /home/pjw7200/.codex/sessions/2026/07/10/rollout-2026-07-10T06-05-19-019f4aa1-68ea-7db2-a40f-d46e7f7fcf4b.jsonl
cwd: /home/pjw7200

# BranchFill offline prefix-opportunity study on SWE-bench Verified, then a Korean written report.

Rollout context: The user proposed a BranchFill-like speculative prefill idea for tool outputs and wanted to test whether exact output prefixes repeat often enough on SWE-bench Verified traces to justify the approach. They explicitly asked to start offline, ignore cost at first, and measure exact prefix overlap on existing traces before any GPU/runtime work. Later they asked for a consolidated report of the experiments in Korean.

## Task 1: Define and run the offline prefix-opportunity study

Outcome: success

Preference signals:

- when discussing the first experiment, the user said: "일단 offline으로 비용을 생각하지 않고 기회가 얼마나 있을 수 있는지를 보고싶어" -> in similar research explorations, start with a cost-free offline opportunity study before any runtime/GPU work.
- when asked what to measure, the user repeatedly narrowed it to exact text overlap: "일단 정확히 text가 겹쳐야 미리 prefill 하는게 의미가 있으니까" -> prioritize exact token/byte prefix overlap over semantic similarity or fuzzy matching.
- when the assistant proposed extra go/no-go thresholds, the user said: "그건 나중에 생각하고 일단 실험 결과를 보고 이야기해도 될 것 같아" -> defer decision thresholds until after seeing the distributional results.
- when the assistant started discussing candidate branches and top-k, the user asked: "topk 후보를 뽑고 그중 가장 긴prefix를 고른다는거야? topk가 왜 필요한건지 이해를 못했어" -> explain BranchFill-style top-k in plain language and separate the notion of candidate selection from the final exact-prefix verification.
- when the assistant summarized the metric, the user checked: "재사용률이 겹치는 후보가 있는 command를 말하는거야? 전체 command 중에? 아니면 전체 output token 중 재사용 가능한 output token을 말하는거야? 후자지?" -> future explanations should state clearly that the headline metric is token-weighted output reuse, not command-count coverage.

Key steps:

- Used the repo’s `ask-matt` -> `grill-me` flow to freeze the experiment scope before coding.
- Confirmed the offline 1st-pass experiment should be causal and trajectory-local: only past outputs from the same trajectory and only exact token LCP.
- Implemented a new analyzer under `agent/src/minisweagent/run/extra/branchfill_prefix_opportunity.py` with tests in `agent/tests/run/test_branchfill_prefix_opportunity.py`.
- Validated the analyzer on the existing SWE-bench Verified traces and generated reports under `reports/branchfill_*`.
- Re-ran after a metric-definition correction so oracle capture cannot exceed 100%.

Failures and how to do differently:

- The first iteration conflated oracle capture with raw policy reuse, producing misleading >100% “capture” values for some policies. The fix was to compute capture per call as `min(policy LCP, oracle LCP)` and then sum over oracle tokens.
- The initial report omitted trajectory-level uncertainty for the policy frontier. The fix was to add 95% bootstrap CI and trajectory distribution fields to the markdown report.
- The uncompressed per-call JSONL became very large. The fix was to gzip `per_call.jsonl` and `policy_per_call.jsonl` and keep the human-readable summary/report separate.

Reusable knowledge:

- The relevant trace corpus already exists under `/home/pjw7200/chunked_tool_prefill/traces/swebench_verified_qwen36_trace_token_timing_full_20260706T113200Z`; the 500 trajectories and 26,435 tool calls were enough for the offline study.
- For model-visible KV reuse, compare the exact formatter-visible output text, not raw tool output length alone; truncated outputs need special handling because only the visible head can contribute prefix KV reuse.
- The most useful first-cut candidate policy on this dataset was simple command similarity over command history; it outperformed a more complex combined heuristic.
- The command-category signal is real but weaker than command similarity; exact-args-only reuse is much smaller than command-similarity reuse.

References:

- [1] Offline oracle summary from the 500-trace run: `any_prior` model-visible reuse 9.90% (797,173 / 8,051,727 tokens), `exact_args` 2.76%, `same_category` 6.48%, `same_signature` 5.79%.
- [2] Command-similarity frontier: k=1 6.66%, k=2 7.72%, k=4 8.48%, k=8 9.11%; k=4 captured 85.70% of the any-prior oracle.
- [3] Generated artifacts: `reports/branchfill_prefix_opportunity_swebench_verified_qwen36_20260710/report.md`, `summary.json`, `top_matches.json`.
- [4] Generated policy artifacts: `reports/branchfill_policy_frontier_swebench_verified_qwen36_20260710/report.md`, `policy_frontier.json`, `policy_categories.json`, `policy_per_call.jsonl.gz`, `top_policy_matches.json`.
- [5] Validation: analyzer tests passed (8 tests) and the environment-independent suite passed (505 passed, 74 skipped).

## Task 2: Write the consolidated Korean report

Outcome: success

Preference signals:

- when the user asked for the write-up, they said: "일단, 지금까지 한 실험들 정리해서 보고서로 작성해줘" -> future similar requests should default to a concise but complete report that integrates setup, metrics, results, and limitations.
- the user kept asking for explanation in Korean throughout, indicating a durable preference for Korean-language analysis summaries in this thread.
- the user asked for metric clarification before the report, indicating that the report should define metrics explicitly rather than assuming the reader already knows the offline analysis vocabulary.

Key steps:

- Wrote a standalone Markdown report at `reports/branchfill_offline_experiments_20260710.md`.
- Integrated both experiment phases: the offline opportunity/oracle study and the causal top-k candidate-policy frontier.
- Included the exact metric definition, experimental scope, main tables, interpretation, limitations, and next-step recommendation.
- Verified the report references and numeric values against the saved JSON/Markdown artifacts.

Failures and how to do differently:

- The repository’s `reports/` directory is gitignored, so the report is an artifact for sharing/reading, not for commit history.
- Some generated report files were large and the workspace had unrelated modified files; future similar writeups should avoid touching unrelated worktrees unless necessary.

Reusable knowledge:

- The final report should distinguish clearly between:
  - model-visible reuse ratio,
  - raw-output reuse as a secondary statistic,
  - call-level metrics such as positive-LCP calls and LCP thresholds,
  - oracle capture vs. reuse ratio.
- The final report should state explicitly that `8.48%` is token-weighted reuse of output tokens, not “8.48% of commands.”

References:

- [1] Final report path: `/home/pjw7200/chunked_tool_prefill/reports/branchfill_offline_experiments_20260710.md`
- [2] The report includes the core result that `command_similarity` k=4 achieved 8.48% reuse and 85.70% of the any-prior oracle.
- [3] It also records the any-prior oracle baseline of 9.90% and the exact-args baseline of 2.76%.
- [4] The report explicitly separates opportunity analysis from replay/GPU-cost analysis, since no runtime cost experiment was run in this rollout.
