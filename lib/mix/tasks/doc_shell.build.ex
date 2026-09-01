defmodule Mix.Tasks.DocShell.Build do
  @shortdoc "Build DocShell JSON artifacts"

  @moduledoc """
  Builds the documentation artifact tree for the current project.

      $ mix doc_shell.build
      $ mix doc_shell.build --no-start

  By default the task starts the application, extracts every configured source,
  and writes the JSON tree to the configured `:public_dir` and `:private_dir`.
  Run it before building assets, and in CI before packaging a release, so the
  artifacts ship with the version of the code they describe.

  Pass `--no-start` when a host application's supervision tree owns development
  servers, sockets, or other side effects that are not needed for static
  documentation generation. That mode still compiles the project and loads its
  application spec before collecting modules, but it does not start the
  application.

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

  @switches [no_start: :boolean]

  @impl Mix.Task
  def run(args) do
    opts = parse_args!(args)
    prepare_project!(Keyword.get(opts, :no_start, false))

    case DocShell.Build.run(modules: project_modules()) do
      {:ok, result} ->
        count =
          length(result.modules) + length(result.guides) + length(result.livebooks) +
            length(result.changelog)

        Mix.shell().info("Generated DocShell artifacts for #{count} documents")

      {:error, reason} ->
        Mix.raise("DocShell build failed: #{inspect(reason)}")
    end
  end

  defp project_modules do
    app = Mix.Project.config()[:app]
    Application.spec(app, :modules) || []
  end

  defp parse_args!(args) do
    case OptionParser.parse(args, strict: @switches) do
      {opts, [], []} ->
        opts

      {_, positional, []} ->
        Mix.raise(
          "mix doc_shell.build does not accept positional arguments: #{Enum.join(positional, " ")}"
        )

      {_, _, invalid} ->
        Mix.raise("Unknown option for mix doc_shell.build: #{format_invalid(invalid)}")
    end
  end

  defp prepare_project!(true) do
    Mix.Task.run("compile")
    load_application!()
  end

  defp prepare_project!(false) do
    Mix.Task.run("app.start")
  end

  defp load_application! do
    app = Mix.Project.config()[:app]

    case Application.load(app) do
      :ok ->
        :ok

      {:error, {:already_loaded, ^app}} ->
        :ok

      {:error, reason} ->
        Mix.raise("Could not load #{inspect(app)} application spec: #{inspect(reason)}")
    end
  end

  defp format_invalid(invalid) do
    Enum.map_join(invalid, ", ", fn
      {switch, nil} -> switch
      {switch, value} -> "#{switch}=#{value}"
    end)
  end
end
