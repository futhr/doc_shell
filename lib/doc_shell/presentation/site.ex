defmodule DocShell.Presentation.Site do
  @moduledoc """
  Contains one validated `doc-shell-site/v1` generation.

  A site binds an exact collection cohort to pages, routes, navigation, search,
  redirects, locale policy, and host metadata. `cohort_digest` identifies the
  source and profile content deterministically; `generation_id` distinguishes
  publication attempts. Renderers consume this value without reading collection
  directories or repeating visibility and route decisions.
  """

  alias DocShell.Presentation.{NavigationItem, Page, SiteSearchEntry}

  @enforce_keys [
    :schema_version,
    :generation_id,
    :cohort_digest,
    :profile,
    :title,
    :base_path,
    :default_locale,
    :locales,
    :pages,
    :routes,
    :navigation,
    :search,
    :redirects,
    :metadata
  ]
  defstruct @enforce_keys

  @typedoc "A portable site generation with one coherent source cohort."
  @type t :: %__MODULE__{
          schema_version: String.t(),
          generation_id: String.t(),
          cohort_digest: String.t(),
          profile: String.t(),
          title: String.t(),
          base_path: String.t(),
          default_locale: String.t(),
          locales: [String.t()],
          pages: %{String.t() => Page.t()},
          routes: %{String.t() => String.t()},
          navigation: [NavigationItem.t()],
          search: [SiteSearchEntry.t()],
          redirects: %{String.t() => String.t()},
          metadata: map()
        }

  @doc "Returns the portable site schema identifier."
  @spec schema_version() :: String.t()
  def schema_version, do: "doc-shell-site/v1"
end

defimpl Jason.Encoder, for: DocShell.Presentation.Site do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
