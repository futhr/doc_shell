#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
dependency_mode="${DOC_SHELL_DEPENDENCIES:-locked}"
case "$dependency_mode" in
  locked|unlocked|minimum) ;;
  *) echo "DOC_SHELL_DEPENDENCIES must be locked, unlocked, or minimum" >&2; exit 1 ;;
esac
consumer_root="$(mktemp -d "${TMPDIR:-/tmp}/doc-shell-consumer.XXXXXX")"
trap 'rm -rf "$consumer_root"' EXIT
cd "$repo_dir"
MIX_ENV=dev mix hex.build --output "$consumer_root/package.tar"
mkdir "$consumer_root/outer" "$consumer_root/package"
tar -xf "$consumer_root/package.tar" -C "$consumer_root/outer"
tar -xzf "$consumer_root/outer/contents.tar.gz" -C "$consumer_root/package"
for integration in core plug ash; do
  consumer_dir="$consumer_root/$integration"
  mkdir -p "$consumer_dir/deps"
  cp -R "$repo_dir/deps/." "$consumer_dir/deps/"
  if [[ "$dependency_mode" == locked ]]; then
    cp "$repo_dir/mix.lock" "$consumer_dir/mix.lock"
  fi
  cp "$repo_dir/scripts/consumer/mix.exs" "$consumer_dir/mix.exs"
  cp "$repo_dir/scripts/consumer/smoke.exs" "$consumer_dir/smoke.exs"
  (
    cd "$consumer_dir"
    export MIX_ENV=prod DOC_SHELL_PACKAGE="$consumer_root/package" DOC_SHELL_INTEGRATION="$integration"
    export DOC_SHELL_DEPENDENCIES="$dependency_mode"
    echo "Checking $integration consumer with $dependency_mode dependencies"
    mix deps.get
    mix hex.audit
    mix deps
    mix compile --warnings-as-errors
    mix run smoke.exs
  )
done
