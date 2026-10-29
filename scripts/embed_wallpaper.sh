#!/usr/bin/env bash
# Copy a theme and replace its wallpaper with a PNG data URI.
# Usage: scripts/embed_wallpaper.sh <source.theme> <wallpaper.png> <output.theme>
set -euo pipefail

if (($# != 3)); then
    printf 'Usage: %s <source.theme> <wallpaper.png> <output.theme>\n' "${0##*/}" >&2
    exit 2
fi

theme_file=$1
wallpaper_file=$2
output_file=$3

if [[ ! -f $theme_file ]]; then
    printf 'Error: theme file not found: %s\n' "$theme_file" >&2
    exit 1
fi
if [[ ! -f $wallpaper_file ]]; then
    printf 'Error: wallpaper image not found: %s\n' "$wallpaper_file" >&2
    exit 1
fi
if [[ -e $output_file ]]; then
    printf 'Error: refusing to overwrite existing file: %s\n' "$output_file" >&2
    exit 1
fi
if [[ $(file --brief --mime-type "$wallpaper_file") != image/png ]]; then
    printf 'Error: wallpaper must be a PNG image: %s\n' "$wallpaper_file" >&2
    exit 1
fi

image_size=$(stat -c %s -- "$wallpaper_file")
if ((image_size > 5000000)); then
    printf 'Error: PNG exceeds SimpleX wallpaper limit (5 MB): %s\n' "$wallpaper_file" >&2
    exit 1
fi

background=$(awk '
    /^wallpaper:[[:space:]]*$/ { in_wallpaper = 1; next }
    in_wallpaper && /^[^[:space:]]/ { exit }
    in_wallpaper && /^[[:space:]]+background:[[:space:]]*"/ {
        line = $0
        sub(/^[[:space:]]+background:[[:space:]]*"/, "", line)
        sub(/".*$/, "", line)
        print line
        exit
    }
' "$theme_file")
background=${background:-'#ff101820'}
tint=$(awk '
    /^wallpaper:[[:space:]]*$/ { in_wallpaper = 1; next }
    in_wallpaper && /^[^[:space:]]/ { exit }
    in_wallpaper && /^[[:space:]]+tint:[[:space:]]*"/ {
        line = $0
        sub(/^[[:space:]]+tint:[[:space:]]*"/, "", line)
        sub(/".*$/, "", line)
        print line
        exit
    }
' "$theme_file")
tint=${tint:-'#00ffffff'}

output_dir=${output_file%/*}
if [[ $output_dir == "$output_file" ]]; then
    output_dir=.
fi
mkdir -p -- "$output_dir"
tmp_uri=$(mktemp)
tmp_theme=$(mktemp "$output_file.tmp.XXXXXX")
trap 'rm -f -- "$tmp_uri" "$tmp_theme"' EXIT
printf 'data:image/png;base64,%s' "$(base64 --wrap=0 <"$wallpaper_file")" >"$tmp_uri"

awk -v uri_file="$tmp_uri" -v background="$background" -v tint="$tint" '
    BEGIN {
        getline image_uri < uri_file
        close(uri_file)
    }
    function write_wallpaper() {
        print "wallpaper:"
        print "  scale: 0.7"
        print "  scaleType: \"repeat\""
        print "  background: \"" background "\""
        print "  tint: \"" tint "\""
        print "  image: \"" image_uri "\""
        inserted = 1
    }
    /^wallpaper:[[:space:]]*$/ {
        write_wallpaper()
        skipping_wallpaper = 1
        next
    }
    skipping_wallpaper && /^[^[:space:]]/ { skipping_wallpaper = 0 }
    skipping_wallpaper { next }
    { print }
    END { if (!inserted) write_wallpaper() }
' "$theme_file" >"$tmp_theme"
mv -- "$tmp_theme" "$output_file"
trap - EXIT
rm -f -- "$tmp_uri"
printf 'Wrote %s with embedded wallpaper PNG (%s bytes).\n' "$output_file" "$image_size"
