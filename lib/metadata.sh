#!/usr/bin/env bash
# lib/metadata.sh
# Reads Steam .acf manifests and fetches game icons.

# extract_acf_field <manifest_path> <field_name>
# Echoes the value of a given field from a Steam .acf manifest.
extract_acf_field() {
  local manifest="$1"
  local field="$2"
  grep -oP "(?<=\"${field}\"\t\t\")[^\"]*" "$manifest" 2>/dev/null || \
  grep -oP "(?<=\"${field}\" \")[^\"]*" "$manifest" 2>/dev/null || \
  echo ""
}

# find_steam_manifest <steamapps_dir> <app_id>
# Echoes the path to appmanifest_<app_id>.acf, or nothing if not found.
find_steam_manifest() {
  local steamapps="$1"
  local app_id="$2"
  find "$steamapps" -maxdepth 1 -name "appmanifest_${app_id}.acf" 2>/dev/null | head -1
}

# safe_name <raw_name>
# Normalizes a game name for use in filenames/paths.
safe_name() {
  echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_-'
}

# fetch_steam_icon <steam_root> <app_id> <dest_path>
# Copies the cached library icon for app_id to dest_path.
# Returns 1 if no cached icon was found.
fetch_steam_icon() {
  local steam_root="$1"
  local app_id="$2"
  local dest="$3"

  local candidates=(
    "$steam_root/appcache/librarycache/${app_id}_icon.jpg"
    "$steam_root/appcache/librarycache/${app_id}/icon.jpg"
    "$steam_root/appcache/librarycache/${app_id}_library_600x900.jpg"
  )

  for src in "${candidates[@]}"; do
    if [[ -f "$src" ]]; then
      cp "$src" "$dest"
      return 0
    fi
  done

  return 1
}

# generate_placeholder_icon <app_id_or_label> <dest_path>
# Creates a simple placeholder PNG icon using Python+PIL if available,
# otherwise creates an empty file (appimagetool tolerates a missing icon).
generate_placeholder_icon() {
  local label="$1"
  local dest="$2"

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
except Exception:
    sys.exit(1)
PY

  # Fallback: empty file
  : > "$dest"
  return 1
}
