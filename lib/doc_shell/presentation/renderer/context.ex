defmodule DocShell.Presentation.Renderer.Context do
  @moduledoc """
  Carries inert site context into one renderer call.

  It supplies the already validated navigation tree, search contract, logical
  asset URLs, locale, current route, and source cohort identity. It deliberately
  has no request, user, session, socket, authorization callback, or application
  process. Hosted adapters keep those concerns outside the portable renderer
  boundary and pass only this stable view to shared components.

  `artifact_assets` contains only selected artifact bytes, indexed by logical
  name as JSON records with `media_type` and original `base64`. Renderers can
  check their format and raw digest without reading files or fetching URLs.
  The exporter bounds inputs before this encoding; renderer chrome retains its
  existing URL map in `assets`.
  """

  alias DocShell.Presentation.NavigationItem

  @enforce_keys [
    :site_title,
    :cohort_digest,
    :base_path,
    :current_route,
    :locale,
    :navigation,
    :search,
    :assets
  ]
  defstruct @enforce_keys ++ [:canonical_origin, presentation: %{}, artifact_assets: %{}]

  @typedoc "Renderer context without session, policy or executable callbacks."
  @type t :: %__MODULE__{
          site_title: String.t(),
          cohort_digest: String.t(),
          base_path: String.t(),
          current_route: String.t(),
          locale: String.t(),
          navigation: [NavigationItem.t()],
          search: map(),
          assets: %{String.t() => String.t()},
          canonical_origin: String.t() | nil,
          presentation: DocShell.Presentation.Settings.t(),
          artifact_assets: %{
            String.t() => %{required(String.t()) => String.t()}
          }
        }
end

defimpl Jason.Encoder, for: DocShell.Presentation.Renderer.Context do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
