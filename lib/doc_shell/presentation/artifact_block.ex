defmodule DocShell.Presentation.ArtifactBlock do
  @moduledoc """
  Projects typed external artifact blocks into verified presentation receipts.

  Blocks keep the four-key documentation AST and store their closed envelope
  inside `meta.artifact`. Their child AST is a complete safe textual fallback.
  Each invocation receives its own profiles, manifests, projections, local
  assets, capability declaration and runtime constraints. Loading this module
  starts nothing and registers nothing.

  ## Integrity and compatibility

  The fallback digest covers block identity, source binding, wording, language
  and fallback AST. Variant bytes have separate original-byte SHA-256 digests.
  Projection checks all advertised bytes before producer callbacks and refuses
  altered content. Unknown optional profiles can retain a verified fallback;
  essential unknown profiles refuse. Receipts are versioned separately from
  v1 collection, page and capability records.

  `project/2` performs no file or network I/O. Publication and actual renderer
  behavior remain separate checks in `DocShell.Presentation.StaticExporter`.
  """

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactAdmission, Asset}

  @block_keys ~w(schema_version profile profile_digest artifact_ref manifest_digest caption description locale bindings variants acceptable_states essential fallback_digest)
  @binding_keys ~w(anchor subject_ref subject_kind subject_id)
  @variant_keys ~w(id profile profile_digest state media_type blob_digest byte_length asset runtime)
  @fallback_keys ~w(profile profile_digest artifact_ref manifest_digest bindings caption description locale)
  @safe_tags ~w(p span strong em ul ol li dl dt dd code pre br)
  @options ~w(profiles manifests projections assets capabilities constraints)a

  @doc "Computes the canonical complete fallback binding for one typed AST block."
  @spec fallback_digest(map()) :: {:ok, String.t()} | {:error, term()}
  def fallback_digest(%{"attrs" => attrs, "content" => content, "meta" => %{"artifact" => block}})
      when is_map(attrs) and is_map(block) do
    block
    |> Map.take(@fallback_keys)
    |> Map.merge(%{"block_id" => attrs["id"], "fallback" => content})
    |> Canonical.digest()
  end

  def fallback_digest(_), do: {:error, :invalid_artifact_block}

  @doc "Finds typed blocks recursively and returns verified selections and local asset closure."
  @spec project([DocShell.Ast.ast_node()], keyword()) :: {:ok, map()} | {:error, term()}
  def project(content, opts) when is_list(opts) do
    with true <- Keyword.keyword?(opts) and Keyword.keys(opts) -- @options == [],
         true <- DocShell.Ast.valid?(content),
         true <-
           is_map(Keyword.get(opts, :manifests, %{})) and
             is_map(Keyword.get(opts, :projections, %{})),
         {:ok, profiles} <- profiles(Keyword.get(opts, :profiles, [])),
         :ok <- ArtifactAdmission.validate(opts[:capabilities], opts[:constraints]),
         {:ok, assets} <- assets(Keyword.get(opts, :assets, [])),
         {:ok, blocks} <- collect(content, []),
         true <- length(blocks) <= 256 and unique?(blocks, & &1["attrs"]["id"]),
         true <- anchors?(content, blocks),
         {:ok, receipts} <- project_blocks(blocks, profiles, assets, opts),
         {:ok, page_digest} <- Canonical.digest(content),
         {:ok, descriptor_digest} <- Canonical.digest(profile_descriptors(profiles)),
         {:ok, constraint_digest} <- Canonical.digest(opts[:constraints]) do
      {:ok,
       %{
         "schema_version" => "doc-shell-artifact-presentation/v1",
         "page_digest" => page_digest,
         "descriptor_set_digest" => descriptor_digest,
         "constraints_digest" => constraint_digest,
         "capabilities" => opts[:capabilities],
         "constraints" => opts[:constraints],
         "blocks" => receipts
       }}
    else
      false -> {:error, :invalid_artifact_projection}
      {:error, _} = error -> error
    end
  end

  def project(_, _), do: {:error, :invalid_artifact_projection}

  defp collect([], acc), do: {:ok, Enum.reverse(acc)}
  defp collect([%{"tag" => "artifact"} = node | rest], acc), do: collect(rest, [node | acc])

  defp collect([%{"content" => children} | rest], acc) do
    with {:ok, nested} <- collect(children, []), do: collect(rest, Enum.reverse(nested) ++ acc)
  end

  defp collect([_ | rest], acc), do: collect(rest, acc)

  defp anchors?(content, blocks) do
    anchors = anchors(content)

    bindings =
      Enum.flat_map(blocks, fn
        %{"meta" => %{"artifact" => %{"bindings" => values}}} when is_list(values) -> values
        _ -> [nil]
      end)

    unique?(anchors, & &1) and Enum.all?(bindings, &(is_map(&1) and &1["anchor"] in anchors))
  end

  defp anchors(nodes) when is_list(nodes), do: Enum.flat_map(nodes, &anchors/1)

  defp anchors(%{"attrs" => attrs, "content" => content}),
    do: List.wrap(attrs["id"]) ++ anchors(content)

  defp anchors(_), do: []

  defp profiles(modules) when is_list(modules) and length(modules) <= 128 do
    Enum.reduce_while(modules, {:ok, %{}}, fn module, {:ok, acc} ->
      with true <- is_atom(module) and Code.ensure_loaded?(module),
           true <-
             function_exported?(module, :describe, 0) and function_exported?(module, :validate, 2),
           {:ok, descriptor} <- invoke(module, :describe, []),
           true <- descriptor?(descriptor),
           {:ok, bytes} <- Canonical.encode(descriptor),
           true <- byte_size(bytes) <= 65_536,
           false <- Map.has_key?(acc, descriptor["profile"]),
           {:ok, digest} <- Canonical.digest(descriptor) do
        {:cont, {:ok, Map.put(acc, descriptor["profile"], {module, descriptor, digest})}}
      else
        _ -> {:halt, {:error, :invalid_artifact_profiles}}
      end
    end)
  end

  defp profiles(_), do: {:error, :invalid_artifact_profiles}

  defp descriptor?(value) when is_map(value),
    do:
      DocShell.Json.valid?(value) and text?(value["profile"]) and text?(value["revision"]) and
        digest?(value["input_schema_digest"]) and is_list(value["subject_vocabulary"]) and
        is_list(value["media_types"]) and text?(value["fallback"]) and is_map(value["limits"])

  defp descriptor?(_), do: false

  defp profile_descriptors(profiles),
    do: Map.new(profiles, fn {id, {_, descriptor, _}} -> {id, descriptor} end)

  defp assets(values) when is_list(values) and length(values) <= 4096 do
    Enum.reduce_while(values, {:ok, %{}}, fn asset, {:ok, acc} ->
      add_asset(asset, acc)
    end)
  end

  defp assets(_), do: {:error, :invalid_artifact_assets}

  defp add_asset(%Asset{path: path, bytes: bytes} = asset, acc) when is_binary(bytes) do
    if path?(path) and byte_size(bytes) <= 33_554_432 and
         not Map.has_key?(acc, String.downcase(path)),
       do: {:cont, {:ok, Map.put(acc, String.downcase(path), asset)}},
       else: {:halt, {:error, :invalid_artifact_assets}}
  end

  defp add_asset(_, _), do: {:halt, {:error, :invalid_artifact_assets}}

  defp project_blocks(blocks, profiles, assets, opts) do
    result =
      Enum.reduce_while(blocks, {:ok, []}, fn node, {:ok, acc} ->
        case project_block(node, profiles, assets, opts) do
          {:ok, result} -> {:cont, {:ok, [result | acc]}}
          {:error, reason} -> {:halt, {:error, {:artifact_block, node["attrs"]["id"], reason}}}
        end
      end)

    then(result, fn
      {:ok, results} -> {:ok, Enum.reverse(results)}
      error -> error
    end)
  end

  defp project_block(node, profiles, assets, opts) do
    block = node["meta"]["artifact"]

    with :ok <- envelope(node, block),
         {:ok, digest} <- fallback_digest(node),
         true <- block["fallback_digest"] == digest,
         true <-
           Enum.all?(
             block["variants"],
             &(&1["profile"] == block["profile"] and
                 &1["profile_digest"] == block["profile_digest"])
           ),
         :ok <- verify_variants(block["variants"], assets),
         {:ok, selection} <- producer(block, profiles, assets, opts) do
      {:ok,
       Map.merge(selection, %{
         "block_id" => node["attrs"]["id"],
         "profile" => block["profile"],
         "profile_digest" => block["profile_digest"],
         "artifact_ref" => block["artifact_ref"],
         "manifest_digest" => block["manifest_digest"],
         "bindings" => block["bindings"],
         "fallback_digest" => digest
       })}
    else
      false -> {:error, :artifact_fallback_digest_mismatch}
      {:error, _} = error -> error
    end
  end

  defp envelope(node, block) do
    valid =
      is_map(block) and keys?(block, @block_keys) and
        block["schema_version"] == "doc-shell-artifact-block/v1" and id?(node["attrs"]["id"]) and
        Enum.all?(~w(profile artifact_ref caption description locale), &text?(block[&1])) and
        Enum.all?(~w(profile_digest manifest_digest fallback_digest), &digest?(block[&1])) and
        envelope_content?(node, block)

    if valid, do: :ok, else: {:error, :invalid_artifact_block}
  end

  defp envelope_content?(node, block) do
    is_boolean(block["essential"]) and states?(block["acceptable_states"]) and
      records?(block["bindings"], 64, &binding?/1, "anchor") and
      records?(block["variants"], 16, &variant?/1, "id") and safe?(node["content"])
  end

  defp binding?(value),
    do:
      is_map(value) and keys?(value, @binding_keys) and id?(value["anchor"]) and
        Enum.all?(~w(subject_ref subject_kind subject_id), &text?(value[&1]))

  defp variant?(value) do
    is_map(value) and keys?(value, @variant_keys) and id?(value["id"]) and
      Enum.all?(~w(profile media_type), &text?(value[&1])) and
      Enum.all?(~w(profile_digest blob_digest), &digest?(value[&1])) and
      value["state"] in ~w(fallback enhanced connected) and path?(value["asset"]) and
      variant_limits?(value)
  end

  defp variant_limits?(value) do
    is_integer(value["byte_length"]) and value["byte_length"] > 0 and
      value["byte_length"] <= 33_554_432 and is_list(value["runtime"]) and
      value["runtime"] == Enum.uniq(value["runtime"]) and
      Enum.all?(value["runtime"], &(&1 in ~w(browser_js live_transport native_host)))
  end

  defp verify_variants(variants, assets) do
    if Enum.all?(variants, &verified?(&1, assets)),
      do: :ok,
      else: {:error, :artifact_variant_integrity}
  end

  defp verified?(variant, assets) do
    case Map.get(assets, String.downcase(variant["asset"])) do
      %Asset{path: path, media_type: media, bytes: bytes} ->
        path == variant["asset"] and media == variant["media_type"] and
          byte_size(bytes) == variant["byte_length"] and sha256(bytes) == variant["blob_digest"]

      _ ->
        false
    end
  end

  defp producer(block, profiles, assets, opts) do
    case Map.get(profiles, block["profile"]) do
      nil ->
        unknown(block)

      {module, descriptor, digest} ->
        checked_producer(block, {module, descriptor, digest}, assets, opts)
    end
  end

  defp unknown(%{"essential" => false, "acceptable_states" => states}) do
    if "fallback" in states,
      do: {:ok, %{"status" => "unavailable", "variant" => nil}},
      else: {:error, :unsupported_artifact_profile}
  end

  defp unknown(_), do: {:error, :unsupported_artifact_profile}

  defp checked_producer(block, {module, descriptor, digest}, assets, opts) do
    manifests = Keyword.get(opts, :manifests, %{})
    projections = Keyword.get(opts, :projections, %{})

    with true <- digest == block["profile_digest"],
         bytes when is_binary(bytes) <- Map.get(manifests, block["manifest_digest"]),
         true <- byte_size(bytes) <= 1_048_576 and sha256(bytes) == block["manifest_digest"],
         {:ok, manifest} <- DocShell.Json.decode(bytes),
         {:ok, {:ok, checked}} <-
           invoke(module, :validate, [
             block,
             %{
               manifest: manifest,
               projection: Map.get(projections, block["manifest_digest"]),
               assets: Map.values(assets)
             }
           ]),
         true <- checked?(checked, block),
         {:ok, selection} <-
           ArtifactAdmission.select(block, descriptor, opts[:capabilities], opts[:constraints]) do
      {:ok, Map.put(selection, "checked_projection", checked)}
    else
      _ -> {:error, :artifact_producer_validation}
    end
  end

  defp checked?(value, block) when is_map(value) do
    DocShell.Json.valid?(value) and value["profile"] == block["profile"] and
      value["artifact_ref"] == block["artifact_ref"] and
      value["manifest_digest"] == block["manifest_digest"] and
      is_list(value["subjects"]) and length(value["subjects"]) <= 64 and
      Enum.all?(value["subjects"], &binding?/1) and
      Enum.all?(block["bindings"], &(&1 in value["subjects"]))
  end

  defp checked?(_, _), do: false

  defp invoke(module, function, arguments) do
    {:ok, apply(module, function, arguments)}
  rescue
    _ -> {:error, :artifact_callback_failed}
  catch
    _, _ -> {:error, :artifact_callback_failed}
  end

  defp safe?(values) when is_list(values), do: values != [] and Enum.all?(values, &safe_node?/1)
  defp safe?(_), do: false
  defp safe_node?(text) when is_binary(text), do: String.valid?(text)

  defp safe_node?(%{"tag" => tag, "attrs" => attrs, "content" => content}) do
    tag in @safe_tags and is_map(attrs) and Map.keys(attrs) -- ["id"] == [] and
      (not Map.has_key?(attrs, "id") or id?(attrs["id"])) and
      is_list(content) and Enum.all?(content, &safe_node?/1)
  end

  defp safe_node?(_), do: false

  defp records?(values, limit, predicate, key),
    do:
      is_list(values) and length(values) <= limit and
        Enum.all?(values, predicate) and unique?(values, & &1[key])

  defp unique?(values, key), do: length(values) == length(Enum.uniq_by(values, key))
  defp keys?(value, keys), do: Enum.sort(Map.keys(value)) == Enum.sort(keys)

  defp states?(values),
    do:
      is_list(values) and values != [] and values == Enum.uniq(values) and
        Enum.all?(values, &(&1 in ~w(fallback enhanced connected)))

  defp path?(value),
    do:
      is_binary(value) and byte_size(value) <= 512 and
        Regex.match?(~r/\A[a-zA-Z0-9_.-]+(?:\/[a-zA-Z0-9_.-]+)*\z/, value) and
        Enum.all?(String.split(value, "/"), &(&1 not in [".", ".."]))

  defp text?(value),
    do: is_binary(value) and value != "" and byte_size(value) <= 4096 and String.valid?(value)

  defp id?(value), do: is_binary(value) and Regex.match?(~r/\A[a-z][a-z0-9._-]{0,127}\z/, value)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/\Asha256:[0-9a-f]{64}\z/, value)
  defp sha256(bytes), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)
end
