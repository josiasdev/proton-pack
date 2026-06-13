#!/usr/bin/env bash
# lib/detect.sh
# Detects whether a game is native Linux or Windows (needs Proton),
# and locates candidate main executables.

# is_elf <file_path>
# Returns 0 if the file is an ELF binary.
is_elf() {
  file -b "$1" 2>/dev/null | grep -q "ELF"
}

# detect_game_type <game_dir>
# Echoes "native" or "windows" depending on what's found in the directory.
#
# Heuristic: if any ELF executable exists at the top 2 levels, treat the
# game as native. Otherwise, if .exe files exist, treat it as Windows.
detect_game_type() {
  local game_dir="$1"
  local has_elf=false
  local has_exe=false

  while IFS= read -r -d '' f; do
    if is_elf "$f"; then
      has_elf=true
      break
    fi
  done < <(find "$game_dir" -maxdepth 2 -type f -executable -print0 2>/dev/null)

  if find "$game_dir" -maxdepth 2 -iname "*.exe" -type f 2>/dev/null | grep -q .; then
    has_exe=true
  fi

  if $has_elf; then
    echo "native"
  elif $has_exe; then
    echo "windows"
  else
    echo "unknown"
  fi
}

# find_native_executables <game_dir>
# Echoes one path per line: ELF executables that look like the main binary,
# excluding common runtime/redist directories.
find_native_executables() {
  local game_dir="$1"

  find "$game_dir" \
    -maxdepth 3 \
    ! -path "*/proton*" ! -path "*/Proton*" \
    ! -path "*/steamlinuxruntime*" ! -path "*/SteamLinuxRuntime*" \
    ! -path "*/_CommonRedist/*" \
    -type f -executable 2>/dev/null \
  | while read -r f; do
      is_elf "$f" && echo "$f"
    done
}

# find_windows_executables <game_dir>
# Echoes one path per line: .exe files that look like the main binary,
# excluding installers, uninstallers, and redistributables.
find_windows_executables() {
  local game_dir="$1"

  find "$game_dir" \
    -maxdepth 3 \
    ! -path "*/_CommonRedist/*" \
    ! -path "*/Redist/*" \
    ! -path "*/installer*" ! -path "*/Installer*" \
    ! -iname "unins*" \
    ! -iname "setup*" \
    ! -iname "vcredist*" \
    ! -iname "dxsetup*" \
    ! -iname "*crashreporter*" \
    -iname "*.exe" -type f 2>/dev/null
}

# find_main_executables <game_dir> <game_type>
# Dispatches to the right finder based on game_type ("native" or "windows").
find_main_executables() {
  local game_dir="$1"
  local game_type="$2"

  case "$game_type" in
    native)  find_native_executables "$game_dir" ;;
    windows) find_windows_executables "$game_dir" ;;
    *)       return 1 ;;
  esac
}
