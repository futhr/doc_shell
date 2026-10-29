defmodule DocShell.Presentation.HostedPair do
  @moduledoc """
  Checks one host-admitted narrative/OpenAPI publication before rendering.

  The presentation's optional `publication` field and the OpenAPI extension
  `x-doc-shell-publication` carry identical string-keyed bindings. A binding has
  schema `doc-shell-publication/v1` and nonempty opaque `publication_id`,
  `source_view`, `graph_position`, `locale`, `release`, and `disclosure_surface`
  strings. Every field must also match the expected binding supplied by the
  host for this request. Thus two mutually consistent but stale inputs still
  fail when the host expects another publication.

  The host authenticates the request, admits both inputs and declares the
  expected view. This module compares those declarations and validates the
  existing presentation/OpenAPI shapes. It neither authenticates a binding nor
  discovers repositories, fetches sources, constructs collections or filters
  private content. Reusing a binding for altered source data violates the host's
  immutable-publication contract; equality is not proof of source authenticity.
  """

  alias DocShell.Generate.OpenApi
  alias DocShell.Presentation.{GraphProjector, Source}

  @fields ~w(publication_id source_view graph_position locale release disclosure_surface)
  @keys ["schema_version" | @fields]

  @typedoc "Host-declared immutable publication identity, with no authorization authority."
  @type binding :: %{String.t() => String.t()}

  @typedoc "Validated inputs retained together for one renderer call."
  @type t :: %{
          publication: binding(),
          presentation: Source.presentation(),
          openapi: map()
        }

  @doc "Validates a closed publication binding and its finite opaque fields."
  @spec validate_binding(term()) :: :ok | {:error, term()}
  def validate_binding(binding) do
    if is_map(binding) and Map.keys(binding) -- @keys == [] and
         binding["schema_version"] == "doc-shell-publication/v1" and
         Enum.all?(@fields, &field?(binding[&1])),
       do: :ok,
       else: {:error, :invalid_publication_binding}
  end

  @doc """
  Admits a typed graph presentation and OpenAPI document against the requested view.

  Bindings are required on both inputs and in `expected`. Shape validation and
  comparison complete before an `{:ok, pair}` is returned. Errors identify the
  input and mismatched field without returning its potentially private value.
  """
  @spec validate(term(), term(), term()) :: {:ok, t()} | {:error, term()}
  def validate(presentation, openapi, expected) when is_map(presentation) and is_map(openapi) do
    with :ok <- binding(expected, :expected),
         :ok <- binding(presentation[:publication], :presentation),
         :ok <- binding(openapi["x-doc-shell-publication"], :openapi),
         :ok <- compare(presentation[:publication], expected, :presentation),
         :ok <- compare(openapi["x-doc-shell-publication"], expected, :openapi),
         {:ok, presentation} <- GraphProjector.validate(presentation),
         :ok <- OpenApi.validate(openapi) do
      {:ok, %{publication: expected, presentation: presentation, openapi: openapi}}
    end
  end

  def validate(_, _, _), do: {:error, :invalid_hosted_pair}

  defp binding(value, side) do
    case validate_binding(value) do
      :ok -> :ok
      {:error, _} -> {:error, {:invalid_publication_binding, side}}
    end
  end

  defp compare(binding, expected, side) do
    case Enum.find(@fields, &(binding[&1] != expected[&1])) do
      nil -> :ok
      field -> {:error, {:publication_mismatch, side, field}}
    end
  end

  defp field?(value),
    do: is_binary(value) and value != "" and byte_size(value) <= 4096 and String.valid?(value)
end
