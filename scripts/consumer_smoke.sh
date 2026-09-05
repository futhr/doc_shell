#!/usr/bin/env bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
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
  cp "$repo_dir/mix.lock" "$consumer_dir/mix.lock"
  cat > "$consumer_dir/mix.exs" <<'MIX'
defmodule ConsumerSmoke.MixProject do
  use Mix.Project
  def project do
    integration = case System.fetch_env!("DOC_SHELL_INTEGRATION") do
      "core" -> []
      "plug" -> [{:plug, "~> 1.16"}]
      "ash" -> [{:ash_oaskit, "~> 0.4"}]
    end
    [app: :consumer_smoke, version: "0.1.0", deps:
      [{:doc_shell, path: System.fetch_env!("DOC_SHELL_PACKAGE")}] ++ integration]
  end
end
MIX
  cat > "$consumer_dir/smoke.exs" <<'SMOKE'
{:ok, result} = DocShell.Build.run(write: false, modules: [], guide_bases: [],
  livebook_base: "missing", changelog_source: nil)
"0.1.0" = result.openapi["info"]["version"]
expected_web = System.fetch_env!("DOC_SHELL_INTEGRATION") != "core"
^expected_web = Code.ensure_loaded?(DocShell.Web.Plug)
^expected_web = Code.ensure_loaded?(DocShell.Web.Controller)
^expected_web = Code.ensure_loaded?(DocShell.Web.Response)
true = Code.ensure_loaded?(DocShell.Web.Cache)
SMOKE
  (
    cd "$consumer_dir"
    export MIX_ENV=prod DOC_SHELL_PACKAGE="$consumer_root/package" DOC_SHELL_INTEGRATION="$integration"
    mix deps.get
    mix compile --warnings-as-errors
    mix run smoke.exs
  )
done
