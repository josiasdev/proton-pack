#!/usr/bin/env bash
# lib/appdir.sh
# Builds the AppDir structure: copies game files, writes AppRun,
# .desktop entry, and copies runtime library dependencies.

# create_appdir <work_dir> <safe_name>
# Creates and echoes the path to a fresh AppDir.
create_appdir() {
  local work_dir="$1"
  local safe_name="$2"
  local appdir="$work_dir/${safe_name}.AppDir"

  mkdir -p "$appdir/usr/lib"
  echo "$appdir"
}

# copy_game_files <game_dir> <appdir>
# Copies all game files into the AppDir root.
copy_game_files() {
  local game_dir="$1"
  local appdir="$2"
  cp -a "$game_dir/." "$appdir/"
}

# write_desktop_entry <appdir> <safe_name> <display_name>
# Writes a minimal .desktop file pointing Exec at AppRun.
write_desktop_entry() {
  local appdir="$1"
  local safe_name="$2"
  local display_name="$3"

  cat > "$appdir/${safe_name}.desktop" <<EOF
[Desktop Entry]
Name=${display_name}
Exec=AppRun
Icon=${safe_name}
Type=Application
Categories=Game;
EOF
}

# write_apprun_native <appdir> <rel_exec>
# Writes AppRun for a native Linux game.
write_apprun_native() {
  local appdir="$1"
  local rel_exec="$2"

  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE:\${LD_LIBRARY_PATH:-}"
cd "\$HERE"
exec "\$HERE/${rel_exec}" "\$@"
APPRUN

  chmod +x "$appdir/AppRun"
}

# write_apprun_windows_bundled <appdir> <rel_exec> <app_id> <bundled_proton_relpath>
# Writes AppRun for a Windows game with GE-Proton bundled inside the AppDir.
write_apprun_windows_bundled() {
  local appdir="$1"
  local rel_exec="$2"
  local app_id="$3"
  local bundled_proton_relpath="$4"

  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
HERE="\$(dirname "\$(readlink -f "\$0")")"

export STEAM_COMPAT_CLIENT_INSTALL_PATH="\${HOME}/.steam/steam"
export STEAM_COMPAT_DATA_PATH="\${STEAM_COMPAT_DATA_PATH:-\${HOME}/.local/share/Steam/steamapps/compatdata/${app_id}}"
export PROTON_DIR="\$HERE/${bundled_proton_relpath}"

mkdir -p "\$STEAM_COMPAT_DATA_PATH/pfx"

cd "\$HERE"
exec "\$PROTON_DIR/proton" run "\$HERE/${rel_exec}" "\$@"
APPRUN

  chmod +x "$appdir/AppRun"
}

# write_apprun_windows_linked <appdir> <rel_exec> <app_id> <ge_name>
# Writes AppRun for a Windows game that locates GE-Proton on the host
# system at runtime (linked mode).
write_apprun_windows_linked() {
  local appdir="$1"
  local rel_exec="$2"
  local app_id="$3"
  local ge_name="$4"

  cat > "$appdir/AppRun" <<APPRUN
#!/usr/bin/env bash
# AppRun for a Windows game using a system-installed GE-Proton.
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
    if [[ -f "\$p" ]]; then
      dirname "\$p"
      return 0
    fi
  done
  return 1
}

PROTON_DIR=\$(find_proton_ge) || {
  echo "[ERROR] GE-Proton '\$GE_NAME' not found." >&2
  echo "Install it to ~/.steam/steam/compatibilitytools.d/" >&2
  echo "Or download from: https://github.com/GloriousEggroll/proton-ge-custom/releases" >&2
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

# copy_native_dependencies <appdir>
# Walks all ELF binaries/libs in the AppDir and copies any dynamically
# linked libraries that aren't part of a typical base system into
# usr/lib, so the AppImage is more portable across distros.
copy_native_dependencies() {
  local appdir="$1"

  # Libraries assumed present on virtually any glibc-based distro.
  local skip_pattern='^(libc|libm|libpthread|libdl|librt|ld-linux|libgcc_s|libstdc\+\+)\.so'

  while IFS= read -r -d '' bin; do
    file -b "$bin" 2>/dev/null | grep -q "ELF" || continue

    ldd "$bin" 2>/dev/null | grep "=> /" | awk '{print $3}' | while read -r lib; do
      [[ -z "$lib" || ! -f "$lib" ]] && continue

      local base
      base=$(basename "$lib")
      echo "$base" | grep -qE "$skip_pattern" && continue

      local dest="$appdir/usr/lib/$base"
      [[ -f "$dest" ]] || cp "$lib" "$dest"
    done
  done < <(find "$appdir" -maxdepth 3 -type f -executable -print0 2>/dev/null)
}
