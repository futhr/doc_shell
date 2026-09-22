defmodule DocShell.Presentation.Renderer do
  @moduledoc """
  Defines the boundary between a portable site and a concrete renderer.

  A renderer turns validated `Page` and `Site` values into output and declares
  the capabilities that output can honestly provide. `admit/3` compares those
  capabilities with requirements derived from page content before rendering.
  Unsupported essential content fails; optional content is admitted only when
  its declared fallback still matches the projected page.

  Renderers receive inert values and local logical assets. Authorization,
  application sessions, routing policy, deployment, and source collection stay
  with the host or projector. This behaviour therefore works for a hosted UI
  and a no-server static build without making either one the core abstraction.
  """

  alias DocShell.Presentation.{Asset, Page, Renderer, Site}

  @reserved_features ~w(
    doc-shell/html/v1
    doc-shell/search/v1
    doc-shell/theme/v1
    doc-shell/navigation/v1
    doc-shell/copy/v1
    doc-shell/tabs/v1
    doc-shell/highlight/v1
    doc-shell/mermaid/v1
    doc-shell/island/v1
    doc-shell/request-execution/v1
  )

  @doc "Renders one admitted page."
  @callback render_page(Page.t(), Renderer.Context.t()) ::
              {:ok, iodata()} | {:error, term()}

  @doc "Renders the site's not-found page."
  @callback render_not_found(Site.t(), Renderer.Context.t()) ::
              {:ok, iodata()} | {:error, term()}

  @doc "Returns local assets needed by this site generation."
  @callback assets(Site.t(), keyword()) :: {:ok, [Asset.t()]} | {:error, term()}

  @doc "Returns the renderer's normalized capability declaration."
  @callback capabilities() :: Renderer.Capabilities.t()

  @doc "Checks that a renderer can satisfy one page in an output mode."
  @spec admit(Page.t(), Renderer.Capabilities.t(), :hosted | :static) ::
          :ok | {:error, term()}
  def admit(%Page{} = page, %Renderer.Capabilities{} = capabilities, mode) do
    with :ok <- Renderer.Capabilities.validate(capabilities),
         true <- mode in capabilities.output_modes do
      admit_requirements(page.requirements, capabilities.features, mode, page.content)
    else
      false -> {:error, {:unsupported_output_mode, mode}}
      {:error, _} = error -> error
    end
  end

  def admit(_, _, mode), do: {:error, {:invalid_renderer_admission, mode}}

  @doc "Returns the closed DSH.01 feature identifiers reserved by DocShell."
  @spec reserved_features() :: [String.t()]
  def reserved_features, do: @reserved_features

  defp admit_requirements([], _, _, _), do: :ok

  defp admit_requirements([requirement | rest], features, mode, content) do
    with :ok <- Renderer.CapabilityRequirement.validate(requirement),
         :ok <- admit_requirement(requirement, features, mode, content) do
      admit_requirements(rest, features, mode, content)
    end
  end

  defp admit_requirements(_, _, _, _), do: {:error, :invalid_page_requirements}

  defp admit_requirement(requirement, features, mode, content) do
    case Map.fetch(features, requirement.feature_id) do
      {:ok, capability} -> match_state(requirement, capability, mode, content)
      :error -> missing_requirement(requirement, content)
    end
  end

  defp match_state(requirement, capability, mode, content) do
    allowed =
      capability.states
      |> Enum.filter(&(&1 in requirement.acceptable_states))
      |> Enum.reject(&(&1 == :connected and mode == :static))
      |> then(fn states ->
        if mode == :static and :live_transport in capability.runtime, do: [], else: states
      end)

    if allowed == [], do: missing_requirement(requirement, content), else: :ok
  end

  defp missing_requirement(%{essential?: false, fallback_digest: digest} = requirement, content) do
    expected =
      DocShell.Json.Canonical.digest(%{
        "feature" => requirement.feature_id,
        "content" => content
      })

    if expected == {:ok, digest},
      do: :ok,
      else: {:error, {:renderer_fallback_digest_mismatch, requirement.feature_id}}
  end

  defp missing_requirement(requirement, _),
    do: {:error, {:unsupported_renderer_capability, requirement.feature_id}}
end
