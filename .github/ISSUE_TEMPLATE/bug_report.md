---
name: Bug report
about: Something didn't work as expected
title: "[BUG] "
labels: bug
assignees: ''
---

## Description

A clear description of what went wrong.

## Command used

```bash
# e.g. ./proton-pack.sh --steam 1245620 --bundle-proton
```

## Expected behavior

What you expected to happen.

## Actual behavior

What actually happened. Include the full error message if any.

## Debug log

Run with output captured and paste the relevant part (or attach the file):

```bash
./proton-pack.sh --steam <APPID> 2>&1 | tee debug.log
```

```
<paste relevant output here>
```

## Environment

- **Distro / version**: (`cat /etc/os-release`)
- **proton-pack version / commit**:
- **GE-Proton version** (if applicable):
- **Steam install type**: native / Flatpak / Snap
- **Game**: (name + Steam App ID if applicable)
- **Mode**: `--steam` / `--dir`, with/without `--bundle-proton`

## Additional context

Anything else that might help — e.g. does the game run fine via Steam directly? Does it use anti-cheat?
