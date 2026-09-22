defmodule DocShell.Presentation.Conformance do
  @moduledoc """
  Shared fixtures and semantic snapshots for independent site renderers.

  HTML byte equality is deliberately absent. A renderer adapter records the
  portable semantics observed in its hosted or static surface; `compare/2`
  checks content identity, routes, headings, links, landmarks, accessible names
  and ordinary actions while allowing an honest unavailable static state for a
  live-only action.
  """

  alias DocShell.Presentation.Site

  @fixture "site-conformance-v1.json"
  @page_keys ~w(route content_digest visible_text headings links landmarks accessible_names actions)
  @required_page_keys ~w(route content_digest visible_text headings links landmarks accessible_names actions)

  defmodule Surface do
    @moduledoc """
    Captures renderer-observed semantics for one exact site generation.

    A renderer adapter extracts visible text, headings, links, landmarks,
    accessible names, and actions from its real output. The normalized value is
    intentionally smaller than a DOM, making parity meaningful across HTML
    frameworks without accepting content or accessibility drift.
    """

    @enforce_keys [:schema_version, :mode, :cohort_digest, :pages]
    defstruct @enforce_keys

    @typedoc "Hosted or static semantics normalized by a renderer adapter."
    @type t :: %__MODULE__{
            schema_version: String.t(),
            mode: :hosted | :static,
            cohort_digest: String.t(),
            pages: %{String.t() => map()}
          }
  end

  @doc "Returns the bundled renderer-conformance fixture path."
  @spec fixture_path() :: Path.t()
  def fixture_path do
    :doc_shell
    |> :code.priv_dir()
    |> to_string()
    |> Path.join("contracts/#{@fixture}")
  end

  @doc "Loads and validates the bundled renderer-conformance fixture."
  @spec fixture() :: {:ok, map()} | {:error, term()}
  def fixture do
    path = fixture_path()

    with {:ok, bytes} <- File.read(path),
         true <- byte_size(bytes) <= 1_048_576,
         {:ok, value} <- DocShell.Json.decode(bytes),
         true <- valid_fixture?(value) do
      {:ok, value}
    else
      false -> {:error, :invalid_conformance_fixture}
      {:error, reason} -> {:error, {:conformance_fixture, path, reason}}
    end
  end

  @doc "Builds a validated semantic surface from renderer-observed page records."
  @spec surface(Site.t(), :hosted | :static, map()) :: {:ok, Surface.t()} | {:error, term()}
  def surface(%Site{} = site, mode, pages) when mode in [:hosted, :static] and is_map(pages) do
    with true <- MapSet.new(Map.keys(pages)) == MapSet.new(Map.keys(site.pages)),
         {:ok, pages} <- validate_surface_pages(site, mode, pages) do
      {:ok,
       %Surface{
         schema_version: "doc-shell-renderer-surface/v1",
         mode: mode,
         cohort_digest: site.cohort_digest,
         pages: pages
       }}
    else
      false -> {:error, :renderer_surface_page_mismatch}
      {:error, _} = error -> error
    end
  end

  def surface(_, mode, _), do: {:error, {:invalid_renderer_surface, mode}}

  @doc "Compares hosted and static surfaces, including honest live-action degradation."
  @spec compare(Surface.t(), Surface.t()) :: :ok | {:error, term()}
  def compare(%Surface{mode: :hosted} = hosted, %Surface{mode: :static} = static) do
    with true <- hosted.schema_version == static.schema_version,
         true <- hosted.cohort_digest == static.cohort_digest,
         true <- MapSet.new(Map.keys(hosted.pages)) == MapSet.new(Map.keys(static.pages)),
         :ok <- compare_pages(hosted.pages, static.pages) do
      :ok
    else
      false -> {:error, :renderer_surface_identity_mismatch}
      {:error, _} = error -> error
    end
  end

  def compare(_, _), do: {:error, :invalid_renderer_surface_pair}

  defp validate_surface_pages(site, mode, pages) do
    Enum.reduce_while(pages, {:ok, %{}}, fn {id, page}, {:ok, valid} ->
      source = site.pages[id]

      with true <- is_map(page) and DocShell.Json.valid?(page),
           [] <- Map.keys(page) -- @page_keys,
           [] <- @required_page_keys -- Map.keys(page),
           true <- page["route"] == source.route,
           true <- page["content_digest"] == source.content_digest,
           true <- string_list?(page["headings"]),
           true <- string_list?(page["links"]),
           true <- string_list?(page["landmarks"]),
           true <- string_list?(page["accessible_names"]),
           true <- is_binary(page["visible_text"]),
           :ok <- validate_actions(page["actions"], mode) do
        {:cont, {:ok, Map.put(valid, id, page)}}
      else
        _ -> {:halt, {:error, {:invalid_renderer_surface_page, id}}}
      end
    end)
  end

  defp validate_actions(actions, mode) when is_list(actions) do
    ids = Enum.map(actions, &action_id/1)

    if Enum.all?(actions, &valid_action?(&1, mode)) and ids == Enum.uniq(ids),
      do: :ok,
      else: {:error, :invalid_renderer_actions}
  end

  defp validate_actions(_, _), do: {:error, :invalid_renderer_actions}

  defp valid_action?(
         %{
           "id" => id,
           "label" => label,
           "live_only" => live_only,
           "availability" => availability
         },
         mode
       ) do
    nonempty?(id) and nonempty?(label) and is_boolean(live_only) and
      availability in ["available", "unavailable"] and
      not (mode == :static and live_only and availability == "available")
  end

  defp valid_action?(_, _), do: false

  defp action_id(%{"id" => id}), do: id
  defp action_id(_), do: nil

  defp compare_pages(hosted, static) do
    Enum.reduce_while(hosted, :ok, fn {id, hosted_page}, :ok ->
      static_page = static[id]
      semantic_keys = @page_keys -- ["actions"]

      with true <- Map.take(hosted_page, semantic_keys) == Map.take(static_page, semantic_keys),
           :ok <- compare_actions(hosted_page["actions"], static_page["actions"]) do
        {:cont, :ok}
      else
        false -> {:halt, {:error, {:renderer_semantic_mismatch, id}}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp compare_actions(hosted, static) do
    hosted_ids = MapSet.new(hosted, & &1["id"])
    static_by_id = Map.new(static, &{&1["id"], &1})

    if Enum.all?(static, &MapSet.member?(hosted_ids, &1["id"])) do
      compare_hosted_actions(hosted, static_by_id)
    else
      {:error, :renderer_static_action_drift}
    end
  end

  defp compare_hosted_actions(hosted, static_by_id) do
    Enum.reduce_while(hosted, :ok, fn action, :ok ->
      id = action["id"]
      counterpart = static_by_id[id]

      cond do
        not action["live_only"] and counterpart == action ->
          {:cont, :ok}

        action["live_only"] and
            (is_nil(counterpart) or
               (counterpart["label"] == action["label"] and
                  counterpart["availability"] == "unavailable" and counterpart["live_only"])) ->
          {:cont, :ok}

        true ->
          {:halt, {:error, {:renderer_action_mismatch, id}}}
      end
    end)
  end

  defp valid_fixture?(%{
         "schema_version" => "doc-shell-renderer-conformance/v1",
         "features" => features,
         "states" => states,
         "unsafe_inputs" => unsafe
       }) do
    is_list(features) and features != [] and is_list(states) and
      Enum.sort(states) == ~w(connected enhanced fallback) and is_map(unsafe)
  end

  defp valid_fixture?(_), do: false

  defp string_list?(values), do: is_list(values) and Enum.all?(values, &nonempty?/1)
  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end

defimpl Jason.Encoder, for: DocShell.Presentation.Conformance.Surface do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
