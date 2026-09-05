if Code.ensure_loaded?(Plug.Conn) do
  defmodule DocShell.Web.Response do
    @moduledoc """
    Sends an immutable cached JSON representation with HTTP validators.

    Both the plug and controller use this response path so HEAD, conditional
    requests, and method handling agree. It performs no authorization: the host
    pipeline or DocShell plug gate must run first, including for 304 responses.
    Cache-Control and Vary remain host choices; this module preserves those
    headers and does not enable shared caching of protected documentation.
    """

    alias DocShell.Web.Cache
    alias Plug.Conn

    @doc "Serves a named artifact for GET or HEAD from the selected cache."
    @spec send(Conn.t(), term(), atom()) :: Conn.t()
    def send(conn, artifact, cache \\ Cache)

    def send(%{method: method} = conn, _, _) when method not in ["GET", "HEAD"] do
      conn
      |> Conn.put_resp_header("allow", "GET, HEAD")
      |> Conn.send_resp(405, "method not allowed")
    end

    def send(conn, artifact, cache) do
      with {:ok, name} <- artifact_name(artifact),
           {:ok, {body, etag}} <- Cache.fetch_response(name, cache) do
        respond(conn, body, etag)
      else
        :error -> send_error(conn, 404, "not found")
      end
    end

    @doc "Sends an error response, omitting its body for HEAD requests."
    @spec send_error(Conn.t(), non_neg_integer(), String.t()) :: Conn.t()
    def send_error(%{method: "HEAD"} = conn, status, body) do
      conn
      |> Conn.put_resp_header("content-length", Integer.to_string(byte_size(body)))
      |> Conn.send_resp(status, "")
    end

    def send_error(conn, status, body), do: Conn.send_resp(conn, status, body)

    defp artifact_name(name) when is_binary(name) and name != "" do
      case String.contains?(name, ["/", "\\"]) do
        true -> :error
        false -> {:ok, if(String.ends_with?(name, ".json"), do: name, else: name <> ".json")}
      end
    end

    defp artifact_name(_), do: :error

    defp respond(conn, body, etag) do
      conn =
        conn
        |> Conn.put_resp_content_type("application/json")
        |> Conn.put_resp_header("etag", etag)

      cond do
        matches?(conn, etag) ->
          Conn.send_resp(conn, 304, "")

        conn.method == "HEAD" ->
          conn
          |> Conn.put_resp_header("content-length", Integer.to_string(byte_size(body)))
          |> Conn.send_resp(200, "")

        true ->
          Conn.send_resp(conn, 200, body)
      end
    end

    defp matches?(conn, etag) do
      conn
      |> Conn.get_req_header("if-none-match")
      |> Enum.flat_map(&Plug.Conn.Utils.list/1)
      |> Enum.any?(fn tag -> tag == "*" or String.trim_leading(tag, "W/") == etag end)
    end
  end
end
