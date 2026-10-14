defmodule DocShell.Artifact.Encoded do
  @moduledoc """
  Holds JSON bytes that have already been encoded and are written verbatim.

  A build encodes every artifact exactly once. The same canonical bytes are
  hashed for `collection.json` and spliced into the file's envelope, so neither
  the digest nor the write encodes the payload again. Wrapping those bytes in a
  struct lets `DocShell.Artifact.write_raw/3` and
  `DocShell.Artifact.Transaction.write/2` tell them apart from a JSON term that
  still needs encoding.

  `iodata` is never flattened into a single binary: writers pass it straight to
  the file descriptor, which keeps a large artifact from being copied in memory
  before it reaches disk. Build one with `DocShell.Artifact.encode/2` or
  `DocShell.Artifact.encode_envelope/4` rather than by hand, so the bytes are
  guaranteed to be valid JSON.
  """

  @typedoc "Encoded JSON bytes, including the trailing newline."
  @type t :: %__MODULE__{iodata: iodata()}

  @enforce_keys [:iodata]
  defstruct [:iodata]
end
