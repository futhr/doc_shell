defmodule DocShell.Generate.OpenApi.Adapters.RawJson do
  @moduledoc """
  Takes the OpenAPI document as it is — from a map or a JSON file on disk.

  Not every API description is generated from Elixir. It may be authored by
  hand, produced by a service written in something else, or committed as a
  build artifact from another repository. This adapter is the escape hatch for
  all of those, and it does the least possible: no introspection, no
  transformation.

  From a file:

      config :doc_shell,
        open_api_adapter: DocShell.Generate.OpenApi.Adapters.RawJson,
        open_api_options: [path: "priv/openapi.json"]

  Or from a map already in memory, which is mostly useful in tests and in hosts
  that assemble the document themselves:

      DocShell.Build.run(
        open_api_adapter: DocShell.Generate.OpenApi.Adapters.RawJson,
        open_api_options: [spec: %{"openapi" => "3.1.0", "info" => %{}, "paths" => %{}}]
      )

  `:spec` wins when both are given. The document still has to satisfy
  `DocShell.Generate.OpenApi.validate/1`, so a JSON file that parses but is not
  an OpenAPI document fails the build rather than reaching a renderer.

  Returns `{:error, :raw_json_source_missing}` when neither option is set, and
  passes through file and JSON decoding errors unchanged.
  """

  @behaviour DocShell.Generate.OpenApi.Adapter

  @impl DocShell.Generate.OpenApi.Adapter
  def load(opts) do
    cond do
      is_map(opts[:spec]) ->
        {:ok, opts[:spec]}

      is_binary(opts[:path]) ->
        opts[:path]
        |> File.read()
        |> decode()

      true ->
        {:error, :raw_json_source_missing}
    end
  end

  defp decode({:ok, json}), do: Jason.decode(json)
  defp decode({:error, reason}), do: {:error, reason}
end
