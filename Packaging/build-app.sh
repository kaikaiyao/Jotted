#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
derived_dir="$project_dir/.build/xcode-derived"
output_dir="$project_dir/dist"
app_source="$derived_dir/Build/Products/Release/Jotted.app"
app_output="$output_dir/Jotted.app"

cd "$project_dir"

xcodegen generate

xcodebuild \
  -project Jotted.xcodeproj \
  -scheme Jotted \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$derived_dir" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$output_dir"
if [[ "$app_output" != "$output_dir/Jotted.app" ]]; then
  print -u2 "Unexpected app output path: $app_output"
  exit 2
fi
rm -rf "$app_output"
ditto "$app_source" "$app_output"

codesign \
  --force \
  --sign - \
  --timestamp=none \
  "$app_output"

codesign --verify --deep --strict --verbose=2 "$app_output"
plutil -lint "$app_output/Contents/Info.plist"

rm -f "$output_dir/Jotted-macOS.zip"
(
  cd "$output_dir"
  /usr/bin/zip -qry -X "Jotted-macOS.zip" "Jotted.app"
)

print "$app_output"
