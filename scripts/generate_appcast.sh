#!/usr/bin/env bash
set -euo pipefail

APPCAST_URL_BASE="https://github.com/zheltukheen/ocrs/releases/download"

VERSION="$(cat VERSION | tr -d '\r\n')"
TAG="v${VERSION}"
ZIP="OCRS-${VERSION}.zip"
DATE_RFC2822="$(date -R)"

if [[ ! -f "$ZIP" ]]; then
  echo "Missing ${ZIP}. Build release zip first." >&2
  exit 1
fi

LENGTH="$(stat -f%z "$ZIP")"

cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>OCRS</title>
    <item>
      <title>OCRS ${VERSION}</title>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>${DATE_RFC2822}</pubDate>
      <enclosure
        url="${APPCAST_URL_BASE}/${TAG}/${ZIP}"
        length="${LENGTH}"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
EOF

echo "Generated appcast.xml for ${VERSION}"
