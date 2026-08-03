#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
assets_dir="$project_dir/docs/assets/readme"
srgb_profile="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
# Keep README captures aligned with GlassTransparencyPreference.defaultValue.
readme_transparency="0.5"

print "Building the app once for README snapshots…"
app_path="$("$project_dir/Packaging/build-app.sh" | tee /dev/stderr | tail -n 1)"

if [[ ! -d "$app_path" ]]; then
    print -u2 "Could not find the built app at: $app_path"
    exit 2
fi

info_plist="$app_path/Contents/Info.plist"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$info_plist")"
binary="$app_path/Contents/MacOS/$executable_name"

if [[ ! -x "$binary" ]]; then
    print -u2 "Could not find the app executable at: $binary"
    exit 2
fi

if [[ ! -f "$srgb_profile" ]]; then
    print -u2 "Could not find the system sRGB profile at: $srgb_profile"
    exit 2
fi

locales=(en zh-Hans zh-Hant ja ko fr es de)

capture_snapshot() {
    local locale="$1"
    local theme="$2"
    local flag="$3"
    local output="$4"

    "$binary" \
        "$flag" "$output" \
        -JottedAppLanguage "$locale" \
        -JottedAppearanceTheme "$theme" \
        -JottedGlassTransparency "$readme_transparency"

    if [[ ! -s "$output" ]]; then
        print -u2 "Snapshot was not created: $output"
        exit 3
    fi

    # Convert the display-dependent P3 capture to a portable web profile.
    sips --matchTo "$srgb_profile" "$output" --out "$output" >/dev/null
}

for locale in $locales; do
    theme="graphite"
    appearance="light"
    output_dir="$assets_dir/$locale"
    mkdir -p "$output_dir"

    print "Capturing $locale · $theme · $appearance…"
    capture_snapshot \
        "$locale" "$theme" "--snapshot-$appearance" \
        "$output_dir/board-graphite.png"
    capture_snapshot \
        "$locale" "$theme" "--snapshot-condensed-$appearance" \
        "$output_dir/compact-graphite.png"
    capture_snapshot \
        "$locale" "$theme" "--snapshot-theme-gallery" \
        "$output_dir/themes.png"
done

print "Created 24 localized README snapshots in: $assets_dir"
