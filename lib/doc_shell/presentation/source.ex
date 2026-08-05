defmodule DocShell.Presentation.Source do
  @moduledoc """
  Producer contract for source-independent documentation presentation data.

  A producer answers `project/1` with a `t:presentation/0`, whatever it reads
  from — authored entries, a knowledge graph, or anything else. The renderer
  never learns which.

  ## Why structs

  These were maps with string keys, typed `[map()]`, which described nothing.
  Two producers drifted apart under that spec without anything noticing: one
  emitted `kind`, `meta`, and `tokens`, the other omitted all three, so the
  renderer's TypeScript had to guess — and guessed wrong on all of them.

  Structs make the shape a compile-time fact. The wire form is unchanged —
  `DocShell.Json.stringify/1` renders them as the same string-keyed JSON — but
  every producer now emits the same keys, with `nil` where a facet does not
  apply, so an artifact no longer depends on who wrote it.
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
end
