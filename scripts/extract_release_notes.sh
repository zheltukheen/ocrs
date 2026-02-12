#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

awk -v ver="$VERSION" '
  $0 ~ "^## "ver" " { found=1; next }
  found && $0 ~ "^## " { exit }
  found { print }
' CHANGELOG.md
