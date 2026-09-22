defmodule DocShell.Presentation.SiteProjection.Requirements do
  @moduledoc false

  alias DocShell.Presentation.Renderer.CapabilityRequirement

  @html_requirement %CapabilityRequirement{
    feature_id: "doc-shell/html/v1",
    acceptable_states: [:fallback],
    essential?: true
  }

  @doc false
  @spec derive([DocShell.Ast.ast_node()]) :: [CapabilityRequirement.t()]
  def derive(content) do
    extras =
      content
      |> feature_tags(MapSet.new())
      |> Enum.sort()
      |> Enum.map(fn feature ->
        %CapabilityRequirement{
          feature_id: feature,
          acceptable_states: [:fallback, :enhanced],
          essential?: false,
          fallback_digest: digest!(%{"feature" => feature, "content" => content})
        }
      end)

    [@html_requirement | extras]
  end

  defp feature_tags(nodes, acc) when is_list(nodes),
    do: Enum.reduce(nodes, acc, &feature_tags/2)

  defp feature_tags(%{"tag" => "pre", "content" => content}, acc) do
    acc = acc |> MapSet.put("doc-shell/copy/v1") |> MapSet.put("doc-shell/highlight/v1")
    feature_tags(content, acc)
  end

  defp feature_tags(%{"tag" => tag, "content" => content}, acc)
       when tag in ["tabs", "mermaid", "island", "request-execution"] do
    feature =
      case tag do
        "tabs" -> "doc-shell/tabs/v1"
        "mermaid" -> "doc-shell/mermaid/v1"
        "island" -> "doc-shell/island/v1"
        "request-execution" -> "doc-shell/request-execution/v1"
      end

    feature_tags(content, MapSet.put(acc, feature))
  end

  defp feature_tags(%{"content" => content}, acc), do: feature_tags(content, acc)
  defp feature_tags(_, acc), do: acc

  defp digest!(value) do
    {:ok, digest} = DocShell.Json.Canonical.digest(value)
    digest
  end
end
