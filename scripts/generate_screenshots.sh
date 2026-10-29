#!/usr/bin/env bash
# Generate four recolored JPG previews from an existing theme's screenshot set.
# Usage: scripts/generate_screenshots.sh <theme.theme> [template.theme|auto] [output-directory]
set -euo pipefail

usage() {
    printf 'Usage: %s <theme.theme> [template.theme|auto] [output-directory]\n' "${0##*/}" >&2
}

if (($# < 1 || $# > 3)); then
    usage
    exit 2
fi

theme_file=$1
if [[ ! -f $theme_file ]]; then
    printf 'Error: theme file not found: %s\n' "$theme_file" >&2
    exit 1
fi

filename=${theme_file##*/}
if [[ $filename != SxC_*.theme ]]; then
    printf 'Error: theme filename must start with SxC_ and end with .theme: %s\n' "$filename" >&2
    exit 2
fi
theme_name=${filename#SxC_}
theme_name=${theme_name%.theme}

template_arg=${2:-auto}
output_dir=${3:-}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

read_wallpaper_preset() {
    local file=$1 line in_wallpaper=false

    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ ^wallpaper:[[:space:]]*$ ]]; then
            in_wallpaper=true
            continue
        fi
        if [[ $in_wallpaper == true && $line =~ ^[^[:space:]] ]]; then
            break
        fi
        if [[ $in_wallpaper == true && $line =~ ^[[:space:]]+preset:[[:space:]]*\"([^\"]+)\" ]]; then
            printf '%s\n' "${BASH_REMATCH[1]}"
            return
        fi
    done <"$file"
}

if [[ $template_arg == auto ]]; then
    target_preset=$(read_wallpaper_preset "$theme_file")
    template_theme=
    if [[ -n $target_preset ]]; then
        for candidate in "$repo_root"/themes/*.theme; do
            [[ -f $candidate ]] || continue
            candidate_filename=${candidate##*/}
            [[ $candidate_filename == "$filename" ]] && continue
            candidate_preset=$(read_wallpaper_preset "$candidate")
            [[ $candidate_preset == "$target_preset" ]] || continue

            candidate_name=${candidate_filename#SxC_}
            candidate_name=${candidate_name%.theme}
            has_screenshots=true
            for index in 01 02 03 04; do
                if [[ ! -f $repo_root/screenshots/SxC_${candidate_name}${index}.jpg ]]; then
                    has_screenshots=false
                    break
                fi
            done
            if [[ $has_screenshots == true ]]; then
                template_theme=$candidate
                break
            fi
        done
        if [[ -z $template_theme ]]; then
            printf 'Error: no four-screenshot template found for wallpaper preset "%s".\n' "$target_preset" >&2
            printf 'Pass a template theme explicitly to choose a different background.\n' >&2
            exit 1
        fi
    else
        template_theme="$repo_root/themes/SxC_adaidasBlack.theme"
    fi
else
    template_theme=$template_arg
fi

if [[ ! -f $template_theme ]]; then
    printf 'Error: template theme not found: %s\n' "$template_theme" >&2
    exit 1
fi

template_filename=${template_theme##*/}
if [[ $template_filename != SxC_*.theme ]]; then
    printf 'Error: template filename must start with SxC_ and end with .theme: %s\n' "$template_filename" >&2
    exit 2
fi
template_name=${template_filename#SxC_}
template_name=${template_name%.theme}
if [[ $theme_name == "$template_name" ]]; then
    printf 'Error: target and template themes must be different.\n' >&2
    exit 2
fi
for index in 01 02 03 04; do
    template="$repo_root/screenshots/SxC_${template_name}${index}.jpg"
    if [[ ! -f $template ]]; then
        printf 'Error: template screenshot not found: %s\n' "$template" >&2
        exit 1
    fi
done

if [[ -z $output_dir ]]; then
    output_dir="$repo_root/screenshots"
fi

if command -v magick >/dev/null 2>&1; then
    image_command=magick
elif command -v convert >/dev/null 2>&1; then
    image_command=convert
else
    printf 'Error: ImageMagick is required (magick or convert).\n' >&2
    exit 1
fi

# Read opaque theme colors only. JPEG screenshots contain colors composited
# against their backgrounds, so transparent theme colors cannot be matched.
declare -A source_colors=()
declare -A target_colors=()
read_colors() {
    local file=$1
    local -n colors=$2
    local in_colors=false line key value

    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ ^colors:[[:space:]]*$ ]]; then
            in_colors=true
            continue
        fi
        if [[ $in_colors == true && $line =~ ^[[:alnum:]_]+: ]]; then
            break
        fi
        if [[ $in_colors == true && $line =~ ^[[:space:]]+([[:alnum:]_]+):[[:space:]]*\"#([[:xdigit:]]{8})\" ]]; then
            key=${BASH_REMATCH[1]}
            value=${BASH_REMATCH[2]^^}
            if [[ ${value:0:2} == FF ]]; then
                # shellcheck disable=SC2034 # The nameref populates the caller's color map.
                colors["$key"]=${value:2}
            fi
        fi
    done <"$file"
}

read_colors "$template_theme" source_colors
read_colors "$theme_file" target_colors
if ((${#source_colors[@]} == 0 || ${#target_colors[@]} == 0)); then
    printf 'Error: no opaque colors found in the colors section of a theme file.\n' >&2
    exit 1
fi

printf 'Using screenshot template: %s\n' "$template_theme"
mapfile -t color_keys < <(printf '%s\n' "${!source_colors[@]}" | sort)
mkdir -p -- "$output_dir"
for index in 01 02 03 04; do
    template="$repo_root/screenshots/SxC_${template_name}${index}.jpg"
    output="$output_dir/SxC_${theme_name}${index}.jpg"
    args=("$template")
    for key in "${color_keys[@]}"; do
        if [[ -n ${target_colors[$key]:-} && ${source_colors[$key]} != "${target_colors[$key]}" ]]; then
            args+=(-fuzz 1% -fill "#${target_colors[$key]}" -opaque "#${source_colors[$key]}")
        fi
    done
    args+=(-quality 92 "$output")
    "$image_command" "${args[@]}"
    printf 'Generated %s\n' "$output"
done
