#!/bin/bash
# Usage: ./Scripts/create_release.sh <version>
# Example: ./Scripts/create_release.sh 1.0.0-beta.2
set -e

VERSION="${1:?Usage: $0 <version>}"
SPARKLE_BIN="$(find ~/Library/Developer/Xcode/DerivedData/Maurice-*/SourcePackages/artifacts/sparkle/Sparkle/bin -maxdepth 0 2>/dev/null | head -1)"

if [ -z "$SPARKLE_BIN" ]; then
    echo "Error: Sparkle tools not found. Build the project in Xcode first."
    exit 1
fi

echo "==> Building Release..."
xcodebuild -project Maurice.xcodeproj -scheme Maurice -configuration Release \
    -destination "platform=macOS" -derivedDataPath build clean build 2>&1 | tail -3

APP_PATH="build/Build/Products/Release/Maurice.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Maurice.app not found at $APP_PATH"
    exit 1
fi

ZIP_NAME="Maurice-${VERSION}.zip"
ZIP_PATH="/tmp/${ZIP_NAME}"

echo "==> Creating zip..."
cd build/Build/Products/Release
zip -r "$ZIP_PATH" Maurice.app
cd - > /dev/null

echo "==> Signing with Sparkle..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" "$ZIP_PATH")
echo "$SIGNATURE"

# Extract edSignature and length
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(stat -f%z "$ZIP_PATH")

echo "==> Updating appcast.xml..."
DOWNLOAD_URL="https://github.com/MaximeChaillou/Maurice/releases/download/v${VERSION}/${ZIP_NAME}"
PUB_DATE=$(date -R)

# Build the new item XML
ITEM="        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure
                url=\"${DOWNLOAD_URL}\"
                sparkle:edSignature=\"${ED_SIGNATURE}\"
                length=\"${LENGTH}\"
                type=\"application/octet-stream\"
            />
        </item>"

# Insert before </channel>
sed -i '' "s|    </channel>|${ITEM}\n    </channel>|" appcast.xml

echo "==> Creating GitHub release..."
gh release create "v${VERSION}" "$ZIP_PATH" \
    --repo MaximeChaillou/Maurice \
    --title "v${VERSION}" \
    --prerelease

echo "==> Done! Don't forget to commit and push appcast.xml"
echo ""
echo "    git add appcast.xml && git commit -m 'Update appcast for v${VERSION}' && git push"
