#!/usr/bin/env bash
set -euo pipefail

part_bytes=196608
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
source_sessions="${codex_home}/sessions"
source_index="${codex_home}/session_index.jsonl"
target_parts="${repo_root}/.codex/session_parts"
target_manifest="${repo_root}/.codex/session_manifest.tsv"
target_index="${repo_root}/.codex/session_index.jsonl"

if [[ ! -d "${source_sessions}" || ! -f "${source_index}" ]]; then
  echo "Codex sessions or session index are missing under ${codex_home}." >&2
  exit 1
fi

snapshot_root="$(mktemp -d "${repo_root}/.codex/session-snapshot.XXXXXX")"
new_parts_root="$(mktemp -d "${repo_root}/.codex/session-parts.XXXXXX")"
manifest_tmp="$(mktemp "${repo_root}/.codex/session-manifest.XXXXXX")"
index_tmp="$(mktemp "${repo_root}/.codex/session-index.XXXXXX")"

cleanup() {
  [[ ! -e "${snapshot_root}" ]] || find "${snapshot_root}" -depth -delete
  [[ ! -e "${new_parts_root}" ]] || find "${new_parts_root}" -depth -delete
  [[ ! -e "${manifest_tmp}" ]] || find "${manifest_tmp}" -delete
  [[ ! -e "${index_tmp}" ]] || find "${index_tmp}" -delete
}
trap cleanup EXIT

mapfile -d '' session_files < <(
  find "${source_sessions}" -type f -name '*.jsonl' -print0 | sort -z
)
if [[ "${#session_files[@]}" -eq 0 ]]; then
  echo "No Codex rollout JSONL files were found." >&2
  exit 1
fi

declare -A indexed_session_ids=()
while IFS= read -r indexed_session_id; do
  indexed_session_ids["${indexed_session_id}"]=1
done < <(python3 - "${source_index}" <<'PY'
import json
import sys
from pathlib import Path

for line in Path(sys.argv[1]).read_text().splitlines():
    if line.strip():
        print(json.loads(line)["id"])
PY
)

snapshot_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
{
  printf '# codex_session_manifest_v1\n'
  printf '# snapshot_utc=%s\n' "${snapshot_utc}"
  printf '# fields=session_id\trelative_path\tsha256\tsize_bytes\tpart_count\n'
} > "${manifest_tmp}"

exported_count=0
for source_session in "${session_files[@]}"; do
  session_name="$(basename "${source_session}")"
  if [[ ! "${session_name}" =~ ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$ ]]; then
    echo "Cannot extract a session ID from ${source_session}." >&2
    exit 1
  fi
  session_id="${BASH_REMATCH[1]}"
  if [[ -z "${indexed_session_ids[${session_id}]+present}" ]]; then
    continue
  fi
  session_rel="${source_session#"${codex_home}/"}"
  snapshot_session="${snapshot_root}/${session_rel}"
  session_parts="${new_parts_root}/${session_id}"

  mkdir -p "$(dirname "${snapshot_session}")" "${session_parts}"
  cp -p "${source_session}" "${snapshot_session}"

  python3 - "${snapshot_session}" "${session_id}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_id = sys.argv[2]
line_count = 0
metadata_ids = []
with path.open(encoding="utf-8") as source:
    for line_count, line in enumerate(source, 1):
        record = json.loads(line)
        if record.get("type") == "session_meta":
            payload = record.get("payload", {})
            metadata_ids.append(payload.get("id", payload.get("session_id")))
if line_count == 0:
    raise SystemExit(f"empty rollout: {path}")
if expected_id not in metadata_ids:
    raise SystemExit(f"session metadata ID mismatch: {path}")
PY

  session_sha256="$(sha256sum "${snapshot_session}" | awk '{print $1}')"
  session_size="$(stat -c '%s' "${snapshot_session}")"
  split -b "${part_bytes}" -d -a 4 \
    "${snapshot_session}" "${session_parts}/part-"
  part_count="$(find "${session_parts}" -maxdepth 1 -type f -name 'part-*' | wc -l)"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "${session_id}" "${session_rel}" "${session_sha256}" \
    "${session_size}" "${part_count}" >> "${manifest_tmp}"
  exported_count=$((exported_count + 1))
done

if [[ "${exported_count}" -eq 0 ]]; then
  echo "No indexed active Codex sessions were found." >&2
  exit 1
fi

cp -p "${source_index}" "${index_tmp}"
python3 - "${manifest_tmp}" "${index_tmp}" <<'PY'
import json
import sys
from pathlib import Path

manifest_ids = {
    line.split("\t", 1)[0]
    for line in Path(sys.argv[1]).read_text().splitlines()
    if line and not line.startswith("#")
}
index_path = Path(sys.argv[2])
kept_lines = []
index_ids = set()
for line in index_path.read_text().splitlines(keepends=True):
    if not line.strip():
        continue
    session_id = json.loads(line)["id"]
    if session_id in manifest_ids:
        kept_lines.append(line)
        index_ids.add(session_id)
missing = sorted(manifest_ids - index_ids)
if missing:
    raise SystemExit(f"session index mismatch: missing={missing}")
index_path.write_text("".join(kept_lines))
PY

mkdir -p "${target_parts}" "$(dirname "${target_manifest}")"
find "${target_parts}" -mindepth 1 -depth -delete
cp -a "${new_parts_root}/." "${target_parts}/"
install -m 644 "${manifest_tmp}" "${target_manifest}"
install -m 644 "${index_tmp}" "${target_index}"

echo "Exported ${exported_count} indexed active Codex sessions at ${snapshot_utc}."
echo "Manifest: ${target_manifest}"
