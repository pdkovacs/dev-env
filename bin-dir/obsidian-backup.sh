#!/bin/bash
set -euo pipefail

SRC_DIR="/home/pkovacs/Documents/Obsidian Vault"
FILE="/home/pkovacs/Documents/Obsidian Vault.tar.xz"
BUCKET="obsidian-pdkovacs-github-io"
KEY="uploads/$(basename "$FILE")"
KEEP_LOCAL=false   # set true to skip cleanup after upload

command -v aws >/dev/null || { echo "aws CLI not found" >&2; exit 1; }
[ -d "$SRC_DIR" ] || { echo "Source directory not found: $SRC_DIR" >&2; exit 1; }

trap 'rm -f "$FILE"' ERR

tar -cf - -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")" | xz -9 -T0 > "$FILE"

# --- Upload with checksum, then verify against a local hash ---

LOCAL_SHA256=$(sha256sum "$FILE" | awk '{print $1}')

aws s3api put-object \
  --bucket "$BUCKET" \
  --key "$KEY" \
  --body "$FILE" \
  --checksum-algorithm SHA256 >/dev/null

REMOTE_SHA256=$(aws s3api head-object \
  --bucket "$BUCKET" \
  --key "$KEY" \
  --checksum-mode ENABLED \
  --query 'ChecksumSHA256' --output text | base64 -d | xxd -p -c 256)

if [ "$LOCAL_SHA256" != "$REMOTE_SHA256" ]; then
  echo "ERROR: SHA256 mismatch — local=$LOCAL_SHA256 remote=$REMOTE_SHA256" >&2
  exit 1
fi
echo "Verified: SHA256 matches ($LOCAL_SHA256)"

if ! $KEEP_LOCAL; then
  rm -f "$FILE"
fi