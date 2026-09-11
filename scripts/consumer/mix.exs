defmodule ConsumerSmoke.MixProject do
  use Mix.Project

  def project do
    [
      app: :consumer_smoke,
      version: "0.1.0",
      deps:
        [{:doc_shell, path: System.fetch_env!("DOC_SHELL_PACKAGE")}] ++ integration() ++ minimum()
    ]
  end

  defp integration do
    case System.fetch_env!("DOC_SHELL_INTEGRATION") do
      "core" -> []
      "plug" -> [{:plug, "~> 1.16"}]
      "ash" -> [{:ash_oaskit, "~> 0.4.1"}]
    end
  end

  defp minimum do
    case System.fetch_env!("DOC_SHELL_DEPENDENCIES") do
      "minimum" ->
        # AshOaskit's Decimal 3 dependency needs Jason 1.4.5; the core still
        # supports Jason 1.4.0. These are compatible minima, not solver overrides.
        jason =
          if System.fetch_env!("DOC_SHELL_INTEGRATION") == "ash", do: "== 1.4.5", else: "== 1.4.0"

        [{:jason, jason}, {:earmark_parser, "== 1.4.8"}, {:yaml_elixir, "== 2.11.0"}]

      _ ->
        []
    end
  end
end
