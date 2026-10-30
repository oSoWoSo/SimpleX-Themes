#!/usr/bin/env bash
# Dispatch the repository's theme-management scripts.

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

usage() {
    local prog=${0##*/}
    cat << EOF
Usage: $prog <command> [arguments...]
       $prog help [command]

Commands:
  add-theme           <theme.theme>
  generate-screenshots <theme.theme> [template.theme|auto] [output-directory]
  embed-wallpaper     <source.theme> <wallpaper.png> <output.theme>
  extract-wallpaper   <theme.theme> [output-image]
  help [command]      Show general or command-specific help

Run "$prog help <command>" for argument details.
EOF
}

command_usage() {
    local prog=${0##*/}
    case $1 in
        add-theme)
            printf 'Usage: %s add-theme <theme.theme>\nGenerate a theme index page. Requires python3.\n' "$prog"
            ;;
        generate-screenshots)
            printf 'Usage: %s generate-screenshots <theme.theme> [template.theme|auto] [output-directory]\nGenerate four recolored chat previews and, when embedded, a wallpaper preview. The template defaults to auto.\n' "$prog"
            ;;
        embed-wallpaper)
            printf 'Usage: %s embed-wallpaper <source.theme> <wallpaper.png> <output.theme>\nCreate a new theme with the PNG embedded as its wallpaper; existing output files are not overwritten.\n' "$prog"
            ;;
        extract-wallpaper)
            printf 'Usage: %s extract-wallpaper <theme.theme> [output-image]\nExtract an embedded PNG or JPG; without output-image, save it under wallpapers/.\n' "$prog"
            ;;
        *)
            printf 'Unknown command: %s\n' "$1" >&2
            return 2
            ;;
    esac
}

main() {
    local command=${1:-}

    case $command in
        '' | -h | --help)
            usage
            return 0
            ;;
        help)
            if (($# == 1)); then
                usage
                return 0
            fi
            if (($# != 2)); then
                usage >&2
                return 2
            fi
            command_usage "$2"
            return $?
            ;;
    esac

    shift
    case $command in
        add-theme)
            exec python3 "$script_dir/scripts/add_theme.py" "$@"
            ;;
        generate-screenshots)
            exec bash "$script_dir/scripts/generate_screenshots.sh" "$@"
            ;;
        embed-wallpaper)
            exec bash "$script_dir/scripts/embed_wallpaper.sh" "$@"
            ;;
        extract-wallpaper)
            exec bash "$script_dir/scripts/extract_wallpaper.sh" "$@"
            ;;
        *)
            printf 'Unknown command: %s\n\n' "$command" >&2
            usage >&2
            return 2
            ;;
    esac
}

main "$@"
