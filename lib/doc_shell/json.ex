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

  Numbers and valid UTF-8 strings are preserved. Other terms and invalid binaries
  become inspected text; improper list tails become a final array value. Preserving
  native types matters: a version number that arrives as `1` should not reach a
  renderer as `"1"`.

  `normalize/1` rejects collisions between converted map keys. The legacy
  `stringify/1` function remains lossy: string keys take precedence over other
  keys that normalize to the same text. Use `normalize/1` at input boundaries.

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

  @typedoc "A native JSON value with UTF-8 string object keys."
  @type value ::
          nil | boolean() | number() | String.t() | [value()] | %{optional(String.t()) => value()}

  @doc "Decodes native JSON values and rejects duplicate keys at every object depth."
  @spec decode(binary()) :: {:ok, value()} | {:error, term()}
  def decode(json) do
    with {:ok, value} <- Jason.decode(json, objects: :ordered_objects) do
      decoded_value(value)
    end
  end

  defp decoded_value(%Jason.OrderedObject{values: pairs}) do
    Enum.reduce_while(pairs, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      if Map.has_key?(acc, key),
        do: {:halt, {:error, {:duplicate_json_key, key}}},
        else: decode_pair(key, value, acc)
    end)
  end

  defp decoded_value(values) when is_list(values), do: decode_list(values, [])
  defp decoded_value(value), do: {:ok, value}

  defp decode_pair(key, value, acc) do
    case decoded_value(value) do
      {:ok, decoded} -> {:cont, {:ok, Map.put(acc, key, decoded)}}
      error -> {:halt, error}
    end
  end

  defp decode_list([], acc), do: {:ok, Enum.reverse(acc)}

  defp decode_list([value | rest], acc) do
    with {:ok, value} <- decoded_value(value), do: decode_list(rest, [value | acc])
  end

  @doc "Recursively coerces a term into a JSON-encodable value with string keys."
  @spec stringify(term()) :: term()
  def stringify(value) when is_nil(value) or is_boolean(value), do: value
  def stringify(value) when is_atom(value), do: Atom.to_string(value)

  def stringify(value) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> Enum.map(&stringify/1)
  end

  def stringify([]), do: []
  def stringify([head | tail]), do: [stringify(head) | stringify_tail(tail)]

  def stringify(%_{} = value), do: stringify_struct(value)

  def stringify(value) when is_map(value) do
    value
    |> Enum.sort_by(fn {key, _} -> {is_binary(key), key} end)
    |> Map.new(fn {key, item} -> {stringify_key(key), stringify(item)} end)
  end

  def stringify(value) when is_binary(value) do
    if String.valid?(value), do: value, else: inspect(value)
  end

  def stringify(value) when is_number(value), do: value
  def stringify(value), do: inspect(value)

  @doc "Normalizes metadata, returning an error when converted map keys collide."
  @spec normalize(term()) :: {:ok, term()} | {:error, {:duplicate_json_key, String.t()}}
  def normalize(value) do
    with :ok <- check_keys(value), do: {:ok, stringify(value)}
  end

  @doc "Checks that a value contains only native JSON values and UTF-8 string keys."
  @spec valid?(term()) :: boolean()
  def valid?(value) when is_nil(value) or is_boolean(value) or is_number(value), do: true
  def valid?(value) when is_binary(value), do: String.valid?(value)
  def valid?([]), do: true
  def valid?([head | tail]), do: valid?(head) and valid_list?(tail)
  def valid?(%_{}), do: false
  def valid?(value) when is_map(value), do: Enum.all?(value, &valid_pair?/1)
  def valid?(_), do: false

  defp valid_list?(value) when is_list(value), do: valid?(value)
  defp valid_list?(_), do: false
  defp valid_pair?({key, value}), do: is_binary(key) and String.valid?(key) and valid?(value)

  defp stringify_tail([]), do: []
  defp stringify_tail([_ | _] = tail), do: stringify(tail)
  defp stringify_tail(tail), do: [stringify(tail)]

  defp check_keys(%_{}), do: :ok

  defp check_keys(value) when is_map(value) do
    with :ok <- unique_keys(Map.keys(value)) do
      check_keys(Map.values(value))
    end
  end

  defp check_keys(value) when is_tuple(value), do: check_keys(Tuple.to_list(value))

  defp check_keys([head | tail]) do
    with :ok <- check_keys(head), do: check_keys(tail)
  end

  defp check_keys(_), do: :ok

  defp unique_keys(keys) do
    case Enum.reduce_while(keys, MapSet.new(), &collect_key/2) do
      {:error, _} = error -> error
      _ -> :ok
    end
  end

  defp collect_key(key, seen) do
    key = stringify_key(key)

    if MapSet.member?(seen, key) do
      {:halt, {:error, {:duplicate_json_key, key}}}
    else
      {:cont, MapSet.put(seen, key)}
    end
  end

  @doc """
  Encodes a presentation struct as a plain string-keyed JSON object.

  Presentation structs use this helper in their `Jason.Encoder` implementations
  to emit all fields with string keys. This is distinct from `stringify/1`,
  which treats arbitrary structs as textual metadata values.
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
      _ -> value |> to_string() |> stringify()
    end
  rescue
    _ -> inspect(value)
  end

  defp stringify_key(key) when is_binary(key), do: stringify(key)
  defp stringify_key(key) when is_atom(key), do: Atom.to_string(key)
  defp stringify_key(key), do: inspect(key)
end
