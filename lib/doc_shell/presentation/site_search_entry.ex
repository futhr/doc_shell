defmodule DocShell.Presentation.SiteSearchEntry do
  @moduledoc """
  Represents one page or heading in the portable site search corpus.

  Records retain the route and public filter dimensions needed by a browser or
  build-time indexer. They contain plain text rather than rendered markup, so a
  JSON adapter, Pagefind adapter, hosted search process, or test reference query
  can consume the same admitted corpus.
  """

  @enforce_keys [:id, :page_id, :route, :title, :text, :locale, :kind, :collection, :version]
  defstruct [
    :id,
    :page_id,
    :route,
    :title,
    :section,
    :text,
    :locale,
    :audience,
    :kind,
    :collection,
    :version,
    :status,
    tags: []
  ]

  @typedoc "A deterministic search record and its public filter dimensions."
  @type t :: %__MODULE__{
          id: String.t(),
          page_id: String.t(),
          route: String.t(),
          title: String.t(),
          section: String.t() | nil,
          text: String.t(),
          locale: String.t(),
          audience: String.t() | [String.t()] | nil,
          kind: String.t(),
          collection: String.t(),
          version: String.t(),
          status: String.t() | nil,
          tags: [String.t()]
        }
end

defimpl Jason.Encoder, for: DocShell.Presentation.SiteSearchEntry do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
