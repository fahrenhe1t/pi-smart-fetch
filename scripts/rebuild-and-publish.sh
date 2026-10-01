#!/usr/bin/env bash
#
# rebuild-and-publish.sh
#
# Rebuilds pi-smart-fetch from the upstream monorepo fork, syncs the built
# dist/ + package.json into this standalone pi package, then commits and
# pushes so pi can consume it via a git: source.
#
# Layout:
#   ~/projects/agent-smart-fetch        <- monorepo fork (source of truth, has upstream)
#   ~/projects/pi-smart-fetch           <- this standalone pi package (what pi installs)
#
# After running, update the pinned commit in ~/.pi/agent/settings.json
# (the "git:github.com/fahrenhe1t/pi-smart-fetch@<sha>" entry) to the new SHA
# printed at the end, then restart pi.

set -euo pipefail

export PATH="$HOME/.bun/bin:$PATH"

MONOREPO="${PI_SMART_FETCH_MONOREPO:-$HOME/projects/agent-smart-fetch}"
PKG="${PI_SMART_FETCH_PKG:-$HOME/projects/pi-smart-fetch}"

command -v bun >/dev/null 2>&1 || { echo "ERROR: bun not found on PATH (expected ~/.bun/bin/bun)" >&2; exit 1; }
[ -d "$MONOREPO" ] || { echo "ERROR: monorepo fork not found at $MONOREPO" >&2; exit 1; }
[ -d "$PKG" ] || { echo "ERROR: standalone package dir not found at $PKG" >&2; exit 1; }

echo "==> 1/4 Building pi-smart-fetch in monorepo fork: $MONOREPO"
cd "$MONOREPO"
git fetch --all --quiet || echo "   (no remote fetch; continuing with local state)"
bun install --quiet
bun run build:pi

echo "==> 2/4 Syncing dist/ + package.json into standalone package: $PKG"
# The monorepo gitignores dist/; the standalone repo commits it, so we must copy it.
rm -rf "$PKG/dist"
cp -a "$MONOREPO/packages/pi-smart-fetch/dist" "$PKG/dist"
cp -a "$MONOREPO/packages/pi-smart-fetch/package.json" "$PKG/package.json"
# Keep the standalone package's own repo metadata (repository/homepage/bugs point here),
# so re-copy just the fields that can drift from the monorepo. The monorepo package.json
# and this one should already agree on deps/peers/pi; we take the monorepo's as source of
# truth for those, then restore the standalone-specific fields.
node - <<'NODE'
const fs = require("fs");
const path = require("path");
const p = path.resolve("package.json");
const j = JSON.parse(fs.readFileSync(p, "utf8"));
j.repository = { type: "git", url: "git+https://github.com/fahrenhe1t/pi-smart-fetch.git" };
j.homepage = "https://github.com/fahrenhe1t/pi-smart-fetch";
j.bugs = { url: "https://github.com/fahrenhe1t/pi-smart-fetch/issues" };
if (j.pi && j.pi.image) j.pi.image = "https://raw.githubusercontent.com/fahrenhe1t/pi-smart-fetch/main/demo.gif";
delete j.scripts; // standalone is consumed, not developed, via this repo
fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
console.log("   package.json normalized for standalone repo");
NODE

echo "==> 3/4 Committing"
cd "$PKG"
git add -A
if git diff --cached --quiet; then
  echo "   (no changes to commit — dist is identical to last publish)"
else
  git commit -m "build: refresh pi-smart-fetch dist from agent-smart-fetch fork"
fi

echo "==> 4/4 Pushing to origin"
git push origin main
NEW_SHA="$(git rev-parse --short HEAD)"

echo
echo "DONE. New commit: $NEW_SHA"
echo "Update ~/.pi/agent/settings.json to:"
echo "  \"git:github.com/fahrenhe1t/pi-smart-fetch@$NEW_SHA\""
echo "Then restart pi."
