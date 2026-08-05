import Config

# For developing DocShell itself. Consumers never load this file, so package
# defaults belong in `DocShell.Config`, not here.

config :logger, level: :warning

config :mix_test_watch, clear: true, tasks: ["test"]

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
