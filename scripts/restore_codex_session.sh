#!/usr/bin/env bash
set -euo pipefail

session_id="01a032b1-ad6d-7bc2-a677-1004af67a370"
session_rel="sessions/2026/08/24/rollout-2026-08-24T07-35-00-${session_id}.jsonl"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
codex_home="${CODEX_HOME:-${HOME}/.codex}"
source_parts="${repo_root}/.codex/session_parts/${session_id}"
source_index="${repo_root}/.codex/session_index.jsonl"
target_session="${codex_home}/${session_rel}"
target_index="${codex_home}/session_index.jsonl"
expected_sha256="d220904cd57a776861e63b5084a242011774cd27e6f6f389e6bea05b6cda6254"

if [[ ! -d "${source_parts}" || ! -f "${source_index}" ]]; then
  echo "Backup files are missing." >&2
  exit 1
fi

mkdir -p "$(dirname "${target_session}")" "${codex_home}"

assembled_session="$(mktemp "${codex_home}/rollout.XXXXXX")"
for part in "${source_parts}"/part-*; do
  cat "${part}" >> "${assembled_session}"
done
actual_sha256="$(sha256sum "${assembled_session}" | awk '{print $1}')"
if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
  echo "Session checksum mismatch." >&2
  rm -f "${assembled_session}"
  exit 1
fi

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -f "${target_session}" ]]; then
  cp -p "${target_session}" "${target_session}.backup-${timestamp}"
fi
if [[ -f "${target_index}" ]]; then
  cp -p "${target_index}" "${target_index}.backup-${timestamp}"
fi

install -m 600 "${assembled_session}" "${target_session}"
rm -f "${assembled_session}"

index_tmp="$(mktemp "${codex_home}/session_index.XXXXXX")"
if [[ -f "${target_index}" ]]; then
  awk -v id="${session_id}" 'index($0, "\"id\":\"" id "\"") == 0' \
    "${target_index}" > "${index_tmp}"
fi
cat "${source_index}" >> "${index_tmp}"
chmod 600 "${index_tmp}"
mv "${index_tmp}" "${target_index}"

echo "Restored Codex session ${session_id} into ${codex_home}."
echo "Reopen VS Code/Codex. If needed, run: codex resume --all ${session_id}"
