#!/usr/bin/env python3
"""Export user-visible messages from a Codex rollout JSONL.

The raw rollout also contains developer instructions, reasoning records, tool
payloads, and runtime state.  This exporter intentionally omits those records
so the result is suitable for a public backup repository.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


SECRET_PATTERNS = (
    re.compile(r"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}\b"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"(?i)(authorization:\s*bearer\s+)[A-Za-z0-9._~+/=-]+"),
)


def redact(text: str) -> str:
    for pattern in SECRET_PATTERNS:
        text = pattern.sub(lambda match: match.group(1) + "[REDACTED]"
                           if match.lastindex else "[REDACTED]", text)
    return text


def visible_text(content: list[dict]) -> list[str]:
    texts: list[str] = []
    for item in content:
        text = item.get("text") or item.get("input_text") or item.get(
            "output_text")
        if not text:
            continue
        # These are runtime-injected context records, not user-authored chat.
        if text.startswith("<recommended_plugins>"):
            continue
        if text.startswith("<environment_context>"):
            continue
        normalized = "\n".join(line.rstrip() for line in text.splitlines())
        texts.append(redact(normalized.strip()))
    return texts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("rollout", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    messages: list[tuple[str, str]] = []
    session_id = "unknown"
    timestamp = "unknown"
    cli_version = "unknown"

    with args.rollout.open(encoding="utf-8") as source:
        for line in source:
            record = json.loads(line)
            payload = record.get("payload", {})
            if record.get("type") == "session_meta":
                session_id = payload.get("id", payload.get("session_id",
                                                           session_id))
                timestamp = payload.get("timestamp", timestamp)
                cli_version = payload.get("cli_version", cli_version)
                continue
            if record.get("type") != "response_item":
                continue
            if payload.get("type") != "message":
                continue
            role = payload.get("role")
            if role not in {"user", "assistant"}:
                continue
            for text in visible_text(payload.get("content", [])):
                messages.append((role, text))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sections = [(
        "# Codex visible conversation: GH200 KV experiments\n\n"
        f"- Session ID: `{session_id}`\n"
        f"- Started: `{timestamp}`\n"
        f"- Codex CLI: `{cli_version}`\n"
        f"- Exported visible messages: `{len(messages)}`\n\n"
            "> Public-safe export: user and assistant messages only. Developer "
            "instructions, reasoning records, tool payloads, authentication, "
            "and runtime databases are intentionally excluded.")]
    sections.extend(f"## {index}. {role.title()}\n\n{text}"
                    for index, (role, text) in enumerate(messages, 1))
    with args.output.open("w", encoding="utf-8") as target:
        target.write("\n\n".join(sections) + "\n")


if __name__ == "__main__":
    main()
