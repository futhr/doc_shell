import Config

# Only the integration fixtures use Ash resources. Consumers own their Ash
# configuration; DocShell never sets this option in a host application.
config :ash, default_string_length_count: :codepoints
