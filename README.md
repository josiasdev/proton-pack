# proton-pack 📦

> Package any locally installed game as a portable AppImage — with GE-Proton bundled or linked.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-blue.svg)](https://kernel.org)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**proton-pack** is an open source CLI tool that reads a locally installed game (from Steam, Heroic, GOG, Epic, or any directory), detects whether it needs Proton to run on Linux, and produces a self-contained `.AppImage` file ready to launch on any Linux distribution — no installation required.

🇧🇷 [Leia em português](README.pt-BR.md)

---

## Why proton-pack?

| Tool | Creates AppImage | Includes Proton | Works with any store |
|---|---|---|---|
| Lutris | ✗ | ✗ | ✓ |
| Bottles | ✗ | ✗ | ✓ |
| ProtonUp-Qt | ✗ | manages only | — |
| Heroic | ✗ | ✗ | ✓ |
| **proton-pack** | **✓** | **✓** | **✓** |

proton-pack fills a gap no existing tool covers: converting an already-installed game into a portable, runnable AppImage — including the Proton-GE compatibility layer when needed.

---

## Features

- **Auto-detection** — reads Steam `.acf` manifests or accepts any game directory
- **Native vs Windows** — detects ELF binaries (native Linux) or `.exe` files (needs Proton)
- **GE-Proton support** — locates existing GE-Proton installations or bundles one inside the AppImage
- **Linked mode** *(default)* — lightweight AppImage that uses GE-Proton already on your system
- **Bundled mode** — fully portable AppImage (~800 MB+) with GE-Proton embedded
- **Multi-store** — works with Steam, Heroic (Epic/GOG/Amazon), or any game directory
- **Icon extraction** — pulls icons from Steam's library cache automatically
- **WINEPREFIX aware** — uses existing `compatdata` so saves and settings are preserved

---

## Requirements

```bash
# Required
bash >= 5.0
file
patchelf
libfuse2        # for AppImage mounting

# Download appimagetool
wget -O ~/bin/appimagetool \
  "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
chmod +x ~/bin/appimagetool

# GE-Proton (for Windows games) — install via protonup-qt or manually:
# https://github.com/GloriousEggroll/proton-ge-custom/releases
```

---

## Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/proton-pack.git
cd proton-pack

# Make the script executable
chmod +x proton-pack.sh

# Optional: add to PATH
sudo ln -s "$(pwd)/proton-pack.sh" /usr/local/bin/proton-pack
```

---

## Usage

### Steam game (by App ID)

```bash
# Find your App IDs
ls ~/.steam/steam/steamapps/appmanifest_*.acf | grep -oP '\d+(?=\.acf)'

# Package a game (lightweight — uses GE-Proton from system)
./proton-pack.sh --steam 1245620

# Package with GE-Proton bundled inside the AppImage (fully portable)
./proton-pack.sh --steam 1245620 --bundle-proton
```

### Any game directory

```bash
# Native Linux game
./proton-pack.sh --dir /path/to/game --exe game_binary --name "My Game"

# Windows game with linked GE-Proton
./proton-pack.sh --dir /path/to/game --exe Game.exe --name "My Game"

# Windows game with bundled GE-Proton
./proton-pack.sh --dir /path/to/game --exe Game.exe --name "My Game" --bundle-proton
```

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `STEAM_ROOT` | `~/.steam/steam` | Steam installation path |
| `OUTPUT_DIR` | `~/AppImages` | Where AppImages are saved |
| `APPIMAGETOOL` | `~/bin/appimagetool` | Path to appimagetool binary |
| `STEAM_COMPAT_DATA_PATH` | auto-detected | Override WINEPREFIX path |

See [docs/usage.md](docs/usage.md) for the full guide, including multi-library setups, executable selection, and troubleshooting.

---

## How it works

```
Input (Steam App ID / game dir)
        │
        ▼
 Read metadata (.acf manifest or flags)
        │
        ▼
 Detect game type ──► Native Linux ──► Copy ELF + libs → AppDir
        │
        └──────────► Windows (.exe) ──► Locate or bundle GE-Proton
                                               │
                                               ▼
                                         Build AppRun with
                                         proton run wrapper
                                               │
                                               ▼
                                     appimagetool → .AppImage
```

### Linked mode (default)

The AppImage is small. The `AppRun` script locates GE-Proton at runtime from standard paths:

```
~/.steam/steam/compatibilitytools.d/GE-ProtonX-XX/
~/.var/app/com.valvesoftware.Steam/data/Steam/compatibilitytools.d/
~/snap/steam/common/.steam/steam/compatibilitytools.d/
```

### Bundled mode (`--bundle-proton`)

GE-Proton is copied inside the AppDir before packaging. The resulting AppImage is self-contained and runs on any Linux machine without any prior setup. A `LICENSES/PROTON_NOTICE.txt` is generated automatically for LGPL compliance.

---

## Heroic Games Launcher integration

proton-pack is designed to work well alongside [Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher).

If you use Heroic to install GOG or Epic games, you can package them as AppImages:

```bash
# GOG game installed via Heroic (default path)
./proton-pack.sh \
  --dir "$HOME/Games/Heroic/MyGame" \
  --exe "MyGame.exe" \
  --name "My Game" \
  --bundle-proton
```

See [docs/heroic-integration.md](docs/heroic-integration.md) for a detailed guide, including notes on saves/prefix separation and possible upstream integration.

---

## Limitations

| Scenario | Behavior |
|---|---|
| Games with Steam DRM | AppImage runs, but Steam may need to be open |
| Anti-cheat (EAC, BattlEye) | May not work — anti-cheat often requires the original launcher |
| WINEPREFIX | Always stored outside the AppImage (saves are preserved) |
| Multiplayer with VAC | Not recommended — run through Steam directly |

---

## Project structure

```
proton-pack/
├── proton-pack.sh        # Main entry point
├── lib/
│   ├── detect.sh         # Game type and executable detection
│   ├── proton.sh         # GE-Proton locator and bundler
│   ├── appdir.sh          # AppDir structure builder
│   └── metadata.sh        # Manifest reader and icon fetcher
├── docs/
│   ├── usage.md          # Extended usage guide
│   ├── heroic-integration.md
│   └── legal.md
├── LICENSES/             # Third-party license notices (Wine, Proton)
└── .github/              # Issue templates and CI
```

---

## Contributing

Contributions are very welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

Areas where help is especially appreciated:

- Testing with more games and stores
- macOS / Flatpak / Snap path detection improvements
- GUI wrapper (Zenity / Yad / Electron)
- Heroic Games Launcher plugin interface

---

## Legal notice

This tool does not redistribute any Steam, Proton, or game files.  
It only reorganizes files already legally owned and installed by the user.

- Not affiliated with Valve Corporation or GloriousEggroll
- Users are responsible for complying with each game's license terms
- Games with DRM may not function correctly when launched outside of Steam
- Steam® is a trademark of Valve Corporation
- GE-Proton is a project by GloriousEggroll — [MIT + LGPL components](LICENSES/)

See [docs/legal.md](docs/legal.md) for a full breakdown.

---

## License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

<div align="center">
  Made with ❤️ for the Linux gaming community
</div>
