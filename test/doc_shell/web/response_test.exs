defmodule DocShell.Web.ResponseTest do
  @moduledoc false
  use ExUnit.Case, async: false
  import Plug.Test
  import DocShell.TmpDir
  alias DocShell.ArtifactFixture
  alias DocShell.Web.Cache
  alias DocShell.Web.Plug, as: DocsPlug
  alias DocShell.Web.Response

  setup do
    root = tmp_dir!()
    ArtifactFixture.write_snapshot!(root, [{"guide.json", %{"body" => "hello"}}])
    start_supervised!({Cache, dir: root})
    %{root: root}
  end

  test "GET and HEAD share validators and preserve host caching headers" do
    get = Response.send(conn(:get, "/guide"), "guide")
    head = Response.send(conn(:head, "/guide"), "guide.json")
    assert get.status == 200
    assert head.status == 200
    assert head.resp_body == ""

    assert Plug.Conn.get_resp_header(head, "content-length") == [
             Integer.to_string(byte_size(get.resp_body))
           ]

    assert Plug.Conn.get_resp_header(head, "etag") == Plug.Conn.get_resp_header(get, "etag")

    cached =
      Plug.Conn.put_resp_header(conn(:get, "/guide"), "cache-control", "private, max-age=0")

    assert Plug.Conn.get_resp_header(Response.send(cached, "guide"), "cache-control") == [
             "private, max-age=0"
           ]
  end

  test "conditional GET and HEAD use weak comparison and support wildcard lists" do
    [etag] = Plug.Conn.get_resp_header(Response.send(conn(:get, "/guide"), "guide"), "etag")

    for method <- [:get, :head], validator <- [etag, "W/" <> etag, "*", "\"other\", " <> etag] do
      request = Plug.Conn.put_req_header(conn(method, "/guide"), "if-none-match", validator)
      assert %{status: 304, resp_body: ""} = Response.send(request, "guide")
    end

    request = Plug.Conn.put_req_header(conn(:get, "/guide"), "if-none-match", "\"other\"")
    assert Response.send(request, "guide").status == 200
  end

  test "the gate still runs before conditional responses and method handling" do
    opts = DocsPlug.init(gate: fn _ -> false end)
    request = Plug.Conn.put_req_header(conn(:get, "/guide"), "if-none-match", "*")
    assert DocsPlug.call(request, opts).status == 403
    assert DocsPlug.call(conn(:post, "/guide"), opts).status == 403
  end

  test "unsupported methods and invalid names have explicit responses" do
    response = Response.send(conn(:post, "/guide"), "guide")
    assert response.status == 405
    assert Plug.Conn.get_resp_header(response, "allow") == ["GET, HEAD"]

    for name <- [nil, "", "missing", "a/b", "a\\b"] do
      assert Response.send(conn(:get, "/"), name).status == 404
    end

    assert Cache.fetch_response("guide.json", :absent_cache) == :error
  end

  test "reload replaces the body and validator together", %{root: root} do
    assert {:ok, {body, etag}} = Cache.fetch_response("guide.json")
    assert Jason.decode!(body)["data"] == %{"body" => "hello"}
    assert :ok = Cache.reload()
    assert {:ok, {^body, ^etag}} = Cache.fetch_response("guide.json")
    ArtifactFixture.write_snapshot!(root, [{"guide.json", %{"body" => "updated"}}])
    assert :ok = Cache.reload()
    assert {:ok, {new_body, new_etag}} = Cache.fetch_response("guide.json")
    refute new_etag == etag
    assert Jason.decode!(new_body)["data"] == %{"body" => "updated"}
  end

  test "HEAD errors carry the GET content length and no body" do
    assert %{status: 404, resp_body: ""} =
             missing = Response.send(conn(:head, "/missing"), "missing")

    assert Plug.Conn.get_resp_header(missing, "content-length") == ["9"]
    opts = DocsPlug.init(gate: fn _ -> false end)
    assert %{status: 403, resp_body: ""} = denied = DocsPlug.call(conn(:head, "/guide"), opts)
    assert Plug.Conn.get_resp_header(denied, "content-length") == ["9"]
  end
end
