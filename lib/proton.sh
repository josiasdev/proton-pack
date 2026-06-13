#!/usr/bin/env bash
# lib/proton.sh
# Locates GE-Proton installations on the system, across native,
# Flatpak, and Snap Steam setups, and supports bundling one into an AppDir.

# proton_search_paths
# Echoes a list of compatibilitytools.d directories to search,
# covering native, Flatpak, and Snap Steam installs.
proton_search_paths() {
  cat <<'EOF'
~/.steam/steam/compatibilitytools.d
~/.steam/root/compatibilitytools.d
~/.local/share/Steam/compatibilitytools.d
~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d
~/snap/steam/common/.steam/steam/compatibilitytools.d
EOF
}

# list_ge_proton_installs
# Echoes one path per line: directories containing a `proton` script,
# across all known compatibilitytools.d locations.
list_ge_proton_installs() {
  while IFS= read -r raw_path; do
    local expanded="${raw_path/#\~/$HOME}"
    [[ -d "$expanded" ]] || continue

    while IFS= read -r -d '' d; do
      [[ -f "$d/proton" ]] && echo "$d"
    done < <(find "$expanded" -maxdepth 1 -type d -iname "GE-Proton*" -print0 2>/dev/null)
  done < <(proton_search_paths)
}

# find_ge_proton_by_name <name>
# Echoes the directory path of a GE-Proton install matching <name>,
# searching all known locations. Returns 1 if not found.
find_ge_proton_by_name() {
  local name="$1"

  while IFS= read -r raw_path; do
    local expanded="${raw_path/#\~/$HOME}"
    local candidate="$expanded/$name"
    if [[ -f "$candidate/proton" ]]; then
      echo "$candidate"
      return 0
    fi
  done < <(proton_search_paths)

  return 1
}

# bundle_proton <proton_dir> <appdir>
# Copies a GE-Proton install into <appdir>/proton-ge/<name>/.
# Echoes the relative path (proton-ge/<name>) on success.
bundle_proton() {
  local proton_dir="$1"
  local appdir="$2"
  local name
  name=$(basename "$proton_dir")

  mkdir -p "$appdir/proton-ge"
  cp -a "$proton_dir" "$appdir/proton-ge/$name"

  echo "proton-ge/$name"
}

# write_proton_license_notice <dest_dir>
# Writes a short notice about Wine/Proton LGPL components into <dest_dir>.
# Used when --bundle-proton is set, to keep the AppImage LGPL-compliant.
write_proton_license_notice() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"

  cat > "$dest_dir/PROTON_NOTICE.txt" <<'EOF'
This AppImage bundles GE-Proton, which includes components licensed
under the LGPL 2.1 (Wine, VKD3D-Proton) and other open source licenses
(DXVK is Zlib-licensed; Proton itself is BSD + per-component licenses).

Source code for these projects is available at:
  - Wine:          https://gitlab.winehq.org/wine/wine
  - Proton:        https://github.com/ValveSoftware/Proton
  - GE-Proton:     https://github.com/GloriousEggroll/proton-ge-custom
  - DXVK:          https://github.com/doitsujin/dxvk
  - VKD3D-Proton:  https://github.com/HansKristian-Work/vkd3d-proton

This bundling does not imply endorsement by Valve Corporation or
GloriousEggroll. See LICENSES/ in this AppImage for full license texts.
EOF
}
