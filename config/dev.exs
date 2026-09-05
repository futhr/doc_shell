import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/futhr/doc_shell",
  version_tag_prefix: "v",
  manage_mix_version?: true,
  manage_readme_version: "README.md",
  managed_files:
    [
      {"README.md", fn v -> "doc_shell%2Fv#{v}%2Fnotebooks" end,
       fn v -> "doc_shell%2Fv#{v}%2Fnotebooks" end}
    ] ++
      Enum.map(
        ~w(build-pipeline artifact-contract openapi-adapters serving-artifacts),
        fn name ->
          {"notebooks/#{name}.livemd", fn v -> "\"== #{v}\"" end, fn v -> "\"== #{v}\"" end}
        end
      )
