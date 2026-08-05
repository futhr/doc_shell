[
  ## Run tools one at a time so failures are readable
  parallel: false,

  ## Report tools that were skipped and why
  skipped: true,
  tools: [
    {:compiler, "mix compile --warnings-as-errors"},

    ## The package must still compile when hosts omit :ash_oaskit and :plug
    {:optional_deps,
     command: "mix compile --no-optional-deps --warnings-as-errors",
     env: %{"MIX_ENV" => "no_optional"}},
    {:formatter, "mix format --check-formatted"},
    {:unused_deps, "mix deps.unlock --check-unused"},
    {:credo, "mix credo --strict"},

    ## Coverage is enforced through excoveralls, so the plain ExUnit tool is off
    {:ex_unit, false},
    {:test, command: "mix coveralls", env: %{"MIX_ENV" => "test"}},
    {:hex_audit, "mix hex.audit"},
    {:mix_audit, "mix deps.audit"},
    {:doctor, "mix doctor --summary"},
    {:dialyzer, "mix dialyzer"},
    {:ex_doc, "mix docs --warnings-as-errors"}
  ]
]
