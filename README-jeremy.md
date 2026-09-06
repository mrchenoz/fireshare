# Fork notes — mrchenoz/fireshare

Detached copy of [ShaneIsrael/fireshare](https://github.com/ShaneIsrael/fireshare) (`upstream` remote, fetch only). Purpose: install Fireshare on any machine with **one `uv tool install` and no Docker**, including old Intel MacBooks and a Raspberry Pi. Upstream ships a Docker image only.

| | |
|---|---|
| Branch | `feat/single-wheel`, merged into `main` |
| Build | `scripts/build_wheel.sh` → `dist/fireshare-<version>-py3-none-any.whl` (~1.8 MB) |
| Install | `uv tool install ./fireshare-1.7.9-py3-none-any.whl` |
| Run | `fireshare serve --videos ~/Videos --host 0.0.0.0 --port 8000` |
| Based on | upstream v1.7.9 + 8 commits (`fb005df`), 2026-09-06 |

## What this fork changes

1. **`python-ldap` is an extra, not a requirement.** It has no macOS wheels on PyPI and needs OpenLDAP headers plus a compiler at install time. The code already guards the import, so `pip install fireshare[ldap]` gets the old behaviour and the default install compiles nothing.
2. **The wheel is self-contained.** `scripts/build_wheel.sh` stages the built React client, the alembic `migrations/` folder and `gunicorn.conf.py` into the package before `uv build` (all three are gitignored inside the package; the source layout is unchanged so upstream merges stay cheap). `__init__.py` looks for migrations inside the package first, then at the repo root.
3. **`fireshare serve`**: runs gunicorn through the venv's interpreter with the packaged config, after applying migrations. Defaults for a non-Docker box: data under `~/.local/share/fireshare/{data,processed,images}`, a persisted `SECRET_KEY` (so logins survive restarts and are shared by workers), a generated admin password in `data/admin_password` (0600) unless `ADMIN_PASSWORD` is set, binds `127.0.0.1:8000` unless `--host 0.0.0.0`. It writes the resolved settings to `~/.local/share/fireshare/env`, which the other CLI commands (`scan-videos`, `add-user`, …) load, so they work without exporting anything.
4. **`fireshare db-upgrade`**: `flask db upgrade` without `FLASK_APP`.
5. **macOS fix in `gunicorn.conf.py`**: `worker_tmp_dir = /dev/shm` only where it exists.
6. **First-boot race fix in `create_app`**: several workers inserting the admin user at once no longer crash a worker (`IntegrityError` → rollback); `serve` also seeds the user once after migrations.

Not changed: Docker build, nginx layout, every feature. Upstream PRs are not a goal; this file is the trail.

## Build (once, on any machine with node and uv)

```bash
scripts/build_wheel.sh                # builds the client with npm, then the wheel
scripts/build_wheel.sh --reuse-client # skip npm if app/client/build exists
```

Version comes from `git describe --tags` (override with `FIRESHARE_VERSION=…`). Publish the wheel as a GitHub release asset so the Macs can fetch it by URL.

## Install on a machine (Intel/Apple Silicon Mac, Linux, Pi)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh          # once
uv tool install --python 3.12 https://github.com/mrchenoz/fireshare/releases/download/v1.7.9-wheel1/fireshare-1.7.9-py3-none-any.whl
# ffmpeg + ffprobe on PATH: Linux `pacman -S ffmpeg` / `apt install ffmpeg`;
# macOS without Homebrew: static builds from https://evermeet.cx/ffmpeg/ into ~/.local/bin
fireshare serve --videos ~/Videos --host 0.0.0.0 --port 8000
cat ~/.local/share/fireshare/data/admin_password   # first login: admin / <this>
```

Upgrade: `uv tool install --force <new wheel>`. Rollback: same with the previous wheel. Data and the database are untouched by either.

### Run at login

macOS, `~/Library/LaunchAgents/cc.mrchen.fireshare.plist` then `launchctl load` it:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>cc.mrchen.fireshare</string>
  <key>ProgramArguments</key><array>
    <string>/Users/USER/.local/bin/fireshare</string><string>serve</string>
    <string>--videos</string><string>/Users/USER/Videos</string>
    <string>--host</string><string>0.0.0.0</string><string>--port</string><string>8000</string>
  </array>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/Users/USER/.local/bin:/usr/local/bin:/usr/bin:/bin</string></dict>
  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/Users/USER/Library/Logs/fireshare.log</string>
  <key>StandardErrorPath</key><string>/Users/USER/Library/Logs/fireshare.log</string>
</dict></plist>
```

Linux / Pi, `~/.config/systemd/user/fireshare.service` then `systemctl --user enable --now fireshare` (and `loginctl enable-linger $USER` so it runs without a login session):

```ini
[Unit]
Description=Fireshare video library
After=network.target
[Service]
ExecStart=%h/.local/bin/fireshare serve --videos %h/Videos --host 0.0.0.0 --port 8000
Restart=on-failure
[Install]
WantedBy=default.target
```

## Verified 2026-09-06 (popeye, Arch, Python 3.12 via uv)

Clean `uv tool install` of the wheel into an empty tool dir, no compiler used; `fireshare serve --workers 4` on an empty database; `scan-videos` from the CLI via the env file; login with the generated password; video list, tag create + attach, list by tag, stream, poster; restart keeps the login. Install footprint 75 MB plus ffmpeg. Not yet run on macOS: the launchd plist and the static ffmpeg step are written from the docs, test them on the first Mac.

## Keeping up with upstream

`git fetch upstream && git merge upstream/main`. Conflicts expected only in `setup.py`, `cli.py` (new commands at the end of the file) and the two small hunks in `__init__.py` / `gunicorn.conf.py`. Rebuild the wheel after every merge.
