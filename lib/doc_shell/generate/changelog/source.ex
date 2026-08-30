defmodule DocShell.Generate.Changelog.Source do
  @moduledoc """
  Source adapter contract for changelog or release-note entries.

  A source answers with renderer-neutral DocShell changelog entries. The storage
  mechanism is deliberately outside the contract: a host can read a Markdown
  file, query a graph database, call a release service, or synthesize entries
  from another internal model.

  File and Markdown-backed sources can use
  `DocShell.Generate.Changelog.from_markdown/2` to reuse the package parser.
  Sources that already store structured release data may return entry maps
  directly, as long as they pass `DocShell.Generate.Changelog.validate/1`.

      defmodule MyApp.Docs.ReleaseNotes do
        @behaviour DocShell.Generate.Changelog.Source

        @impl true
        def load(opts) do
          opts
          |> Keyword.fetch!(:graph)
          |> MyApp.Graph.release_notes_markdown()
          |> DocShell.Generate.Changelog.from_markdown("graph://docs/release-notes")
        end
      end

  Configure it from the host:

      config :doc_shell,
        changelog_source: MyApp.Docs.ReleaseNotes,
        changelog_options: [graph: MyApp.Graph]
  """

  @typedoc """
  A string-keyed DocShell changelog entry.

  Required keys are `"id"`, `"title"`, `"kind" => "changelog"`, and `"ast"`.
  Metadata is optional but should include source identity when available.
  """
  @type entry :: %{required(String.t()) => term()}

  @doc """
  Loads changelog entries from the source.

  Return `{:ok, entries}` or `{:error, reason}`. Prefer returning an error with a
  human-actionable reason over raising; DocShell catches either so a bad source
  fails the build instead of producing partial artifacts.
  """
  @callback load(opts :: keyword()) :: {:ok, [entry()]} | {:error, term()}
end
