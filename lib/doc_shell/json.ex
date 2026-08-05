defmodule DocShell.Json do
  @moduledoc """
  Coerces arbitrary Elixir terms into something JSON can represent.

  Documentation metadata is not JSON-shaped. The BEAM docs chunk hands back
  atoms, charlists, tuples, and structs; Earmark node metadata carries atom
  keys; frontmatter can hold anything YAML parses. All of it has to survive the
  trip to a renderer, so `stringify/1` walks a term and coerces what JSON
  cannot express:

    * atoms become strings — except `nil`, `true`, and `false`, which JSON has
      natively and which would be useless as `"nil"`
    * tuples become lists, since JSON has no tuple
    * map keys become strings, with anything exotic passed through `inspect/1`
      rather than dropped
    * lists and maps are walked recursively
    * structs become their `String.Chars` text where they have one, and their
      `inspect/1` form otherwise

  Structs are not walked field by field, which would preserve more but is not
  safe in general: a `Regex` carries a compiled `re_pattern` holding a
  non-UTF-8 binary, and emitting that produces a map no JSON encoder can
  encode. Losing the structure of an exotic value beats failing the build on
  it.

  Everything else — numbers, binaries — is left exactly as it is. Preserving
  native types matters: a version number that arrives as `1` should not reach a
  renderer as `"1"`.

  ## One implementation

  Both the AST and ExDoc extractors go through this module. Two coercion passes
  drifting apart would show up as one artifact spelling `:since` metadata
  differently from another, and a renderer discovering it in production.

  ## Examples

      iex> DocShell.Json.stringify(%{since: "1.2.0", deprecated: nil})
      %{"since" => "1.2.0", "deprecated" => nil}

      iex> DocShell.Json.stringify({:ok, [:a, 1]})
      ["ok", ["a", 1]]

      iex> DocShell.Json.stringify(%{released: ~D[2026-08-05]})
      %{"released" => "2026-08-05"}
  """

  @doc "Recursively coerces a term into a JSON-encodable value with string keys."
  @spec stringify(term()) :: term()
  def stringify(value) when is_nil(value) or is_boolean(value), do: value
  def stringify(value) when is_atom(value), do: Atom.to_string(value)

  def stringify(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&stringify/1)
  end

  def stringify(value) when is_list(value), do: Enum.map(value, &stringify/1)

  def stringify(%_{} = value), do: stringify_struct(value)

  def stringify(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {stringify_key(key), stringify(item)} end)

  def stringify(value), do: value

  @doc """
  Encodes a presentation struct as a plain string-keyed JSON object.

  Deriving `Jason.Encoder` would serialise fields in `defstruct` order, whereas
  these shapes were string-keyed maps and so encoded lexicographically. Keeping
  string keys keeps that order, which keeps the artifact byte-stable across the
  switch to structs — an artifact diff should show a content change or nothing.
  """
  @spec encode_struct(struct(), Jason.Encode.opts()) :: iodata()
  def encode_struct(value, opts) do
    value
    |> Map.from_struct()
    |> Map.new(fn {key, item} -> {Atom.to_string(key), item} end)
    |> Jason.Encode.map(opts)
  end

  defp stringify_struct(value) do
    case String.Chars.impl_for(value) do
      nil -> inspect(value)
      _ -> to_string(value)
    end
  end

  defp stringify_key(key) when is_binary(key), do: key
  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: inspect(key)
end
