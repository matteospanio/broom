# broom

```
    __                                   |
   / /_  _________  ____  ____ ___       |
  / __ \/ ___/ __ \/ __ \/ __ `__ \      |
 / /_/ / /  / /_/ / /_/ / / / / / /     /|\
/_.___/_/   \____/\____/_/ /_/ /_/     //|\\
                                      ///|\\\
```

**Keep your Linux box lean.** `broom` shows what is eating your disk, cleans it safely, updates
everything with one command and points out duplicate files.

It is a single Bash script with no dependencies beyond the standard GNU tools. Copy it anywhere
on your `PATH` and it works: it reads paths from the environment (`$HOME`, `XDG_*`, `CARGO_HOME`,
…) and only runs a task when the tool it needs is installed.

![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Bash 4.4+](https://img.shields.io/badge/bash-4.4%2B-green.svg)
![Linux](https://img.shields.io/badge/platform-linux-lightgrey.svg)

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Commands](#commands)
- [Tasks](#tasks)
- [Options](#options)
- [Safety](#safety)
- [Running on a schedule](#running-on-a-schedule)
- [Exit codes](#exit-codes)
- [FAQ](#faq)
- [Development](#development)
- [License](#license)

## Features

- **`scan`**: a disk usage bar, your ten largest folders and how much each cleanup task would
  free. Read-only, takes a few seconds.
- **`clean`**: removes old snap revisions, oversized system logs, package caches, developer caches
  (pip, npm, yarn, poetry, go, cargo, uv, pnpm, conda…), leftovers of old JetBrains IDEs, stale
  build artifacts and unused Docker data. Each task shows an estimate and asks before it runs.
- **`update`**: one command for system packages (apt, dnf or pacman), snaps, flatpaks, pipx, uv
  tools, rustup, oh-my-zsh, tldr and, if you ask, firmware.
- **`dupes`**: finds files with identical content, skipping hardlinks, and reports how much space
  they waste. It never deletes anything.
- **Dry run everywhere**: `-n` prints the exact commands without running them.
- Works the same on every machine, with no configuration file to maintain.

## Requirements

- Linux with **bash 4.4+** (any distribution from 2017 onwards)
- GNU coreutils and findutils (`du`, `df`, `find`, `numfmt`, `md5sum`, `realpath`), which are
  preinstalled on every mainstream distribution
- `sudo`, only for the tasks that touch the system (snaps, journal, system packages)

Everything else is optional: if `snap`, `flatpak`, `docker`, `pipx`, `uv`, … are not installed,
the corresponding task is skipped and reported as such.

macOS and the BSDs are not supported (GNU tool flags, systemd, snap).

## Installation

### One-liner

```sh
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/matteospanio/broom/main/broom -o ~/.local/bin/broom
chmod +x ~/.local/bin/broom
```

Most distributions already have `~/.local/bin` on the `PATH`. If `broom` is not found, add
`export PATH="$HOME/.local/bin:$PATH"` to your `~/.bashrc` or `~/.zshrc`.

### From a clone

```sh
git clone https://github.com/matteospanio/broom.git
cd broom
install -Dm755 broom ~/.local/bin/broom          # just for you
sudo install -Dm755 broom /usr/local/bin/broom   # or for every user
```

### Uninstall

```sh
rm ~/.local/bin/broom
```

`broom` keeps no configuration, state or log files, so there is nothing else to remove.

## Quick start

```sh
broom                 # look: disk usage, biggest folders, what can be reclaimed
broom clean -n        # preview: print what would be deleted, change nothing
broom clean           # clean, confirming each task
broom update          # bring everything up to date
```

## Commands

```
broom [command] [options] [task...]
```

With no command, `broom` runs `scan`.

### `scan`

Read-only overview of the machine:

```
Disk usage
  /              ███████████████████░░░░░░░░░░░  66%  75.2 GiB free of 232.6 GiB

Largest directories in your home
    41.4 GiB  ~/projects
    20.4 GiB  ~/snap
     9.1 GiB  ~/.cache
     ...

Reclaimable space
  snap            9.7 GiB  sudo
  journal         3.4 GiB  sudo
  packages      196.0 KiB  sudo
  flatpak               -  not installed
  trash          71.7 MiB
  thumbnails     94.8 MiB
  devcaches     279.9 MiB
  jetbrains       6.3 GiB
  builds                -  needs --path DIR
  docker                -  Docker daemon not reachable

  Total: 19.8 GiB
```

A `?` means the amount can't be known in advance (for example, how much
`flatpak uninstall --unused` will free). Add `-p DIR` to include the `builds` task in the
estimate.

### `clean [task...]`

Runs the cleanup tasks. With no task names it runs every task that is not opt-in (see
[Tasks](#tasks)); with names it runs exactly those, opt-in ones included:

```sh
broom clean                        # all default tasks, asking before each one
broom clean trash thumbnails       # only these two
broom clean -x snap,journal        # everything except snaps and logs
broom clean -a -p ~/code           # also stale build artifacts under ~/code, and Docker
broom clean builds -p ~/code -n    # preview which build artifacts would go
```

For each task broom prints what it is about to delete and the estimated space, asks for
confirmation (skipped with `-y`), runs it and records the result. The summary at the end shows
what was freed per task and the real change in free disk space:

```
Summary
  snap         ✔ done     freed 9.7 GiB
  journal      ✔ done     freed 3.4 GiB
  flatpak      – skipped  not installed
  trash        – skipped  declined
  ...

  Freed 13.1 GiB  (free space: 17.0 GiB → 30.1 GiB)
```

If a task needs root, broom asks for your sudo password once, before starting.

### `update [task...]`

Updates everything it finds, after a single confirmation:

```sh
broom update            # every available updater (asks once)
broom update -y         # unattended: also passes -y to apt/dnf/flatpak
broom update system     # only the system packages
broom update -x snap    # everything except snaps
broom update -a         # include firmware updates
```

The summary lists what was updated, what failed and how long each step took.

### `dupes [path...]`

Finds files with the same content and reports the space they waste. It defaults to your home
folder and files of at least 50 MiB:

```sh
broom dupes                              # big duplicates anywhere in ~
broom dupes ~/Downloads ~/Documents      # only here
broom dupes ~/Pictures --min-size 1M     # smaller files too
```

```
  2.1 GiB × 2  2.1 GiB wasted
    ~/projects/aria/models/model.safetensors
    ~/projects/old/aria/models/model.safetensors

  1 group(s): 2.1 GiB could be freed by keeping one copy of each.
```

Files are first grouped by size, then hardlinks are dropped (they share their data already),
and only the remaining candidates are hashed. `dupes` never deletes anything: you decide which
copy to keep.

## Tasks

### Clean tasks

| Task | What it does | sudo | opt-in |
|---|---|:---:|:---:|
| `snap` | Removes disabled snap revisions (snapd keeps the previous version of every snap after each update) together with their data in `~/snap/<name>/<revision>` | ✔ | |
| `journal` | Shrinks the systemd journal to `--journal-size` (default 500M) with `journalctl --vacuum-size` | ✔ | |
| `packages` | apt: `autoremove --purge` + `clean`; dnf: `autoremove` + `clean all`; pacman: `paccache -rk2 -ruk0` (or `pacman -Sc`) | ✔ | |
| `flatpak` | `flatpak uninstall --unused` | | |
| `trash` | Empties `$XDG_DATA_HOME/Trash` | | |
| `thumbnails` | Deletes thumbnails older than `--older-than` days from `$XDG_CACHE_HOME/thumbnails` | | |
| `devcaches` | Empties the caches of pip, poetry, pre-commit, npm, yarn, puppeteer, electron, go (`GOCACHE`) and cargo (`registry/cache`), then runs `uv cache prune`, `pnpm store prune` and `conda clean --all` | | |
| `jetbrains` | Deletes the caches and plugins of JetBrains IDE versions that have a newer one installed (`PyCharm2025.2` when `PyCharm2025.3` exists). Settings are kept | | |
| `builds` | In the `--path` directories, deletes `target/` (Rust or Maven), `node_modules/`, Python virtualenvs and `.mypy_cache` of projects untouched for `--older-than` days | | ✔ |
| `docker` | `docker system prune --all` for objects older than `--older-than` days. Volumes are never touched | | ✔ |

All cache paths follow `XDG_CACHE_HOME`, `XDG_DATA_HOME`, `npm_config_cache`, `GOCACHE` and
`CARGO_HOME` when they are set.

### Update tasks

| Task | Runs | sudo | opt-in |
|---|---|:---:|:---:|
| `system` | apt: `apt-get update` + `apt-get upgrade`; dnf: `dnf upgrade`; pacman: `pacman -Syu` | ✔ | |
| `snap` | `snap refresh` | ✔ | |
| `flatpak` | `flatpak update` | | |
| `pipx` | `pipx upgrade-all` | | |
| `uv` | `uv tool upgrade --all` | | |
| `rustup` | `rustup update` | | |
| `omz` | oh-my-zsh's own `tools/upgrade.sh` (found via `$ZSH`) | | |
| `tldr` | `tldr --update` | | |
| `firmware` | `fwupdmgr refresh` + `fwupdmgr update` (may require a reboot) | | ✔ |

Opt-in tasks run only with `-a/--all` or when you name them explicitly.

## Options

| Option | Description | Default |
|---|---|---|
| `-n`, `--dry-run` | Print what would happen, change nothing | |
| `-y`, `--yes` | Don't ask for confirmation; also passes `-y`/`--noconfirm` to package managers | |
| `-a`, `--all` | Include opt-in tasks | |
| `-x`, `--exclude LIST` | Comma-separated tasks to skip | |
| `-d`, `--older-than DAYS` | Age threshold for `thumbnails`, `builds` and `docker` | `30` |
| `-p`, `--path DIR` | Where `builds` looks for artifacts and `dupes` looks for files (repeatable) | |
| `--journal-size SIZE` | Maximum journal size kept by `journal` (`K`, `M`, `G`, `T`) | `500M` |
| `--min-size SIZE` | Smallest file compared by `dupes` | `50M` |
| `-q`, `--quiet` | No banner, no spinner | |
| `--no-color` | Disable colors (the [`NO_COLOR`](https://no-color.org) variable works too) | |
| `-h`, `--help` | Show help | |
| `-V`, `--version` | Show version | |

Short flags can be combined (`-ny`), and long options accept `--option=value`.

## Safety

broom deletes files, so it is built to be predictable:

- `scan` and `dupes` are read-only, and `dupes` never deletes anything.
- `-n` shows every command exactly as it would run, without running it.
- Each clean task shows its estimate (and, for caches, IDE folders and builds, the exact paths),
  then asks before running. Updates ask once.
- Every deletion goes through a guard that refuses relative paths, `/`, `$HOME` and paths
  containing `..`.
- Caches are emptied, not removed, so tools find their cache folder where they expect it.
- `builds` runs only on the folders you pass with `--path`. It never scans your whole home,
  where `node_modules` folders inside editor extensions would break if deleted. A folder counts
  as a build artifact only next to its project marker (`Cargo.toml`, `pom.xml`, `package.json`,
  or containing `pyvenv.cfg`). A project counts as stale only if none of its files changed in
  `--older-than` days, looking 4 levels deep and ignoring `.git` and dependency folders. Hidden
  folders are skipped.
- `docker` never prunes volumes, which is where container data lives.
- Root is used only by the tasks marked sudo, through `sudo`, and only when they run.

Everything `clean` removes can be recreated: caches fill up again, and build artifacts come back
with `cargo build`, `npm install` or `uv sync`.

## Running on a schedule

User-level cleanup once a week, with `crontab -e`:

```cron
# Sunday at 12:00: clean caches as your user, skip the tasks that need sudo
0 12 * * 0  PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" broom clean -y -q --no-color -x snap,journal,packages >> "$HOME/.cache/broom.log" 2>&1
```

System-level cleanup with `sudo crontab -e` (broom installed in `/usr/local/bin`):

```cron
30 12 * * 0  /usr/local/bin/broom clean -y -q --no-color snap journal packages
```

cron runs with a minimal `PATH`, so tools installed in your home (uv, pnpm, rustup, …) are
found only if their folders are added to `PATH` as in the first example. Updates are better
run by hand, since `broom update` may need your input or a reboot.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (skipped tasks are not errors) |
| `1` | At least one task failed |
| `2` | Invalid usage: unknown option, command or task, or a bad value |
| `130` | Interrupted with Ctrl-C |

## FAQ

**Snap revisions come back after a few days. Is that a bug?**
No. snapd keeps the previous revision of each snap so it can roll back, and it can't be told to
keep fewer than two (`refresh.retain`). Running `broom clean snap` now and then is the intended
use.

**Docker Desktop still takes gigabytes after `broom clean docker`.**
Docker Desktop stores everything in a virtual machine disk image that does not shrink by itself.
Use *Troubleshoot → Clean / Purge data* in Docker Desktop to reclaim that space.

**Why does `scan` show `?` for some tasks?**
Some tools can't report in advance what they would free (`flatpak --unused`, `docker prune`,
`apt autoremove`). broom runs them and the summary shows the real result.

**conda is installed but `devcaches` ignores it.**
broom looks for conda via `$CONDA_EXE` (exported by `conda init`) and then the `PATH`. If you
run broom from a shell where conda was never initialised, neither is set.

**Can I add my own cache folder?**
Each task is a small function near the top of the script. `devcache_dirs` lists the cache
folders, so adding a line there is enough. Pull requests are welcome.

## Development

```sh
bash -n broom     # syntax check
./test.sh         # smoke test
```

`test.sh` builds a fake home folder in a temporary directory with old and new caches, stale and
active projects, and JetBrains version folders. It puts stub `uv`, `pnpm`, `conda` and `pipx`
first on a minimal `PATH`, then checks what `broom` keeps and deletes and which commands it runs.
It never touches your real files. Running
[ShellCheck](https://www.shellcheck.net/) (`shellcheck broom test.sh`) before a pull request is
appreciated.

broom replaces [linux-tools](https://github.com/matteospanio/linux-tools): `lt clean` becomes
`broom clean` and `lt update` becomes `broom update`.

## License

[MIT](LICENSE) © 2026 Matteo Spanio
