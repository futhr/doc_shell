defmodule DocShell.Generate.Collection.Descriptor do
  @moduledoc """
  Validates caller-owned collection identity independently of corpus I/O.

  The public struct stays in `DocShell.Generate.Collection` for compatibility.
  This module handles only descriptor fields and their portable representation;
  it never reads artifacts, resolves source revisions, or contacts source URLs.
  Atom and string field names are accepted, but aliases that collide are errors
  so caller identity cannot depend on map enumeration order.
  """

  alias DocShell.Generate.Collection

  @digest_prefix "sha256:"
  @required ~w(id title version revision tree_digest artifact_dir source_url edit_base_url)a
  @optional ~w(package license default_locale audience source_root status)a
  @fields @required ++ @optional

  @doc "Normalizes a descriptor, returning structured validation errors."
  @spec new(term()) :: {:ok, Collection.t()} | {:error, term()}
  def new(%Collection{} = descriptor), do: validate_descriptor(descriptor)
  def new(%_{} = value), do: descriptor_error(value)

  def new(value) when is_map(value) or is_list(value) do
    with {:ok, map} <- descriptor_map(value),
         {:ok, descriptor} <- build_descriptor(map) do
      validate_descriptor(descriptor)
    end
  end

  def new(value), do: descriptor_error(value)

  @doc "Removes local import location and nil fields from validated identity."
  @spec portable(Collection.t()) :: map()
  def portable(%Collection{} = descriptor) do
    descriptor
    |> Map.from_struct()
    |> Map.drop([:artifact_dir])
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp descriptor_map(value) when is_list(value) do
    if Keyword.keyword?(value), do: reduce_fields(value), else: descriptor_error(value)
  end

  defp descriptor_map(value), do: reduce_fields(value)

  defp reduce_fields(value) do
    Enum.reduce_while(value, {:ok, %{}}, fn {key, item}, {:ok, acc} ->
      case normalize_key(key) do
        {:ok, normalized} -> put_field(acc, normalized, item)
        :error -> {:halt, {:error, {:invalid_collection_descriptor, :field, key}}}
      end
    end)
  end

  defp descriptor_error(value), do: {:error, {:invalid_collection_descriptor, :descriptor, value}}
  defp normalize_key(key) when key in @fields, do: {:ok, key}

  defp normalize_key(key) when is_binary(key) do
    case Enum.find(@fields, &(Atom.to_string(&1) == key)) do
      nil -> :error
      field -> {:ok, field}
    end
  end

  defp normalize_key(_), do: :error

  defp build_descriptor(map) do
    case Enum.find(@required, &(not Map.has_key?(map, &1))) do
      nil -> {:ok, struct!(Collection, map)}
      field -> {:error, {:invalid_collection_descriptor, field, :missing}}
    end
  end

  defp validate_descriptor(descriptor) do
    checks = [
      {:id, descriptor.id, &valid_id?/1},
      {:title, descriptor.title, &nonempty_string?/1},
      {:version, descriptor.version, &nonempty_string?/1},
      {:revision, descriptor.revision, &nonempty_string?/1},
      {:tree_digest, descriptor.tree_digest, &valid_digest?/1},
      {:artifact_dir, descriptor.artifact_dir, &nonempty_string?/1},
      {:source_url, descriptor.source_url, &nonempty_string?/1},
      {:edit_base_url, descriptor.edit_base_url, &nonempty_string?/1},
      {:package, descriptor.package, &optional_string?/1},
      {:license, descriptor.license, &optional_string?/1},
      {:default_locale, descriptor.default_locale, &optional_string?/1},
      {:audience, descriptor.audience, &valid_audience?/1},
      {:source_root, descriptor.source_root, &valid_source_root?/1},
      {:status, descriptor.status, &optional_string?/1}
    ]

    case Enum.find(checks, fn {_, value, predicate} -> not predicate.(value) end) do
      nil -> {:ok, %{descriptor | source_root: descriptor.source_root || "."}}
      {field, value, _} -> {:error, {:invalid_collection_descriptor, field, value}}
    end
  end

  defp valid_id?(id), do: is_binary(id) and Regex.match?(~r/\A[a-z][a-z0-9_]*\z/, id)
  defp nonempty_string?(value), do: is_binary(value) and value != "" and String.valid?(value)
  defp optional_string?(nil), do: true
  defp optional_string?(value), do: nonempty_string?(value)

  defp valid_audience?(nil), do: true
  defp valid_audience?(value) when is_binary(value), do: nonempty_string?(value)

  defp valid_audience?(value) when is_list(value),
    do: value != [] and DocShell.Json.valid?(value) and Enum.all?(value, &nonempty_string?/1)

  defp valid_audience?(_), do: false

  defp valid_source_root?(nil), do: true

  defp valid_source_root?(path) do
    nonempty_string?(path) and Path.type(path) != :absolute and contained_relative_path?(path)
  end

  defp valid_digest?(@digest_prefix <> hex),
    do: byte_size(hex) == 64 and Regex.match?(~r/^[0-9a-f]{64}$/, hex)

  defp valid_digest?(_), do: false

  defp put_field(acc, key, value) do
    if Map.has_key?(acc, key),
      do: {:halt, {:error, {:duplicate_collection_field, key}}},
      else: {:cont, {:ok, Map.put(acc, key, value)}}
  end

  defp contained_relative_path?(path) do
    path != "" and Path.type(path) == :relative and ".." not in Path.split(path) and
      not String.contains?(path, ["\\", <<0>>])
  end
end
