/// The script that finishes a Linux update after the app has exited.
///
/// Windows hands off to the Inno Setup wizard and macOS hands off to the disk
/// image, so only Linux needs a helper: the tarball has no installer and the
/// running binary has to be replaced from outside the process.
///
/// Paths arrive as positional arguments, so nothing here has to quote a user
/// directory at generation time. The tests assert on the commands, because a
/// wrong `cp` flag breaks an install on someone else's machine.
///
/// The helper relaunches the installed app on every failure path: the process
/// that started it is already gone, so exiting quietly would look like FanCAD
/// crashed.
library;

/// Waits for `pid`, unpacks the tarball over the install directory and starts
/// the app again.
///
/// `$1` pid, `$2` tarball, `$3` bundle directory, `$4` executable name,
/// `$5` log file.
const String linuxInstallScript = r'''#!/bin/sh
set -eu
pid="$1"
archive="$2"
target="$3"
executable="$4"
log="$5"

waited=0
while kill -0 "$pid" 2>/dev/null; do
  sleep 0.3
  waited=$((waited + 1))
  if [ "$waited" -gt 100 ]; then
    break
  fi
done

relaunch() {
  "$target/$executable" >>"$log" 2>&1 &
}

work="$(mktemp -d "${TMPDIR:-/tmp}/fancad-update.XXXXXX")"
trap 'rm -rf "$work"' EXIT INT TERM

if ! tar -xzf "$archive" -C "$work" >>"$log" 2>&1; then
  echo "could not unpack the archive" >>"$log"
  relaunch
  exit 70
fi

if [ ! -x "$work/$executable" ]; then
  echo "the archive does not contain $executable" >>"$log"
  relaunch
  exit 70
fi

rm -rf "$target.old"
if ! mv "$target" "$target.old" >>"$log" 2>&1; then
  echo "could not move the current install aside" >>"$log"
  relaunch
  exit 70
fi

if ! mkdir -p "$target" >>"$log" 2>&1; then
  echo "could not recreate the install directory" >>"$log"
  mv "$target.old" "$target"
  relaunch
  exit 70
fi

if ! cp -a "$work/." "$target/" >>"$log" 2>&1; then
  echo "copy failed, restoring the previous version" >>"$log"
  rm -rf "$target"
  mv "$target.old" "$target"
  relaunch
  exit 70
fi

relaunch
''';
