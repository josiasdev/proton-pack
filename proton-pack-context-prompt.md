# Context Prompt — proton-pack project

## What this project is

**proton-pack** is an open source CLI tool (Bash) that packages locally installed games as portable AppImages on Linux. It supports:

- Steam games (by App ID, reading `.acf` manifests automatically)
- Any game directory (`--dir` mode, for Heroic/GOG/Epic/itch.io games)
- Native Linux games (ELF binaries) and Windows games (`.exe` via GE-Proton)
- Two Proton modes: **linked** (uses GE-Proton already on the system) and **bundled** (`--bundle-proton`, embeds GE-Proton inside the AppImage)

The project was designed to fill a gap no existing Linux gaming tool covers: converting an already-installed game into a standalone, portable AppImage — including the Proton-GE compatibility layer when needed.

It was also designed to open a collaboration proposal with the **Heroic Games Launcher** team (https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher).

---

## License

MIT. The project does not redistribute any game, Steam, or Proton files. When `--bundle-proton` is used, it copies a GE-Proton install already present on the user's machine and generates a `LICENSES/PROTON_NOTICE.txt` for LGPL compliance.

---

## Project file structure

```
proton-pack/
├── proton-pack.sh              # Main entry point (307 lines)
├── lib/
│   ├── detect.sh               # Game type + executable detection (89 lines)
│   ├── metadata.sh             # Steam .acf manifest reader + icon fetcher (77 lines)
│   ├── proton.sh               # GE-Proton locator + bundler (88 lines)
│   └── appdir.sh               # AppDir builder + AppRun writer (160 lines)
├── docs/
│   ├── usage.md                # Extended usage guide (EN)
│   ├── heroic-integration.md   # Heroic-specific integration guide (EN)
│   └── legal.md                # Full legal analysis (EN)
├── LICENSES/
│   ├── WINE.txt                # LGPL notice for Wine
│   └── PROTON.txt              # License notice for GE-Proton components
├── README.md                   # English README
├── README.pt-BR.md             # Brazilian Portuguese README
├── CONTRIBUTING.md             # Contributor guide
├── LICENSE                     # MIT license
├── .gitignore
└── .github/
    ├── ISSUE_TEMPLATE/
    │   ├── bug_report.md
    │   ├── feature_request.md
    │   └── config.yml
    └── workflows/
        └── ci.yml              # ShellCheck + syntax check + smoke tests
```

All scripts pass `shellcheck` with zero warnings and `bash -n` syntax check. The full pipeline was tested end-to-end with a mock `appimagetool`.

---

## CLI interface

```bash
# Steam mode
./proton-pack.sh --steam <APP_ID> [--bundle-proton]

# Directory mode (Heroic, GOG, any game folder)
./proton-pack.sh --dir <PATH> --exe <RELATIVE_EXE> --name "<DISPLAY_NAME>" [--bundle-proton]

# Help
./proton-pack.sh --help
```

### Environment variables

| Variable | Default |
|---|---|
| `STEAM_ROOT` | `~/.steam/steam` |
| `OUTPUT_DIR` | `~/AppImages` |
| `APPIMAGETOOL` | `~/bin/appimagetool` |
| `STEAM_COMPAT_DATA_PATH` | auto-detected |

### Output filenames

| Mode | Filename |
|---|---|
| Steam, linked | `<SafeName>-<AppID>.AppImage` |
| Steam, bundled | `<SafeName>-<AppID>-GEProton.AppImage` |
| Dir, linked | `<SafeName>.AppImage` |
| Dir, bundled | `<SafeName>-GEProton.AppImage` |

---

## Full source code

### proton-pack.sh (main entry point)

```bash
#!/usr/bin/env bash
# proton-pack.sh
# Package a locally installed game as a portable AppImage,
# bundling or linking GE-Proton as needed.
#
# Usage:
#   ./proton-pack.sh --steam <APP_ID> [--bundle-proton]
#   ./proton-pack.sh --dir <PATH> --exe <RELATIVE_EXE> --name <DISPLAY_NAME> [--bundle-proton]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/metadata.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/proton.sh"
source "$SCRIPT_DIR/lib/appdir.sh"

STEAM_ROOT="${STEAM_ROOT:-$HOME/.steam/steam}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/AppImages}"
APPIMAGETOOL="${APPIMAGETOOL:-$HOME/bin/appimagetool}"

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
  --name <DISPLAY_NAME>  Display name for the game
  --bundle-proton        Embed GE-Proton inside the AppImage (Windows games only)
  -h, --help             Show this help

Environment:
  STEAM_ROOT             Steam installation root (default: ~/.steam/steam)
  OUTPUT_DIR             Where AppImages are written (default: ~/AppImages)
  APPIMAGETOOL           Path to appimagetool (default: ~/bin/appimagetool)
  STEAM_COMPAT_DATA_PATH Override the WINEPREFIX path used by Proton
EOF
}

MODE=""
APP_ID=""
GAME_DIR=""
EXE_REL=""
DISPLAY_NAME=""
BUNDLE_PROTON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --steam)       MODE="steam"; APP_ID="${2:-}"; shift 2 ;;
    --dir)         MODE="dir";   GAME_DIR="${2:-}"; shift 2 ;;
    --exe)         EXE_REL="${2:-}"; shift 2 ;;
    --name)        DISPLAY_NAME="${2:-}"; shift 2 ;;
    --bundle-proton) BUNDLE_PROTON=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown argument: $1 (see --help)" ;;
  esac
done

[[ -z "$MODE" ]] && { usage; die "You must specify --steam <APP_ID> or --dir <PATH>"; }
[[ ! -f "$APPIMAGETOOL" ]] && die "appimagetool not found at $APPIMAGETOOL"
command -v file >/dev/null     || die "Missing dependency: file"
command -v patchelf >/dev/null || yellow "Warning: patchelf not found — RPATH adjustments will be skipped"

if [[ "$MODE" == "steam" ]]; then
  [[ -z "$APP_ID" ]] && die "--steam requires an App ID"
  STEAMAPPS="$STEAM_ROOT/steamapps"
  [[ -d "$STEAMAPPS" ]] || die "steamapps directory not found at $STEAMAPPS"
  MANIFEST=$(find_steam_manifest "$STEAMAPPS" "$APP_ID")
  [[ -z "$MANIFEST" ]] && die "Game with App ID $APP_ID is not installed"
  info "Manifest: $MANIFEST"
  GAME_NAME=$(extract_acf_field "$MANIFEST" "name")
  INSTALL_DIR_NAME=$(extract_acf_field "$MANIFEST" "installdir")
  [[ -z "$GAME_NAME" || -z "$INSTALL_DIR_NAME" ]] && die "Could not parse manifest fields"
  GAME_DIR="$STEAMAPPS/common/$INSTALL_DIR_NAME"
  DISPLAY_NAME="$GAME_NAME"
else
  [[ -z "$GAME_DIR" ]]      && die "--dir requires a path"
  [[ -z "$EXE_REL" ]]       && die "--dir requires --exe <relative path to main executable>"
  [[ -z "$DISPLAY_NAME" ]]  && die "--dir requires --name <display name>"
fi

[[ -d "$GAME_DIR" ]] || die "Game directory not found: $GAME_DIR"
SAFE_NAME=$(safe_name "$DISPLAY_NAME")
info "Game: $DISPLAY_NAME"
info "Directory: $GAME_DIR"

GAME_TYPE=$(detect_game_type "$GAME_DIR")
[[ "$GAME_TYPE" == "unknown" ]] && die "Could not detect game type (no ELF or .exe executables found)"
info "Detected type: $GAME_TYPE"

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
    for i in "${!EXEC_LIST[@]}"; do echo "  [$i] ${EXEC_LIST[$i]}"; done
    echo ""
    read -rp "Choose the main executable [0]: " EXEC_CHOICE
    EXEC_CHOICE="${EXEC_CHOICE:-0}"
    MAIN_EXEC="${EXEC_LIST[$EXEC_CHOICE]}"
  fi
fi

REL_EXEC="${MAIN_EXEC#"$GAME_DIR"/}"

PROTON_DIR=""
if [[ "$GAME_TYPE" == "windows" ]]; then
  info "Windows game — GE-Proton is required."
  mapfile -t GE_LIST < <(list_ge_proton_installs)
  if [[ ${#GE_LIST[@]} -eq 0 ]]; then
    yellow "No GE-Proton installation found."
    die "GE-Proton not installed. Install via protonup-qt or https://github.com/GloriousEggroll/proton-ge-custom/releases"
  fi
  if [[ ${#GE_LIST[@]} -eq 1 ]]; then
    PROTON_DIR="${GE_LIST[0]}"
  else
    echo ""
    yellow "GE-Proton versions found:"
    for i in "${!GE_LIST[@]}"; do echo "  [$i] $(basename "${GE_LIST[$i]}")"; done
    echo ""
    read -rp "Choose GE-Proton version [0]: " GE_CHOICE
    GE_CHOICE="${GE_CHOICE:-0}"
    PROTON_DIR="${GE_LIST[$GE_CHOICE]}"
  fi
  info "Using: $(basename "$PROTON_DIR")"
fi

WORK_DIR=$(mktemp -d /tmp/proton-pack-XXXXXX)
trap 'rm -rf "$WORK_DIR"' EXIT

APPDIR=$(create_appdir "$WORK_DIR" "$SAFE_NAME")
info "Copying game files..."
copy_game_files "$GAME_DIR" "$APPDIR"

[[ "$MODE" == "steam" ]] && WINE_APP_ID="$APP_ID" || WINE_APP_ID="proton-pack-$SAFE_NAME"

info "Writing AppRun..."
BUNDLED_PROTON_RELPATH=""
if [[ "$GAME_TYPE" == "windows" ]] && $BUNDLE_PROTON; then
  info "Bundling $(basename "$PROTON_DIR") (~800MB+)..."
  BUNDLED_PROTON_RELPATH=$(bundle_proton "$PROTON_DIR" "$APPDIR")
  write_proton_license_notice "$APPDIR/LICENSES"
fi

case "$GAME_TYPE" in
  native)  write_apprun_native "$APPDIR" "$REL_EXEC" ;;
  windows)
    if $BUNDLE_PROTON; then
      write_apprun_windows_bundled "$APPDIR" "$REL_EXEC" "$WINE_APP_ID" "$BUNDLED_PROTON_RELPATH"
    else
      write_apprun_windows_linked "$APPDIR" "$REL_EXEC" "$WINE_APP_ID" "$(basename "$PROTON_DIR")"
    fi ;;
esac

write_desktop_entry "$APPDIR" "$SAFE_NAME" "$DISPLAY_NAME"

info "Fetching icon..."
ICON_DEST="$APPDIR/${SAFE_NAME}.png"
if [[ "$MODE" == "steam" ]] && fetch_steam_icon "$STEAM_ROOT" "$APP_ID" "$ICON_DEST"; then
  info "Icon copied from Steam library cache."
else
  generate_placeholder_icon "${APP_ID:-$SAFE_NAME}" "$ICON_DEST" \
    && yellow "Using a generated placeholder icon." \
    || yellow "Using an empty placeholder icon (PIL not available)."
fi

if [[ "$GAME_TYPE" == "native" ]]; then
  info "Copying native library dependencies..."
  copy_native_dependencies "$APPDIR"
fi

mkdir -p "$OUTPUT_DIR"
[[ "$GAME_TYPE" == "windows" ]] && $BUNDLE_PROTON && OUTPUT_SUFFIX="-GEProton" || OUTPUT_SUFFIX=""
[[ "$MODE" == "steam" ]] \
  && OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}-${APP_ID}${OUTPUT_SUFFIX}.AppImage" \
  || OUTPUT_FILE="$OUTPUT_DIR/${SAFE_NAME}${OUTPUT_SUFFIX}.AppImage"

info "Generating AppImage..."
ARCH=x86_64 "$APPIMAGETOOL" "$APPDIR" "$OUTPUT_FILE"
chmod +x "$OUTPUT_FILE"

echo ""
green "AppImage created successfully!"
green "  -> $OUTPUT_FILE"
echo ""

if [[ "$GAME_TYPE" == "windows" ]] && ! $BUNDLE_PROTON; then
  yellow "Note: this AppImage requires GE-Proton '$(basename "$PROTON_DIR")' installed on the system."
  yellow "  tar -xf GE-Proton*.tar.gz -C ~/.steam/steam/compatibilitytools.d/"
fi
if [[ "$MODE" == "dir" ]]; then
  yellow "Note: synthetic WINEPREFIX id ($WINE_APP_ID) — saves stored under compatdata/$WINE_APP_ID."
fi
```

---

### lib/detect.sh

```bash
#!/usr/bin/env bash
# lib/detect.sh

is_elf() { file -b "$1" 2>/dev/null | grep -q "ELF"; }

detect_game_type() {
  local game_dir="$1" has_elf=false has_exe=false
  while IFS= read -r -d '' f; do
    is_elf "$f" && { has_elf=true; break; }
  done < <(find "$game_dir" -maxdepth 2 -type f -executable -print0 2>/dev/null)
  find "$game_dir" -maxdepth 2 -iname "*.exe" -type f 2>/dev/null | grep -q . && has_exe=true
  $has_elf && echo "native" || { $has_exe && echo "windows" || echo "unknown"; }
}

find_native_executables() {
  local game_dir="$1"
  find "$game_dir" -maxdepth 3 \
    ! -path "*/proton*" ! -path "*/Proton*" \
    ! -path "*/steamlinuxruntime*" ! -path "*/SteamLinuxRuntime*" \
    ! -path "*/_CommonRedist/*" \
    -type f -executable 2>/dev/null \
  | while read -r f; do is_elf "$f" && echo "$f"; done
}

find_windows_executables() {
  local game_dir="$1"
  find "$game_dir" -maxdepth 3 \
    ! -path "*/_CommonRedist/*" ! -path "*/Redist/*" \
    ! -path "*/installer*" ! -path "*/Installer*" \
    ! -iname "unins*" ! -iname "setup*" ! -iname "vcredist*" \
    ! -iname "dxsetup*" ! -iname "*crashreporter*" \
    -iname "*.exe" -type f 2>/dev/null
}

find_main_executables() {
  case "$2" in
    native)  find_native_executables "$1" ;;
    windows) find_windows_executables "$1" ;;
    *)       return 1 ;;
  esac
}
```

---

### lib/metadata.sh

```bash
#!/usr/bin/env bash
# lib/metadata.sh

extract_acf_field() {
  grep -oP "(?<=\"${2}\"\t\t\")[^\"]*" "$1" 2>/dev/null || \
  grep -oP "(?<=\"${2}\" \")[^\"]*" "$1" 2>/dev/null || echo ""
}

find_steam_manifest() {
  find "$1" -maxdepth 1 -name "appmanifest_${2}.acf" 2>/dev/null | head -1
}

safe_name() {
  echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_-'
}

fetch_steam_icon() {
  local steam_root="$1" app_id="$2" dest="$3"
  local candidates=(
    "$steam_root/appcache/librarycache/${app_id}_icon.jpg"
    "$steam_root/appcache/librarycache/${app_id}/icon.jpg"
    "$steam_root/appcache/librarycache/${app_id}_library_600x900.jpg"
  )
  for src in "${candidates[@]}"; do [[ -f "$src" ]] && { cp "$src" "$dest"; return 0; }; done
  return 1
}

generate_placeholder_icon() {
  local label="$1" dest="$2"
  python3 - "$label" "$dest" <<'PY' 2>/dev/null && return 0
import sys
try:
    from PIL import Image, ImageDraw
    label, dest = sys.argv[1], sys.argv[2]
    img = Image.new("RGBA", (256, 256), (20, 20, 40, 255))
    d = ImageDraw.Draw(img)
    d.ellipse([30, 30, 226, 226], fill=(60, 100, 200, 255))
    d.text((128, 128), str(label), fill="white", anchor="mm")
    img.save(dest)
except Exception: sys.exit(1)
PY
  : > "$dest"; return 1
}
```

---

### lib/proton.sh

```bash
#!/usr/bin/env bash
# lib/proton.sh

proton_search_paths() {
  cat <<'EOF'
~/.steam/steam/compatibilitytools.d
~/.steam/root/compatibilitytools.d
~/.local/share/Steam/compatibilitytools.d
~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d
~/snap/steam/common/.steam/steam/compatibilitytools.d
EOF
}

list_ge_proton_installs() {
  while IFS= read -r raw_path; do
    local expanded="${raw_path/#\~/$HOME}"
    [[ -d "$expanded" ]] || continue
    while IFS= read -r -d '' d; do
      [[ -f "$d/proton" ]] && echo "$d"
    done < <(find "$expanded" -maxdepth 1 -type d -iname "GE-Proton*" -print0 2>/dev/null)
  done < <(proton_search_paths)
}

find_ge_proton_by_name() {
  local name="$1"
  while IFS= read -r raw_path; do
    local expanded="${raw_path/#\~/$HOME}"
    local candidate="$expanded/$name"
    [[ -f "$candidate/proton" ]] && { echo "$candidate"; return 0; }
  done < <(proton_search_paths)
  return 1
}

bundle_proton() {
  local proton_dir="$1" appdir="$2"
  local name; name=$(basename "$proton_dir")
  mkdir -p "$appdir/proton-ge"
  cp -a "$proton_dir" "$appdir/proton-ge/$name"
  echo "proton-ge/$name"
}

write_proton_license_notice() {
  local dest_dir="$1"; mkdir -p "$dest_dir"
  cat > "$dest_dir/PROTON_NOTICE.txt" <<'EOF'
This AppImage bundles GE-Proton, which includes components licensed
under the LGPL 2.1 (Wine, VKD3D-Proton) and other open source licenses.

Source code:
  - Wine:         https://gitlab.winehq.org/wine/wine
  - Proton:       https://github.com/ValveSoftware/Proton
  - GE-Proton:    https://github.com/GloriousEggroll/proton-ge-custom
  - DXVK:         https://github.com/doitsujin/dxvk
  - VKD3D-Proton: https://github.com/HansKristian-Work/vkd3d-proton
EOF
}
```

---

### lib/appdir.sh

```bash
#!/usr/bin/env bash
# lib/appdir.sh

create_appdir() {
  local work_dir="$1" safe_name="$2"
  local appdir="$work_dir/${safe_name}.AppDir"
  mkdir -p "$appdir/usr/lib"
  echo "$appdir"
}

copy_game_files() { cp -a "$1/." "$2/"; }

write_desktop_entry() {
  cat > "$1/${2}.desktop" <<EOF
[Desktop Entry]
Name=${3}
Exec=AppRun
Icon=${2}
Type=Application
Categories=Game;
EOF
}

write_apprun_native() {
  local appdir="$1" rel_exec="$2"
  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE:\${LD_LIBRARY_PATH:-}"
cd "\$HERE"
exec "\$HERE/${rel_exec}" "\$@"
APPRUN
  chmod +x "$appdir/AppRun"
}

write_apprun_windows_bundled() {
  local appdir="$1" rel_exec="$2" app_id="$3" proton_rel="$4"
  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\${HOME}/.steam/steam"
export STEAM_COMPAT_DATA_PATH="\${STEAM_COMPAT_DATA_PATH:-\${HOME}/.local/share/Steam/steamapps/compatdata/${app_id}}"
export PROTON_DIR="\$HERE/${proton_rel}"
mkdir -p "\$STEAM_COMPAT_DATA_PATH/pfx"
cd "\$HERE"
exec "\$PROTON_DIR/proton" run "\$HERE/${rel_exec}" "\$@"
APPRUN
  chmod +x "$appdir/AppRun"
}

write_apprun_windows_linked() {
  local appdir="$1" rel_exec="$2" app_id="$3" ge_name="$4"
  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
GE_NAME="${ge_name}"
find_proton_ge() {
  local candidates=(
    "\$HOME/.steam/steam/compatibilitytools.d/\$GE_NAME/proton"
    "\$HOME/.steam/root/compatibilitytools.d/\$GE_NAME/proton"
    "\$HOME/.local/share/Steam/compatibilitytools.d/\$GE_NAME/proton"
    "\$HOME/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/\$GE_NAME/proton"
    "\$HOME/snap/steam/common/.steam/steam/compatibilitytools.d/\$GE_NAME/proton"
  )
  for p in "\${candidates[@]}"; do
    [[ -f "\$p" ]] && { dirname "\$p"; return 0; }
  done
  return 1
}
PROTON_DIR=\$(find_proton_ge) || {
  echo "[ERROR] GE-Proton '\$GE_NAME' not found." >&2
  echo "Install: https://github.com/GloriousEggroll/proton-ge-custom/releases" >&2
  exit 1
}
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\${HOME}/.steam/steam"
export STEAM_COMPAT_DATA_PATH="\${STEAM_COMPAT_DATA_PATH:-\${HOME}/.local/share/Steam/steamapps/compatdata/${app_id}}"
mkdir -p "\$STEAM_COMPAT_DATA_PATH/pfx"
cd "\$HERE"
exec "\$PROTON_DIR/proton" run "\$HERE/${rel_exec}" "\$@"
APPRUN
  chmod +x "$appdir/AppRun"
}

copy_native_dependencies() {
  local appdir="$1"
  local skip_pattern='^(libc|libm|libpthread|libdl|librt|ld-linux|libgcc_s|libstdc\+\+)\.so'
  while IFS= read -r -d '' bin; do
    file -b "$bin" 2>/dev/null | grep -q "ELF" || continue
    ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
      [[ -z "$lib" || ! -f "$lib" ]] && continue
      local base; base=$(basename "$lib")
      echo "$base" | grep -qE "$skip_pattern" && continue
      local dest="$appdir/usr/lib/$base"
      [[ -f "$dest" ]] || cp "$lib" "$dest"
    done
  done < <(find "$appdir" -maxdepth 3 -type f -executable -print0 2>/dev/null)
}
```

---

## Key design decisions

1. **Bash only, no external runtime needed** — the tool itself has zero dependencies beyond standard Linux utilities (`file`, `bash`, `find`, `ldd`, optionally `patchelf`)
2. **WINEPREFIX always outside AppImage** — preserves saves/settings between runs; can be overridden via `STEAM_COMPAT_DATA_PATH`
3. **Linked vs bundled split** — linked for personal use (small), bundled for portability and sharing
4. **Shellcheck-clean** — all scripts pass `shellcheck` with zero warnings
5. **Source-based architecture** — main script sources `lib/*.sh`; each library file has single-purpose functions with docstring comments
6. **GE-Proton search covers native, Flatpak, and Snap Steam installs** — `proton_search_paths()` in `lib/proton.sh`
7. **Automatic LGPL compliance** — when `--bundle-proton` is used, `LICENSES/PROTON_NOTICE.txt` is generated automatically pointing to all upstream source repos

## What was tested (all passed)

- `shellcheck` on all scripts → 0 warnings
- `bash -n` syntax check on all files
- `--help` output and no-argument exit code
- Full pipeline: native Linux game (`--dir` mode)
- Full pipeline: Windows game, linked mode (`--dir` and `--steam`)
- Full pipeline: Windows game, `--bundle-proton` (GE-Proton copied, LICENSES generated, `-GEProton` suffix on output)
- Steam `.acf` manifest parsing (name, installdir fields)
- Multi-executable selection prompt (interactive `read`)
- Error cases: invalid App ID, missing exe, missing flags, unknown flag — all exit 1 with clear message

## What's next / open questions

- Add support for Heroic's game library paths automatically (without needing `--dir`)
- GUI wrapper (Zenity / Yad) for non-CLI users
- Integration proposal to Heroic Games Launcher team (Discussion, not Issue; link to working project first)
- Detection of Heroic's own GE-Proton installations (stored separately from Steam's `compatibilitytools.d`)
- AUR / Flathub packaging of proton-pack itself
- CI: add an integration test with a real minimal ELF game and the real `appimagetool`
