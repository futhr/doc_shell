defmodule DocShell.Presentation.Source do
  @moduledoc """
  Producer contract for source-independent documentation presentation data.

  A producer answers `project/1` with a `t:presentation/0`, whatever it reads
  from — authored entries, a knowledge graph, or anything else. The renderer
  never learns which.

  Presentation structs provide a common set of fields and defaults for all
  producers. Their `Jason.Encoder` implementations emit the string-keyed JSON
  contract, including null facets. `DocShell.Presentation.GraphProjector`
  validates field types, recursive AST content, and JSON metadata at runtime.

  Optional backlinks are available in the in-memory result. The build writes
  navigation, search, and content artifacts; it does not serialize backlinks.
  """

  alias DocShell.Presentation.Backlink
  alias DocShell.Presentation.NavigationItem
  alias DocShell.Presentation.SearchEntry

  @typedoc """
  A renderer-neutral documentation artifact.

  `content` maps an entry id to its AST nodes; `backlinks` maps an entry id to
  the entries that reference it.
  """
  @type presentation :: %{
          required(:schema_version) => String.t(),
          required(:navigation) => [NavigationItem.t()],
          required(:search) => [SearchEntry.t()],
          required(:content) => %{optional(String.t()) => [DocShell.Ast.ast_node()]},
          optional(:backlinks) => %{optional(String.t()) => [Backlink.t()]}
        }

  @callback project(keyword()) :: {:ok, presentation()} | {:error, term()}
  @doc "Rejects duplicate document IDs, retaining source locations in the error."
  @spec validate_ids([map()]) :: :ok | {:error, term()}
  def validate_ids(entries) do
    case Enum.reduce_while(entries, {:ok, %{}}, &collect_id/2) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  defp collect_id(%{"id" => id} = entry, {:ok, seen}) when is_binary(id) and id != "" do
    source = get_in(entry, ["meta", "source_path"]) || id

    case Map.fetch(seen, id) do
      {:ok, previous} -> {:halt, {:error, {:duplicate_document_id, id, [previous, source]}}}
      :error -> {:cont, {:ok, Map.put(seen, id, source)}}
    end
  end

  defp collect_id(entry, _), do: {:halt, {:error, {:invalid_document_id, entry}}}
end
