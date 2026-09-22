defmodule DocShell.Generate.Cohort do
  @moduledoc """
  Binds an ordered set of loaded collections to one site profile.

  The digest covers portable collection descriptors, their content digests and
  the profile. Local artifact directories, generation identifiers and build
  time never enter it, so rebuilding the same source cohort produces the same
  identity. Collection loading and source authenticity remain separate caller
  responsibilities; a cohort only identifies admitted portable content.
  """

  alias DocShell.Generate.Collection
  alias DocShell.Json.Canonical

  @enforce_keys [:profile, :collections, :digest]
  defstruct [:profile, :collections, :digest]

  @typedoc "A validated source cohort and its canonical SHA-256 identity."
  @type t :: %__MODULE__{
          profile: String.t(),
          collections: [Collection.loaded()],
          digest: String.t()
        }

  @doc "Validates loaded collections and computes their portable cohort digest."
  @spec new([Collection.loaded()], String.t()) :: {:ok, t()} | {:error, term()}
  def new(collections, profile) when is_list(collections) and is_binary(profile) do
    with :ok <- validate_profile(profile),
         :ok <- validate_collections(collections),
         {:ok, digest} <- Canonical.digest(payload(collections, profile)) do
      {:ok, %__MODULE__{profile: profile, collections: collections, digest: digest}}
    end
  end

  def new(collections, profile), do: {:error, {:invalid_cohort, collections, profile}}

  @doc "Returns the canonical, path-free payload used to identify a cohort."
  @spec payload([Collection.loaded()], String.t()) :: map()
  def payload(collections, profile) do
    %{
      "profile" => profile,
      "collections" =>
        Enum.map(collections, fn collection ->
          %{
            "descriptor" => Collection.portable_descriptor(collection.descriptor),
            "content_digest" => collection.content_digest
          }
        end)
    }
  end

  defp validate_profile(profile) do
    if Regex.match?(~r/\A[a-z0-9][a-z0-9._\/-]*\z/, profile),
      do: :ok,
      else: {:error, {:invalid_cohort_profile, profile}}
  end

  defp validate_collections(collections) do
    result =
      Enum.reduce_while(collections, {:ok, MapSet.new()}, fn collection, {:ok, ids} ->
        with {:ok, id} <- collection_id(collection),
             false <- MapSet.member?(ids, id) do
          {:cont, {:ok, MapSet.put(ids, id)}}
        else
          true -> {:halt, {:error, {:duplicate_collection_id, collection.descriptor.id}}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, ids} -> if(MapSet.size(ids) > 0, do: :ok, else: {:error, :empty_cohort})
      error -> error
    end
  end

  defp collection_id(
         %{
           descriptor: %Collection{id: id},
           content_digest: "sha256:" <> digest,
           documents: documents
         } = collection
       )
       when is_list(documents) and byte_size(digest) == 64 do
    with {:ok, %Collection{id: ^id}} <- Collection.new(collection.descriptor),
         true <- Regex.match?(~r/\A[0-9a-f]{64}\z/, digest) do
      {:ok, id}
    else
      false -> {:error, {:invalid_collection_content_digest, id}}
      {:error, _} -> {:error, {:invalid_loaded_collection, collection}}
    end
  end

  defp collection_id(collection), do: {:error, {:invalid_loaded_collection, collection}}
end
