#!/usr/bin/env bash
# update-index.sh — Updates docs/learnings/index.md with new learning entries
# Usage: ./update-index.sh <learning_file> <project_root>
set -euo pipefail

LEARNING_FILE="${1:-}"
PROJECT_ROOT="${2:-$(pwd)}"
INDEX_FILE="${PROJECT_ROOT}/docs/learnings/index.md"

if [[ -z "$LEARNING_FILE" || ! -f "$LEARNING_FILE" ]]; then
  echo "Usage: $0 <learning_file> [project_root]" >&2
  exit 1
fi

# Extract frontmatter fields using awk
extract_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    /^---$/ { front++; next }
    front == 1 && $0 ~ "^" field ":" {
      sub("^" field ":[[:space:]]*", "")
      print
      exit
    }
    front >= 2 { exit }
  ' "$file"
}

TITLE=$(extract_field "$LEARNING_FILE" "title")
TAGS=$(extract_field "$LEARNING_FILE" "tags")
DATE=$(extract_field "$LEARNING_FILE" "date")
FILENAME=$(basename "$LEARNING_FILE")

if [[ -z "$TITLE" ]]; then
  TITLE="$FILENAME"
fi
if [[ -z "$DATE" ]]; then
  DATE=$(date +%Y-%m-%d)
fi

# Ensure index directory exists
mkdir -p "$(dirname "$INDEX_FILE")"

# Create index.md if it doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
  cat > "$INDEX_FILE" <<'EOF'
# Learnings Index

| Date | Title | Tags | File |
|------|-------|------|------|
EOF
fi

# Check if entry already exists (by filename)
if grep -qF "$FILENAME" "$INDEX_FILE" 2>/dev/null; then
  # Already indexed, skip
  exit 0
fi

# Append new entry atomically
TMPFILE="${INDEX_FILE}.tmp.$$"
cp "$INDEX_FILE" "$TMPFILE"
printf '| %s | %s | %s | [%s](%s) |\n' "$DATE" "$TITLE" "$TAGS" "$FILENAME" "$FILENAME" >> "$TMPFILE"
mv "$TMPFILE" "$INDEX_FILE"

echo "Indexed: $FILENAME"
