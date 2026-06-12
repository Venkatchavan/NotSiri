#!/bin/bash
# generate_icons.sh – AgentOS
# Drop your 1024x1024 source icon as "source_icon.png" in the project root, then run:
#   bash generate_icons.sh
# Requires: sips (built into macOS – no extra installs needed)

SRC="source_icon.png"
DEST="AgenticOS/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SRC" ]; then
  echo "Error: source_icon.png not found. Save your icon as source_icon.png next to this script."
  exit 1
fi

mkdir -p "$DEST"

generate() {
  local SIZE=$1
  local NAME=$2
  sips -z "$SIZE" "$SIZE" "$SRC" --out "$DEST/$NAME" > /dev/null 2>&1
  echo "  ✓ ${SIZE}x${SIZE}  →  $NAME"
}

echo "Generating AppIcon sizes from $SRC..."
generate 16    "AppIcon_16x16.png"
generate 32    "AppIcon_16x16@2x.png"
generate 32    "AppIcon_32x32.png"
generate 64    "AppIcon_32x32@2x.png"
generate 128   "AppIcon_128x128.png"
generate 256   "AppIcon_128x128@2x.png"
generate 256   "AppIcon_256x256.png"
generate 512   "AppIcon_256x256@2x.png"
generate 512   "AppIcon_512x512.png"
generate 1024  "AppIcon_512x512@2x.png"
generate 1024  "AppIcon_1024.png"

echo ""
echo "All sizes generated in $DEST"
echo "Open Xcode → AgenticOS target → Assets.xcassets → AppIcon to verify."
