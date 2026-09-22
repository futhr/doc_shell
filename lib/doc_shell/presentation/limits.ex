defmodule DocShell.Presentation.Limits do
  @moduledoc """
  Finite resource ceilings for site projection and static export.

  Hosts may lower or explicitly raise a ceiling with a positive integer. There
  is no unlimited sentinel. Limit errors name the resource, observed value and
  admitted maximum.
  """

  @defaults %{
    max_collections: 256,
    max_pages: 100_000,
    max_page_bytes: 8 * 1_024 * 1_024,
    max_ast_depth: 64,
    max_navigation_depth: 16,
    max_identity_bytes: 512,
    max_route_bytes: 2_048,
    max_redirects: 100_000,
    max_output_files: 250_000,
    max_file_bytes: 32 * 1_024 * 1_024,
    max_output_bytes: 2 * 1_024 * 1_024 * 1_024
  }

  @enforce_keys Map.keys(@defaults)
  defstruct Map.to_list(@defaults)

  @typedoc "Validated site resource ceilings."
  @type t :: %__MODULE__{
          max_collections: pos_integer(),
          max_pages: pos_integer(),
          max_page_bytes: pos_integer(),
          max_ast_depth: pos_integer(),
          max_navigation_depth: pos_integer(),
          max_identity_bytes: pos_integer(),
          max_route_bytes: pos_integer(),
          max_redirects: pos_integer(),
          max_output_files: pos_integer(),
          max_file_bytes: pos_integer(),
          max_output_bytes: pos_integer()
        }

  @doc "Builds a limits value from a closed keyword list of positive integers."
  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts \\ [])

  def new(opts) when is_list(opts) do
    maximum = :erlang.bsl(1, :erlang.system_info(:wordsize) * 8 - 1) - 1

    with true <- Keyword.keyword?(opts),
         [] <- Keyword.keys(opts) -- Map.keys(@defaults),
         values = Map.merge(@defaults, Map.new(opts)),
         true <-
           Enum.all?(values, fn {_, value} ->
             is_integer(value) and value > 0 and value <= maximum
           end) do
      {:ok, struct!(__MODULE__, values)}
    else
      _ -> {:error, {:invalid_presentation_limits, opts}}
    end
  end

  def new(opts), do: {:error, {:invalid_presentation_limits, opts}}

  @doc "Accepts an existing limits value or validates a keyword override list."
  @spec normalize(t() | keyword()) :: {:ok, t()} | {:error, term()}
  def normalize(%__MODULE__{} = limits) do
    limits
    |> Map.from_struct()
    |> Map.to_list()
    |> new()
  end

  def normalize(opts), do: new(opts)

  @doc "Checks one observed resource count against the corresponding ceiling."
  @spec check(t(), atom(), non_neg_integer()) :: :ok | {:error, term()}
  def check(%__MODULE__{} = limits, resource, observed)
      when is_integer(observed) and observed >= 0 do
    case Map.fetch(limits, resource) do
      {:ok, maximum} when observed <= maximum -> :ok
      {:ok, maximum} -> {:error, {:site_limit, resource, observed, maximum}}
      :error -> {:error, {:unknown_site_limit, resource}}
    end
  end

  def check(_, resource, observed), do: {:error, {:invalid_site_observation, resource, observed}}
end
