defmodule DocShell.Presentation.Renderer.Context do
  @moduledoc """
  Carries inert site context into one renderer call.

  It supplies the already validated navigation tree, search contract, logical
  asset URLs, locale, current route, and source cohort identity. It deliberately
  has no request, user, session, socket, authorization callback, or application
  process. Hosted adapters keep those concerns outside the portable renderer
  boundary and pass only this stable view to shared components.
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
  defstruct @enforce_keys ++ [:canonical_origin]

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
          canonical_origin: String.t() | nil
        }
end

defimpl Jason.Encoder, for: DocShell.Presentation.Renderer.Context do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
