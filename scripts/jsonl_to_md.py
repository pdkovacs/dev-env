import json
import sys
from pathlib import Path

# Record types that carry conversation content; everything else in a Claude Code
# transcript (bridge-session, queue-operation, attachment, file-history-snapshot,
# ai-title, atis-latch, last-prompt, mode, ...) is bookkeeping.
MESSAGE_TYPES = {"user", "assistant", "system"}


def render_block(block):
    """Render one content block of an Anthropic message."""
    if isinstance(block, str):
        return block
    if not isinstance(block, dict):
        return json.dumps(block, indent=2, ensure_ascii=False)

    btype = block.get("type")

    if btype == "text":
        return block.get("text", "")

    if btype == "thinking":
        thought = block.get("thinking", "")
        return "> **Thinking**\n" + "\n".join(
            f"> {line}" for line in thought.splitlines()
        )

    if btype == "tool_use":
        args = json.dumps(block.get("input", {}), indent=2, ensure_ascii=False)
        return (
            f"**Tool use: `{block.get('name', '?')}`**\n\n"
            f"```json\n{args}\n```"
        )

    if btype == "tool_result":
        content = block.get("content", "")
        if isinstance(content, list):
            content = "\n".join(render_block(b) for b in content)
        elif not isinstance(content, str):
            content = json.dumps(content, indent=2, ensure_ascii=False)
        label = "Tool result (error)" if block.get("is_error") else "Tool result"
        return f"**{label}**\n\n```\n{content}\n```"

    if btype == "image":
        return "_[image omitted]_"

    # Unknown block type: dump it rather than silently dropping it.
    return f"```json\n{json.dumps(block, indent=2, ensure_ascii=False)}\n```"


def render_content(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = [render_block(b) for b in content]
        return "\n\n".join(p for p in parts if p.strip())
    if content is None:
        return ""
    return json.dumps(content, indent=2, ensure_ascii=False)


def jsonl_to_md(input_path: str, output_path: str = None):
    input_file = Path(input_path)
    output_file = Path(output_path) if output_path else input_file.with_suffix(".md")

    sections = []
    with open(input_file) as f:
        for lineno, raw in enumerate(f, 1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                sections.append(f"## Unparseable line {lineno}\n\n```\n{raw}\n```\n")
                continue

            if obj.get("type") not in MESSAGE_TYPES:
                continue

            # Claude Code nests the Anthropic message under "message";
            # some records (e.g. compact summaries) put content at top level.
            message = obj.get("message")
            if isinstance(message, dict):
                role = message.get("role") or obj.get("type") or "unknown"
                content = message.get("content", "")
            else:
                role = obj.get("type", "unknown")
                content = obj.get("content", "")

            body = render_content(content)
            if not body.strip():
                continue

            heading = role.capitalize()
            if obj.get("isSidechain"):
                heading += " (subagent)"
            ts = obj.get("timestamp")
            if ts:
                heading += f" — {ts}"

            sections.append(f"## {heading}\n\n{body}\n")

    output_file.write_text("\n---\n\n".join(sections))
    print(f"Written to {output_file} ({len(sections)} messages)")


if __name__ == "__main__":
    jsonl_to_md(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
