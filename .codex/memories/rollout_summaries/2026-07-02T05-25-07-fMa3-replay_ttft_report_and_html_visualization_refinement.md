thread_id: 019f2149-b8f9-7d62-970c-cf88bbd24507
updated_at: 2026-07-03T10:14:56+00:00
rollout_path: /home/pjw7200/.codex/sessions/2026/07/02/rollout-2026-07-02T05-25-07-019f2149-b8f9-7d62-970c-cf88bbd24507.jsonl
cwd: /home/pjw7200

# The user requested a human-friendly report of the replay TTFT experiment, then iteratively refined the presentation of an HTML graph so the data would be easier to explain in a presentation.

Rollout context: The work was in `/home/pjw7200/chunked_tool_prefill/agent` and the experiment outputs lived under `/home/pjw7200/chunked_tool_prefill/runs/replay_qwen36_verified_full500_output_first_tmux_20260702T111434Z`. The experiment itself had already completed successfully with `REPLAY_EXIT_CODE=0`; the user then asked for clearer reporting, better TTFT summary statistics, interpretation of faster/slower cases, and a cleaner HTML visualization.

## Task 1: Analyze and present the replay TTFT experiment

Outcome: success

Preference signals:

- When asked to report the experiment results, the user wanted the output to be “사람이 이해하기 좋게” and explicitly asked for analysis of “왜 그런 결과가 나왔는지” -> future similar reports should prioritize explanation and narrative, not just raw metrics.
- The user later corrected the TTFT presentation format to “ttft는 mean, p50, p95, p99로 보고해줘” -> future reports should default to mean/p50/p95/p99 for TTFT and avoid ad hoc statistics unless specifically requested.
- The user pushed back on confusing percentile comparisons (“아니 그럼 p95 값도 더 빨라야지”, “mean은 왜 뺀 값이랑 같아?”) -> future explanations should distinguish sample-wise delta distributions from aggregate percentile differences and should not imply that p95(delta) means p95 latency improved.
- The user asked “그럼 p 몇부터 양수 구간이야? delta는?” -> future analysis should include the sign-crossing percentile of the delta distribution when that is relevant.
- The user asked for an HTML graph (“그래프로 그려줄 수 있어? html 기반으로”) -> future presentations of this kind should default to a standalone HTML artifact if possible.

Key steps:

- The experiment was summarized from `replay_results.jsonl` and `summary.json` in the replay output directory.
- TTFT was reported with `mean / p50 / p95 / p99` for baseline and stream prefill.
- The delta distribution was interpreted as `baseline - stream`, so positive means stream prefill is faster.
- A standalone HTML report was generated at `runs/replay_qwen36_verified_full500_output_first_tmux_20260702T111434Z/delta_ttft_report.html`.
- The HTML report was iteratively refined after user feedback: first a custom SVG histogram, then a matplotlib-based version with a real numeric x-axis, then removal of extra “zoomed/tail” explanatory text.

Failures and how to do differently:

- The first delta explanation was confusing because percentile deltas were mixed with percentile TTFT comparisons. Future reports should avoid mixing `p95(delta)` with `p95(latency difference)` unless the distinction is explicitly spelled out.
- The first HTML histogram used equal-width visual bins and looked misleading on the x-axis. Future graphs should use a plotting library with a real numeric x-axis when the interval spacing matters.
- The user repeatedly removed helper text from the graph. Future presentation graphics should be minimal by default and avoid extra annotations unless they carry essential meaning.

Reusable knowledge:

- In this run, `delta = baseline_ttft_s - stream_prefill_ttft_s` was the key interpretation axis.
- For the 500-trajectory run, the final reported TTFT summary was approximately: baseline mean `201.6ms`, p50 `187.5ms`, p95 `337.6ms`, p99 `452.6ms`; stream prefill mean `228.5ms`, p50 `208.1ms`, p95 `399.4ms`, p99 `566.1ms`.
- The delta distribution crossed zero at about the `p67.15` sample percentile, meaning roughly 32.9% of samples were faster and 67.1% were slower.
- The HTML report that the user actually opened lives at `.../delta_ttft_report.html` and was updated multiple times to reflect these preferences.

References:

- [1] Final HTML report path: `/home/pjw7200/chunked_tool_prefill/runs/replay_qwen36_verified_full500_output_first_tmux_20260702T111434Z/delta_ttft_report.html`
- [2] Core summary numbers from the final report: baseline mean/p50/p95/p99 `201.6 / 187.5 / 337.6 / 452.6 ms`; stream mean/p50/p95/p99 `228.5 / 208.1 / 399.4 / 566.1 ms`.
- [3] Delta sign-crossing point: `p67.15`.
- [4] Final interpretation used in the report: about `32.9%` faster, `67.1%` slower, actual completed prefill only `1.37%` of valid steps.
