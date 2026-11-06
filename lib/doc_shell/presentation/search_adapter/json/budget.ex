defmodule DocShell.Presentation.SearchAdapter.JSON.Budget do
  @moduledoc false

  alias DocShell.Presentation.{Limits, SiteSearchEntry}

  @envelope_bytes byte_size(~s({"records":[],"schema_version":"doc-shell-search/v1"}))
  @escaped_bytes Enum.map([?", ?\\ | Enum.to_list(0..31)], &<<&1>>)

  @doc false
  @spec admit(term(), Limits.t(), [atom()]) :: :ok | {:error, term()}
  def admit(records, limits, resources) do
    state = %{bytes: 0, limits: limits, resources: resources, mode: :minimum, pattern: nil}
    count(records, state)
    count(records, %{state | mode: :escaped, pattern: :binary.compile_pattern(@escaped_bytes)})
    :ok
  catch
    {:budget_error, error} -> {:error, error}
  end

  defp count(records, state), do: records(records, add(state, @envelope_bytes), false)

  defp records([], state, _), do: state

  defp records([%SiteSearchEntry{} = record | rest], state, comma?) do
    fields = Map.from_struct(record)
    state = add(state, 2 + max(map_size(fields) - 1, 0) + if(comma?, do: 1, else: 0))
    state = Enum.reduce(fields, state, &field/2)
    records(rest, state, true)
  end

  defp records(_, _, _), do: invalid()

  defp field({key, value}, state) when is_atom(key) do
    state = string(Atom.to_string(key), add(state, 1))
    value(value, state)
  end

  defp field(_, _), do: invalid()

  defp value(value, state) when is_binary(value), do: string(value, state)
  defp value(nil, state), do: add(state, 4)
  defp value(values, state) when is_list(values), do: strings(values, add(state, 2), false)
  defp value(_, _), do: invalid()

  defp strings([], state, _), do: state

  defp strings([value | rest], state, comma?) when is_binary(value) do
    state = string(value, add(state, if(comma?, do: 1, else: 0)))
    strings(rest, state, true)
  end

  defp strings(_, _, _), do: invalid()

  defp string(value, %{mode: :minimum} = state), do: add(state, 2 + byte_size(value))

  defp string(value, state) do
    escaped(value, 0, add(state, 2 + byte_size(value)))
  end

  defp escaped(value, offset, state) when offset < byte_size(value) do
    case :binary.match(value, state.pattern, scope: {offset, byte_size(value) - offset}) do
      {position, 1} ->
        extra = if :binary.at(value, position) in [?", ?\\, 8, 9, 10, 12, 13], do: 1, else: 5
        escaped(value, position + 1, add(state, extra))

      :nomatch ->
        state
    end
  end

  defp escaped(_, _, state), do: state

  defp add(state, bytes) do
    state = %{state | bytes: state.bytes + bytes}
    Enum.each(state.resources, &check(state, &1))
    state
  end

  defp check(state, resource) do
    case Limits.check(state.limits, resource, state.bytes) do
      :ok -> :ok
      {:error, error} -> throw({:budget_error, error})
    end
  end

  @spec invalid() :: no_return()
  defp invalid, do: throw({:budget_error, :invalid_search_records})
end
