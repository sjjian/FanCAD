#!/usr/bin/env bash
#
# Runs the LibreDWG-backed DWG import/export tests.
#
# The default `dart test pkg/fancad_core` skips the `native` tag so a checkout
# without LibreDWG still passes. This script compiles the backend through the
# package build hook and then runs those tests for real, failing when the
# backend is not linked. Round trips live in pkg/fancad_core/integration_test and
# are not part of the default test directory.
#
# Usage:
#   pkg/fancad_core/tool/run_native_tests.sh
#   FANCAD_LIBREDWG_ROOT=/path/to/prefix pkg/fancad_core/tool/run_native_tests.sh
#
# With FANCAD_LIBREDWG_ROOT unset the hook builds the LibreDWG submodule, so run
# `git submodule update --init --recursive` first. See pkg/fancad_core/IO.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"

dart pub get
dart test pkg/fancad_core --tags native --run-skipped "$@"
dart test pkg/fancad_core/integration_test --tags native --run-skipped "$@"
