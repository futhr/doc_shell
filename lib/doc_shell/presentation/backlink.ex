defmodule DocShell.Presentation.Backlink do
  @moduledoc """
  A document that links to another, for rendering "referenced by" panels.

  Backlinks are the reverse of the links inside a document: given a page, which
  other pages point at it. They are what lets a reader landing on a low-level
  module page find the guide that explains when to use it.

  DocShell does not compute backlinks. Resolving a link in a document to the
  entry it refers to needs a routing scheme and a naming convention, and both
  belong to the host. What DocShell provides is the shape those relationships
  take on the wire, so that a graph-backed producer and a renderer agree
  without a private contract between them.

  The `backlinks` key is optional in `t:DocShell.Presentation.Source.presentation/0`
  precisely because most producers have nothing to put there. When present it
  maps an entry id to the entries referencing it, and
  `DocShell.Presentation.GraphProjector.validate/1` checks the shape.

  Only enough is carried to render a link — id, title, path. A renderer wanting
  more looks the referencing entry up in the navigation index.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          path: String.t()
        }

  @enforce_keys [:id, :title, :path]
  defstruct [:id, :title, :path]
end

defimpl Jason.Encoder, for: DocShell.Presentation.Backlink do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
