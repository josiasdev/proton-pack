# Legal Notice

This document is informational and does not constitute legal advice. If you have concerns about a specific use case, consult a lawyer familiar with software licensing and the laws of your jurisdiction.

---

## What proton-pack does (and doesn't do)

proton-pack is a packaging tool. Given a game already installed and owned by the user, it:

- Reads metadata (Steam `.acf` manifests, or user-provided paths)
- Reorganizes already-installed files into an AppDir structure
- Locates or copies an already-installed GE-Proton runtime
- Invokes `appimagetool` to produce a `.AppImage`

**proton-pack does not:**

- Download, distribute, or host any game files
- Download, distribute, or host Steam, Proton, or GE-Proton binaries (except when the user explicitly enables `--bundle-proton`, which copies a runtime *already present on the user's own machine*)
- Bypass DRM, anti-cheat, or any access control
- Interact with Steam's authentication or online services

---

## Steam Subscriber Agreement

The [Steam Subscriber Agreement](https://store.steampowered.com/subscriber_agreement/) governs use of Steam content and the Steam client. Relevant points:

- The SSA primarily restricts **redistribution** of Steam content and **circumvention** of Steam's access controls
- proton-pack operates only on files the user has already legitimately installed via their own Steam account, and does not redistribute them
- proton-pack does not interact with Steam's DRM or authentication systems

If you build something on top of proton-pack that **does** call the Steam Web API (e.g. to fetch metadata or artwork programmatically), review the [Steamworks Web API Terms of Use](https://steamcommunity.com/dev/apiterms) separately — those terms are not automatically satisfied by proton-pack's current scope.

---

## Proton and GE-Proton licensing

GE-Proton is a fork of Valve's Proton, itself built on Wine and other open source components.

| Component | License |
|---|---|
| Proton (Valve) | BSD-style + per-component licenses |
| Wine | LGPL 2.1 |
| DXVK | Zlib |
| VKD3D-Proton | LGPL 2.1 |
| GE-Proton (patches/scripts) | MIT, with the above inherited |

### Linked mode

proton-pack does not copy or redistribute any GE-Proton files in linked mode — it only locates an installation already present on the host system at runtime. No additional licensing obligations apply.

### Bundled mode (`--bundle-proton`)

When the user opts into `--bundle-proton`, proton-pack copies a GE-Proton release the user already has installed into the AppDir. Because this includes LGPL-licensed components (Wine, VKD3D-Proton):

- proton-pack automatically writes a `LICENSES/PROTON_NOTICE.txt` file into the AppDir, pointing to the upstream source repositories for Wine, Proton, GE-Proton, DXVK, and VKD3D-Proton
- This satisfies the LGPL's source-availability requirement by reference, since the bundled binaries are unmodified copies of publicly available open source releases

If you modify GE-Proton's binaries before bundling them (not something proton-pack does by default), additional LGPL obligations regarding modified-source availability would apply to you.

---

## AppImage / appimagetool

[`appimagetool`](https://github.com/AppImage/AppImageKit) is MIT licensed. No restrictions relevant to proton-pack's use case.

---

## DRM and the DMCA / anti-circumvention laws

Some games include DRM (Denuvo) or anti-cheat (Easy Anti-Cheat, BattlEye, VAC). The relevant question is whether **wrapping a game's launch in a script** constitutes "circumvention" under laws like the US DMCA §1201, the EU Copyright Directive's anti-circumvention provisions, or similar laws elsewhere.

- proton-pack's `AppRun` is a launcher wrapper: it sets environment variables and execs the original, unmodified game binary — the same category of operation performed by Lutris, Bottles, Heroic, and Steam's own Proton integration
- It does not patch, decrypt, or modify the protected binary or its DRM checks
- If a DRM or anti-cheat system refuses to run outside its expected environment (e.g. outside Steam, or without a specific kernel module loaded), that is the *game's* DRM/anti-cheat behaving as designed — proton-pack neither attempts nor achieves circumvention of that check

This is consistent with the long-established legal position of compatibility-layer and launcher tools in the Linux gaming ecosystem (Wine, Lutris, Bottles, Heroic, ProtonUp-Qt) — none of which have faced successful anti-circumvention claims for providing alternative launch environments for user-owned software.

**Practical implication for users:** if a specific game's anti-cheat refuses to run via the generated AppImage, that's a compatibility limitation (documented in the [README's Limitations table](../README.md#limitations)), not a legal one. Running such games through their original launcher/Steam remains the reliable option.

---

## Trademarks

- **Steam®** is a registered trademark of Valve Corporation. proton-pack is not affiliated with, endorsed by, or sponsored by Valve Corporation.
- **GE-Proton** is a project maintained by GloriousEggroll. proton-pack is not affiliated with or endorsed by GloriousEggroll.
- **Heroic Games Launcher** is an independent open source project. proton-pack is not affiliated with or endorsed by the Heroic Games Launcher project.
- Any other product or company names mentioned in this project's documentation are trademarks of their respective owners, used only for identification/interoperability purposes.

---

## User responsibilities

Users of proton-pack are responsible for:

- Owning a legitimate license for any game they package
- Complying with that game's End User License Agreement (EULA), including any clauses about modified launch environments
- Understanding that anti-cheat-protected games may not function correctly (or may flag the account) when launched outside their intended environment — **when in doubt, don't use proton-pack on multiplayer games with kernel-level anti-cheat**

---

## License of proton-pack itself

proton-pack's own source code (the shell scripts, documentation, and project files in this repository) is licensed under the **MIT License** — see [LICENSE](../LICENSE).

This MIT license applies only to proton-pack's own code. It does not grant any rights to Steam, GE-Proton, game content, or any other third-party software referenced by this project.
