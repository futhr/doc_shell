defmodule DocShell.Presentation.SiteSource do
  @moduledoc """
  Defines the host-owned policy input to site projection.

  The callback returns inert page declarations keyed by qualified collection
  document IDs, plus optional navigation, redirects, locale policy, and site
  metadata. This is where a host chooses taxonomy, public routes, and exact
  source or edit links when its forge has provider-specific URL rules. DocShell
  then joins those declarations to source content and derives digests, headings,
  internal links, reading flow, search records, and capability requirements.

  A source must not render content, write files, authorize a request, or fetch a
  collection. It receives already loaded collections specifically so those
  side effects remain outside the presentation contract.
  """

  alias DocShell.Generate.Collection

  @doc "Returns inert site and page declarations for loaded collections."
  @callback project([Collection.loaded()], keyword()) :: {:ok, map()} | {:error, term()}
end
