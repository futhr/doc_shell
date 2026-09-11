defmodule DocShell.Presentation.References do
  @moduledoc """
  Checks identity and reference consistency after presentation shape validation.

  Navigation groups may omit content when they have children. Absolute HTTP(S)
  links may refer to another site; other navigation leaves and search results
  need local content. IDs are unique within each index, and navigation/search
  paths for a shared ID must agree. Content need not appear in either index.

  Backlink targets must be local content. Their origins may belong to a host's
  wider graph, but a known origin cannot contradict its indexed path. This
  deliberately does not parse document links or impose a host routing policy.
  """

  @doc "Validates relationships in an already shape-checked presentation."
  @spec validate(DocShell.Presentation.Source.presentation()) :: :ok | {:error, term()}
  def validate(presentation) do
    with {:ok, navigation} <-
           index(presentation.navigation, :navigation, presentation.content, %{}),
         {:ok, search} <- index(presentation.search, :search, presentation.content, %{}),
         :ok <- agree(search, navigation) do
      backlinks(
        Map.get(presentation, :backlinks) || %{},
        presentation.content,
        Map.merge(navigation, search)
      )
    end
  end

  defp index(items, kind, content, seen) do
    Enum.reduce_while(items, {:ok, seen}, fn item, {:ok, acc} ->
      with :ok <- unique(acc, item.id, kind),
           :ok <- reference(item, kind, content),
           {:ok, next} <- children(item, kind, content, Map.put(acc, item.id, item.path)) do
        {:cont, {:ok, next}}
      else
        error -> {:halt, error}
      end
    end)
  end

  defp unique(seen, id, kind) do
    if Map.has_key?(seen, id), do: error({:duplicate_id, kind, id}), else: :ok
  end

  defp children(item, :navigation, content, seen),
    do: index(item.children, :navigation, content, seen)

  defp children(_, _, _, seen), do: {:ok, seen}

  defp reference(%{children: [_ | _]}, :navigation, _), do: :ok

  defp reference(item, kind, content) do
    if Map.has_key?(content, item.id) or external?(item.path),
      do: :ok,
      else: error({:missing_content, kind, item.id})
  end

  defp external?(path) do
    case URI.parse(path) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        true

      _ ->
        false
    end
  end

  defp agree(index, known) do
    Enum.reduce_while(index, :ok, fn {id, path}, :ok ->
      case Map.fetch(known, id) do
        {:ok, other} when other != path -> {:halt, error({:path_mismatch, id, other, path})}
        _ -> {:cont, :ok}
      end
    end)
  end

  defp backlinks(backlinks, content, known) do
    Enum.reduce_while(backlinks, :ok, fn {target, links}, :ok ->
      with true <- Map.has_key?(content, target),
           {:ok, origins} <- origin_index(links),
           :ok <- agree(origins, known) do
        {:cont, :ok}
      else
        false -> {:halt, error({:missing_content, :backlinks, target})}
        error -> {:halt, error}
      end
    end)
  end

  defp origin_index(links) do
    Enum.reduce_while(links, {:ok, %{}}, fn link, {:ok, seen} ->
      case unique(seen, link.id, :backlinks) do
        :ok -> {:cont, {:ok, Map.put(seen, link.id, link.path)}}
        error -> {:halt, error}
      end
    end)
  end

  defp error(reason), do: {:error, {:invalid_presentation, reason}}
end
