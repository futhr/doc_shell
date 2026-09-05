if Code.ensure_loaded?(Plug.Conn) do
  defmodule DocShell.Web.Controller do
    @moduledoc """
    Serves artifacts from a controller action you already own.

    `DocShell.Web.Plug` handles the whole request, which is convenient until
    the host wants its own pipeline in front — authentication, tenant scoping,
    telemetry, rate limiting, layout for a matching HTML route. Rather than
    growing options for each, this module exposes the response half on its own
    and lets the host keep the routing half:

        defmodule MyAppWeb.DocsController do
          use MyAppWeb, :controller

          plug :require_authenticated_user

          def show(conn, params), do: DocShell.Web.Controller.show(conn, params)
        end

        # router.ex
        get "/docs/api/:artifact", MyAppWeb.DocsController, :show

    There is no gate option here on purpose. Everything before the call is the
    host's, so authorization goes in a plug where it is visible next to the
    rest of the pipeline, instead of being buried in a callback.

    The `"artifact"` param names the file, with `.json` optional. Responses
    match `DocShell.Web.Plug`: `200` with the stored envelope — including the
    build's `generated_at`, not the request's — `404` when it is not cached,
    `304` for a matching ETag, and `405` for methods other than GET or HEAD.

    Despite the name this is not a Phoenix controller — it takes a conn and
    params and returns a conn, which works from a Phoenix action or a bare Plug
    router. The module is only compiled when Plug is installed.
    """

    @doc """
    Sends the cached artifact named by the `"artifact"` param as JSON.

    Reads from the default `DocShell.Web.Cache`; hosts running several named
    caches should use `DocShell.Web.Plug` with its `:cache` option instead.
    """
    @spec show(Plug.Conn.t(), map()) :: Plug.Conn.t()
    def show(conn, %{"artifact" => artifact}), do: DocShell.Web.Response.send(conn, artifact)
    def show(conn, _), do: Plug.Conn.send_resp(conn, 404, "not found")
  end
end
