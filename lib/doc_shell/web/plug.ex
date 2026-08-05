if Code.ensure_loaded?(Plug) do
  defmodule DocShell.Web.Plug do
    @moduledoc """
    Serves cached artifacts over HTTP, behind an authorization gate you supply.

    Mount it wherever the documentation JSON should live:

        forward "/docs/api",
          to: DocShell.Web.Plug,
          init_opts: [gate: &MyApp.Auth.allow_docs?/1]

    The last path segment names the artifact, with `.json` optional, so
    `GET /docs/api/navigation` and `GET /docs/api/navigation.json` both return
    `navigation.json` from `DocShell.Web.Cache`. The stored envelope is served
    as-is, so `generated_at` is the time of the build that produced the
    artifact — not the time of the request, which would be useless to a client
    and would defeat any caching built on top of it.

    The conn is halted once a response is sent, so this is safe to place in a
    pipeline as well as behind `forward`.

    ## The gate

    Documentation is rarely uniformly public. Internal runbooks, unreleased
    features, and per-tenant guides all need someone to decide who may read
    them — and that someone is the host, which knows about sessions, roles, and
    tenancy. DocShell knows about none of it and should not pretend otherwise.

    So authorization is a single `:gate` option, either a unary function or an
    `{module, function, extra_args}` tuple receiving the conn first:

        init_opts: [gate: {MyApp.Auth, :allow_docs?, [:internal]}]

    Return `:ok` or `true` to allow the request; anything else yields 403.
    Omitting `:gate` serves every artifact to every caller, which is the right
    default for genuinely public documentation and the wrong one everywhere
    else — decide deliberately.

    ## Responses

      * `200` with `application/json` — the enveloped artifact
      * `403` — the gate refused
      * `404` — no such artifact, or a path that is not a single segment
      * `500` — the artifact is cached but could not be encoded

    Multi-segment paths are rejected rather than joined, so no request can walk
    out of the cache and into the filesystem.

    ## Multiple caches

    The `:cache` option selects which named `DocShell.Web.Cache` to read,
    defaulting to `DocShell.Web.Cache` itself. A host serving public and
    internal artifact sets runs two caches and mounts this plug twice, with a
    different gate on each.

    Hosts that would rather route through their own controller can call
    `DocShell.Web.Controller.show/2` instead. This module is only compiled when
    Plug is installed.
    """

    @behaviour Plug

    alias DocShell.Web.Cache

    @impl Plug
    def init(opts) do
      %{cache: Keyword.get(opts, :cache, Cache), gate: Keyword.get(opts, :gate)}
    end

    @impl Plug
    def call(conn, %{cache: cache, gate: gate}) do
      with :ok <- authorize(conn, gate),
           name when is_binary(name) <- artifact_name(conn.path_info),
           {:ok, envelope} <- Cache.fetch_envelope(name, cache),
           {:ok, body} <- Jason.encode(envelope) do
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, body)
        |> Plug.Conn.halt()
      else
        {:error, :forbidden} -> respond(conn, 403, "forbidden")
        {:error, _} -> respond(conn, 500, "internal error")
        _ -> respond(conn, 404, "not found")
      end
    end

    defp respond(conn, status, body) do
      conn
      |> Plug.Conn.send_resp(status, body)
      |> Plug.Conn.halt()
    end

    defp artifact_name([name]) when name != "" do
      case String.ends_with?(name, ".json") do
        true -> name
        false -> name <> ".json"
      end
    end

    defp artifact_name(_), do: nil

    defp authorize(_, nil), do: :ok
    defp authorize(conn, fun) when is_function(fun, 1), do: normalize_gate(fun.(conn))

    defp authorize(conn, {module, function, args}),
      do: normalize_gate(apply(module, function, [conn | args]))

    defp normalize_gate(:ok), do: :ok
    defp normalize_gate(true), do: :ok
    defp normalize_gate(_), do: {:error, :forbidden}
  end
end
