#!/usr/bin/env bash
# Automate SimpleX Chat screenshot capture with a theme applied.
set -euo pipefail

if (($# < 1)); then
    printf 'Usage: %s <theme.theme> [output-dir]\n' "${0##*/}" >&2
    exit 2
fi

theme_file=$1
output_dir=${2:-screenshots}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ ! -f $theme_file ]]; then
    printf 'Error: theme file not found: %s\n' "$theme_file" >&2
    exit 1
fi

theme_name=$(basename "$theme_file" .theme)
theme_name=${theme_name#SxC_}

mkdir -p -- "$output_dir"

DISPLAY_NUM=:99
SIMPLEX_APP=/tmp/simplex-chat.AppImage
SIMPLEX_EXTRACTED=/tmp/squashfs-root
PROFILE_DIR="${HOME}/.config/simplex"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

cleanup() {
    if [[ -n "${SIMPLEX_PID:-}" ]] && kill -0 "$SIMPLEX_PID" 2>/dev/null; then
        kill "$SIMPLEX_PID" 2>/dev/null || true
        wait "$SIMPLEX_PID" 2>/dev/null || true
    fi
    pkill -f Xvfb 2>/dev/null || true
}
trap cleanup EXIT

log "Starting Xvfb on $DISPLAY_NUM"
Xvfb "$DISPLAY_NUM" -screen 0 1920x1080x24 &
XVFB_PID=$!
sleep 2
export DISPLAY=$DISPLAY_NUM
xdpyinfo -display "$DISPLAY_NUM" > /dev/null 2>&1 || { log "Xvfb failed"; exit 1; }

log "Preparing profile"
mkdir -p -- "$PROFILE_DIR"
if [[ ! -f "$PROFILE_DIR/settings.properties" ]]; then
    cat > "$PROFILE_DIR/settings.properties" <<'PROPS'
AppLanguage=en
DesktopCloseBehavior=MinimizeToTray
NewDatabaseInitialized=true
CurrentTheme=BLACK
DeveloperTools=true
PROPS
fi
cp -- "$theme_file" "$PROFILE_DIR/"

if [[ ! -f $SIMPLEX_APP ]]; then
    log "Downloading SimpleX Chat..."
    SIMPLEX_VERSION=$(curl -s https://api.github.com/repos/simplex-chat/simplex-chat/releases/latest | jq -r '.tag_name')
    wget -q "https://github.com/simplex-chat/simplex-chat/releases/download/${SIMPLEX_VERSION}/simplex-desktop-x86_64.AppImage" -O "$SIMPLEX_APP" || \
    wget -q "https://github.com/simplex-chat/simplex-chat/releases/download/${SIMPLEX_VERSION}/simplex-chat-ubuntu-24_04-x86_64" -O "$SIMPLEX_APP"
    chmod +x "$SIMPLEX_APP"
fi

if [[ ! -d $SIMPLEX_EXTRACTED ]]; then
    log "Extracting AppImage..."
    cd /tmp && "$SIMPLEX_APP" --appimage-extract > /tmp/extract.log 2>&1
    if [[ ! -d $SIMPLEX_EXTRACTED ]]; then
        log "Extraction failed"
        cat /tmp/extract.log | tail -5
        exit 1
    fi
fi

SIMPLEX_BIN=""
if [[ -f "$SIMPLEX_EXTRACTED/AppRun" ]]; then
    SIMPLEX_BIN="$SIMPLEX_EXTRACTED/AppRun"
elif [[ -f "$SIMPLEX_EXTRACTED/simplex-desktop" ]]; then
    SIMPLEX_BIN="$SIMPLEX_EXTRACTED/simplex-desktop"
else
    SIMPLEX_BIN=$(find "$SIMPLEX_EXTRACTED" -maxdepth 2 -type f -executable | head -1)
fi
log "Using binary: $SIMPLEX_BIN"

log "Launching SimpleX Chat..."
"$SIMPLEX_BIN" --no-sandbox > /tmp/simplex.log 2>&1 &
SIMPLEX_PID=$!
sleep 20

if ! kill -0 "$SIMPLEX_PID" 2>/dev/null; then
    log "SimpleX Chat failed to start"
    cat /tmp/simplex.log | tail -20
    exit 1
fi
log "SimpleX Chat running (PID: $SIMPLEX_PID)"

log "Taking initial screenshot"
scrot "$output_dir/${theme_name}_01_initial.png"
sleep 2

log "Done. Screenshots saved to $output_dir/"
ls -la "$output_dir"/${theme_name}_*.png 2>/dev/null || true
