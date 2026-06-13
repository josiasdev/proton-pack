# Usage Guide

This document covers proton-pack in more depth than the README quickstart: flags, modes, environment variables, and common scenarios.

---

## Modes

proton-pack has two input modes, chosen via the first flag:

| Mode | Flag | Source of metadata |
|---|---|---|
| Steam | `--steam <APP_ID>` | Reads `appmanifest_<APP_ID>.acf` automatically |
| Directory | `--dir <PATH>` | You provide `--exe` and `--name` manually |

You cannot mix modes in a single invocation.

---

## Steam mode

```bash
proton-pack --steam <APP_ID> [--bundle-proton]
```

### Finding App IDs

```bash
ls ~/.steam/steam/steamapps/appmanifest_*.acf | grep -oP '\d+(?=\.acf)'
```

Or look up the game on [SteamDB](https://steamdb.info) — the App ID is in the URL.

### What gets read automatically

- **Game name** — from the `name` field in the `.acf` manifest
- **Install directory** — from the `installdir` field
- **Icon** — from `appcache/librarycache/<APP_ID>_icon.jpg`, if cached locally

### Multiple Steam libraries

If the game is installed in a secondary library (not the default one under `~/.steam/steam/steamapps`), point `STEAM_ROOT` at the library's root:

```bash
STEAM_ROOT="/mnt/games/SteamLibrary" proton-pack --steam 1245620
```

Note: `STEAM_ROOT` should be the directory that **contains** `steamapps`, not `steamapps` itself.

---

## Directory mode

```bash
proton-pack --dir <PATH> --exe <RELATIVE_EXE> --name "<DISPLAY_NAME>" [--bundle-proton]
```

Use this for games installed via Heroic, GOG Galaxy (via Heroic/Lutris), itch.io, or any manually placed game folder.

- `--dir` — the game's root folder
- `--exe` — path to the main executable, **relative to `--dir`**
- `--name` — display name used for the `.desktop` entry, icon filename, and output filename

### Example

```bash
proton-pack \
  --dir "$HOME/Games/Heroic/MyGame" \
  --exe "MyGame.exe" \
  --name "My Game" \
  --bundle-proton
```

In directory mode there's no Steam App ID, so proton-pack generates a synthetic identifier (`proton-pack-<safe-name>`) for the WINEPREFIX path. This keeps saves/settings separate from any Steam install of the same game.

---

## Linked vs. bundled mode

### Linked (default)

```bash
proton-pack --steam 1245620
```

- Small AppImage (close to the game's own size)
- `AppRun` searches standard `compatibilitytools.d` locations at runtime
- Requires the matching GE-Proton version to be installed on the machine that runs the AppImage

If GE-Proton isn't found at runtime, `AppRun` prints an error with install instructions and exits — it won't silently fail.

### Bundled (`--bundle-proton`)

```bash
proton-pack --steam 1245620 --bundle-proton
```

- AppImage size increases by the size of the GE-Proton release (~800 MB+)
- GE-Proton is copied into `proton-ge/<GE-version>/` inside the AppDir
- `AppRun` calls the bundled `proton` directly — no host lookup
- A `LICENSES/PROTON_NOTICE.txt` is included automatically, pointing to upstream source repos (LGPL compliance)

Use bundled mode when:

- Sharing the AppImage with someone who may not have GE-Proton installed
- Archiving a fully self-contained backup
- Running on a system where you can't install anything system-wide

---

## Native vs. Windows games

proton-pack detects this automatically:

- **Native**: an ELF executable is found in the top 2 directory levels → no Proton needed, dependencies are copied into `usr/lib/`
- **Windows**: only `.exe` files are found → GE-Proton is required

If detection finds **neither** (no ELF, no `.exe`), proton-pack exits with an error. This usually means the game is in a subdirectory deeper than 2 levels, or uses an unusual launcher structure — in that case, directory mode with an explicit `--exe` is more reliable.

---

## Choosing between multiple executables / GE-Proton versions

When proton-pack finds more than one candidate (multiple `.exe` files, or multiple installed GE-Proton versions), it lists them with indices and prompts:

```
Multiple candidate executables found:
  [0] /path/to/game/Game.exe
  [1] /path/to/game/x64/Game-Win64-Shipping.exe

Choose the main executable [0]:
```

Press Enter to accept the default (`[0]`), or type the index of the one you want.

This is a common case for Unreal Engine games, where the top-level `.exe` is often a launcher and the real binary is in `<GameName>/Binaries/Win64/`.

---

## Environment variables reference

| Variable | Default | Notes |
|---|---|---|
| `STEAM_ROOT` | `~/.steam/steam` | Must contain `steamapps/`. Used only in `--steam` mode (and for icon lookup). |
| `OUTPUT_DIR` | `~/AppImages` | Created if it doesn't exist. |
| `APPIMAGETOOL` | `~/bin/appimagetool` | Must be executable. proton-pack exits early if missing. |
| `STEAM_COMPAT_DATA_PATH` | auto (`~/.local/share/Steam/steamapps/compatdata/<id>`) | Override if you want the WINEPREFIX somewhere else. |

---

## Output filenames

| Mode | Filename pattern |
|---|---|
| Steam, linked | `<SafeName>-<AppID>.AppImage` |
| Steam, bundled | `<SafeName>-<AppID>-GEProton.AppImage` |
| Directory, linked | `<SafeName>.AppImage` |
| Directory, bundled | `<SafeName>-GEProton.AppImage` |

`<SafeName>` is the display name with spaces replaced by underscores and non-alphanumeric characters stripped.

---

## Troubleshooting

### "No candidate executables found"

The game's binaries might be nested deeper than 2 levels. Use `--dir` with an explicit `--exe` pointing at the correct path.

### "GE-Proton not installed"

Install via [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) (recommended), or manually:

```bash
mkdir -p ~/.steam/steam/compatibilitytools.d
tar -xf GE-ProtonX-XX.tar.gz -C ~/.steam/steam/compatibilitytools.d/
```

### The AppImage runs but the game shows a black screen / crashes immediately

This is often an anti-cheat or DRM issue — see [Limitations](../README.md#limitations) in the main README. Try running the game through Steam directly first to confirm it works there, then compare environment variables (`STEAM_COMPAT_DATA_PATH`, `STEAM_COMPAT_CLIENT_INSTALL_PATH`) between the two runs.

### Saves don't carry over from my existing Steam install

By design — `STEAM_COMPAT_DATA_PATH` for AppImages defaults to a path under `~/.local/share/Steam/...`, which may differ from where Steam itself stores `compatdata` for that App ID (`~/.steam/steam/steamapps/compatdata/<APP_ID>`). If you want the AppImage to share the same prefix as your Steam install, set `STEAM_COMPAT_DATA_PATH` explicitly before launching the AppImage:

```bash
STEAM_COMPAT_DATA_PATH="$HOME/.steam/steam/steamapps/compatdata/1245620" ./MyGame-1245620.AppImage
```
