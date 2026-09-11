defmodule DocShell.Presentation.GraphProjector do
  @moduledoc """
  Port implemented by graph-backed hosts to produce DocShell presentation data.

  A host projector reads its own store and answers with the same
  `t:DocShell.Presentation.Source.presentation/0` the built-in generator
  produces. `project/2` checks the answer before returning it, because a
  projector lives in another repository: a shape mistake there would otherwise
  surface as a renderer bug in a third one.
  """

  alias DocShell.Presentation.Backlink
  alias DocShell.Presentation.NavigationItem
  alias DocShell.Presentation.References
  alias DocShell.Presentation.SearchEntry
  alias DocShell.Presentation.Source

  @callback project(keyword()) :: {:ok, Source.presentation()} | {:error, term()}

  @doc "Invokes a host graph projector, then validates the shape it returned."
  @spec project(module(), keyword()) :: {:ok, Source.presentation()} | {:error, term()}
  def project(module, opts) when is_atom(module) do
    with {:module, _} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :project, 1) do
      invoke(module, opts)
    else
      _ -> {:error, :graph_projector_unavailable}
    end
  end

  @doc """
  Checks a presentation against the contract.

  Returns `{:error, {:invalid_presentation, reason}}` rather than a boolean so a
  host sees which part of the shape it got wrong.
  """
  @spec validate(term()) :: {:ok, Source.presentation()} | {:error, term()}
  def validate(%{schema_version: version} = presentation) do
    with :ok <- check_version(version),
         :ok <- check_list(presentation[:navigation], NavigationItem, :navigation),
         :ok <- check_list(presentation[:search], SearchEntry, :search),
         :ok <- check_content(presentation[:content]),
         :ok <- check_backlinks(Map.get(presentation, :backlinks)),
         :ok <- References.validate(presentation) do
      {:ok, presentation}
    end
  end

  def validate(_), do: {:error, {:invalid_presentation, :missing_schema_version}}

  defp invoke(module, opts) do
    normalize_result(module.project(opts))
  rescue
    error -> {:error, {:graph_projector_failed, Exception.message(error)}}
  end

  defp normalize_result({:ok, presentation}), do: validate(presentation)
  defp normalize_result({:error, _} = error), do: error
  defp normalize_result(_), do: {:error, :invalid_graph_projector_result}

  defp check_version(version) do
    case version == DocShell.schema_version() do
      true -> :ok
      false -> {:error, {:invalid_presentation, {:unsupported_schema_version, version}}}
    end
  end

  defp check_list(values, struct, key) when is_list(values) do
    case all?(values, &valid_item?(&1, struct)) do
      true -> :ok
      false -> {:error, {:invalid_presentation, {key, :expected, struct}}}
    end
  end

  defp check_list(_, _, key), do: {:error, {:invalid_presentation, {key, :expected_a_list}}}

  defp check_content(content) when is_map(content) do
    case Enum.all?(content, fn {id, nodes} ->
           nonempty?(id) and DocShell.Ast.valid?(nodes)
         end) do
      true -> :ok
      false -> {:error, {:invalid_presentation, {:content, :expected_id_to_nodes}}}
    end
  end

  defp check_content(_), do: {:error, {:invalid_presentation, {:content, :expected_a_map}}}

  defp check_backlinks(nil), do: :ok

  defp check_backlinks(backlinks) when is_map(backlinks) do
    valid? =
      Enum.all?(backlinks, fn {id, links} ->
        nonempty?(id) and all?(links, &valid_item?(&1, Backlink))
      end)

    case valid? do
      true -> :ok
      false -> {:error, {:invalid_presentation, {:backlinks, :expected, Backlink}}}
    end
  end

  defp check_backlinks(_), do: {:error, {:invalid_presentation, {:backlinks, :expected_a_map}}}

  defp valid_item?(%NavigationItem{} = item, NavigationItem) do
    nonempty?(item.id) and nonempty?(item.title) and navigation_path?(item) and
      optional_string?(item.kind) and is_map(item.meta) and DocShell.Json.valid?(item.meta) and
      all?(item.children, &valid_item?(&1, NavigationItem))
  end

  defp valid_item?(%SearchEntry{} = item, SearchEntry) do
    nonempty?(item.id) and nonempty?(item.title) and valid_string?(item.content) and
      nonempty?(item.path) and optional_string?(item.kind) and
      all?(item.tokens, &valid_string?/1) and
      optional_string?(item.audience) and
      optional_string?(item.locale)
  end

  defp valid_item?(%Backlink{} = item, Backlink) do
    nonempty?(item.id) and nonempty?(item.title) and nonempty?(item.path)
  end

  defp valid_item?(_, _), do: false

  defp valid_string?(value), do: is_binary(value) and String.valid?(value)

  defp nonempty?(value), do: valid_string?(value) and value != ""
  defp navigation_path?(%{path: "", children: [_ | _]}), do: true
  defp navigation_path?(item), do: nonempty?(item.path)
  defp all?([], _), do: true
  defp all?([head | tail], fun), do: fun.(head) and all?(tail, fun)
  defp all?(_, _), do: false

  defp optional_string?(value), do: is_nil(value) or valid_string?(value)
end
