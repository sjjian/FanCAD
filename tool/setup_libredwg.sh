#!/usr/bin/env bash
# Initialize the LibreDWG submodule (and its nested jsmn submodule).
# The build hook compiles that tree automatically.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "LibreDWG is a git submodule; run this from a FanCAD git checkout." >&2
  exit 1
fi

git submodule update --init --recursive -- \
  pkg/fancad_io/native/third_party/libredwg
echo "LibreDWG submodule is ready at pkg/fancad_io/native/third_party/libredwg"
echo "The next flutter/dart build will compile it as a static library."
