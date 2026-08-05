defmodule DocShell.Presentation.SearchEntry do
  @moduledoc """
  One searchable document, flattened to plain text.

  `tokens` is a pre-split lowercase form of `content`, and it is empty unless
  the producer was asked for it. The shipped Svelte shell indexes `title` and
  `content` itself and never reads them, while they cost roughly three quarters
  of the size of the text they duplicate — so paying for them by default was
  paying for nothing. Hosts wiring a search backend that wants the split form
  set `search_tokens: true`, either in `config :doc_shell` or as an option to
  `DocShell.Presentation.StaticGenerator`.

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
