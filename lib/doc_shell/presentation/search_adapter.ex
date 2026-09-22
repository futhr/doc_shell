defmodule DocShell.Presentation.SearchAdapter do
  @moduledoc """
  Build-time adapter for a validated, renderer-neutral search corpus.

  Adapters return local assets and an inert browser query contract. They do not
  receive a destination path, make network requests, or introduce a served
  runtime dependency.
  """

  alias DocShell.Presentation.{Asset, SiteSearchEntry}

  defmodule Output do
    @moduledoc """
    Returns local index assets together with their browser query contract.

    The contract describes how a renderer locates and interprets the assets; it
    is inert JSON data rather than a callback or hosted-service client.
    """

    @enforce_keys [:assets, :contract]
    defstruct [:assets, :contract]

    @typedoc "A deterministic search adapter result."
    @type t :: %__MODULE__{assets: [Asset.t()], contract: map()}
  end

  @doc "Builds local search assets and a browser-neutral query contract."
  @callback build([SiteSearchEntry.t()], keyword()) ::
              {:ok, Output.t()} | {:error, term()}
end

defimpl Jason.Encoder, for: DocShell.Presentation.SearchAdapter.Output do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
