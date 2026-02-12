#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
shift || true

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [release note line...]" >&2
  exit 1
fi

NOTES=("$@")
if [[ "${#NOTES[@]}" -eq 0 && -n "${RELEASE_NOTES:-}" ]]; then
  IFS=$'\n' read -r -d '' -a NOTES <<< "${RELEASE_NOTES}" || true
fi

if [[ "${#NOTES[@]}" -eq 0 ]]; then
  NOTES=("Release ${VERSION}.")
fi

DATE="$(date +%Y-%m-%d)"
BUILD="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}"

echo "${VERSION}" > VERSION
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" -c "Set :CFBundleVersion ${BUILD}" "OCRS-Info.plist"

if [[ ! -f CHANGELOG.md ]]; then
  echo "# Changelog" > CHANGELOG.md
  echo "" >> CHANGELOG.md
fi

TMP="$(mktemp)"
{
  head -n 1 CHANGELOG.md
  echo ""
  echo "## ${VERSION} - ${DATE}"
  for line in "${NOTES[@]}"; do
    echo "- ${line}"
  done
  echo ""
  tail -n +2 CHANGELOG.md
} > "${TMP}"
mv "${TMP}" CHANGELOG.md

echo "Bumped version to ${VERSION} (build ${BUILD})."
