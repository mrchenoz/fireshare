# CLAUDE.md

Fork of ShaneIsrael/fireshare whose only purpose is a self-contained wheel for `uv tool install`.
**Read README-jeremy.md first**: it lists every change from upstream and the build/verify steps.

- Build with `scripts/build_wheel.sh`; never commit `app/server/fireshare/{build,migrations,gunicorn.conf.py}`, they are staged copies.
- Keep changes small and at the edges of upstream files so `git merge upstream/main` stays cheap.
- After any change: rebuild the wheel, clean-install it with `UV_TOOL_DIR`/`UV_TOOL_BIN_DIR` pointed at an empty folder, run `fireshare serve --workers 4` on an empty database, and exercise login / scan / tag / stream through the API.
- `dev_root/` and anything under `~/.local/share/fireshare` is user data; never bulk-edit it.
