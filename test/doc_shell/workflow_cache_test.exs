defmodule DocShell.WorkflowCacheTest do
  @moduledoc false
  use ExUnit.Case, async: true

  test "dependency keys and restore prefixes invalidate after either BEAM patch changes" do
    assert_patch_invalidation(caches("deps"))
  end

  test "PLT keys and restore prefixes invalidate after either BEAM patch changes" do
    assert_patch_invalidation(caches("priv/plts"))
  end

  defp assert_patch_invalidation(caches) do
    assert caches != []
    versions = %{otp: "29.0.4", elixir: "1.20.4"}

    for {job, template} <- caches do
      original = render(job, template, versions)
      otp_patch = render(job, template, %{versions | otp: "29.0.5"})
      elixir_patch = render(job, template, %{versions | elixir: "1.20.5"})

      refute original == otp_patch, "#{template} reuses a cache after an OTP patch change"
      refute original == elixir_patch, "#{template} reuses a cache after an Elixir patch change"
    end
  end

  defp caches(path) do
    for file <- ["ci.yml", "publish.yml"],
        {_, job} <- YamlElixir.read_from_file!(".github/workflows/" <> file)["jobs"],
        step <- job["steps"] || [],
        String.starts_with?(step["uses"] || "", "actions/cache@"),
        path in String.split(step["with"]["path"], "\n"),
        template <-
          [
            step["with"]["key"]
            | String.split(step["with"]["restore-keys"] || "", "\n", trim: true)
          ],
        do: {job, template}
  end

  defp render(job, template, versions) do
    setup = Enum.find(job["steps"], &String.starts_with?(&1["uses"] || "", "erlef/setup-beam@"))
    id = setup["id"]

    context = %{
      "runner.os" => "Linux",
      "matrix.otp" => "29",
      "matrix.elixir" => "1.20",
      "hashFiles('**/mix.lock')" => "lock-digest",
      "steps.#{id}.outputs.otp-version" => versions.otp,
      "steps.#{id}.outputs.elixir-version" => versions.elixir
    }

    Regex.replace(~r/\$\{\{\s*(.*?)\s*\}\}/, template, fn _, key ->
      Map.fetch!(context, String.trim(key))
    end)
  end
end
