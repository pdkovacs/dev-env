#!/bin/bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
FILE="/tmp/claude-backup.tar.xz"
BUCKET="claude-pdkovacs-github-io"
KEY="uploads/claude-backup.tar.xz"
KEEP_LOCAL=false

MODE="${1:-backup}"
FORCE=false
for arg in "${@:2}"; do
  [[ "$arg" == "--force" ]] && FORCE=true
done

command -v aws >/dev/null || { echo "aws CLI not found" >&2; exit 1; }
[ -d "$CLAUDE_DIR" ] || { echo "Claude directory not found: $CLAUDE_DIR" >&2; exit 1; }

build_file_list() {
  local list_file="$1"
  {
    [ -f "$CLAUDE_DIR/CLAUDE.md" ] && echo ".claude/CLAUDE.md" || true
    [ -f "$CLAUDE_DIR/settings.json" ] && echo ".claude/settings.json" || true
    find "$CLAUDE_DIR/projects" -path "*/memory/*" -type f 2>/dev/null \
      | sed "s|^$HOME/||" \
      || true
  } | sort > "$list_file"
}

checksum_verify() {
  local file="$1" bucket="$2" key="$3"
  local local_sha remote_sha
  local_sha=$(sha256sum "$file" | awk '{print $1}')
  remote_sha=$(aws s3api head-object \
    --bucket "$bucket" --key "$key" \
    --checksum-mode ENABLED \
    --query 'ChecksumSHA256' --output text | base64 -d | xxd -p -c 256)
  if [ "$local_sha" != "$remote_sha" ]; then
    echo "ERROR: SHA256 mismatch — local=$local_sha remote=$remote_sha" >&2
    return 1
  fi
  echo "Verified: SHA256 matches ($local_sha)"
}

LIST=$(mktemp)
trap 'rm -f "$LIST" "$FILE"' EXIT

if [[ "$MODE" == "backup" ]]; then
  build_file_list "$LIST"
  echo "Backing up $(wc -l < "$LIST") files..."

  tar -cf - -C "$HOME" -T "$LIST" | xz -9 -T0 > "$FILE"

  aws s3api put-object \
    --bucket "$BUCKET" \
    --key "$KEY" \
    --body "$FILE" \
    --checksum-algorithm SHA256 >/dev/null \
    || { echo "ERROR: upload to s3://$BUCKET/$KEY failed (bucket exists?)" >&2; exit 1; }

  checksum_verify "$FILE" "$BUCKET" "$KEY"

  $KEEP_LOCAL || { rm -f "$FILE"; }

elif [[ "$MODE" == "restore" ]]; then
  S3_MODIFIED=$(aws s3api head-object \
    --bucket "$BUCKET" --key "$KEY" \
    --query 'LastModified' --output text 2>&1) || {
    echo "ERROR: Could not reach s3://$BUCKET/$KEY — $S3_MODIFIED" >&2
    exit 1
  }
  S3_EPOCH=$(date -d "$S3_MODIFIED" +%s)

  build_file_list "$LIST"

  NEWER=()
  while IFS= read -r rel_path; do
    abs_path="$HOME/$rel_path"
    if [ -f "$abs_path" ]; then
      local_epoch=$(stat -c %Y "$abs_path")
      if (( local_epoch > S3_EPOCH )); then
        NEWER+=("$rel_path  (local: $(date -d "@$local_epoch" '+%Y-%m-%d %H:%M:%S'))")
      fi
    fi
  done < "$LIST"

  if (( ${#NEWER[@]} > 0 )) && ! $FORCE; then
    echo "ERROR: Local files are newer than the backup ($(date -d "@$S3_EPOCH" '+%Y-%m-%d %H:%M:%S')):" >&2
    printf '  %s\n' "${NEWER[@]}" >&2
    echo "Use --force to overwrite." >&2
    exit 1
  fi

  echo "Downloading from s3://$BUCKET/$KEY (backup: $(date -d "@$S3_EPOCH" '+%Y-%m-%d %H:%M:%S'))..."
  aws s3api get-object --bucket "$BUCKET" --key "$KEY" "$FILE" >/dev/null

  checksum_verify "$FILE" "$BUCKET" "$KEY"

  echo "Extracting to $HOME..."
  tar -xJf "$FILE" -C "$HOME"
  echo "Done."

  $KEEP_LOCAL || { rm -f "$FILE"; }

else
  echo "Usage: $(basename "$0") [backup|restore [--force]]" >&2
  exit 1
fi
