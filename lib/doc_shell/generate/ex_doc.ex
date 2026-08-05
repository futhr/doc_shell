defmodule DocShell.Generate.ExDoc do
  @moduledoc """
  Extracts documentation from compiled modules through the BEAM docs chunk.

  This reads the same `Docs` chunk that `h MyApp.Accounts` and ExDoc read, so
  what comes out is whatever the compiler actually stored — no source parsing,
  no separate Markdown pass over `.ex` files, and no chance of the artifact
  disagreeing with `IEx`. The modules must be compiled and loadable; in
  practice that means running inside the host application, which is what
  `mix doc_shell.build` arranges.

  Each module becomes one entry:

      %{
        "id" => "MyApp.Accounts",
        "title" => "MyApp.Accounts",
        "kind" => "module",
        "ast" => [...],
        "meta" => %{
          "module" => "MyApp.Accounts",
          "language" => "elixir",
          "moduledoc" => "present",
          "members" => [...]
        }
      }

  `ast` is the module documentation parsed by `DocShell.Ast`. `members` lists
  every documented function, macro, callback, and type with its kind, name,
  arity, signatures, raw documentation, and metadata such as `since` or
  `deprecated`. Member documentation is left as Markdown text rather than
  parsed, because a page usually renders a member list lazily and parsing every
  member of every module up front is work most renderers throw away.

  ## Modules without documentation

  A module compiled with `--no-docs`, or from Erlang without a chunk, is
  skipped rather than treated as an error — `extract/1` simply omits it. A
  module that has a chunk but fails to read is an error, tagged with the module
  name.

  Modules that *have* a chunk but no prose are a different case, and they are
  deliberately still returned, with an empty `ast`. `meta["moduledoc"]` says
  which situation each one is in:

    * `"present"` — the module has documentation
    * `"hidden"` — the author wrote `@moduledoc false`
    * `"none"` — no `@moduledoc` at all

  Extraction stays complete because callers use it for more than rendering: a
  documentation-coverage report needs the undocumented modules precisely
  because they are undocumented, and dropping them here would make every
  codebase look fully documented.

  Filtering for display happens later, in
  `DocShell.Presentation.StaticGenerator`, which skips empty entries by
  default so `mix doc_shell.build` does not fill a navigation tree with
  internal modules that opted out.

  Modules are sorted by name so the artifact is stable across builds.
  """

  alias DocShell.Ast
  alias DocShell.Generate.Collector

  @doc """
  Extracts documentation for a list of compiled modules.

  Undocumented modules are omitted. The first module that fails to read
  short-circuits the run and returns `{:error, {module, reason}}`.
  """
  @spec extract([module()]) :: {:ok, [map()]} | {:error, term()}
  def extract(modules) when is_list(modules) do
    modules
    |> Enum.sort()
    |> Collector.map_ok(fn module ->
      case extract_module(module) do
        {:error, reason} -> {:error, {module, reason}}
        ok -> ok
      end
    end)
  end

  @doc """
  Extracts one compiled module.

  Returns `{:ok, nil}` when the module carries no docs chunk, which callers
  treat as "nothing to document" rather than as a failure.
  """
  @spec extract_module(module()) :: {:ok, map() | nil} | {:error, term()}
  def extract_module(module) when is_atom(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, moduledoc, metadata, docs} ->
        build_entry(module, moduledoc, metadata, docs)

      {:error, :chunk_not_found} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_entry(module, moduledoc, metadata, docs) do
    markdown = doc_text(moduledoc)

    with {:ok, ast} <- Ast.from_markdown(markdown) do
      {:ok,
       %{
         "id" => inspect(module),
         "title" => inspect(module),
         "kind" => "module",
         "ast" => ast,
         "meta" => %{
           "module" => inspect(module),
           "language" => to_string(Map.get(metadata, :language, :elixir)),
           "moduledoc" => moduledoc_state(moduledoc),
           "members" => Enum.map(docs, &member/1)
         }
       }}
    end
  end

  defp moduledoc_state(%{"en" => text}) when is_binary(text), do: "present"
  defp moduledoc_state(:hidden), do: "hidden"
  defp moduledoc_state(_), do: "none"

  defp member({{kind, name, arity}, _, signatures, doc, metadata}) do
    %{
      "kind" => to_string(kind),
      "name" => to_string(name),
      "arity" => arity,
      "signatures" => signatures,
      "doc" => doc_text(doc),
      "metadata" => DocShell.Json.stringify(metadata)
    }
  end

  defp doc_text(%{"en" => text}) when is_binary(text), do: text
  defp doc_text(_), do: ""
end
