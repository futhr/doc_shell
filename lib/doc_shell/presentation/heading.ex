defmodule DocShell.Presentation.Heading do
  @moduledoc """
  Identifies a heading after deterministic anchor projection.

  The site projector stores the same `id` in the page AST and this value. A
  renderer therefore uses the supplied anchor for the heading, table of
  contents, and incoming links instead of deriving its own slug.
  """

  @enforce_keys [:id, :title, :level]
  defstruct [:id, :title, :level]

  @typedoc "A stable heading anchor, plain-text title and HTML heading level."
  @type t :: %__MODULE__{id: String.t(), title: String.t(), level: 1..6}
end

defimpl Jason.Encoder, for: DocShell.Presentation.Heading do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
