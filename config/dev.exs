import Config

config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/futhr/doc_shell",
  version_tag_prefix: "v",
  manage_mix_version?: true,
  manage_readme_version: "README.md"
