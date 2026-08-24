# Codex visible conversation: GH200 KV experiments

- Session ID: `01a032b1-ad6d-7bc2-a677-1004af67a370`
- Started: `2026-08-24T07:35:00.206Z`
- Codex CLI: `0.149.0-alpha.4.3`
- Exported visible messages: `199`

> Public-safe export: user and assistant messages only. Developer instructions, reasoning records, tool payloads, authentication, and runtime databases are intentionally excluded.

## 1. User

지금 컨테이너에서 돌린 실험이 잘 나오지 않아서 따로 검사해봤는데 아래와 같은 이유인 것 같아.



Nsight Systems trace로 분석 결과



기본적으로 kv 압축으로 얻는 이득이 크지 않아서 나타나는 문제로 보임.



추가로 comp를 할 때 join 하는 부분이 있어서 이 부분을 완화하고자 `TIERED_SERVE_KV_COMPRESS_WORKERS` = 2로 worker 수를 2로 늘려서 했을 때 성능향상이 약간 나타남. 다만, worker 1로 돌렸을 때의 성능이 어제 보다 낮게 나왔고, worker 수를 2로 늘린 것이 어제 성능 정도 나와서(90%) 재실험 필요.



kv free 할 때 \
batch\_decomp\_stream.synchronize(), load\_kv\_stream.synchronize(), comp\_stream.synchronize()를 수행하는데 이게 병목이 될 수 있다고 생각해서 CUDA event로 slot을 retired 상태에 넣고, GPU가 해당 slot 사용을 마친 뒤 재사용하는 방식으로 synchronize를 제거함. 실제로 sync 딜레이 문제는 해결된 것으로 보이나, 전체 실험 결과는 아무 것도 적용하지 않은 기존보다 낮게 측정됐음(84.3%, 기존 87%). 실험을 돌릴 때 잠깐 codex 작업을 했어서 재실험이 필요하지만, 별 차이는 없을 것 같음.



codex로 분석한 원인:

**두 worker1 실험의 HBM 조건이 같지 않았습니다.** 이걸 처음 비교할 때 제가 놓쳤습니다.

| **실험**             | **가용 HBM** | **Dedicated KV blocks** | **Request 200 SLO** |
| ------------------ | ---------- | ----------------------- | ------------------- |
| 기존 Worker 1        | 21.07 GiB  | 2384                    | 87.0%               |
| Retired + Worker 1 | 20.58 GiB  | 2288                    | 84.3%               |

Retired 실행은 시작 시 가용 HBM이 **0.49 GiB 적어서 dedicated KV block이 96개 감소**했습니다. 모델 weight와 GPU aux 사용량은 두 실행이 동일하므로, KV budget 계산 시점의 GPU free-memory 편차입니다. Retired 코드는 이 시점에는 CUDA event를 생성하지 않기 때문에 retired 자체가 0.49 GiB를 쓴 것은 아닙니다.

그 결과:

- 평균 offloadable KV: **613 → 712 blocks**, 약 16% 증가
- 최대 offloadable KV: **3191 → 3690 blocks**
- 느린 560-call 경로 비율: **24.6% → 34.6%**
- 560-call GPU span: **143.0 → 163.8 ms**
- Condition wait: **8.88 → 11.03 ms**
- H2D-compute overlap: **67.6% → 60.9%**

즉 더 많은 KV가 HBM에서 밀려나면서 unload, CPU compression, reload가 증가했고, 남아 있던 single-worker foreground join 병목이 더 자주 발생했습니다. 이것이 free 개선 효과를 덮었습니다.

SLO도 실제로는 큰 전면 퇴행이라기보다 200ms 경계 효과가 큽니다.

- TPOT p50: 159.79 → 161.18 ms
- TPOT p90: 202.78 → 207.08 ms
- Request 200 attainment: 87.0 → 84.3%
- Request 250 attainment: 94.7 → 94.5%

반면 free 경로 자체는 확실히 개선됐습니다. 320-block free가 32.7ms/stream-sync 0회이고, 기존에는 333-block free가 127ms/1,008회였습니다.

따라서 현재 결론은:

> **Retired가 느려진 것이 아니라, retired run에서 HBM residency가 줄어 더 많은 요청이 느린 offload 경로로 들어갔다. 현재 SLO 비교로 retired 효과를 판정할 수 없다.**

다음 비교에서는 모든 실행에 아래 값을 고정해야 합니다.

TIERED\_SERVE\_DEDICATED\_KV\_BLOCKS=2288

Worker 2 실행도 dedicated blocks가 2416개라서, 앞서 관측한 90.0% 중 일부는 worker 효과가 아니라 더 많은 HBM residency 효과입니다. 세 결과 모두 동일한 2288 blocks로 다시 비교해야 정확합니다.

-> 처음 기존 시스템 성능이 낮았던 것도 이것이 원인일 수 있음.



\---------

이것처럼 저 block을 고정해두고 실험할 수는 없어?

## 2. Assistant

가능합니다. 현재 코드에서 dedicated KV block 수가 어디서 계산되고 환경변수로 override되는지 먼저 확인한 뒤, 실행 설정까지 동일하게 고정되도록 반영하고 검증하겠습니다.

## 3. Assistant

확인 결과 코드 자체는 이미 `TIERED_SERVE_DEDICATED_KV_BLOCKS` override를 지원합니다. 다만 현재 실험 스크립트와 문서에 미커밋 변경이 있으므로, 기존 작업을 덮지 않게 diff와 실제 설치된 vLLM 적용 상태를 함께 확인하겠습니다.

## 4. Assistant

중요한 점이 하나 더 확인됐습니다. 현재 KV compression 경로는 `max_num_seqs=512`만큼 resident-tail HBM row를 별도로 예약하는데, 기존 override 구현은 이 512개를 dedicated 값에 포함해 해석합니다. 따라서 지금 그대로 `=2288`을 주면 실제 scheduler의 dedicated block은 2288이 아니라 1776까지 줄 수 있습니다. 환경변수 값이 로그의 `dedicated_kv_total`과 정확히 일치하도록 이 의미를 바로잡아야 합니다.

## 5. Assistant

수정 방향은 `2288`을 “scheduler가 실제 사용하는 dedicated block 수”로 정의하고, resident-tail 512개는 내부에서 별도로 더해 HBM row를 계획하게 하는 것입니다. 또한 HBM이 부족하면 조용히 더 작은 값으로 낮추지 않고 시작 단계에서 실패시켜, 비교 실험이 다른 조건으로 진행되는 일을 막겠습니다. 현재 실행 중인 Nsight 프로세스는 건드리지 않습니다.

## 6. Assistant

코드와 source-of-truth 패치에 반영했고 문법 검사는 통과했습니다. 다음으로 실제 diff가 의도한 두 변경만 포함하는지 확인하고, 현재 실행이 끝난 뒤 바로 쓸 수 있는 고정 실행 명령과 로그 검증 조건을 정리하겠습니다.

## 7. Assistant

가능하고, 다음 실행부터 정확히 고정되도록 수정했습니다.

```bash
TIERED_SERVE_DEDICATED_KV_BLOCKS=2288 \
TIERED_SERVE_KV_COMPRESS_WORKERS=1 \
nsys launch ... numactl -m 0 python serve_offload_kvweight.py ...
```

Worker 2 비교에서는 worker 값만 `2`로 변경하면 됩니다.

기존 구현의 resident-tail 512개 해석 문제와 HBM 부족 시 조용히 block 수를 낮추던 동작도 수정했습니다. 이제 로그에 다음이 보여야 합니다.

```text
logical=2288 tail_rows=512 physical_hbm_rows=2800
num_dedicated_blocks=2288
```

2288을 확보하지 못하면 실행이 즉시 실패하므로 잘못된 조건으로 실험되지 않습니다. 현재 실행 중인 Nsight run은 환경변수가 없어서 `2352` blocks이며 수정의 영향을 받지 않습니다. 다음 실행부터 적용됩니다.

## 8. User

저 블럭이 몇 기가바이트야? 지금 우리 실험 환경에서 사용가능한 최댓값이 몇이고?

## 9. Assistant

현재 실행 로그의 block 크기, layer 수, KV planner 예산을 기준으로 논리 block과 resident-tail까지 포함한 실제 HBM 사용량을 나눠 계산해보겠습니다. 최댓값은 자동 정렬된 안전값과 이론적 고정 가능값을 구분하겠습니다.

## 10. Assistant

현재 70B 모델(80 KV layers) 기준:

- block 1개 = 64 KiB × 80 layers = 5 MiB
- 2288 blocks = 11.17 GiB
- resident-tail 512개 = 2.5 GiB
- 실제 dedicated HBM 점유 = 2800 rows = 13.67 GiB

현재 실행에서 확인된 안전한 최대치는:

- logical dedicated: 2352 blocks = 11.48 GiB
- tail 포함: 2864 rows = 13.98 GiB
- 전체 logical KV: 2352 + offloadable 14561 = 16913 blocks

따라서 2288은 현재 최대보다 64 blocks, 즉 320 MiB 낮아 안정적으로 고정 가능한 값입니다. 시작 시 planner가 본 가용 예산은 14.95 GiB였습니다.

## 11. User

근데 저 블럭이 무슨 값이야?

## 12. Assistant

여기서 `2288 blocks`는 vLLM scheduler가 관리하는 “HBM 상주 KV-cache 페이지 개수”입니다.

- KV block 1개 = 한 요청의 연속된 16 tokens에 대한 K/V 저장 공간
- 각 block ID는 80개 transformer layer에 동일하게 존재
- 따라서 1 block 전체 크기 = 5 MiB
- `DEDICATED_KV_BLOCKS=2288`이면 block ID `0~2287`은 HBM에 계속 상주
- 그 이후 block은 필요에 따라 LPDDR로 offload·압축·reload

즉 2288은 메모리 크기 자체가 아니라 HBM/offload 경계를 결정하는 KV 페이지 개수입니다. 토큰 용량으로는 `2288 × 16 = 36,608 tokens`입니다.

resident-tail 512개는 partial block 처리용 물리 공간이므로 이 2288에는 포함되지 않습니다.

## 13. User

그러니까 kv cache용 page 개수라는거지? weight랑 무관하게?

## 14. Assistant

맞습니다. `2288`은 KV cache용 HBM page(block) 개수이며 weight와 직접 관계없습니다.

다만 weight가 HBM을 많이 차지하면 남는 HBM이 줄어들어 확보 가능한 KV block의 최댓값은 간접적으로 감소합니다. 동일한 weight 설정으로 비교할 때 `2288`을 고정하면 KV residency 조건이 같아집니다.

## 15. User

내가 알기로는 hbm에 kv용 공간이 6gb로 알고 있는데 아니었어?

## 16. Assistant

그 6 GiB가 `GPU aux`인지, K/V 한쪽 크기인지, 아니면 과거의 KV budget 설정인지 구분해야 합니다. 현재 코드의 실제 tensor 크기와 실행 로그의 메모리 항목을 대조해보겠습니다.

## 17. Assistant

맞습니다. 제가 앞서 말한 `11.17 GiB`는 K와 V를 합친 크기입니다.

2288 blocks 기준:

- K cache: 약 5.59 GiB
- V cache: 약 5.59 GiB
- K+V 합계: 약 11.17 GiB

그리고 로그의 `GPU aux: 5.96 GiB`는 KV가 아니라 weight 실행용 auxiliary buffer입니다.

따라서 “KV 전체를 6 GiB로 제한”하려던 설계였다면 `2288`은 너무 큽니다. 6 GiB는 약 `1228 blocks`에 해당합니다. resident-tail까지 6 GiB 안에 포함하려면 logical dedicated는 약 `716 blocks`만 가능합니다.

## 18. User

뭔 차이지?&#x20;

## 19. Assistant

KV cache에는 서로 다른 두 tensor가 함께 저장됩니다.

- K(Key): 현재 query가 어떤 과거 token에 주목할지 점수를 계산
- V(Value): 그 점수로 실제 정보를 가져오는 데 사용

Llama 70B에서는 K와 V 크기가 같습니다. 그래서 “KV 6 GiB”가 한쪽만 계산한 값이라면 실제 K+V는 약 12 GiB입니다.

반면 로그의 `GPU aux 5.96 GiB`는 KV가 아니라 압축된 weight를 연산할 때 쓰는 staging/workspace입니다. 즉 숫자만 비슷할 뿐 완전히 다른 메모리입니다.

## 20. User

그럼 상주 kv는 절대 안 바껴?&#x20;

## 21. Assistant

`2288`로 고정되는 것은 “상주 KV의 최대 수용량”입니다.

- HBM dedicated slot 수: 항상 2288
- 실제 사용량(`dedicated_kv_used`): 요청에 따라 0~2288로 변함
- slot 안의 KV 내용: 요청 종료 시 free되고 다른 요청이 재사용
- dedicated slot의 KV: offload·압축되지 않음

즉 공간 크기는 실행 중 절대 바뀌지 않지만, 사용량과 저장된 요청은 계속 바뀝니다. 환경변수로 고정하면 다음 실행에서도 2288을 확보하거나, HBM이 부족하면 실행이 실패합니다.

## 22. User

그럼 지금 hbm 사용량(weight, kv 등)을 고려했을 때 상주 kv를 위해 쓸 수 있는 공간이 최대 몇이야? 다시 계산해줘

## 23. Assistant

이번에는 `상주 KV 용량`, `resident-tail`, `offload decode buffer`를 분리해 현재 실행의 실제 HBM 배치 기준으로 다시 계산하겠습니다. 6 GiB로 보였던 weight auxiliary 영역도 별도로 제외하겠습니다.

## 24. Assistant

최근 동일 실험 실행 로그 기준, 상주 KV에 쓸 수 있는 재현 가능한 최대치는 다음과 같습니다.

| 구분 | Blocks | HBM |
|---|---:|---:|
| 일반 dedicated KV | 2352 | 11.48 GiB |
| resident-tail | 512 | 2.50 GiB |
| 실제 상주 KV pool | 2864 | 13.98 GiB |
| offload decode buffer | 별도 | 1.78 GiB |
| 전체 KV 관련 HBM |  | 15.76 GiB |

Weight 관련 사용량은 모델 로딩 70.57 GiB이며, 여기에는 `GPU aux 5.96 GiB`가 포함됩니다. planner는 이를 고려한 뒤 위 KV 공간을 확보했습니다.

`2288`로 고정하면:

- 일반 상주 KV: 11.17 GiB
- tail 포함 상주 pool: 13.67 GiB
- decode buffer 포함 전체 KV HBM: 약 15.45 GiB
- 확인된 최대 2352보다 320 MiB 여유

따라서 현재 환경의 안전한 최대 고정값은 `2352 blocks`이고, 세 실험의 공통 조건으로는 `2288 blocks`가 적절합니다. 6 GiB는 전체 KV pool이 아니라 K/V 한쪽 또는 weight aux를 본 값입니다.

## 25. User

내 첫 요청에 따르면 2384 블럭도 가능하잖아 왜 최대값이 2352야?

## 26. Assistant

맞습니다. 제가 `2352`를 전체 환경의 절대 최대라고 표현한 것은 잘못이었습니다. `2352`는 가장 최근 실행에서 자동 planner가 선택한 값일 뿐입니다. 말씀하신 2384/2416 실행 로그를 찾아 어떤 시작 조건에서 가능했는지 다시 대조하겠습니다.

## 27. Assistant

맞습니다. `2384`도 가능했고, 제가 `2352`를 절대 최대라고 한 것은 잘못입니다.

Dedicated KV 최대치는 고정된 값이 아니라 서버 시작 시점의 가용 HBM에 따라 달라집니다.

- 기존 Worker 1: 2384 blocks
- 최근 실행: 2352 blocks
- 과거 동일 config 실행에서 관측된 값: 최대 2432 blocks
- 세 비교 실험에서 공통으로 확보된 값: 2288 blocks

크기로 보면:

- 2352: 11.48 GiB
- 2384: 11.64 GiB
- 2432: 11.88 GiB

최근 실행은 이전보다 약 160 MiB 부족해서 `2384 → 2352`가 된 것입니다. 따라서 절대 관측 최대는 적어도 `2432`, 현재 실행에서 확인된 값은 `2352`, 공정 비교용 안전값은 `2288`입니다.

## 28. User

이론 최댓값은 얼마야?

## 29. Assistant

코드의 실제 HBM planner 식으로 계산하겠습니다. 최근 실행 조건과 지금까지 관측된 가장 좋은 시작 조건을 각각 계산해, 자동 16-block 정렬 전의 이론 상한을 구분하겠습니다.

## 30. Assistant

현재 코드의 8 GiB runtime reserve를 유지한 이론 최댓값은 약 `2435 blocks`입니다.

- 이론 상한: 약 2435 blocks = 11.89 GiB
- tail 512 포함 물리 공간: 약 14.39 GiB
- 16-block 단위로 안정 정렬한 실사용 최대: `2432 blocks`

최근 실행은 시작 HBM이 적어 이론 상한이 약 2367이었고, 정렬 후 2352가 선택됐습니다. 반면 HBM 조건이 좋았던 실행에서는 약 2435까지 가능했으므로 2384도 당연히 들어갑니다.

따라서 정리하면:

- 이론 최대: 약 2435
- 안정적인 최대 설정: 2432
- 모든 기존 비교 실행에 공통 적용 가능한 값: 2288

8 GiB 안전 reserve까지 없애면 계산상 약 4000 blocks도 나오지만, prefill·CUDA graph·workspace 메모리가 없어져 OOM이 발생하므로 실행 가능한 최대값은 아닙니다.

## 31. User

8 GiB 안전 reserve 가 뭔데?

## 32. Assistant

`8 GiB reserve`는 실제로 8 GiB짜리 tensor를 미리 할당하는 것이 아닙니다. KV 크기를 계산할 때 가용 HBM에서 8 GiB를 빼고 남겨두는 여유 공간입니다.

```text
KV 계산용 HBM = cuda free memory - 8 GiB
```

이 공간은 이후 다음 용도로 사용됩니다.

- offload KV decode double buffer: 현재 약 1.78 GiB
- 큰 prefill activation
- fused weight decompression scratch
- CUDA graph: 현재 약 0.82 GiB
- cuBLAS workspace, sampler buffer
- PyTorch allocator fragmentation 및 순간 peak

현재 로그의 `gpu_avail=14.95 GiB`는 실제 free HBM 약 22.95 GiB에서 이 8 GiB를 제외한 값입니다. 실행 중에는 reserve 일부가 위 버퍼들에 실제로 사용됩니다.

기본값은 다음 환경변수로 설정됩니다.

```bash
TIERED_SERVE_GPU_RESERVE_GIB=8
```

낮추면 dedicated KV block을 늘릴 수 있지만 prefill이나 runtime 중 OOM 가능성이 커집니다.

## 33. User

일단 2432로 설정하자 그리고 서버 띄울 때 환경변수로 넣어도 적용돼?

## 34. Assistant

네. 서버 프로세스를 시작할 때 환경변수로 넣으면 engine worker까지 상속되어 적용됩니다.

```bash
TIERED_SERVE_DEDICATED_KV_BLOCKS=2432 \
TIERED_SERVE_KV_COMPRESS_WORKERS=1 \
nsys launch --cuda-graph-trace node \
numactl -m 0 python serve_offload_kvweight.py ...
```

예상 로그:

```text
logical=2432 tail_rows=512 physical_hbm_rows=2944
num_dedicated_blocks=2432
```

이미 실행 중인 서버에는 적용되지 않아 재시작해야 합니다. 시작 시 HBM이 부족하면 더 작은 값으로 조정하지 않고 실패하도록 해두었습니다.

## 35. User

TIERED\_SERVE\_DEDICATED\_KV\_BLOCKS=2432 TIERED\_SERVE\_KV\_COMPRESS\_WORKERS=1 TIERED\_SERVE\_NUM\_WEIGHT\_HUGE\_PAGE=14 TIERED\_SERVE\_N\_WEIGHT\_BUFFERS=2 LD\_PRELOAD=/root/projects/tiered-serve/etc/stack\_pool.so numactl -m 0 python serve\_offload\_kvweight.py --model meta-llama/Llama-3.1-70B-Instruct  --weight-comp p4flat --fused-mm --kv-comp p4flat --ts-configs cao-p4-kvcomp

명령어는 이런식으로 실행하면 되지? 확인만 해줘

## 36. Assistant

환경변수 상속, 실행 파일 경로, `--ts-configs` 인자 정의만 읽기 전용으로 확인하겠습니다.

## 37. Assistant

네, 형식과 옵션 모두 맞습니다. 다만 기본 PATH에는 `python`이 없으므로 venv 경로를 쓰는 것이 확실합니다.

```bash
TIERED_SERVE_DEDICATED_KV_BLOCKS=2432 \
TIERED_SERVE_KV_COMPRESS_WORKERS=1 \
TIERED_SERVE_NUM_WEIGHT_HUGE_PAGE=14 \
TIERED_SERVE_N_WEIGHT_BUFFERS=2 \
LD_PRELOAD=/root/projects/tiered-serve/etc/stack_pool.so \
numactl -m 0 ./.venv/bin/python serve_offload_kvweight.py \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --weight-comp p4flat --fused-mm \
  --kv-comp p4flat \
  --ts-configs cao-p4-kvcomp
```

가상환경이 이미 활성화됐다면 기존 `python`도 괜찮습니다. HBM이 부족하면 2432보다 낮춰 실행하지 않고 시작 단계에서 실패합니다.

## 38. User

지금 아무런 작업을 하지 않는대도 gpu를 점유하는 메모리가 있는데 원인이 뭐야?

## 39. Assistant

현재 GPU 사용량과 CUDA context를 가진 프로세스를 호스트·컨테이너 양쪽에서 확인하겠습니다. 프로세스가 없는데도 남는 드라이버 고정 사용량인지, 숨은 서비스/좀비 context인지 구분하겠습니다.

## 40. Assistant

현재는 사용량이 108 MiB이고 `nvidia-smi`에 CUDA 프로세스가 전혀 없습니다. 드라이버/persistence 고정 점유인지 확인하기 위해 GPU 디바이스를 열고 있는 서비스와 상세 메모리 상태를 추가로 보겠습니다.

## 41. Assistant

현재 GPU를 점유하는 사용자 프로세스는 없습니다.

`nvidia-smi` 기준:

- CUDA 프로세스: 없음
- GPU utilization: 0%
- Driver reserved: 1103 MiB
- Used: 108 MiB
- Free: 96,661 MiB
- Persistence mode: 활성화

따라서 보이는 약 1.2 GiB는 모델이나 Codex가 아니라 NVIDIA 드라이버의 내부 메모리와 persistence daemon이 GPU 초기화 상태를 유지하는 데 쓰는 기본 점유량입니다. KV planner의 `cuda.mem_get_info()`에도 이미 반영되므로 별도로 빼서 계산할 필요는 없습니다.

## 42. User

이 남은 100mb를 완젠히 제거할 수도 없고, 제거할 필요도 없다는거야? 실험에 영향을 크게 안 미쳐?

## 43. Assistant

완전히 없애기는 어렵고, 없애도 CUDA 서버를 시작하면 드라이버 초기화 과정에서 다시 생깁니다. Persistence mode를 꺼도 일부만 줄며, driver reserved 1103 MiB는 회수할 수 없습니다.

영향은 구분해야 합니다.

- 실행 성능: 96 GiB 중 108 MiB라 거의 영향 없음
- 자동 KV 용량 계산: 약 21 KV blocks에 해당하므로 경계에서는 16-block 단위 차이를 만들 수 있음
- `2432` 고정 실험: 시작에 성공하면 성능 비교에는 영향 없음. 부족하면 서버가 즉시 실패함

실험 전 `nvidia-smi`가 프로세스 없음, baseline 약 108 MiB인 상태인지 확인하고 시작하면 됩니다. 이를 억지로 제거하기보다 모든 실험의 시작 조건을 동일하게 유지하는 것이 중요합니다.

## 44. User

&#x20;[2026-08-24 17:20:15] ERROR huge\_page\_allocator.py:470: Error removing directory /mnt/hugepages: [Errno 16] Device or resource busy: '/mnt/hugepages'

서버 띄우다가 이 오류 났는데 원인이 뭐야?

## 45. Assistant

이 오류가 mount point 자체를 지우려 해서 발생한 것인지, 이전 서버가 hugepage 파일을 잡고 있어서 발생한 것인지 확인하겠습니다. allocator의 해당 코드와 현재 mount/파일 점유 상태를 읽어보겠습니다.

## 46. Assistant

확인 결과 `/mnt/hugepages`는 디렉터리가 아니라 hugetlbfs mount point라서 `os.rmdir()`가 항상 `EBUSY`로 실패합니다. 이 메시지는 종료 정리 중 발생한 2차 오류일 가능성이 높으므로, 바로 앞의 실제 서버 시작 실패 원인을 로그에서 찾겠습니다.

## 47. Assistant

표시된 hugepage 오류는 원인이 아니라 서버 시작 실패 후 발생한 2차 cleanup 오류입니다.

실제 원인은 앞선 로그입니다.

```text
requested=2432, max=2417, tail_rows=512, gpu_avail=15.20 GiB
```

현재 시작 조건에서는 최대 2417 blocks만 가능하지만 2432를 요청해서 서버가 중단됐습니다. 이후 cleanup이 hugetlbfs mount point인 `/mnt/hugepages` 자체를 `rmdir()`하려다가 `EBUSY`가 발생했습니다. hugepage 파일 점유 문제는 아닙니다.

16-block 단위로 맞춘 현재 안전 최댓값은 `2416`입니다. 2432에는 약 74 MiB가 부족합니다.

## 48. User

왜 부족한데? 예전에는 됐잖아

## 49. Assistant

성공했던 2432 실행과 방금 실패한 실행의 동일한 초기화 로그를 직접 비교하겠습니다. Weight 사용량, profile KV budget, planner 시점 free HBM 중 무엇이 달라졌는지 수치로 확인하겠습니다.

## 50. Assistant

예전과 지금의 weight 사용량은 완전히 같습니다. 차이는 KV planner 시점의 가용 HBM이 80 MiB 줄었다는 점입니다.

| 항목 | 예전 성공 | 현재 실패 |
|---|---:|---:|
| Weight | 63.75 GiB | 63.75 GiB |
| GPU aux | 5.96 GiB | 5.96 GiB |
| KV용 `gpu_avail` | 15.28 GiB | 15.20 GiB |
| 이론 logical 최대 | 2435 | 2417 |
| 요청값 | 2432 | 2432 |

2432는 예전에도 최대치보다 불과 3 blocks 낮은 경계값이었습니다. 현재는 CUDA allocator·driver·compile profiling 등의 시작 시점 편차로 약 80 MiB가 줄어 15 blocks 부족해진 것입니다.

즉 코드나 weight가 커진 것이 아니라, 2432가 원래부터 HBM 경계에 너무 가까웠습니다. 현재 조건에서 16-block 정렬값은 `2416`입니다.

## 51. User

그 문제는 해결 못해?

## 52. Assistant

해결할 수 있습니다. 핵심은 80 MiB 변동을 없애기보다, KV planner의 큰 runtime reserve 중 일부를 명시적으로 KV에 돌려 `2432`가 작은 startup jitter에 흔들리지 않게 만드는 것입니다. 현재 reserve가 실제로 어디서 두 번 계산되는지 먼저 확인하겠습니다.

## 53. Assistant

가용 HBM의 80 MiB 변동 자체를 완전히 제거하기는 어렵지만, `2432`가 안정적으로 들어가게 만들 수는 있습니다.

권장 방법은 `max_num_seqs`를 512에서 432로 낮추는 것입니다.

```bash
... ./.venv/bin/python serve_offload_kvweight.py \
  --max-num-seqs 432 \
  ...
```

그러면 resident-tail이 `512 → 432`로 줄어 400 MiB가 확보됩니다.

```text
logical=2432
tail_rows=432
physical_hbm_rows=2864
```

현재 workload의 동시 요청은 약 40~50개라 432 제한은 실제 실행에 영향을 주지 않을 가능성이 높습니다. 모든 비교 실험에서 동일하게 432를 사용해야 합니다.

Reserve를 `6 → 5 GiB`로 낮추는 방법도 있지만 runtime OOM 위험이 있으므로 권하지 않습니다. 설정을 바꾸지 않으려면 dedicated 값을 `2416`으로 낮추는 것이 가장 단순합니다.

## 54. User

/root/projects/tiered-serve/logs/serving/llama\_3\_1\_70b\_instruct/cao-p4-kvcomp/20260824\_172838/summary.csv 여기 실험 결과 있을 텐데 request att가 몇인지 봐바ㅗ

## 55. Assistant

해당 `summary.csv`에서 request attainment 관련 열과 값을 확인하겠습니다.

## 56. Assistant

Request attainment는 다음과 같습니다.

- Request 200ms: **88.60%**
- Request 250ms: **95.00%**

## 57. User

그거 밖에 안돼? 예전 실험에서는 92가까이도 있었는데 뭐가 다른데?

## 58. Assistant

현재 run의 서버 조건과 같은 config의 과거 `summary.csv`들을 비교해서, 92% 근처 run이 dedicated blocks·worker 수·HBM·latency 중 무엇이 달랐는지 찾겠습니다.

## 59. Assistant

맞아. 현재 **88.6%는 예전 최고 92.9%보다 4.3%p 낮아.** 단순히 KV 블록 16개 차이로는 설명하기 어렵다.

| 실험 | Dedicated KV | TPOT p50 / p90 | Decode 200 | Request 200 |
|---|---:|---:|---:|---:|
| 예전 `20260817_203514` | 2432 | 154.2 / 185.2ms | 95.1% | **92.9%** |
| 현재 `20260824_172838` | 2416 | 160.0 / 198.9ms | 90.7% | **88.6%** |

요청 데이터, weight, worker 1 설정은 거의 동일하고 prefill도 97.0% → 96.7%로 비슷하다. 성능 차이는 주로 **decode 경로가 느려진 것**이다.

가장 큰 차이는 코드 버전이다. 예전 실험 이후 다음과 같은 성능 경로 변경이 들어갔다.

- `cudaMemcpyBatchAsync` 사용
- memcpy/compute stream 변경
- `FastStream` 제거
- barrier 및 chunk 처리 변경
- 현재의 retired-slot/free 동기화 변경

또 현재 CPU KV compression 시간이 예전보다 호출당 약간 길고, 평균 batch도 커져 single-worker join 병목이 더 나타난다.

결론적으로 **2432→2416의 80MiB 차이가 주원인은 아니며, 이후 코드 변경 중 decode 경로 회귀가 있는 것으로 보인다.** 정확히 찾으려면 `D=2416`으로 고정한 뒤:

1. 현재 코드에서 retired 적용 전/후 비교
2. 그래도 차이가 나면 8월 17일 코드와 현재 코드를 A/B 비교

하는 게 맞다.

## 60. User

chunk 크기도 8192로 같지?

## 61. Assistant

두 실행 로그와 당시 코드 설정에서 chunk 관련 값을 다시 대조해볼게.

## 62. Assistant

응. **두 실험 모두 실제 `max_num_batched_tokens=8192`로 실행됐어.**

현재 로그의 `Required scheduler policy ... 1024` 문구는 오래된 출력 문구일 뿐, 실제 engine args와 vLLM 확인 메시지는 모두 `8192`다.

따라서 chunk 크기는 성능 차이 원인에서 제외해야 해. 이전 답변에서 변경 후보로 언급한 건 부정확했어.

## 63. User

- 현재의 retired-slot/free 동기화 변경 이건 뭐야?

## 64. Assistant

네가 처음 설명한 이 변경을 말한 거야.

기존:

1. KV slot 해제
2. 세 CUDA stream에 `synchronize()`
3. GPU 작업이 끝날 때까지 CPU 대기
4. slot 재사용

Retired 방식:

1. CUDA event 기록
2. slot을 `retired` 상태로 전환
3. CPU는 대기하지 않음
4. event 완료 후 slot을 free pool로 반환

여기서 `free`는 HBM 할당 자체를 해제하는 게 아니라 **KV slot을 재사용 가능하게 만드는 것**이야.

그리고 이것이 성능 저하 원인으로 확인된 건 아니야. 오히려 free 경로는 개선됐고, 이전 답변에서는 단지 예전 92.9% 실행과 다른 코드 요소로 열거한 거야. 원인으로 단정하면 안 돼.

## 65. User

그럼 과거 버전이랑 제대로 비교해봐. 너가 직접 실험 돌려도 돼. 내 생각엔 지금 코드는 굳이 다시 할 필요는 없을 것 같고 과거 만 다시 하면 되지 안을까?

## 66. Assistant

맞아. 현재 결과(`20260824_172838`, D=2416)는 그대로 기준으로 쓰고, 92.9%가 나왔던 시점의 코드를 별도 worktree로 복원해 **D=2416·worker=1·동일 워크로드**만 다시 돌리면 돼. 먼저 당시 커밋과 실행 스크립트, 현재 GPU/서버 상태를 확인한 뒤 기존 작업물을 건드리지 않고 재현하겠다.

## 67. Assistant

확인 결과, 현재 서버가 아직 GPU 약 96 GiB를 점유한 채 살아 있어 과거 서버를 띄우기 전에 종료해야 해. 또 92.9% 실행은 커밋 시각보다 앞서지만 로그 내용은 나중에 커밋된 `8192` 변경까지 포함하고 있어서, 단순히 “그 시각 직전 커밋”을 체크아웃하면 오히려 다른 코드가 된다. 로그와 패치 내용을 대조해 당시 상태를 정확히 지문 매칭하고 있다.

## 68. Assistant

당시 상태는 `af2e7c1` worktree로 잡는 게 맞다. 92.9% 로그의 문구와 `max_num_batched_tokens=8192`가 이 상태와 일치한다. 현재 실행에는 과거와 달리 KV 주소순 할당 기본값도 켜져 있었으므로, 과거 재현에서는 이를 명시적으로 `0`으로 고정하고 현재 변경은 보존한 채 서버만 종료하겠다.

## 69. Assistant

현재 서버는 정상 종료됐고 GPU는 유휴 상태(잔여 110 MiB)야. 이제 격리된 `af2e7c1` 코드에 현재의 “논리 D 고정” 계측만 사용해 D=2416으로 서버를 올린다. 과거 동작을 맞추기 위해 `TIERED_SERVE_KV_ADDR_ORDER=0`, worker=1, chunk=8192를 명시했다.

## 70. Assistant

과거 서버는 정상 기동 중이고, 로그에서 실제 scheduler chunk가 `8192`임을 확인했어. 현재는 모델 weight 압축/로딩 단계라 GPU 사용량이 아직 약 740 MiB이며, health endpoint가 열릴 때까지 진행 상황을 계속 확인하겠다.

## 71. Assistant

모델 로딩은 정상 완료됐고 과거 로그와 동일하게 weight 63.75 GiB, aux 5.96 GiB, 총 70.5698 GiB가 잡혔다. 이제 torch.compile/profile 및 KV pool 배치 단계다. 여기서 물리 HBM row 2928, 논리 dedicated 2416이 정확히 찍히는지 확인한 뒤 벤치마크를 시작할게.

## 72. Assistant

첫 기동은 비교 코드 문제가 아니라 HBM 조건에서 fail-fast가 동작해 중단됐어. 정확한 요청/최대값과 hugepage 정리 상태를 로그 앞부분에서 확인한 뒤, 같은 논리 D=2416을 유지할 수 있는지 바로 조정하겠다. EBUSY 메시지는 엔진 실패 후 마운트 정리 과정의 2차 오류야.

## 73. Assistant

실패한 EngineCore가 NCCL 종료 전에 죽으면서 프로세스는 없는데 GPU에 약 8.9 GiB가 남는 드라이버 잔류 상태가 확인됐어(`Processes: None`). 이 상태로 재시도하면 D=2416 비교가 불가능하므로, 다른 GPU 프로세스가 없음을 확인한 GPU 0만 reset해서 메모리를 회수한 뒤 다시 시작하겠다.

## 74. Assistant

GPU reset은 권한 부족으로 수행되지 않았어. 대신 실험용 `tiered-serve` 컨테이너에는 실행 중인 서버가 없고 작업 파일은 컨테이너 레이어에 보존되므로, 컨테이너만 재시작해 CUDA namespace/잔류 context가 정리되는지 확인하겠다. 호스트 GPU reset이나 재부팅은 하지 않을게.

## 75. Assistant

과거 버전 재실행 준비는 끝났지만 GPU 메모리 잔류로 막혔어.

- 실패한 EngineCore 종료 후 프로세스는 없음
- 그런데 HBM **8.9 GiB가 드라이버에 잔류**
- 컨테이너 재시작으로도 회수되지 않음
- 일반 권한 GPU reset은 거부됨
- 이 상태에서는 D=2416의 최대치가 639로 계산돼 비교 불가

GPU 프로세스가 전혀 없는 것은 확인했어. 호스트 권한으로 GPU 0 reset을 시도해도 될까?

```bash
sudo nvidia-smi --gpu-reset -i 0
```

허용되면 초기화 후 과거 버전 실험을 바로 이어서 돌릴게.

## 76. User

초기화 해도 문제 없어? 향후 실험에?

## 77. Assistant

향후 실험 관점에서는 오히려 잔류 HBM을 제거해 출발 조건을 정상화하는 작업이야. 다만 GPU reset이 건드리는 범위를 현재 환경 기준으로 확인해서 안전 조건을 짚어줄게.

## 78. Assistant

응. 현재는 GPU 프로세스가 전혀 없어서 reset해도 안전해.

영향은:

- 잔류 CUDA context/HBM만 초기화
- 컨테이너 파일, 코드, 로그, hugepage 데이터에는 영향 없음
- 이후 서버는 처음부터 다시 로딩·워밍업
- 벤치마크는 앞 100개 요청을 제외하므로 초기 clock 상태 영향도 거의 없음

Reset 후 HBM, GPU clock/power 설정을 다시 확인하고 실험하면 돼. 향후 실험에는 오히려 더 깨끗한 조건이 된다. 실행해도 된다고 하면 진행할게.

## 79. User

그럼 빌드도 다시 해야하나?

## 80. Assistant

아니, **다시 빌드할 필요 없어.**

GPU reset은 HBM/CUDA context만 초기화하고 다음은 그대로 유지돼.

- vLLM·CUDA 확장 `.so`
- tiered-serve 코드
- torch compile 캐시
- 모델 파일

또 과거 `af2e7c1`과 현재 사이의 비교 대상 변경은 Python 로직이고 C++/CUDA 확장은 같아서 재빌드 없이 실행 가능해. 서버만 다시 띄우면 CUDA graph와 runtime context는 자동으로 재생성돼.

## 81. User

그럼 진행해

## 82. Assistant

GPU 0 reset을 실행하고 HBM이 정상 기준으로 돌아왔는지 확인한 뒤, 과거 `af2e7c1` 서버를 D=2416 조건으로 다시 올리겠다. 재빌드는 하지 않는다.

## 83. Assistant

Reset이 성공했고 HBM은 `used 0 MiB / free 96,768 MiB`로 완전히 정리됐어. 격리 worktree와 컨테이너도 그대로 보존됐다. 이제 동일 조건으로 과거 서버를 재기동한다.

## 84. User

근데 코드가 바뀌는거 아니야? 정말 빌드 안해도 돼?

## 85. User

그럼 진행해

## 86. Assistant

진행 중이야. GPU reset 후 두 번째 기동은 정상적으로 모델 shard를 로딩하고 있어. D=2416 검증 로그까지 확인되면 바로 1.0 QPS·1200요청 벤치마크를 붙이겠다.

## 87. Assistant

두 번째 기동도 D 검증에서 중단됐는데, 이번에는 초기 HBM은 완전히 깨끗했음에도 KV 계산 시점의 free HBM이 과거보다 약 4.5 GiB 적었어(과거 약 21.2 GiB, 지금 16.68 GiB). 즉 단순 잔류 메모리 문제가 아니라 과거 worktree와 현재 vLLM 실행 조합에서 profile/compile 임시 메모리가 덜 반환되는 차이가 있어. 로그를 단계별로 대조해서 이 차이를 먼저 제거하겠다. 낮은 D로 억지 실행하면 공정 비교가 아니므로 그렇게 하지는 않을게.

## 88. Assistant

코드 diff를 직접 확인하니 과거 `af2e7c1`과 현재 tiered-serve의 모델 로딩 경로 차이는 사실상 barrier 검증 리팩터뿐이라 4.5 GiB 차이를 설명하지 못해. 다음으로 같은 깨끗한 GPU에서 현재 코드도 KV 초기화까지만 올려 보고, 이 현상이 과거 코드 때문인지 GPU reset 이후 환경 때문인지 분리하겠다. 이건 벤치마크 재실행이 아니라 시작 조건 진단이야.

## 89. Assistant

현재 코드로도 모델 로딩 단계의 HBM 사용량이 과거와 동일해. 이제 profile 직후 수치를 기다리는 중이야. 여기서도 D=2416이 실패하면 코드 버전이 아니라 GPU reset 이후 프로파일 메모리 조건이 변한 것이 확정된다.

## 90. Assistant

현재 코드도 동일하게 profile 후 약 8 GiB 임시 allocation을 반환하지 못해 실패했으므로, 과거 코드 문제가 아니라 현재 allocator 시작 조건 문제로 확정됐어. 저장소의 공식 실험 wrapper가 사용하는 `expandable_segments:True`를 적용해 이 임시 allocation이 반환되도록 한 뒤 과거 버전을 다시 올린다. 이 설정은 결과에 반드시 별도 표기하겠다.

## 91. Assistant

profile 직후 `torch.cuda.empty_cache()`가 호출되지 않은 채 KV planner가 `mem_get_info()`를 읽는 구조를 확인했어. 실험 조건을 바꾸지 않도록 env-gated 진단 한 줄을 임시로 넣어, KV 배치 직전에 캐시만 반환하고 실제 free HBM을 기록하겠다. 서버가 뜬 뒤에는 원본 파일로 복구하므로 런타임 경로와 빌드 산출물은 그대로다.

## 92. Assistant

진단 결과 `empty_cache()`는 0.01 GiB만 회수했어. 문제는 PyTorch 캐시가 아니라 **non-torch CUDA 메모리가 과거 약 3 GiB에서 현재 약 13 GiB로 증가한 것**이야. 임시 진단 코드는 효과가 없으므로 즉시 원복하고, 다음 단계에서는 CUDA module loading 상태를 명시적으로 과거 조건에 맞춰 확인하겠다.

## 93. Assistant

명시적 `CUDA_MODULE_LOADING=LAZY`도 동일하게 실패했어. 지금 차이는 Python/allocator 설정이 아니라 CUDA가 로드한 non-torch 영역이 약 10 GiB 커진 상태야. 다음으로 현재 사용 중인 vLLM CUDA 바이너리의 빌드 시각과 과거 실험 시각을 대조하겠다. 만약 실험 뒤 `.so`가 교체됐다면 “빌드 불필요”가 아니라 당시 바이너리를 복원해야 정확한 비교가 된다.

## 94. Assistant

바이너리도 대조했는데 vLLM CUDA `.so`는 4월 6일, `stack_pool.so`는 8월 17일 20:28 빌드로 92.9% 실험 때와 동일해. 따라서 재빌드 문제가 아니다. 지금은 GPU reset 뒤 non-torch HBM이 매 기동마다 9–13 GiB 생기는 드라이버 상태가 남아 있어 D=2416 자체를 만들 수 없다. 실패 프로세스와 임시 진단 변경을 정리하고 GPU를 다시 깨끗한 상태로 돌려놓겠다.

## 95. Assistant

현재는 호스트 재부팅이 필요해 보여.

확인 결과:

- 과거/현재 코드 모두 D=2416 초기화 실패
- non-torch CUDA 메모리가 기존 약 3 GiB → 현재 9–13 GiB
- `empty_cache`, allocator 설정, CUDA lazy loading으로 해결되지 않음
- 바이너리는 과거와 동일하며 재빌드 문제 아님
- 임시 코드 변경은 원복 완료
- GPU는 현재 `used 0 MiB`로 정리 완료

컨테이너 재시작과 GPU reset으로 해결되지 않아 다음 단계는 호스트 재부팅이야. 호스트를 재부팅해도 될까? 재부팅 후 D=2416 가능 여부부터 확인하고 과거 실험을 이어가면 된다.

## 96. User

재부팅해

## 97. Assistant

호스트를 재부팅한다. 현재 서버 프로세스는 없고, 임시 vLLM 변경은 원복됐으며 과거 `af2e7c1` worktree와 기존 실험 로그는 디스크에 보존된 상태야. 재부팅 후 컨테이너를 다시 시작하고 HBM부터 검증하겠다.

## 98. User

재부팅 됐어

## 99. Assistant

재부팅 상태를 확인하고 `tiered-serve` 컨테이너를 다시 올린 뒤, 먼저 idle HBM과 D=2416 초기화 가능 여부를 확인하겠다. 정상화됐으면 곧바로 과거 버전 벤치마크까지 이어갈게.

## 100. Assistant

재부팅은 완료됐고 GPU는 `used 0 MiB`로 깨끗해. 재부팅 후 현재 셸의 Docker socket 그룹 권한만 적용되지 않아, 이미 허용된 관리자 권한으로 컨테이너를 시작하겠다.

## 101. Assistant

과거 worktree(`af2e7c1`)와 vLLM 원본 상태가 모두 보존된 것을 확인했어. 이제 추가 allocator/진단 옵션 없이, D=2416·worker=1·chunk=8192·주소순 할당 off 조건으로 서버를 올린다.

## 102. User

원래 컨테이너는 launch.sh로 했는데 그렇게 안해도 돼?

## 103. Assistant

기존 컨테이너를 삭제·재생성한 게 아니라 재부팅으로 정지된 동일 컨테이너를 `docker start`한 것이어서, 일반적으로 `launch.sh`를 다시 실행할 필요는 없어. 다만 `launch.sh`가 매 부팅마다 수행하는 호스트 hugepage 설정이 있는지 확인해서 현재 실행 조건이 같은지 바로 대조할게.

## 104. Assistant

확인해보니 `launch.sh` 전체를 다시 실행하면 안 돼. 그 스크립트는 이미지를 다시 import하고 기존 컨테이너를 삭제하는 초기 설치용이야.

다만 재부팅 때 풀린 두 설정은 다시 적용해야 해.

- 16 GiB hugetlbfs 마운트
- GPU power limit 900W / clock 1980MHz

지금 컨테이너 안 `/mnt/hugepages`가 일반 ext4로 보이는 것을 발견했으므로, 현재 기동은 중단하고 이 두 설정만 복원한 뒤 같은 컨테이너를 다시 시작하겠다.

## 105. Assistant

초기화 전에 잘못 보인 ext4 경로에 서버가 16 GiB 파일 6개(총 97 GiB)를 생성한 것도 확인했어. 이들은 방금 중단한 잘못된 기동에서 생긴 임시 weight page라서, 정확한 6개 파일만 제거하고 hugetlbfs를 다시 마운트한 뒤 시작하겠다. 기존 실험 로그나 코드에는 손대지 않는다.

## 106. Assistant

부팅 시 필요한 상태가 이제 정확히 복원됐어.

- GPU clock/power: 1980 MHz / 900W
- `/mnt/hugepages`: 16 GiB hugetlbfs
- 잘못 생성된 ext4 임시 파일 97 GiB 제거
- 과거 코드: `af2e7c1`
- vLLM 임시 변경 없음

이제 서버를 다시 기동한다.

## 107. Assistant

재부팅과 hugetlbfs 복원 효과가 나타났어. 모델 로딩 직후 free HBM이 이전 실패 때 9–12 GiB 수준에서 지금 18.34 GiB로 크게 회복됐다. profile 종료 후 D=2416 검증만 남았어.

## 108. Assistant

재부팅으로 크게 회복됐지만 `max_num_seqs=512`가 예약하는 resident-tail 512개 때문에 D=2416에 아직 약 3.3 GiB 부족했어. 기존 두 결과에서 실제 batch 최대가 58–60이므로, `max_num_seqs=128`로 내려도 이 워크로드의 동시 실행에는 걸리지 않는다. 논리 dedicated D=2416은 그대로 두고, 사용되지 않는 tail 예약만 512→128로 줄여 과거 실험을 진행하겠다. 안전 reserve는 실제 남는 공간에 맞춰 6 GiB로 설정한다. 이 차이는 최종 비교에 명시할게.

## 109. Assistant

이번 실패로 조건이 명확해졌어. 재부팅 직후 첫 기동에서는 free HBM이 19.9 GiB였지만, 그 뒤 GPU reset을 하면 다음 기동에서 14.1 GiB로 다시 줄어든다. 즉 이 GH200 환경에서는 GPU reset이 완전 초기화가 아니고 오히려 다음 CUDA context의 non-torch 메모리를 늘린다.

한 번 더 호스트를 재부팅하되, 이번에는 순서를 바로잡아 **hugetlbfs 마운트 → 컨테이너 시작 → 첫 서버 기동(max_seq=128, D=2416)**으로 진행하겠다. 중간에 GPU reset은 하지 않는다.

## 110. User

리붓됐어

## 111. Assistant

좋아. 이번에는 컨테이너를 먼저 시작하지 않고, 호스트 hugetlbfs와 GPU clock/power를 먼저 복원한 뒤 컨테이너를 올리겠다. 그 다음 첫 CUDA context로 바로 과거 서버를 실행할게.

## 112. Assistant

순서가 정상적으로 맞춰졌어: HBM 0 MiB, 16 GiB hugetlbfs, `af2e7c1`, vLLM 원복 상태야. 이제 GPU reset 없이 첫 서버 기동을 시작한다.

## 113. Assistant

재부팅 후 hugepage 마운트와 컨테이너 복구를 마쳤고, 지금 과거 코드(`af2e7c1`) 서버가 정확히 2416 KV 블록으로 올라왔는지 최종 확인 중입니다. 성공하면 바로 1.0 QPS 재실험을 이어가겠습니다.

## 114. Assistant

이번 첫 기동은 실패했습니다. 고정값 2416에 필요한 HBM보다 약 2.3 GiB가 부족해 최대 1945로 계산됐습니다. 지금은 값을 낮춰 진행하지 않고, 과거에는 2432가 가능했던 만큼 재부팅 직후부터 어디에서 HBM 차이가 생겼는지 프로세스·로그·계산식을 먼저 대조하겠습니다.

## 115. Assistant

원인이 수치상 명확해졌습니다. 모델 자체 메모리는 과거와 정확히 같은 70.5698 GiB인데, 이번 실행은 프로파일 단계의 여유 HBM이 21.29→17.01 GiB로 4.28 GiB 줄었습니다. 현재 서버 프로세스가 끝났는데도 `nvidia-smi`에 약 4.3 GiB가 남아 있어, 코드/모델이 아니라 종료된 CUDA 컨텍스트의 잔류 할당과 정확히 일치합니다. 잔존 프로세스와 드라이버 상태를 더 확인하겠습니다.

## 116. Assistant

과거 로그와 현재 로그는 모델 weight/aux/컴파일 경로까지 동일합니다. 차이는 부팅 뒤 자동으로 올라온 `nvidia-persistenced`와 함께 보이는 프로세스 미귀속 4.3 GiB뿐입니다. 과거 `launch.sh`는 persistence mode를 켜지 않았으므로, 이를 일시 해제해 HBM이 반환되는지 확인하고 실험 후 원상태 여부도 기록하겠습니다. GPU 전력 제한은 과거 조건인 900 W, 클럭 1980 MHz로 복구했습니다.

## 117. Assistant

확인됐습니다. `nvidia-persistenced`를 끄자 미귀속 4.3 GiB가 즉시 사라져 GPU 사용량이 0 MiB가 됐습니다. 이제 인위적으로 `max-num-seqs`를 128로 줄일 필요도 없습니다. 과거와 같은 512, reserve 6 GiB를 유지하고, 비교 대상만 고정 D=2416·worker=1·과거 코드로 서버를 다시 올리겠습니다.

## 118. Assistant

서버 인자는 과거 조건과 일치하게 적용됐습니다: `max_num_batched_tokens=8192`, `max_num_seqs=512`, worker 1입니다. 현재 70B weight 로딩 중이며, 다음 핵심 확인값은 가용 HBM이 과거의 약 21.29 GiB로 복구되는지와 logical dedicated block이 정확히 2416인지입니다.

## 119. Assistant

핵심 조건이 모두 맞았습니다. 가용 HBM은 과거와 동일한 21.29 GiB로 복구됐고, `logical=2416`, tail 512, physical HBM rows 2928로 정확히 고정됐습니다. CUDA graph 준비와 health check가 끝나는 즉시 1200-request 벤치마크를 시작합니다.

## 120. Assistant

서버 health check가 통과했습니다. 이제 과거와 동일한 Azure conversation 1200개, 앞뒤 100개 제외, 1.0 QPS 벤치마크를 시작합니다. 약 20분 걸리며 중간 진행률과 서버 오류 여부를 계속 확인하겠습니다.

## 121. Assistant

벤치마크가 정상 시작됐고 서버 측 로깅도 `20260824_190541` 디렉터리에 연결됐습니다. 초기 단일 요청 검증을 통과했으며 현재 오류 없이 요청을 처리 중입니다. 초반 진행률의 긴 ETA는 응답 완료 순서 때문에 부정확하고, 요청 투입 자체는 1 QPS로 진행됩니다.

## 122. Assistant

현재 119/1200 요청이 완료됐고 오류는 보이지 않습니다. 초반 warm-up 제외 구간에 곧 진입합니다. GPU 조건도 과거와 동일하게 유지되는지 별도로 확인하면서 계속 진행하겠습니다.

## 123. Assistant

진행률은 244/1200(20%)입니다. 서버 health는 정상이고 오류 로그가 없으며, GPU는 약 59% 사용률·900 W 제한·고정 클럭 조건에서 동작 중입니다. 현재까지 실패 요청 징후는 없습니다.

## 124. Assistant

현재 292/1200(24%)까지 완료됐습니다. 처리 흐름은 안정적입니다.

## 125. Assistant

354/1200(30%) 완료됐습니다. 실험 조건 변경 없이 계속 진행 중입니다.

## 126. Assistant

418/1200(35%) 완료됐고 오류 없이 정상입니다.

## 127. Assistant

466/1200(39%)까지 진행됐습니다. 비교에 사용할 측정 구간(요청 101–1100) 안에서 안정적으로 처리 중입니다.

## 128. Assistant

522/1200(44%) 완료됐습니다. 계속 정상입니다.

## 129. Assistant

581/1200(48%)로 절반에 가까워졌습니다. 실패 요청이나 서버 오류는 아직 없습니다.

## 130. Assistant

627/1200(52%) 완료했습니다. 중간 지점을 통과했고 조건은 그대로 유지되고 있습니다.

## 131. Assistant

673/1200(56%) 완료됐습니다. 정상 진행 중입니다.

## 132. Assistant

739/1200(62%) 완료됐습니다. 출력 완료 속도도 안정적으로 유지되고 있습니다.

## 133. Assistant

795/1200(66%) 완료됐습니다. 서버 상태는 계속 정상입니다.

## 134. Assistant

843/1200(70%) 완료됐습니다. 이 시점에 로그량이 늘어 별도로 오류 문자열과 health를 재확인하겠습니다.

## 135. Assistant

906/1200(76%) 완료됐습니다. 방금 재검사에서도 client/server 오류 0건, health 정상입니다.

## 136. Assistant

959/1200(80%) 완료됐습니다. 남은 요청도 같은 조건으로 진행합니다.

## 137. Assistant

1011/1200(84%) 완료됐습니다. 측정 구간의 끝(1100번째 요청)에 가까워지고 있습니다.

## 138. Assistant

1057/1200(88%) 완료됐습니다. 곧 집계 대상 1000개 요청 구간이 모두 채워집니다.

## 139. Assistant

1110/1200(92%) 완료됐고, 실제 집계 대상인 101–1100번째 요청은 모두 끝났습니다. 마지막 100개 제외 구간을 마친 뒤 자동 생성되는 `summary.csv`를 과거·현재 결과와 바로 대조하겠습니다.

## 140. Assistant

1154/1200(96%)입니다. 약 1분 내외로 완료될 전망입니다.

## 141. Assistant

재실험이 완료됐습니다. 성공 1000/실패 0이고, 과거 코드 재실행의 Request 200 attainment는 **88.3%**입니다. 즉 현재 88.6%와 사실상 같고, 과거 기록 92.9%는 코드 버전 차이로 재현되지 않았습니다. 지금 summary와 서버 내부 지표를 세 실행에서 대조해 남은 환경 차이를 좁힌 뒤 서버를 정상 종료하겠습니다.

## 142. Assistant

정정합니다. 방금 88.3%는 진행 출력이 앞뒤 제외 전 1200개 전체에 대해 표시한 값이었습니다. 기존 결과와 동일하게 앞뒤 100개를 제외한 공식 `summary.csv` 값은 **86.4%**입니다. 현재 코드 88.6%보다 2.2%p 낮고 과거 92.9%보다 6.5%p 낮습니다. 이제부터는 공식 집계값만 사용하겠습니다. 서버는 로그 저장 완료 후 정상 종료합니다.

## 143. Assistant

서버는 정상 종료됐고 GPU HBM은 다시 0 MiB, hugepage 23장도 모두 free 상태입니다. 종료 오류로 보이는 `/mnt/hugepages` rmdir 메시지는 마운트 지점을 지우려다 난 것이며 할당 누수는 없습니다. 이제 동일 요청 여부와 offload/join 발생 비율을 세 로그에서 정량 비교합니다.

## 144. Assistant

현재까지 핵심은 세 실행의 1200개 입력·출력 길이가 전부 완전히 동일하다는 점입니다. 과거 고성능 대비 재실행은 TPOT가 평균 8.4 ms 느렸지만, 현재 코드 대비로는 평균 0.77 ms 차이뿐입니다. 소스 효과라기보다 실행 환경/변동으로 보입니다. 같은 설정의 기존 여러 실행도 모아 92.9%가 반복된 값인지 단발성인지 확인하겠습니다.

## 145. Assistant

추가로 확인할 중요한 점이 있습니다. 첫 재실행은 과거 `tiered-serve` 코드였지만, 고정 D 검증을 위해 현재의 별도 `vLLM` 소스 트리를 사용했습니다. 입력은 동일했지만 이것만으로 “완전한 과거 버전”이라고 단정할 수는 없습니다. 과거 커밋에 함께 저장된 `vllm.patch`를 독립 worktree에 적용해 vLLM Python 경로까지 당시 상태로 복원하고, D=2416이 정확히 적용되는지 확인한 뒤 한 번 더 실행하겠습니다. 사용자 작업 트리는 건드리지 않습니다.

## 146. Assistant

과거 vLLM 패치는 clean base에 충돌 없이 적용됐습니다. 당시 변수 의미는 현재와 달라 `DEDICATED_KV_BLOCKS`가 tail 512를 포함한 물리 row 수였습니다. 따라서 동일한 상주 logical D=2416을 만들려면 과거 코드에는 **2928(=2416+512)**을 넣어야 합니다. 이 의미 차이를 반영해 완전 과거 조합을 기동하겠습니다.

## 147. Assistant

완전 과거 조합의 첫 기동은 모델 로딩 전에 중단됐습니다. clean worktree에 Python 소스는 복원됐지만, 빌드된 `vllm_flash_attn` 공유 라이브러리 경로가 새 worktree에서 보이지 않는 import 경로 문제입니다. GPU/hugepage 할당 전 실패라 실험 상태에는 영향이 없습니다. 기존 빌드 산출물을 복사하지 않고 경로로 재사용하도록 연결하겠습니다.

## 148. Assistant

빌드 산출물 경로만 연결했고 import 검증이 통과했습니다. Python 모듈은 `/root/projects/vllm-af2`, FlashAttention의 기존 `.so`만 원래 빌드 디렉터리에서 읽습니다. 재빌드 없이 당시 Python 패치와 동일한 CUDA 바이너리를 쓰는 구성입니다. 서버 기동을 다시 시도합니다.

## 149. Assistant

두 번째 기동은 HBM 할당 전 `cudaHostRegister`에서 장치 일시 unavailable 오류가 났습니다. 코드 오류가 아니라 persistence mode를 끈 뒤 CUDA 모듈 import 테스트가 컨텍스트를 닫는 과정에서 생긴 드라이버 전환 상태로 보입니다. 프로세스와 GPU 상태를 확인하고, 필요하면 persistence daemon만 다시 켠 뒤 미귀속 HBM이 생기지 않는지 검증하겠습니다. GPU reset은 사용하지 않겠습니다.

## 150. Assistant

확인 결과 persistence daemon 자체는 HBM을 사용하지 않습니다(활성화 후에도 0 MiB). 이전 4.3 GiB는 실패한 CUDA 컨텍스트의 잔류분이었습니다. persistence를 켜 두면 900 W/1980 MHz 설정과 장치 컨텍스트가 안정적으로 유지되므로, HBM 0 MiB 상태에서 다시 기동합니다.

## 151. Assistant

persistence를 켜도 동일하게 모델 로딩 전 실패해, 단순 드라이버 전환 문제는 아니었습니다. 완전 과거 vLLM import 경로가 CUDA 초기화 순서를 바꾸는지 최소 테스트로 분리하겠습니다. 반복 실패는 hugepage 파일을 남기지 않았고 HBM 할당도 없습니다.

## 152. Assistant

CUDA runtime 자체가 `memGetInfo`에서 unavailable 상태로 고정됐고, persistence 재시작으로도 복구되지 않았습니다. `nvidia-smi`만 정상인 드라이버 불일치 상태라 서버를 더 반복 실행하면 안 됩니다. 이전에 합의한 방식대로 GPU reset 대신 호스트를 한 번 재부팅하겠습니다. 재부팅 후에는 hugepage를 먼저 마운트하고 컨테이너를 시작한 다음, 별도 import 테스트 없이 완전 과거 서버를 바로 기동하겠습니다.

## 153. User

재부팅 됐어

## 154. Assistant

재부팅 확인했습니다. 이번에는 컨테이너를 시작하기 전에 호스트 hugepage 마운트·GPU HBM 0 MiB·persistence 상태를 먼저 검증하고, 900 W/1980 MHz를 복구한 뒤 완전 과거 서버를 바로 기동하겠습니다.

## 155. Assistant

부팅 상태가 정확합니다: host/container 모두 16 GiB hugetlbfs, 23/23 pages free, HBM 0 MiB, persistence 활성, 900 W/1980 MHz입니다. worktree와 빌드 링크도 유지됐습니다. 이제 다른 CUDA 테스트 없이 완전 과거 서버를 바로 시작합니다.

## 156. Assistant

재부팅으로 CUDA 문제는 해결됐고 hugepage 등록까지 통과했습니다. 이번 실패는 GPU가 아니라 과거 패치 묶음에 누락된 단일 Python 호환성 문제입니다: `log_non_default_args()`가 당시 `EngineArgs`에 없는 `enable_log_requests` 필드를 조회합니다. 모델/HBM 할당 전이므로 상태는 깨끗합니다. 현재 파일과 과거 파일의 해당 함수만 비교해 역사 실행 때 존재했던 보완 코드를 최소 복원하겠습니다.

## 157. Assistant

누락된 호환 보완은 현재 트리와 동일한 한 줄(`EngineArgs` 대신 실제 subclass 타입으로 기본값 생성)뿐이며, 성능 경로에는 관여하지 않습니다. HBM은 2 MiB, hugepage는 23/23 free입니다. 서버를 다시 기동합니다.

## 158. Assistant

완전 과거 vLLM 경로로 엔진 프로세스가 정상 생성됐고 70B weight 로딩에 들어갔습니다. 다음으로 가용 HBM 21.29 GiB와 runtime logical D=2416을 확인하겠습니다.

## 159. Assistant

완전 과거 조합이 정상 기동됐습니다. 가용 HBM 21.30 GiB, 물리 2928 rows, runtime `num_dedicated_blocks=2416`, offloadable 14561로 비교 조건이 정확히 일치합니다. CUDA graph 준비도 과거 기록과 같은 약 6초였습니다. health 확인 후 마지막 1.0 QPS 실험을 시작합니다.

## 160. Assistant

최종 비교 실험이 정상 시작됐고 서버 측 로깅도 `20260824_194205`에 연결됐습니다. 입력 1200개와 Poisson seed는 이전 실행과 동일합니다. 진행률과 오류를 계속 확인하겠습니다.

## 161. Assistant

42/1200(4%) 완료됐습니다. 초기 처리 흐름은 정상입니다.

## 162. Assistant

88/1200(7%) 완료됐고 오류는 없습니다.

## 163. Assistant

153/1200(13%) 완료됐습니다. 공식 측정 구간에 진입했고 조건은 안정적입니다.

## 164. Assistant

196/1200(16%) 완료됐습니다. 계속 정상입니다.

## 165. Assistant

262/1200(22%) 완료됐습니다. 실패 요청이나 서버 오류 징후는 없습니다.

## 166. Assistant

315/1200(26%) 완료됐습니다. 정상 진행 중입니다.

## 167. Assistant

386/1200(32%) 완료됐습니다. 이전 두 실행과 같은 속도 범위로 진행됩니다.

## 168. Assistant

433/1200(36%) 완료됐습니다. 조건 변화 없이 계속 진행 중입니다.

## 169. Assistant

491/1200(41%) 완료됐습니다. 중간 health와 오류 로그를 한 번 재검사하겠습니다.

## 170. Assistant

553/1200(46%) 완료됐습니다. health 정상, 오류 0건이며 GPU도 900 W 제한 아래 정상 동작 중입니다.

## 171. Assistant

615/1200(51%) 완료해 절반을 넘었습니다. 정상 진행 중입니다.

## 172. Assistant

654/1200(55%) 완료됐습니다. 계속 정상입니다.

## 173. Assistant

712/1200(59%) 완료됐습니다. 측정 조건은 그대로 유지되고 있습니다.

## 174. Assistant

768/1200(64%) 완료됐습니다. 오류 없이 진행 중입니다.

## 175. Assistant

824/1200(69%) 완료됐습니다. 로그량 증가는 이전 실행과 같은 진행 표시 갱신이며, 오류 문자열은 보이지 않습니다.

## 176. Assistant

870/1200(72%) 완료됐습니다. 정상 진행 중입니다.

## 177. Assistant

927/1200(77%) 완료됐습니다. 남은 약 270개 요청도 같은 조건으로 처리 중입니다.

## 178. Assistant

978/1200(82%) 완료됐습니다. 서버는 계속 정상입니다.

## 179. Assistant

1033/1200(86%) 완료됐습니다. 공식 측정 구간 종료까지 67개 남았습니다.

## 180. Assistant

1090/1200(91%) 완료됐습니다. 10개 후 집계 대상 1000개가 모두 채워집니다.

## 181. Assistant

1139/1200(95%) 완료됐고 공식 집계 구간은 끝났습니다. 마지막 제외 구간 처리 후 summary를 읽겠습니다.

## 182. Assistant

1189/1200(99%)입니다. 곧 완료됩니다.

## 183. Assistant

완전 과거 조합 실험이 성공 1000/실패 0으로 완료됐습니다. 전체 1200개 진행 출력은 87.6%였고, 이제 공식 앞뒤 제외 `summary.csv` 값을 읽어 네 결과를 비교하겠습니다.

## 184. Assistant

공식 결과는 **Request 200 attainment 85.6%**입니다. 따라서 완전 과거 조합도 92.9%를 재현하지 못했고, 오히려 현재 코드 88.6%보다 3.0%p 낮았습니다. 서버를 정상 종료한 뒤 request-level·offload 통계를 최종 비교하겠습니다.

## 185. Assistant

과거 `tiered-serve`와 당시 `vLLM`까지 함께 복원한 비교 실험도 끝났습니다. 결과 파일과 종료 후 GPU/hugepage 상태를 마지막으로 검증하고 결론을 정리하겠습니다.

## 186. Assistant

고정 조건 재현 결과는 이미 명확합니다. 다만 “과거 조합”에서 재사용한 CUDA 바이너리의 소스가 당시 패치와 동일한지도 확인해, 비교 범위에 불필요한 단서를 남기지 않겠습니다.

## 187. Assistant

실험 완료했어. 결론은 **과거 코드로 되돌려도 92%가 재현되지 않았고, 현재 코드보다 오히려 낮았습니다.**

| 구성 | Runtime KV blocks | Request 200 | Request 250 | TPOT p50/p90 |
|---|---:|---:|---:|---:|
| 과거 기록 | 2432 | 92.9% | 96.2% | 154.2/185.2ms |
| 현재 코드 | 2416 | 88.6% | 95.0% | 160.0/198.9ms |
| 과거 tiered-serve | 2416 | 86.4% | 94.2% | 160.3/202.5ms |
| 과거 tiered-serve+vLLM | 2416 | 85.6% | 93.5% | 161.4/204.1ms |

모든 재실험은 worker 1, chunk 8192이고, 1,200개 요청의 입력·출력 길이도 완전히 동일합니다.

92.9% 기록은 오프로딩 평균이 467 blocks였지만 현재는 582, 과거 재실험은 613 blocks였습니다. 과거에도 동일한 2448 blocks 실행이 81.4~91.9%로 흔들려, **92.9%는 코드 버전보다는 실행별 오프로딩 상태가 유리했던 결과**로 보입니다. 현재 retired 변경이 퇴행 원인이라는 증거는 없습니다.

최종 결과:

`/root/projects/tiered-serve-af2/logs/serving/llama_3_1_70b_instruct/cao-p4-kvcomp/20260824_194205/summary.csv`

서버는 종료했고 GPU 3 MiB, hugepage 23/23 free, persistence enabled, power 900W, clock 1980MHz로 다음 실험 가능한 상태입니다. 이후에는 runtime logical KV blocks를 동일하게 고정하고 최소 3회 중앙값으로 비교하는 게 좋습니다.

## 188. User

오프로딩 평균은 어떻게 줄이는데?

## 189. Assistant

오프로딩 평균은 대략 **활성 요청의 KV 총량 − 상주 KV 용량**이야. 줄이는 방법은 세 가지야.

- `DEDICATED_KV_BLOCKS` 증가: 현재 runtime 2416이므로 2432가 실제 적용되면 16 blocks 정도만 직접 감소해. 평균 613→467처럼 146 blocks를 줄이기엔 부족해.
- 처리 속도 향상: worker 2로 압축 대기·join을 줄이면 요청이 빨리 끝나 KV 체류 시간이 짧아져 간접적으로 감소할 수 있어.
- 동시 KV 수요 제한: request rate, concurrency, `max_num_seqs`를 낮추면 가장 확실히 감소하지만 동일 부하 비교가 아니게 돼.

따라서 동일 워크로드를 유지한다면 먼저 **runtime logical D=2432 적용 여부를 로그에서 확인하고 worker 1/2를 각각 반복 측정**하는 게 현실적이야. 92.9% 실행의 평균 467은 단순히 16 blocks 차이로 설명되지 않고, 실행 중 요청 적체가 덜 발생했던 영향이 큽니다.

## 190. User

근데 과거랑 똑같은 셋업이면 달라질 이유가 없잖아

## 191. Assistant

맞아. **소프트웨어·HBM·입력뿐 아니라 도착 시각과 실행 상태까지 정말 같다면 7%p 차이는 정상적인 오차로 넘길 수 없어.** 지금까지 맞춘 항목과 아직 달랐던 항목을 로그에서 다시 분리해 원인을 좁혀볼게.

## 192. Assistant

그리고 로그상 실제로는 완전히 같지 않았어. 92.9% 과거 실행은 runtime `D=2432`, 방금 과거 재실험은 현재 실행에 맞추느라 `D=2416`으로 고정했어. HBM은 오히려 재실험이 21.30 GiB로 충분했으니, 이번에는 과거 코드에 runtime `D=2432`를 정확히 맞춰 다시 돌려야 이 의문을 판정할 수 있어. 그렇게 재실험하겠다.

## 193. User

그건 나중에 하고 지금 코덱스 대화 기록을 [https://github.com/QuiverDance/codex-backup](https://github.com/QuiverDance/codex-backup) 이 리포에 gh200 브랜치 따서 백업해줘. 나중에 다시 서버 할당받고 초기화된 상태여도 컨텍스트를 그대로 이어갈 수 있도록

## 194. Assistant

이전 재실험은 중단하고 시작 중인 서버부터 안전하게 종료하겠습니다. 이후 Codex 기록 저장 위치와 재개에 필요한 메타데이터까지 확인해 `codex-backup` 저장소의 `gh200` 브랜치에 백업하겠습니다. Codex 데이터 구조를 다루므로 `openai-docs` 지침도 함께 적용할게요.

## 195. Assistant

`openai-docs` 확인상 공식 문서 검색만으로는 로컬 세션 백업 파일 구성이 명확히 나오지 않았습니다. 그래서 실제 `.codex` 세션 저장소를 확인하되, `auth.json`·토큰·캐시 같은 비밀정보는 절대 저장소에 넣지 않고 대화 재개에 필요한 세션 기록만 선별하겠습니다.

## 196. Assistant

저장소가 **public**인 것도 확인했습니다. 따라서 인증 파일이나 내부 상태 DB 전체를 올리지는 않고, 기존 저장소 형식을 먼저 확인한 뒤 공개 저장소에 적합한 대화·실험 컨텍스트와 복원 절차를 구성하겠습니다. 원본 세션은 비밀 패턴 검사 후 포함 범위를 결정할게요.

## 197. Assistant

공개 저장소용으로 원본 세션을 그대로 올리는 대신, 사용자·어시스턴트의 가시 대화 196개를 전부 추출했고 별도의 상세 handoff와 다음 실험 절차를 만들었습니다. 이제 비밀 패턴과 diff를 검사한 뒤 커밋·푸시하겠습니다.

## 198. User

gh200 브랜치에서는 내가 지금 이 서버에서 대화한 내역만 저장해. 혹시나 해서 말하는거야.

## 199. Assistant

맞아. 현재 만든 브랜치는 `main`에서 분기해서 과거 백업 이력이 부모 커밋에 남는 구조였어. 아직 원격 푸시는 인증 실패로 되지 않았으니, **부모 이력 없는 orphan `gh200` 브랜치**로 다시 만들고 이 서버의 현재 세션 한 개만 넣겠습니다. 다른 서버의 memories·skills·대화는 전부 제외할게요.
