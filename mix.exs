defmodule DocShell.MixProject do
  use Mix.Project

  @version "0.2.0"
  @source_url "https://github.com/futhr/doc_shell"

  def project do
    [
      app: :doc_shell,
      name: "DocShell",
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [no_warn_undefined: [AshOaskit]],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      test_coverage: test_coverage(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger]]
  end

  def cli do
    [
      preferred_envs: [
        check: :dev,
        ci: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "test.cover": :test,
        "test.cover.html": :test,
        "test.watch": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_coverage do
    [tool: ExCoveralls]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts",
      flags: [:error_handling, :unknown],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp deps do
    optional_integrations(Mix.env()) ++
      [
        {:jason, "~> 1.4"},
        {:earmark_parser, "~> 1.4"},
        {:yaml_elixir, "~> 2.11"},
        {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
        {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
        {:doctor, "~> 0.21", only: [:dev, :test], runtime: false},
        {:doctest_formatter, "~> 0.4", only: [:dev, :test], runtime: false},
        {:ex_check, "~> 0.16", only: :dev, runtime: false},
        {:excoveralls, "~> 0.18", only: :test},
        {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
        {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
        {:stream_data, "~> 1.0", only: [:dev, :test], override: true},
        {:benchee, "~> 1.3", only: :dev, runtime: false},
        {:benchee_markdown, "~> 0.3", only: :dev, runtime: false},
        {:ex_doc, "~> 0.34", only: :dev, runtime: false},
        {:git_ops, "~> 2.6", only: :dev}
      ]
  end

  # Declared in :dev and :test, where this library's own tests exercise the
  # integrations, and where `mix hex.build` reads them for the published
  # metadata. Plug remains declared in :prod so hosts that install Plug compile
  # the optional web modules in dependency order. AshOaskit is dropped in :prod
  # because its tree needs development-only support libraries in this package's
  # own build, and the adapter resolves it at runtime instead.
  defp optional_integrations(:no_optional), do: []

  defp optional_integrations(:prod) do
    [
      {:plug, "~> 1.16", optional: true}
    ]
  end

  defp optional_integrations(_) do
    [
      # DocShell uses only AshOaskit.spec/1, which is stable across both minor
      # lines. Keep the optional metadata honest for hosts still on 0.3.
      {:ash_oaskit, "~> 0.3 or ~> 0.4", optional: true},
      {:plug, "~> 1.16", optional: true}
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "deps.compile", "compile"],

      # Testing
      "test.watch": ["test.watch --stale"],
      "test.cover": ["coveralls"],
      "test.cover.html": ["coveralls.html"],

      # Quality
      lint: ["format --check-formatted", "credo --strict", "dialyzer"],
      ci: ["setup", "lint", "test.cover"],

      # Benchmarks
      bench: ["bench.all"],
      "bench.all": ["bench.ast", "bench.presentation", "bench.json"],
      "bench.ast": ["run bench/ast.exs"],
      "bench.presentation": ["run bench/presentation.exs"],
      "bench.json": ["run bench/json.exs"],

      # Release
      release: ["git_ops.release"]
    ]
  end

  defp description do
    "Renderer-neutral documentation generation and serving for Elixir applications"
  end

  defp package do
    [
      files: ~w(
        lib
        notebooks
        bench/output
        .formatter.exs
        mix.exs
        README.md
        LICENSE.md
        CONTRIBUTING.md
        usage-rules.md
      ),
      maintainers: ["Tobias Bohwalli <hi@futhr.io>"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Issues" => "#{@source_url}/issues"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md": [title: "Overview"],
        "notebooks/build-pipeline.livemd": [title: "The Build Pipeline"],
        "notebooks/openapi-adapters.livemd": [title: "OpenAPI Adapters"],
        "notebooks/artifact-contract.livemd": [title: "Artifact Contract"],
        "notebooks/serving-artifacts.livemd": [title: "Serving Artifacts"],
        "bench/output/ast.md": [title: "Markdown Parsing"],
        "bench/output/presentation.md": [title: "Presentation Projection"],
        "bench/output/json.md": [title: "Term Coercion"],
        "bench/output/artifact.md": [title: "Artifact Round Trip"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "LICENSE.md": [title: "License"],
        "usage-rules.md": [title: "Usage Rules (LLM)"]
      ],
      groups_for_extras: [
        Tutorials: ~r/notebooks\//,
        Performance: ~r/bench\/output\//,
        Reference: ~r/CHANGELOG|CONTRIBUTING|usage-rules|LICENSE/
      ],
      groups_for_modules: [
        Core: [
          DocShell,
          DocShell.Build,
          DocShell.Config,
          DocShell.Artifact
        ],
        Extraction: [
          DocShell.Ast,
          DocShell.Generate.ExDoc,
          DocShell.Generate.Guides,
          DocShell.Generate.Livebooks,
          DocShell.Generate.Collector
        ],
        Changelog: [
          DocShell.Generate.Changelog,
          DocShell.Generate.Changelog.Source,
          DocShell.Generate.Changelog.Sources.MarkdownFile
        ],
        OpenAPI: [
          DocShell.Generate.OpenApi,
          DocShell.Generate.OpenApi.Adapter,
          DocShell.Generate.OpenApi.Adapters.AshOaskit,
          DocShell.Generate.OpenApi.Adapters.OpenApiSpex,
          DocShell.Generate.OpenApi.Adapters.RawJson
        ],
        Presentation: [
          DocShell.Presentation.Source,
          DocShell.Presentation.StaticGenerator,
          DocShell.Presentation.GraphProjector,
          DocShell.Presentation.NavigationItem,
          DocShell.Presentation.SearchEntry,
          DocShell.Presentation.Backlink
        ],
        "Web Serving": [
          DocShell.Web.Cache,
          DocShell.Web.Plug,
          DocShell.Web.Controller
        ],
        Support: [
          DocShell.Json
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,

      # ex_doc's defaults, named so a future edit has to be deliberate:
      # dropping "markdown" also drops llms.txt and the per-module .md files
      formatters: ["html", "markdown", "epub"]
    ]
  end
end
