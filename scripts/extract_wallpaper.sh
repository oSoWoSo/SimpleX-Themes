#!/usr/bin/env bash
# Extract a theme's embedded wallpaper image.
# Usage: scripts/extract_wallpaper.sh <theme.theme> [output-image]
set -euo pipefail

if (($# < 1 || $# > 2)); then
    printf 'Usage: %s <theme.theme> [output-image]\n' "${0##*/}" >&2
    exit 2
fi

theme_file=$1
if [[ ! -f $theme_file ]]; then
    printf 'Error: theme file not found: %s\n' "$theme_file" >&2
    exit 1
fi

image_uri=$(awk '
    /^wallpaper:[[:space:]]*$/ { in_wallpaper = 1; next }
    in_wallpaper && /^[^[:space:]]/ { exit }
    in_wallpaper && /^[[:space:]]+image:[[:space:]]*"/ {
        line = $0
        sub(/^[[:space:]]+image:[[:space:]]*"/, "", line)
        sub(/"[[:space:]]*$/, "", line)
        print line
        exit
    }
' "$theme_file")

case $image_uri in
    data:image/png\;base64,*)
        mime_type=image/png
        extension=png
        payload=${image_uri#data:image/png\;base64,}
        ;;
    data:image/jpg\;base64,*)
        mime_type=image/jpeg
        extension=jpg
        payload=${image_uri#data:image/jpg\;base64,}
        ;;
    *)
        printf 'Error: theme has no supported embedded PNG/JPG wallpaper: %s\n' "$theme_file" >&2
        exit 1
        ;;
esac

if (($# == 2)); then
    output_file=$2
else
    theme_name=${theme_file##*/}
    theme_name=${theme_name%.theme}
    output_file="wallpapers/${theme_name}-wallpaper.${extension}"
fi
if [[ -e $output_file ]]; then
    printf 'Error: refusing to overwrite existing file: %s\n' "$output_file" >&2
    exit 1
fi

output_dir=${output_file%/*}
if [[ $output_dir == "$output_file" ]]; then
    output_dir=.
fi
mkdir -p -- "$output_dir"
tmp_image=$(mktemp "$output_file.tmp.XXXXXX")
trap 'rm -f -- "$tmp_image"' EXIT
printf '%s' "$payload" | base64 --decode > "$tmp_image"
if [[ $(file --brief --mime-type "$tmp_image") != "$mime_type" ]]; then
    printf 'Error: decoded wallpaper does not match its declared MIME type.\n' >&2
    exit 1
fi
mv -- "$tmp_image" "$output_file"
trap - EXIT
printf 'Extracted wallpaper to %s.\n' "$output_file"
