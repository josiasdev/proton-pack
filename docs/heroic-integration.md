# Heroic Games Launcher Integration

[Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher) is an open source launcher for Epic Games Store, GOG, and Amazon Games on Linux and the Steam Deck. proton-pack does **not** modify or depend on Heroic's internals — this document describes how to use proton-pack on games that Heroic has installed.

> **Scope note:** this is a companion workflow, not a Heroic plugin. If you're interested in a tighter integration (e.g. an "Export as AppImage" button inside Heroic itself), see [Possible upstream integration](#possible-upstream-integration) below.

---

## Why this is useful

Heroic gives you native Linux GOG/Epic/Amazon game management, but doesn't currently offer a way to export a game as a standalone, portable executable. proton-pack fills that gap for games Heroic has already installed and configured with Proton.

Typical use cases:

- Moving a single game to another machine without reinstalling via Heroic
- Running a Heroic-managed game on a system where Heroic/Epic/GOG login isn't practical (e.g. a shared or offline machine)
- Archiving a fully self-contained copy of a game + its Proton runtime

---

## Locating Heroic's game install paths

Heroic's default install locations (can be changed in Heroic's settings):

| Platform | Default path |
|---|---|
| Linux (native install) | `~/Games/Heroic/<GameName>` |
| Flatpak | `~/.var/app/com.heroicgameslauncher.hgl/data/Heroic/<GameName>` (or wherever configured) |

You can confirm the exact path from Heroic itself: **Library → right-click the game → "Open Container Folder"** (wording may vary slightly by Heroic version).

---

## Packaging a Heroic game with proton-pack

### 1. Native Linux games (GOG Linux builds, some Epic titles)

```bash
proton-pack \
  --dir "$HOME/Games/Heroic/MyGame" \
  --exe "start.sh" \
  --name "My Game"
```

proton-pack detects native ELF binaries automatically and skips GE-Proton entirely.

### 2. Windows games (most Epic/GOG titles, run via Proton in Heroic)

```bash
proton-pack \
  --dir "$HOME/Games/Heroic/MyGame" \
  --exe "MyGame.exe" \
  --name "My Game" \
  --bundle-proton
```

**`--bundle-proton` is recommended for Heroic games.** Heroic manages its own Wine/Proton prefixes separately from Steam's `compatdata`, so a *linked* AppImage may not find a compatible runtime on another machine. Bundling makes the AppImage self-contained.

### 3. Matching Heroic's GE-Proton version

If you want the bundled Proton to match what Heroic uses for that game:

1. In Heroic, go to the game's **Settings → Wine/Proton** tab and note the version (e.g. `GE-Proton9-7`)
2. Make sure that version is also listed under one of the paths proton-pack searches (see `lib/proton.sh`'s `proton_search_paths`) — Heroic's bundled Wine/Proton versions live in Heroic's own data directory by default, which is **not** one of these paths
3. If needed, copy or symlink Heroic's GE-Proton version into `~/.steam/steam/compatibilitytools.d/` so proton-pack can find it:

```bash
ln -s "$HOME/.config/heroic/tools/proton/GE-Proton9-7" \
      "$HOME/.steam/steam/compatibilitytools.d/GE-Proton9-7"
```

Exact Heroic data paths vary by install method (native, Flatpak, AppImage) and version — check Heroic's own documentation if the path above doesn't exist on your system.

---

## Saves and settings

proton-pack's AppImage uses its own WINEPREFIX (under `compatdata/proton-pack-<safe-name>` by default), **separate from Heroic's prefix** for the same game. This means:

- Saves made in the AppImage won't automatically appear in Heroic, and vice versa
- If the game stores saves in the cloud (GOG Galaxy saves, Epic cloud saves), this may not matter
- If saves are local-only, you'll want to manually copy the relevant save folder between prefixes, or point `STEAM_COMPAT_DATA_PATH` at Heroic's prefix for that game (advanced — see [docs/usage.md](usage.md))

---

## Possible upstream integration

This section is aimed at anyone interested in proposing a tighter integration to the Heroic team — including the proton-pack maintainers.

### What we are **not** proposing

- proton-pack does not aim to make Heroic a Steam client or read Steam libraries
- This is not a request for Heroic to bundle or depend on proton-pack

### What could make sense

- An optional **"Export as AppImage"** action in Heroic's per-game context menu, which shells out to a tool like proton-pack with the game's install path, executable, and Proton version pre-filled
- Heroic already handles "Add to Steam" for its games — exporting to AppImage is a similar category of feature (packaging an already-installed game for use outside Heroic itself)

### Current status

There is an existing discussion in the Heroic repository about Steam library support, where maintainers noted concerns about scope (workshop/DLC handling) and general workload — that discussion is about **importing** Steam games into Heroic, which is a different (and larger) problem than what's described here.

If you want to raise *this* idea (AppImage export) with the Heroic team:

1. Open a **Discussion** (not an Issue) in the [Heroic repository](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/discussions)
2. Link to proton-pack as a working proof-of-concept rather than asking them to build it from scratch
3. Be explicit that this is a narrower scope than "Steam support" — it's "export an already-managed game as a portable file"

Any such integration would be Heroic's call to make, on Heroic's terms — this document just documents the current state of compatibility so the option is visible.

---

## Legal note

This document describes interoperability with Heroic Games Launcher's file layout and does not redistribute any part of Heroic, Epic, GOG, Amazon, or any game. See [legal.md](legal.md) for the full legal notice.

Heroic Games Launcher is an independent open source project, licensed under GPL-3.0. proton-pack is not affiliated with the Heroic Games Launcher project.
