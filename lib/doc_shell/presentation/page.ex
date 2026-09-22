defmodule DocShell.Presentation.Page do
  @moduledoc """
  Holds the complete renderer-neutral record for one documentation page.

  It joins one qualified source document to its canonical route, anchored AST,
  provenance, locale and audience, search/navigation visibility, reading flow,
  and renderer capability requirements. All local links and heading anchors are
  resolved before the value is returned by `DocShell.Presentation.SiteProjector`.

  A page never carries raw head HTML, executable callbacks, scripts, framework
  component names, application sessions, or authorization decisions. `metadata`,
  `banner`, and `hero` remain inert JSON records; their interpretation belongs to
  the selected host profile and renderer. Source and edit URLs are inert links:
  DocShell validates them but never assumes a source-hosting provider.
  """

  alias DocShell.Presentation.{Breadcrumb, Heading, Link}
  alias DocShell.Presentation.Renderer.CapabilityRequirement

  @enforce_keys [
    :id,
    :collection_id,
    :document_id,
    :kind,
    :route,
    :title,
    :locale,
    :template,
    :content,
    :content_digest
  ]
  defstruct [
    :id,
    :collection_id,
    :document_id,
    :kind,
    :route,
    :title,
    :description,
    :locale,
    :audience,
    :template,
    :content,
    :content_digest,
    :canonical_url,
    :source_url,
    :edit_url,
    :source_revision,
    :source_path,
    :package_version,
    :last_modified,
    :status,
    :previous,
    :next,
    :banner,
    :hero,
    breadcrumbs: [],
    headings: [],
    tags: [],
    metadata: %{},
    navigation?: true,
    search?: true,
    requirements: []
  ]

  @typedoc "A validated page ready for any conforming renderer."
  @type t :: %__MODULE__{
          id: String.t(),
          collection_id: String.t(),
          document_id: String.t(),
          kind: String.t(),
          route: String.t(),
          title: String.t(),
          description: String.t() | nil,
          locale: String.t(),
          audience: String.t() | [String.t()] | nil,
          template: :document | :splash,
          content: [DocShell.Ast.ast_node()],
          content_digest: String.t(),
          canonical_url: String.t() | nil,
          source_url: String.t() | nil,
          edit_url: String.t() | nil,
          source_revision: String.t(),
          source_path: String.t() | nil,
          package_version: String.t(),
          last_modified: String.t() | nil,
          status: String.t() | nil,
          breadcrumbs: [Breadcrumb.t()],
          headings: [Heading.t()],
          previous: Link.t() | nil,
          next: Link.t() | nil,
          tags: [String.t()],
          metadata: map(),
          navigation?: boolean(),
          search?: boolean(),
          banner: map() | nil,
          hero: map() | nil,
          requirements: [CapabilityRequirement.t()]
        }
end

defimpl Jason.Encoder, for: DocShell.Presentation.Page do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
