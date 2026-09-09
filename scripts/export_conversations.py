#!/usr/bin/env python3
"""Export the conversational content of Claude Code transcripts as Markdown.

Transcripts are ~97% tool output, bookkeeping records and thinking signatures.
This keeps only what a human would want to reread years later: the user and
assistant prose. The result is not resumable by Claude Code -- it is a record,
not a restorable session.
"""

import hashlib
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

SRC = Path(os.path.expanduser("~/.claude/projects"))
DST = Path(os.path.expanduser("~/claude-conversations"))


def read_records(path):
    """Yield (record, message) pairs for conversational records only."""
    with open(path, errors="replace") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                continue
            yield obj


def text_blocks(message):
    """Plain-text blocks of a message; tool_use/tool_result/thinking dropped."""
    content = message.get("content")
    if isinstance(content, str):
        return [content]
    if not isinstance(content, list):
        return []
    return [
        b.get("text", "")
        for b in content
        if isinstance(b, dict) and b.get("type") == "text"
    ]


def scan(path):
    """Collect the conversation and the metadata needed to name the file."""
    turns, title, cwd, stamps = [], None, None, []
    for obj in read_records(path):
        if obj.get("type") == "ai-title" and obj.get("aiTitle"):
            title = obj["aiTitle"]
            continue
        if obj.get("cwd") and not cwd:
            cwd = obj["cwd"]
        if obj.get("type") not in ("user", "assistant"):
            continue
        message = obj.get("message")
        if not isinstance(message, dict):
            continue
        parts = [t for t in text_blocks(message) if t.strip()]
        if not parts:
            continue
        ts = obj.get("timestamp") or ""
        if ts:
            stamps.append(ts)
        turns.append((message.get("role", "?"), ts, "\n\n".join(parts)))
    return turns, title, cwd, stamps


def slugify(text, limit=60):
    slug = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return slug[:limit].rstrip("-")


def render(turns, title, cwd, session_id, stamps):
    head = [f"# {title or 'Untitled conversation'}", ""]
    head.append(f"- Session: `{session_id}`")
    if cwd:
        head.append(f"- Project: `{cwd}`")
    if stamps:
        head.append(f"- Dates: {stamps[0][:10]} .. {stamps[-1][:10]}")
    head.append("")
    body = []
    for role, ts, text in turns:
        heading = role.capitalize() + (f" — {ts}" if ts else "")
        body.append(f"## {heading}\n\n{text}\n")
    return "\n".join(head) + "\n---\n\n" + "\n---\n\n".join(body)


def project_dir_names(sessions):
    """Readable per-project directory names, disambiguated on collision."""
    by_base = defaultdict(set)
    for _, _, cwd, _, _, _ in sessions:
        if cwd:
            by_base[os.path.basename(cwd)].add(cwd)
    names = {}
    for base, cwds in by_base.items():
        for cwd in cwds:
            if len(cwds) == 1:
                names[cwd] = base
            else:
                digest = hashlib.sha1(cwd.encode()).hexdigest()[:6]
                names[cwd] = f"{base}-{digest}"
    return names


def main():
    if not SRC.is_dir():
        print(f"No transcripts at {SRC}", file=sys.stderr)
        return 0

    sessions = []
    for path in sorted(SRC.glob("**/*.jsonl")):
        turns, title, cwd, stamps = scan(path)
        if not turns:
            continue
        sessions.append((path, path.stem, cwd, title, turns, stamps))

    names = project_dir_names(sessions)
    written = skipped = 0

    for path, session_id, cwd, title, turns, stamps in sessions:
        folder = DST / (names.get(cwd) or path.parent.name)
        folder.mkdir(parents=True, exist_ok=True)

        short = session_id[:8]
        date = stamps[0][:10] if stamps else "undated"
        parts = [date, slugify(title)] if title else [date]
        out = folder / ("-".join(p for p in parts if p) + f"-{short}.md")

        # A retitled session would otherwise leave its old file behind.
        for stale in folder.glob(f"*-{short}.md"):
            if stale != out:
                stale.unlink()

        if out.exists() and out.stat().st_mtime >= path.stat().st_mtime:
            skipped += 1
            continue

        out.write_text(render(turns, title, cwd, session_id, stamps))
        written += 1

    print(f"Conversations: {written} written, {skipped} up to date, in {DST}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
