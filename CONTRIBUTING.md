# Contributing to proton-pack

Thanks for considering a contribution! This project lives and breathes thanks to community testing across distros, stores, and Proton versions — that's the part a single maintainer can never fully cover alone.

---

## Ways to contribute

You don't need to write code to help:

- **Test with your games** — report which games work, which don't, and what error you got
- **Improve documentation** — clarify steps, fix typos, add examples
- **Triage issues** — help reproduce bugs reported by others
- **Translate** — `README.pt-BR.md` exists; other languages are welcome

---

## Reporting a bug

Before opening an issue, please check:

1. Does it reproduce with `--bundle-proton` *and* without it?
2. What does `file` say about the game's main executable?
3. Output of `./proton-pack.sh --steam <APPID> 2>&1 | tee debug.log`

Include in your report:

- Distro and version (`cat /etc/os-release`)
- GE-Proton version (if relevant)
- Game name and Steam App ID (if applicable)
- Full output / `debug.log`

Use the **Bug Report** issue template — it has these fields pre-filled.

---

## Suggesting a feature

Open a **Feature Request** issue, or start a **Discussion** if it's more exploratory (e.g. "should we support X store?"). Discussions are better for ideas that need back-and-forth before becoming a concrete spec.

---

## Development setup

```bash
git clone https://github.com/YOUR_USERNAME/proton-pack.git
cd proton-pack
chmod +x proton-pack.sh lib/*.sh
```

No build step — it's pure Bash. You'll need a Linux machine with Steam (and ideally GE-Proton) installed to test the full pipeline end to end.

### Running shellcheck locally

CI runs [ShellCheck](https://www.shellcheck.net/) on every PR. Run it before pushing:

```bash
shellcheck proton-pack.sh lib/*.sh
```

---

## Code style

- **Bash strict mode**: every script starts with `set -euo pipefail`
- **Functions over inline logic**: anything reused twice becomes a function in `lib/`
- **Quote everything**: `"$var"`, not `$var`, unless you have a specific reason not to (and a comment explaining why)
- **Color helpers**: use the existing `info()`, `yellow()`, `green()`, `red()`, `die()` helpers for output — don't introduce new echo styles
- **No silent failures**: if something can fail, either `die` with a clear message or explicitly comment why it's safe to ignore

---

## Pull request process

1. **Fork** the repo and create a branch from `main`: `git checkout -b fix/short-description`
2. Make your changes, keeping commits focused (one logical change per commit when possible)
3. Test against at least one real game if your change touches `lib/detect.sh`, `lib/proton.sh`, or `lib/appdir.sh`
4. Run `shellcheck` and fix any warnings (or justify with a `# shellcheck disable=SCxxxx` comment + reason)
5. Update `README.md` / `README.pt-BR.md` / `docs/` if behavior or flags change
6. Open the PR against `main` with:
   - What changed and why
   - How you tested it (which game, which distro, linked or bundled mode)
   - Any remaining caveats

A maintainer will review — for changes to `lib/proton.sh` or anything involving WINEPREFIX handling, expect a closer look since these affect user save data.

---

## Adding support for a new store / launcher

If you're adding detection for a new launcher (e.g. itch.io, Amazon Games path conventions):

1. Add detection logic to `lib/metadata.sh` following the existing pattern for Steam's `.acf` parsing
2. Add a new `--<launcher>` flag in `proton-pack.sh` if it needs its own metadata source, or extend `--dir` detection if it's just a path convention
3. Document the new flag/path in both READMEs and `docs/usage.md`
4. If possible, include a sample/dummy manifest in a PR description so reviewers can test without owning that store's client

---

## Heroic integration contributions

Changes related to [docs/heroic-integration.md](docs/heroic-integration.md) or any Heroic-specific path detection should:

- Reference the actual Heroic config/install paths (link to Heroic's own docs or source where possible)
- Avoid assuming Heroic internals that could change between versions — prefer reading from user-facing config files over Heroic's internal database format
- Flag in the PR description if this should also be raised with the Heroic team directly

---

## Code of conduct

Be respectful, assume good faith, and keep discussions focused on the technical problem. Disagreements about implementation are normal — personal attacks aren't.

---

## Questions?

Open a Discussion or ask in an existing issue. There are no bad questions when it comes to "will this break someone's save file?" — ask before assuming.
