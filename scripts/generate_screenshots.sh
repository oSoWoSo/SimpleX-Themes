#!/usr/bin/env bash
# Generate four preview images from SVG templates with theme colors applied.
# Usage: scripts/generate_screenshots.sh <theme.theme> [output-directory]
set -euo pipefail

usage() {
    printf 'Usage: %s <theme.theme> [output-directory]\n' "${0##*/}" >&2
}

if (($# < 1 || $# > 2)); then
    usage
    exit 2
fi

theme_file=$1
if [[ ! -f $theme_file ]]; then
    printf 'Error: theme file not found: %s\n' "$theme_file" >&2
    exit 1
fi

filename=${theme_file##*/}
if [[ $filename != *.theme ]]; then
    printf 'Error: theme filename must end with .theme: %s\n' "$filename" >&2
    exit 2
fi
theme_name=${filename#SxC_}
theme_name=${theme_name%.theme}

output_dir=${2:-}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

if [[ -z $output_dir ]]; then
    output_dir="$repo_root/screenshots"
fi

if ! command -v inkscape > /dev/null 2>&1; then
    printf 'Error: inkscape is required.\n' >&2
    exit 1
fi

if ! command -v magick > /dev/null 2>&1 && ! command -v convert > /dev/null 2>&1; then
    printf 'Error: ImageMagick is required.\n' >&2
    exit 1
fi
if command -v magick > /dev/null 2>&1; then
    image_command=magick
else
    image_command=convert
fi

mkdir -p -- "$output_dir"

# Check if theme has embedded wallpaper
has_wallpaper=false
if awk '
    /^wallpaper:[[:space:]]*$/ { in_wallpaper = 1; next }
    in_wallpaper && /^[^[:space:]]/ { exit }
    in_wallpaper && $1 == "image:" && $2 ~ /^"data:image\/(png|jpg);base64,/ {
        found = 1
        exit
    }
    END { if (!found) exit 1 }
' "$theme_file"; then
    has_wallpaper=true
fi

# Prepare wallpaper if present
wallpaper_prepared=""
if [[ $has_wallpaper == true ]]; then
    tmp_wp_dir=$(mktemp -d)
    tmp_wp="$tmp_wp_dir/wallpaper_raw.png"
    "$script_dir/extract_wallpaper.sh" "$theme_file" "$tmp_wp" 2>/dev/null

    wp_scale_type=$(awk -v key="scaleType" '
        /^wallpaper:[[:space:]]*$/ { in_wp = 1; next }
        in_wp && /^[^[:space:]]/ { exit }
        in_wp && $1 == key { gsub(/"/, "", $2); print $2; exit }
    ' "$theme_file")
    wp_scale_type=${wp_scale_type:-fill}

    wp_background=$(awk -v key="background" '
        /^wallpaper:[[:space:]]*$/ { in_wp = 1; next }
        in_wp && /^[^[:space:]]/ { exit }
        in_wp && $1 == key { gsub(/"/, "", $2); print $2; exit }
    ' "$theme_file")
    wp_background=${wp_background:-'#ff101820'}
    if [[ $wp_background =~ ^#[[:xdigit:]]{8}$ ]]; then
        wp_background="#${wp_background:3}"
    fi

    wp_tint=$(awk -v key="tint" '
        /^wallpaper:[[:space:]]*$/ { in_wp = 1; next }
        in_wp && /^[^[:space:]]/ { exit }
        in_wp && $1 == key { gsub(/"/, "", $2); print $2; exit }
    ' "$theme_file")
    tint_color=
    tint_percent=0
    if [[ $wp_tint =~ ^#([[:xdigit:]]{2})([[:xdigit:]]{6})$ ]]; then
        tint_color="#${BASH_REMATCH[2]}"
        tint_percent=$((16#${BASH_REMATCH[1]} * 100 / 255))
    elif [[ $wp_tint =~ ^#[[:xdigit:]]{6}$ ]]; then
        tint_color=$wp_tint
        tint_percent=100
    fi

    args_wp=("$tmp_wp")
    if ((tint_percent > 0)); then
        args_wp+=(-fill "$tint_color" -colorize "${tint_percent}%")
    fi

    if [[ $wp_scale_type == repeat ]]; then
        args_wp+=(-write mpr:tile +delete -size 1440x2759 tile:mpr:tile)
    else
        args_wp+=(-resize 1440x2759!)
    fi

    args_wp+=(-background "$wp_background" -alpha remove -alpha off)
    wallpaper_prepared="$tmp_wp_dir/wallpaper_prepared.png"
    "$image_command" "${args_wp[@]}" "$wallpaper_prepared"
    trap 'rm -rf -- "$tmp_wp_dir"' EXIT
fi

# Generate previews from SVG templates
for i in 01 02 03 04; do
    svg_template="$repo_root/templates/screenshot-${i}.svg"
    if [[ ! -f $svg_template ]]; then
        printf 'Error: SVG template not found: %s\n' "$svg_template" >&2
        exit 1
    fi

    output_png="$output_dir/.tmp_${theme_name}_${i}.png"
    output_jpg="$output_dir/SxC_${theme_name}${i}.jpg"

    # Render SVG with theme colors
    python3 "$script_dir/render_svg.py" "$svg_template" "$theme_file" "$output_png"

    if [[ $has_wallpaper == true ]]; then
        # Make background transparent and composite wallpaper behind
        magick "$output_png" -fuzz 8% -transparent "#111528" /tmp/tpl_transparent.png 2>/dev/null || \
        magick "$output_png" -fuzz 8% -transparent "#0b1120" /tmp/tpl_transparent.png
        magick "$wallpaper_prepared" /tmp/tpl_transparent.png -composite /tmp/tpl_composited.png
        magick /tmp/tpl_composited.png -quality 92 "$output_jpg"
    else
        magick "$output_png" -quality 92 "$output_jpg"
    fi

    rm -f "$output_png"
    printf 'Generated %s\n' "$output_jpg"
done

# Generate wallpaper preview if theme has embedded wallpaper
if [[ $has_wallpaper == true ]]; then
    tmp_wp_dir2=$(mktemp -d)
    tmp_wp2="$tmp_wp_dir2/wallpaper.png"
    "$script_dir/extract_wallpaper.sh" "$theme_file" "$tmp_wp2" 2>/dev/null

    wallpaper_background=$(awk -v key="background" '
        /^wallpaper:[[:space:]]*$/ { in_wp = 1; next }
        in_wp && /^[^[:space:]]/ { exit }
        in_wp && $1 == key { gsub(/"/, "", $2); print $2; exit }
    ' "$theme_file")
    wallpaper_background=${wallpaper_background:-'#ff101820'}
    if [[ $wallpaper_background =~ ^#[[:xdigit:]]{8}$ ]]; then
        wallpaper_background="#${wallpaper_background:3}"
    fi

    wallpaper_tint=$(awk -v key="tint" '
        /^wallpaper:[[:space:]]*$/ { in_wp = 1; next }
        in_wp && /^[^[:space:]]/ { exit }
        in_wp && $1 == key { gsub(/"/, "", $2); print $2; exit }
    ' "$theme_file")
    tint_color=
    tint_percent=0
    if [[ $wallpaper_tint =~ ^#([[:xdigit:]]{2})([[:xdigit:]]{6})$ ]]; then
        tint_color="#${BASH_REMATCH[2]}"
        tint_percent=$((16#${BASH_REMATCH[1]} * 100 / 255))
    elif [[ $wallpaper_tint =~ ^#[[:xdigit:]]{6}$ ]]; then
        tint_color=$wallpaper_tint
        tint_percent=100
    fi

    wallpaper_preview="$output_dir/SxC_${theme_name}_wallpaper.png"
    args_wp=("$tmp_wp2")
    if ((tint_percent > 0)); then
        args_wp+=(-fill "$tint_color" -colorize "${tint_percent}%")
    fi
    args_wp+=(-background "$wallpaper_background" -alpha remove -alpha off "$wallpaper_preview")
    "$image_command" "${args_wp[@]}"
    rm -rf -- "$tmp_wp_dir2"
    printf 'Generated %s\n' "$wallpaper_preview"
fi
