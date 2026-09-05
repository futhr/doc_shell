defmodule DocShell.Presentation.SearchEntry do
  @moduledoc """
  One searchable document, flattened to plain text.

  `tokens` is a pre-split lowercase form of `content`. It defaults to an empty
  list because many search engines tokenize the text themselves. Hosts that
  need precomputed tokens set `search_tokens: true` in `config :doc_shell` or
  the options to `DocShell.Presentation.StaticGenerator`. Enabling tokens
  increases the artifact size in exchange for doing that work at build time.

  `audience` and `locale` are null when the producer does not scope entries that
  way. They are always present so a renderer can filter without first checking
  which producer it is reading.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          content: String.t(),
          path: String.t(),
          kind: String.t() | nil,
          tokens: [String.t()],
          audience: String.t() | nil,
          locale: String.t() | nil
        }

  @enforce_keys [:id, :title, :content, :path]
  defstruct [:id, :title, :content, :path, kind: nil, tokens: [], audience: nil, locale: nil]
end

defimpl Jason.Encoder, for: DocShell.Presentation.SearchEntry do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
