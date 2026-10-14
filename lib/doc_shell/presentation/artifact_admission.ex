defmodule DocShell.Presentation.ArtifactAdmission do
  @moduledoc """
  Selects a completed artifact variant under explicit runtime constraints.

  The v2 declaration assigns runtime requirements to each presentation rather
  than inheriting one list across fallback and enhancement. Selection is
  deterministic: caller preferences precede lexical presentation IDs. A static
  mode excludes connected output and live transport. Nothing here discovers
  runtimes or grants permission; the host supplies their actual availability.
  Legacy renderer admission remains in `DocShell.Presentation.Renderer`.
  """

  @runtime ~w(browser_js live_transport native_host)
  @states ~w(fallback enhanced connected)
  @modes ~w(static hosted)

  @doc "Validates a separately versioned capability declaration and caller constraints."
  @spec validate(map(), map()) :: :ok | {:error, term()}
  def validate(capabilities, constraints) do
    with true <- is_map(capabilities) and is_map(constraints),
         true <- capabilities["schema_version"] == "doc-shell-renderer-capabilities/v2",
         true <- text?(capabilities["renderer_id"]),
         true <- text?(capabilities["renderer_version"]),
         true <- unique?(capabilities["output_modes"], @modes),
         true <- is_list(capabilities["features"]) and length(capabilities["features"]) <= 128,
         true <- Enum.all?(capabilities["features"], &feature?/1),
         true <- unique_ids?(capabilities["features"]),
         true <- constraints["output_mode"] in capabilities["output_modes"],
         true <- Map.get(constraints, "reader_mode", "web") in ["web", "file"],
         true <- unique?(constraints["available_runtime"], @runtime),
         true <- unique?(constraints["forbidden_runtime"], @runtime),
         true <- strings?(constraints["preferences"]),
         true <- DocShell.Json.valid?(capabilities) and DocShell.Json.valid?(constraints) do
      :ok
    else
      _ -> {:error, :invalid_artifact_admission}
    end
  end

  @doc "Selects an admitted presentation and variant, or reports unavailable essential content."
  @spec select(map(), map(), map(), map()) :: {:ok, map()} | {:error, term()}
  def select(block, descriptor, capabilities, constraints) do
    alternatives =
      capabilities["features"]
      |> Enum.filter(&matches?(&1, block, descriptor, constraints))
      |> Enum.flat_map(&variants(&1, block))
      |> Enum.sort_by(&rank(&1, constraints["preferences"]))

    case alternatives do
      [selection | _] -> {:ok, Map.put(selection, "status", "available")}
      [] -> unavailable(block)
    end
  end

  defp matches?(feature, block, descriptor, constraints) do
    feature["profile"] == block["profile"] and
      feature["profile_digest"] == block["profile_digest"] and
      feature["schema_digest"] == descriptor["input_schema_digest"] and
      feature["output_mode"] == constraints["output_mode"] and
      feature["state"] in block["acceptable_states"] and
      Enum.all?(feature["runtime"], &(&1 in constraints["available_runtime"])) and
      Enum.all?(feature["runtime"], &(&1 not in constraints["forbidden_runtime"])) and
      static_allowed?(feature, constraints)
  end

  defp static_allowed?(feature, %{"output_mode" => "static"}),
    do: feature["state"] != "connected" and "live_transport" not in feature["runtime"]

  defp static_allowed?(_, _), do: true

  defp variants(feature, block) do
    block["variants"]
    |> Enum.filter(fn variant ->
      variant["state"] == feature["state"] and
        variant["media_type"] in feature["media_types"] and
        variant["runtime"] == feature["runtime"]
    end)
    |> Enum.map(&%{"presentation_id" => feature["id"], "variant" => &1})
  end

  defp rank(selection, preferences) do
    {Enum.find_index(preferences, &(&1 == selection["presentation_id"])) || length(preferences),
     selection["presentation_id"], selection["variant"]["id"]}
  end

  defp unavailable(%{"essential" => false, "acceptable_states" => states}) do
    if "fallback" in states,
      do: {:ok, %{"status" => "unavailable", "variant" => nil}},
      else: {:error, :unsupported_artifact_presentation}
  end

  defp unavailable(_), do: {:error, :unsupported_artifact_presentation}

  defp feature?(feature) when is_map(feature) do
    required = ~w(id profile profile_digest schema_digest output_mode state media_types runtime)

    Enum.sort(Map.keys(feature)) == Enum.sort(required) and
      Enum.all?(~w(id profile), &text?(feature[&1])) and
      digest?(feature["profile_digest"]) and digest?(feature["schema_digest"]) and
      feature["output_mode"] in @modes and feature["state"] in @states and
      strings?(feature["media_types"]) and feature["media_types"] != [] and
      unique?(feature["runtime"], @runtime)
  end

  defp feature?(_), do: false
  defp unique_ids?(features), do: length(features) == length(Enum.uniq_by(features, & &1["id"]))
  defp strings?(values), do: is_list(values) and Enum.all?(values, &text?/1)

  defp unique?(values, vocabulary),
    do: is_list(values) and values == Enum.uniq(values) and Enum.all?(values, &(&1 in vocabulary))

  defp text?(value), do: is_binary(value) and value != "" and byte_size(value) <= 2048
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/\Asha256:[0-9a-f]{64}\z/, value)
end
