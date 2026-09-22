defmodule DocShell.Presentation.SiteSource.Default do
  @moduledoc """
  Supplies a deterministic flat site policy for zero-configuration consumers.

  Every loaded document receives a route based on collection, kind, and source
  identity. Changelog entries stay searchable but are left out of the default
  navigation. Hosts that need branded routes, sections, audiences, or explicit
  navigation implement `DocShell.Presentation.SiteSource` instead.
  """

  @behaviour DocShell.Presentation.SiteSource

  @impl DocShell.Presentation.SiteSource
  def project(collections, opts) do
    pages =
      Enum.flat_map(collections, fn collection ->
        Enum.map(collection.documents, fn document ->
          %{
            "id" => document["id"],
            "route" => route(document),
            "navigation" => document["kind"] != "changelog",
            "search" => true
          }
        end)
      end)

    {:ok,
     %{
       "title" => Keyword.get(opts, :title, "Documentation"),
       "base_path" => Keyword.get(opts, :base_path, "/"),
       "default_locale" => Keyword.get(opts, :default_locale, "en"),
       "locales" => Keyword.get(opts, :locales, [Keyword.get(opts, :default_locale, "en")]),
       "pages" => pages,
       "redirects" => %{},
       "metadata" => %{}
     }}
  end

  defp route(document) do
    collection = URI.encode(document["collection_id"], &URI.char_unreserved?/1)
    kind = URI.encode(document["kind"], &URI.char_unreserved?/1)
    id = URI.encode(document["document_id"], &URI.char_unreserved?/1)
    "/#{collection}/#{kind}/#{id}/"
  end
end
