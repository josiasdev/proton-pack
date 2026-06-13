#!/usr/bin/env bash
# proton-pack.sh
# Package a locally installed game as a portable AppImage,
# bundling or linking GE-Proton as needed.
#
# Usage:
#   ./proton-pack.sh --steam <APP_ID> [--bundle-proton]
#   ./proton-pack.sh --dir <PATH> --exe <RELATIVE_EXE> --name <DISPLAY_NAME> [--bundle-proton]
#
# See README.md for full documentation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/metadata.sh
source "$SCRIPT_DIR/lib/metadata.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/proton.sh
source "$SCRIPT_DIR/lib/proton.sh"
# shellcheck source=lib/appdir.sh
source "$SCRIPT_DIR/lib/appdir.sh"

# ─── Configuration ────────────────────────────────────────────────────────────
STEAM_ROOT="${STEAM_ROOT:-$HOME/.steam/steam}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/AppImages}"
APPIMAGETOOL="${APPIMAGETOOL:-$HOME/bin/appimagetool}"

# ─── Colors / helpers ─────────────────────────────────────────────────────────
red()    { echo -e "\033[1;31m$*\033[0m"; }
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }
info()   { echo -e "\033[1;34m[INFO]\033[0m $*"; }
die()    { red "[ERROR] $*"; exit 1; }

usage() {
  cat <<EOF
proton-pack — package a game as a portable AppImage

Usage:
  $0 --steam <APP_ID> [--bundle-proton]
  $0 --dir <PATH> --exe <RELATIVE_EXE> --name <DISPLAY_NAME> [--bundle-proton]

Options:
  --steam <APP_ID>       Package a game from your Steam library by App ID
  --dir <PATH>           Package a game from an arbitrary directory
  --exe <RELATIVE_EXE>   Path to the main executable, relative to --dir
  --name <DISPLAY_NAME>  Display name for the game (used in .desktop, filenames)
  --bundle-proton        Embed GE-Proton inside the AppImage (Windows games only)
  -h, --help             Show this help

Environment:
  STEAM_ROOT             Steam installation root (default: ~/.steam/steam)
  OUTPUT_DIR             Where AppImages are written (default: ~/AppImages)
  APPIMAGETOOL           Path to appimagetool (default: ~/bin/appimagetool)
  STEAM_COMPAT_DATA_PATH Override the WINEPREFIX path used by Proton

Examples:
  $0 --steam 1245620
  $0 --steam 1245620 --bundle-proton
  $0 --dir ~/Games/Heroic/MyGame --exe MyGame.exe --name "My Game" --bundle-proton
EOF
}

# ─── Argument parsing ──────────────────────────────────────────────────────────
MODE=""
APP_ID=""
GAME_DIR=""
EXE_REL=""
DISPLAY_NAME=""
BUNDLE_PROTON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --steam)
      MODE="steam"
      APP_ID="${2:-}"
      shift 2
      ;;
    --dir)
      MODE="dir"
      GAME_DIR="${2:-}"
      shift 2
      ;;
    --exe)
      EXE_REL="${2:-}"
      shift 2
      ;;
    --name)
      DISPLAY_NAME="${2:-}"
      shift 2
      ;;
    --bundle-proton)
      BUNDLE_PROTON=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (see --help)"
      ;;
  esac
done

[[ -z "$MODE" ]] && { usage; die "You must specify --steam <APP_ID> or --dir <PATH>"; }
[[ ! -f "$APPIMAGETOOL" ]] && die "appimagetool not found at $APPIMAGETOOL (see README.md for installation)"
command -v file >/dev/null     || die "Missing dependency: file"
command -v patchelf >/dev/null || yellow "Warning: patchelf not found — RPATH adjustments will be skipped"

# ─── Resolve game directory and metadata ───────────────────────────────────────
if [[ "$MODE" == "steam" ]]; then
  [[ -z "$APP_ID" ]] && die "--steam requires an App ID"

  STEAMAPPS="$STEAM_ROOT/steamapps"
  [[ -d "$STEAMAPPS" ]] || die "steamapps directory not found at $STEAMAPPS (set STEAM_ROOT?)"

  MANIFEST=$(find_steam_manifest "$STEAMAPPS" "$APP_ID")
  [[ -z "$MANIFEST" ]] && die "Game with App ID $APP_ID is not installed (no appmanifest_${APP_ID}.acf found)"

  info "Manifest: $MANIFEST"

  GAME_NAME=$(extract_acf_field "$MANIFEST" "name")
  INSTALL_DIR_NAME=$(extract_acf_field "$MANIFEST" "installdir")

  [[ -z "$GAME_NAME" || -z "$INSTALL_DIR_NAME" ]] && die "Could not parse manifest fields (name/installdir)"

  GAME_DIR="$STEAMAPPS/common/$INSTALL_DIR_NAME"
  DISPLAY_NAME="$GAME_NAME"

else
  [[ -z "$GAME_DIR" ]] && die "--dir requires a path"
  [[ -z "$EXE_REL" ]] && die "--dir requires --exe <relative path to main executable>"
  [[ -z "$DISPLAY_NAME" ]] && die "--dir requires --name <display name>"
fi

[[ -d "$GAME_DIR" ]] || die "Game directory not found: $GAME_DIR"

SAFE_NAME=$(safe_name "$DISPLAY_NAME")

info "Game: $DISPLAY_NAME"
info "Directory: $GAME_DIR"

# ─── Detect game type ───────────────────────────────────────────────────────────
GAME_TYPE=$(detect_game_type "$GAME_DIR")
[[ "$GAME_TYPE" == "unknown" ]] && die "Could not detect game type (no ELF or .exe executables found in $GAME_DIR)"

info "Detected type: $GAME_TYPE"

# ─── Select main executable ────────────────────────────────────────────────────
if [[ "$MODE" == "dir" ]]; then
  MAIN_EXEC="$GAME_DIR/$EXE_REL"
  [[ -f "$MAIN_EXEC" ]] || die "Executable not found: $MAIN_EXEC"
else
  CANDIDATES=$(find_main_executables "$GAME_DIR" "$GAME_TYPE")
  [[ -z "$CANDIDATES" ]] && die "No candidate executables found in $GAME_DIR"

  mapfile -t EXEC_LIST <<< "$CANDIDATES"

  if [[ ${#EXEC_LIST[@]} -eq 1 ]]; then
    MAIN_EXEC="${EXEC_LIST[0]}"
    info "Executable: $MAIN_EXEC"
  else
    echo ""
    yellow "Multiple candidate executables found:"
    for i in "${!EXEC_LIST[@]}"; do
      echo "  [$i] ${EXEC_LIST[$i]}"
    done
    echo ""
    read -rp "Choose the main executable [0]: " EXEC_CHOICE
    EXEC_CHOICE="${EXEC_CHOICE:-0}"
    MAIN_EXEC="${EXEC_LIST[$EXEC_CHOICE]}"
  fi
fi

REL_EXEC="${MAIN_EXEC#"$GAME_DIR"/}"

# ─── For Windows games: select GE-Proton ───────────────────────────────────────
PROTON_DIR=""
if [[ "$GAME_TYPE" == "windows" ]]; then
  info "Windows game — GE-Proton is required."

  mapfile -t GE_LIST < <(list_ge_proton_installs)

  if [[ ${#GE_LIST[@]} -eq 0 ]]; then
    yellow "No GE-Proton installation found."
    yellow "Install it with protonup-qt, or download from:"
    yellow "  https://github.com/GloriousEggroll/proton-ge-custom/releases"
    die "GE-Proton not installed."
  fi

  if [[ ${#GE_LIST[@]} -eq 1 ]]; then
    PROTON_DIR="${GE_LIST[0]}"
  else
    echo ""
    yellow "GE-Proton versions found:"
    for i in "${!GE_LIST[@]}"; do
      echo "  [$i] $(basename "${GE_LIST[$i]}")"
    done
    echo ""
    read -rp "Choose GE-Proton version [0]: " GE_CHOICE
    GE_CHOICE="${GE_CHOICE:-0}"
    PROTON_DIR="${GE_LIST[$GE_CHOICE]}"
  fi

  info "Using: $(basename "$PROTON_DIR")"
fi

# ─── Build AppDir ───────────────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d /tmp/proton-pack-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

APPDIR=$(create_appdir "$WORK_DIR" "$SAFE_NAME")

info "Copying game files..."
copy_game_files "$GAME_DIR" "$APPDIR"

# ─── App ID for WINEPREFIX path (Steam mode has a real one; dir mode fakes one) ─
if [[ "$MODE" == "steam" ]]; then
  WINE_APP_ID="$APP_ID"
else
  WINE_APP_ID="proton-pack-$SAFE_NAME"
fi

# ─── Write AppRun ───────────────────────────────────────────────────────────────
info "Writing AppRun..."

BUNDLED_PROTON_RELPATH=""
if [[ "$GAME_TYPE" == "windows" ]] && $BUNDLE_PROTON; then
  info "Bundling $(basename "$PROTON_DIR") (this may take a while, ~800MB+)..."
  BUNDLED_PROTON_RELPATH=$(bundle_proton "$PROTON_DIR" "$APPDIR")
  write_proton_license_notice "$APPDIR/LICENSES"
fi

case "$GAME_TYPE" in
  native)
    write_apprun_native "$APPDIR" "$REL_EXEC"
    ;;
  windows)
    if $BUNDLE_PROTON; then
      write_apprun_windows_bundled "$APPDIR" "$REL_EXEC" "$WINE_APP_ID" "$BUNDLED_PROTON_RELPATH"
    else
      write_apprun_windows_linked "$APPDIR" "$REL_EXEC" "$WINE_APP_ID" "$(basename "$PROTON_DIR")"
    fi
    ;;
esac

# ─── .desktop entry ───────────────────────────────────────────────────────────
write_desktop_entry "$APPDIR" "$SAFE_NAME" "$DISPLAY_NAME"

# ─── Icon ─────────────────────────────────────────────────────────────────────
info "Fetching icon..."
ICON_DEST="$APPDIR/${SAFE_NAME}.png"

if [[ "$MODE" == "steam" ]] && fetch_steam_icon "$STEAM_ROOT" "$APP_ID" "$ICON_DEST"; then
  info "Icon copied from Steam library cache."
else
  if generate_placeholder_icon "${APP_ID:-$SAFE_NAME}" "$ICON_DEST"; then
    yellow "Using a generated placeholder icon."
  else
    yellow "Using an empty placeholder icon (PIL not available)."
  fi
fi

# ─── Copy native dependencies ──────────────────────────────────────────────────
if [[ "$GAME_TYPE" == "native" ]]; then
  info "Copying native library dependencies..."
  copy_native_dependencies "$APPDIR"
fi

# ─── Generate AppImage ──────────────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"

if [[ "$GAME_TYPE" == "windows" ]] && $BUNDLE_PROTON; then
  OUTPUT_SUFFIX="-GEProton"
else
  OUTPUT_SUFFIX=""
fi

if [[ "$MODE" == "steam" ]]; then
  OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}-${APP_ID}${OUTPUT_SUFFIX}.AppImage"
else
  OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}${OUTPUT_SUFFIX}.AppImage"
fi

info "Generating AppImage..."
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_FILE"

chmod +x "$OUTPUT_FILE"

echo ""
green "AppImage created successfully!"
green "  -> $OUTPUT_FILE"
echo ""

if [[ "$GAME_TYPE" == "windows" ]] && ! $BUNDLE_PROTON; then
  yellow "Note: this AppImage requires GE-Proton '$(basename "$PROTON_DIR")' to be installed on the system."
  yellow "Install with protonup-qt, or:"
  yellow "  tar -xf GE-Proton*.tar.gz -C ~/.steam/steam/compatibilitytools.d/"
fi

if [[ "$MODE" == "dir" ]]; then
  yellow "Note: this game was packaged with a synthetic WINEPREFIX id ($WINE_APP_ID)."
  yellow "Saves/settings will be stored under compatdata/$WINE_APP_ID, separate from any Steam install."
fi
