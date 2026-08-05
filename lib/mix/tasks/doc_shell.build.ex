defmodule Mix.Tasks.DocShell.Build do
  @shortdoc "Build DocShell JSON artifacts"

  @moduledoc """
  Builds the documentation artifact tree for the current project.

      $ mix doc_shell.build

  Starts the application, extracts every configured source, and writes the JSON
  tree to the configured `:public_dir` and `:private_dir`. Run it before
  building assets, and in CI before packaging a release, so the artifacts ship
  with the version of the code they describe.

  ## Modules

  The task documents every module the current application compiled, read from
  its application spec. That is almost always what you want from the command
  line — the alternative is listing modules by hand and watching the list rot.
  It also means the task documents this project only, not its dependencies.

  Hosts wanting a different set call `DocShell.Build.run/1` directly, from a
  release task or a script, and pass `:modules` explicitly. Everything else —
  guide directories, the notebook base, the OpenAPI adapter — comes from
  `config :doc_shell`; see `DocShell.Config` for the keys and their defaults.

  ## Failure

  A source that cannot be read aborts the build with `Mix.raise/1` and a
  non-zero exit status, naming the module or file at fault. Documentation that
  quietly drops a page is worse than a build that stops, especially in CI where
  nothing else will notice.
  """

  use Mix.Task

  @impl Mix.Task
  def run(_) do
    Mix.Task.run("app.start")

    case DocShell.Build.run(modules: project_modules()) do
      {:ok, result} ->
        count = length(result.modules) + length(result.guides) + length(result.livebooks)
        Mix.shell().info("Generated DocShell artifacts for #{count} documents")

      {:error, reason} ->
        Mix.raise("DocShell build failed: #{inspect(reason)}")
    end
  end

  defp project_modules do
    app = Mix.Project.config()[:app]
    Application.spec(app, :modules) || []
  end
end
