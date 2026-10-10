#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
isolation_root="$(mktemp -d "${TMPDIR:-/tmp}/doc-shell-isolation.XXXXXX")"
trap 'rm -rf "$isolation_root"' EXIT
printf 'Caller-owned Mix path: must remain unchanged.\n' > "$isolation_root/expected"
for selector in build-path build-root deps-path; do
  cp "$isolation_root/expected" "$isolation_root/$selector"
done
MIX_BUILD_PATH="$isolation_root/build-path" \
MIX_BUILD_ROOT="$isolation_root/build-root" \
MIX_DEPS_PATH="$isolation_root/deps-path" \
  "$repo_dir/scripts/consumer_smoke.sh"
for selector in build-path build-root deps-path; do
  if ! cmp -s "$isolation_root/expected" "$isolation_root/$selector"; then
    echo "Packaged consumers changed caller-owned $selector" >&2
    exit 1
  fi
done
echo "Packaged consumers preserved inherited Mix paths"
