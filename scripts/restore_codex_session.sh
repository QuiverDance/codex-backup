#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
source_manifest="${repo_root}/.codex/session_manifest.tsv"
source_index="${repo_root}/.codex/session_index.jsonl"
target_index="${codex_home}/session_index.jsonl"

if [[ ! -f "${source_manifest}" || ! -f "${source_index}" ]]; then
  echo "Backup files are missing." >&2
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${codex_home}"

restored_ids="$(mktemp "${codex_home}/restored-session-ids.XXXXXX")"
cleanup() {
  [[ ! -e "${restored_ids}" ]] || find "${restored_ids}" -delete
}
trap cleanup EXIT

restored_count=0
while IFS=$'\t' read -r session_id session_rel expected_sha256 \
  expected_size expected_part_count; do
  [[ -n "${session_id}" && "${session_id}" != \#* ]] || continue
  if [[ ! "${session_id}" =~ ^[0-9a-f-]{36}$ || \
        ! "${session_rel}" =~ ^(sessions|archived_sessions)/ || \
        "${session_rel}" == *..* || \
        ! "${expected_sha256}" =~ ^[0-9a-f]{64}$ || \
        ! "${expected_size}" =~ ^[0-9]+$ || \
        ! "${expected_part_count}" =~ ^[0-9]+$ ]]; then
    echo "Invalid session manifest entry for ${session_id}." >&2
    exit 1
  fi

  source_parts="${repo_root}/.codex/session_parts/${session_id}"
  target_session="${codex_home}/${session_rel}"
  if [[ ! -d "${source_parts}" ]]; then
    echo "Session parts are missing for ${session_id}." >&2
    exit 1
  fi
  actual_part_count="$(find "${source_parts}" -maxdepth 1 -type f -name 'part-*' | wc -l)"
  if [[ "${actual_part_count}" != "${expected_part_count}" ]]; then
    echo "Session part count mismatch for ${session_id}." >&2
    exit 1
  fi

  mkdir -p "$(dirname "${target_session}")"
  assembled_session="$(mktemp "${codex_home}/rollout.XXXXXX")"
  for part in "${source_parts}"/part-*; do
    cat "${part}" >> "${assembled_session}"
  done
  actual_sha256="$(sha256sum "${assembled_session}" | awk '{print $1}')"
  actual_size="$(stat -c '%s' "${assembled_session}")"
  if [[ "${actual_sha256}" != "${expected_sha256}" || \
        "${actual_size}" != "${expected_size}" ]]; then
    echo "Session checksum or size mismatch for ${session_id}." >&2
    find "${assembled_session}" -delete
    exit 1
  fi

  if [[ -f "${target_session}" ]]; then
    cp -p "${target_session}" "${target_session}.backup-${timestamp}"
  fi
  install -m 600 "${assembled_session}" "${target_session}"
  find "${assembled_session}" -delete
  printf '%s\n' "${session_id}" >> "${restored_ids}"
  restored_count=$((restored_count + 1))
done < "${source_manifest}"

if [[ "${restored_count}" -eq 0 ]]; then
  echo "The session manifest contains no sessions." >&2
  exit 1
fi

if [[ -f "${target_index}" ]]; then
  cp -p "${target_index}" "${target_index}.backup-${timestamp}"
fi

index_tmp="$(mktemp "${codex_home}/session_index.XXXXXX")"
if [[ -f "${target_index}" ]]; then
  awk 'NR == FNR { ids[$0] = 1; next }
       {
         keep = 1
         for (id in ids) {
           if (index($0, "\"id\":\"" id "\"") != 0) {
             keep = 0
             break
           }
         }
         if (keep) print
       }' "${restored_ids}" "${target_index}" > "${index_tmp}"
fi
cat "${source_index}" >> "${index_tmp}"
chmod 600 "${index_tmp}"
mv "${index_tmp}" "${target_index}"

echo "Restored ${restored_count} Codex sessions into ${codex_home}."
echo "Next steps:"
echo "  1. Reopen VS Code/Codex with /home/ubuntu as the workspace."
echo "  2. Run: codex resume --all"
echo "     Confirm the restored sessions are listed, then press Ctrl-C."
echo "  3. In VS Code, run 'Developer: Reload Window' from the Command Palette"
echo "     and reopen the Codex sidebar to clear its cached conversation list."
