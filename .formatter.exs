[
  import_deps: [:plug],
  plugins: [DoctestFormatter],
  inputs: [
    "{mix,.formatter,.check,.credo,.doctor,.dialyzer_ignore}.exs",
    "{config,lib,test,bench}/**/*.{ex,exs}"
  ]
]
