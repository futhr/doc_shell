defmodule DocShell.Presentation.Renderer.CapabilityRequirement do
  @moduledoc """
  States what a page needs from a renderer for one portable feature.

  Essential requirements must match a renderer capability. A nonessential
  requirement may fall back only when `fallback_digest` still identifies the
  exact projected feature and page content. This makes degradation explicit and
  guards against a renderer claiming support after silently dropping content.
  """

  @enforce_keys [:feature_id, :acceptable_states, :essential?]
  defstruct [:feature_id, :acceptable_states, :essential?, :fallback_digest]

  @typedoc "A normalized page capability requirement."
  @type t :: %__MODULE__{
          feature_id: String.t(),
          acceptable_states: [:fallback | :enhanced | :connected],
          essential?: boolean(),
          fallback_digest: String.t() | nil
        }

  @doc "Validates a page capability requirement."
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = requirement) do
    states = requirement.acceptable_states

    if is_binary(requirement.feature_id) and
         Regex.match?(~r/\A[a-z0-9][a-z0-9._\/-]*\z/, requirement.feature_id) and
         is_list(states) and states != [] and states == Enum.uniq(states) and
         Enum.all?(states, &(&1 in [:fallback, :enhanced, :connected])) and
         is_boolean(requirement.essential?) and valid_digest?(requirement.fallback_digest) do
      :ok
    else
      {:error, {:invalid_capability_requirement, requirement}}
    end
  end

  def validate(value), do: {:error, {:invalid_capability_requirement, value}}

  defp valid_digest?(nil), do: true

  defp valid_digest?("sha256:" <> digest),
    do: byte_size(digest) == 64 and Regex.match?(~r/\A[0-9a-f]{64}\z/, digest)

  defp valid_digest?(_), do: false
end

defimpl Jason.Encoder, for: DocShell.Presentation.Renderer.CapabilityRequirement do
  @impl Jason.Encoder
  def encode(value, opts), do: DocShell.Json.encode_struct(value, opts)
end
