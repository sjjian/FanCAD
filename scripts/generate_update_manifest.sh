#!/usr/bin/env bash
# Build the unsigned manifest for a release directory.
#
#   scripts/generate_update_manifest.sh 0.6.0 dist
#
# Only the installer files are listed. The manifest is signed afterwards with
# scripts/sign_update_manifest.sh and both files are uploaded to the release.
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <artifact-directory>" >&2
  exit 2
fi

version="$1"
directory="$2"

python3 - "$version" "$directory" <<'PY'
import hashlib
import json
import os
import sys

version, directory = sys.argv[1], sys.argv[2]
if not os.path.isdir(directory):
    raise SystemExit(f"error: {directory} is not a directory")

assets = []
for name in sorted(os.listdir(directory)):
    path = os.path.join(directory, name)
    if not os.path.isfile(path):
        continue
    if not name.startswith("fancad-") or not name.endswith((".dmg", ".exe", ".tar.gz")):
        continue
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    assets.append({
        "name": name,
        "sha256": digest.hexdigest(),
        "size": os.path.getsize(path),
    })

if not assets:
    raise SystemExit(f"error: no installer files in {directory}")

manifest = {"schema": 1, "version": version, "assets": assets}
path = os.path.join(directory, "manifest.json")
with open(path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, indent=2)
    handle.write("\n")
print(f"wrote {path} ({len(assets)} assets)")
PY
