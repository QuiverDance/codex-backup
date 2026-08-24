# GH200 KV compression experiment handoff

This is the portable continuation context for Codex thread
`01a032b1-ad6d-7bc2-a677-1004af67a370`.

## Resume objective

Continue diagnosing why the historical 92.9% Request-200 SLO result is not
reproduced.  The next decisive experiment is an exact historical rerun with
runtime logical dedicated KV blocks set to 2432.  Do not resume an experiment
automatically after restoring; verify the machine state first.

## Repositories and revisions

- Current tiered-serve: `/root/projects/tiered-serve`, observed HEAD `5d56a97`.
  This worktree already had user changes; preserve them.
- Isolated historical tiered-serve: `/root/projects/tiered-serve-af2`, commit
  `af2e7c1`.
- Isolated historical vLLM: `/root/projects/vllm-af2`, base commit
  `72506c983`, with `tiered-serve-af2/patches/vllm.patch` applied.
- Historical vLLM needed one compatibility-only Python change in
  `vllm/entrypoints/utils.py`: construct defaults with `type(args)` rather than
  hard-coded `EngineArgs`.  It does not touch the performance path.
- Historical and current KV CUDA sources compared byte-for-byte equal for
  `csrc/cache.h`, `csrc/cache_kernels.cu`, `csrc/torch_bindings.cpp`,
  `vllm/_custom_ops.py`, and `vllm/attention/layer.py`; a rebuild was not
  required for the completed comparisons.

## Exact benchmark workload

- Model: `meta-llama/Llama-3.1-70B-Instruct`
- Config: `cao-p4-kvcomp`
- Weight compression: `p4flat`; fused MM enabled
- KV compression: `p4flat`
- KV compression workers: 1
- `max_num_batched_tokens=8192`, `max_num_seqs=512`, block size 16
- Azure conversation dataset, 1200 requests, request rate 1.0 QPS
- Skip first 100 and last 100; official summaries cover the middle 1000
- Seed is fixed.  All compared runs had exactly identical per-request prompt
  and output lengths: all-1200 totals 1,408,652 input and 250,295 output tokens;
  middle-1000 totals 1,216,911 input and 195,841 output tokens.

## Completed results

| Run | Runtime logical D | Request 200 | Request 250 | TPOT p50/p90 |
|---|---:|---:|---:|---:|
| Historical recorded high, `20260817_203514` | 2432 | 92.9% | 96.2% | 154.24/185.23 ms |
| Current code, `20260824_172838` | 2416 | 88.6% | 95.0% | 159.97/198.86 ms |
| Historical tiered-serve + current-compatible vLLM, `20260824_190541` | 2416 | 86.4% | 94.2% | 160.27/202.53 ms |
| Historical tiered-serve + historical vLLM, `20260824_194205` | 2416 | 85.6% | 93.5% | 161.39/204.06 ms |

Important correction: an interim 88.3% value was the all-1200 progress metric;
the official trimmed summary for `20260824_190541` is 86.4%.

Relevant summary paths inside the experiment container:

- `/root/projects/tiered-serve/logs/serving/llama_3_1_70b_instruct/cao-p4-kvcomp/20260817_203514/summary.csv`
- `/root/projects/tiered-serve/logs/serving/llama_3_1_70b_instruct/cao-p4-kvcomp/20260824_172838/summary.csv`
- `/root/projects/tiered-serve-af2/logs/serving/llama_3_1_70b_instruct/cao-p4-kvcomp/20260824_190541/summary.csv`
- `/root/projects/tiered-serve-af2/logs/serving/llama_3_1_70b_instruct/cao-p4-kvcomp/20260824_194205/summary.csv`

## Runtime evidence

- Historical high: HBM available 21.29 GiB, logical D=2432, tail=512,
  physical HBM rows=2944, offloadable capacity=14561.
- Current run: HBM available 21.19 GiB, logical D=2416, physical rows=2928.
- Fully historical rerun: HBM available 21.30 GiB, logical D=2416,
  physical rows=2928, offloadable capacity=14561.
- Therefore the latest comparison was intentionally fixed to the current run's
  D=2416 and was not yet an exact reproduction of the 92.9% run's D=2432.

Offloadable KV occupancy snapshots:

- Historical high: mean 467.2, median 319.5, p90 1230.5, max 2610 blocks,
  positive in 76.2% of snapshots.
- Current: mean 581.7, median 434.5, p90 1530, max 2743, positive 81.0%.
- Fully historical D=2416 rerun: mean 612.9, median 444, p90 1442,
  max 2969, positive 82.5%.

Decode scheduler step medians were approximately 105.2 ms for the historical
high, 110.6 ms for current, and 110.5 ms for the fully historical rerun.
Higher service time causes more concurrent active requests, which raises KV
offloading and creates positive feedback.  This describes the observed path but
does not yet identify the first cause.

Historical runs also showed large dispersion even at the same capacity:
runtime D=2448 produced Request-200 results from 81.4% to 91.9%.  Do not treat
this as permission to dismiss the gap as noise; exact D=2432 repeated trials
are still required.

## Memory and boot findings

- A failed CUDA context once left about 4.3 GiB HBM allocated without a process
  shown by `nvidia-smi`.  Stopping `nvidia-persistenced` cleared it.  Restarting
  persistence alone consumed 0 MiB, so the daemon was not itself the allocation.
- Correct clean-boot order used: mount `/mnt/hugepages` as 16-GiB hugetlbfs,
  ensure 23 hugepages, set/verify GPU persistence, 900 W power limit, and
  1980 MHz application clock, then start the existing `tiered-serve` container.
- `launch.sh` is destructive setup: it imports the image and recreates the
  container.  Do not run it merely to restart the existing container.
- The shutdown message `Error removing directory /mnt/hugepages: Device or
  resource busy` is a cleanup bug caused by trying to `rmdir` the hugetlbfs
  mount point; it is not the primary server failure.
- Before the backup request, an exact-D=2432 rerun had just begun loading but
  was explicitly interrupted.  Verify no server process, idle GPU HBM, and all
  hugepages free before any new experiment.

## Next experiment

Reproduce the historical high exactly:

1. Verify HBM is clean, persistence enabled, power limit 900 W, clock 1980 MHz,
   `/mnt/hugepages` is hugetlbfs, and all 23 pages are free.
2. Use historical tiered-serve `af2e7c1` and historical vLLM base `72506c983`
   plus its patch.
3. Old-code environment-variable semantics include the 512 resident-tail rows.
   Set `TIERED_SERVE_DEDICATED_KV_BLOCKS=2944` to obtain runtime logical
   `num_dedicated_blocks=2432`.  Do not confuse the environment value with the
   scheduler-visible logical D.
4. Keep worker=1, weight hugepages=14, weight buffers=2, address order=0,
   p4flat/p4flat, fused MM, and the exact benchmark above.
5. Confirm from startup logs: HBM ~21.29 GiB, logical D=2432, tail=512,
   physical offset=2944, offloadable=14561.
6. Run at least three clean repetitions and compare the median, including
   offload occupancy and scheduler-step distributions.

## Continuation instruction

On a fresh machine, clone branch `gh200`, give this document and
`visible-transcript.md` to Codex, and ask:

> Read the GH200 handoff and visible transcript, verify the restored repository
> paths and machine state, then continue from the exact historical D=2432
> experiment. Do not rerun anything until the preflight checks pass.
