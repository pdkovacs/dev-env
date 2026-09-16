#!/bin/bash
set -euo pipefail

SRC_DIR="/home/pkovacs/Documents/Obsidian Vault"
FILE="/home/pkovacs/Documents/Obsidian Vault.tar.xz"
BUCKET="obsidian-pdkovacs-github-io"
KEY="uploads/$(basename "$FILE")"
KEEP_LOCAL=false   # set true to skip cleanup after upload/download

MODE="${1:-backup}"
FORCE=false
for arg in "${@:2}"; do
  [[ "$arg" == "--force" ]] && FORCE=true
done

command -v aws >/dev/null || { echo "aws CLI not found" >&2; exit 1; }

trap 'rm -f "$FILE"' ERR

checksum_verify() {
  local local_sha remote_sha
  local_sha=$(sha256sum "$FILE" | awk '{print $1}')
  remote_sha=$(aws s3api head-object \
    --bucket "$BUCKET" --key "$KEY" \
    --checksum-mode ENABLED \
    --query 'ChecksumSHA256' --output text | base64 -d | xxd -p -c 256)
  if [ "$local_sha" != "$remote_sha" ]; then
    echo "ERROR: SHA256 mismatch — local=$local_sha remote=$remote_sha" >&2
    return 1
  fi
  echo "Verified: SHA256 matches ($local_sha)"
}

if [[ "$MODE" == "backup" ]]; then
  [ -d "$SRC_DIR" ] || { echo "Source directory not found: $SRC_DIR" >&2; exit 1; }

  tar -cf - -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" | xz -9 -T0 > "$FILE"

  aws s3api put-object \
    --bucket "$BUCKET" \
    --key "$KEY" \
    --body "$FILE" \
    --checksum-algorithm SHA256 >/dev/null

  checksum_verify

  $KEEP_LOCAL || rm -f "$FILE"

elif [[ "$MODE" == "restore" ]]; then
  S3_MODIFIED=$(aws s3api head-object \
    --bucket "$BUCKET" --key "$KEY" \
    --query 'LastModified' --output text 2>&1) || {
    echo "ERROR: Could not reach s3://$BUCKET/$KEY — $S3_MODIFIED" >&2
    exit 1
  }
  S3_EPOCH=$(date -d "$S3_MODIFIED" +%s)

  if [ -d "$SRC_DIR" ]; then
    NEWER=()
    while IFS= read -r -d '' f; do
      local_epoch=$(stat -c %Y "$f")
      if (( local_epoch > S3_EPOCH )); then
        NEWER+=("$f  (local: $(date -d "@$local_epoch" '+%Y-%m-%d %H:%M:%S'))")
      fi
    done < <(find "$SRC_DIR" -type f -print0)

    if (( ${#NEWER[@]} > 0 )) && ! $FORCE; then
      echo "ERROR: Local files are newer than the backup ($(date -d "@$S3_EPOCH" '+%Y-%m-%d %H:%M:%S')):" >&2
      printf '  %s\n' "${NEWER[@]}" >&2
      echo "Use --force to overwrite." >&2
      exit 1
    fi
  fi

  echo "Downloading from s3://$BUCKET/$KEY (backup: $(date -d "@$S3_EPOCH" '+%Y-%m-%d %H:%M:%S'))..."
  aws s3api get-object --bucket "$BUCKET" --key "$KEY" "$FILE" >/dev/null

  checksum_verify

  echo "Extracting to $(dirname "$SRC_DIR")..."
  tar -xJf "$FILE" -C "$(dirname "$SRC_DIR")"
  echo "Done."

  $KEEP_LOCAL || rm -f "$FILE"

else
  echo "Usage: $(basename "$0") [backup|restore [--force]]" >&2
  exit 1
fi
