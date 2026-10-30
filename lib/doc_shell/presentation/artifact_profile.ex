defmodule DocShell.Presentation.ArtifactProfile do
  @moduledoc """
  Defines an explicitly supplied validator for one portable artifact profile.

  A host supplies adapter modules per projection call. Descriptors are inert
  native JSON values; their canonical digest pins the producer contract.
  Adapters validate producer subject membership and completed variant coverage
  against caller-supplied original manifests and checked projections. They do
  not render, retrieve assets, start workers or register global capabilities.

  ## Results and ownership

  `validate/2` returns a checked JSON projection or a located tagged error.
  DocShell checks the generic block and byte envelope before dispatch and
  contains callback exceptions, throws, exits and malformed replies. Producer
  semantics and format-specific validation stay with this adapter's owner. Core
  rejects variant media and subject kinds outside the descriptor before invoking
  `validate/2`; returned subjects must use the same declared vocabulary.
  """

  @doc "Returns the immutable JSON descriptor for this producer profile."
  @callback describe() :: map()

  @doc "Checks producer identities, subject membership and selected artifact coverage."
  @callback validate(map(), map()) :: {:ok, map()} | {:error, term()}
end
