#!/usr/bin/env bash
# Build a self-contained wheel: backend + built web client + migrations + gunicorn config.
# Needs: uv, and node/npm unless app/client/build already exists (pass --reuse-client).
#   scripts/build_wheel.sh            -> dist/fireshare-<version>-py3-none-any.whl
#   scripts/build_wheel.sh --reuse-client
set -euo pipefail
cd "$(dirname "$0")/.."
PKG=app/server/fireshare

if [[ "${1:-}" != "--reuse-client" || ! -d app/client/build ]]; then
  echo "[wheel] building web client"
  (cd app/client && npm ci --silent && npm run build)
fi

echo "[wheel] staging client build, migrations and gunicorn config into the package"
rm -rf "$PKG/build" "$PKG/migrations" "$PKG/gunicorn.conf.py"
cp -r app/client/build "$PKG/build"
cp -r migrations "$PKG/migrations"
cp app/server/gunicorn.conf.py "$PKG/gunicorn.conf.py"

cleanup() { rm -rf "$PKG/build" "$PKG/migrations" "$PKG/gunicorn.conf.py"; }
trap cleanup EXIT

VERSION="${FIRESHARE_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo 1.7.9)}"
echo "[wheel] version $VERSION"
mkdir -p dist
FIRESHARE_VERSION="$VERSION" uv build --wheel --out-dir dist app/server
ls -la dist/fireshare-"$VERSION"-py3-none-any.whl
