defmodule DocShell.Web.ControllerTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Plug.Test
  import DocShell.TmpDir

  alias DocShell.ArtifactFixture
  alias DocShell.Web.Cache
  alias DocShell.Web.Controller

  setup do
    root = tmp_dir!("doc-shell-controller")
    ArtifactFixture.write_snapshot!(root, [{"guide.json", %{"id" => "intro"}}])
    start_supervised!({Cache, dir: root})
    :ok
  end

  test "serves a cached artifact as a versioned JSON envelope" do
    conn = Controller.show(conn(:get, "/docs/guide"), %{"artifact" => "guide"})

    assert conn.status == 200
    assert hd(Plug.Conn.get_resp_header(conn, "content-type")) =~ "application/json"

    body = Jason.decode!(conn.resp_body)
    assert body["schema_version"] == DocShell.schema_version()
    assert body["data"] == %{"id" => "intro"}
  end

  test "returns 404 for an unknown artifact" do
    conn = Controller.show(conn(:get, "/docs/missing"), %{"artifact" => "missing"})
    assert conn.status == 404
  end

  test "accepts an artifact name with its JSON extension" do
    conn = Controller.show(conn(:get, "/docs/guide.json"), %{"artifact" => "guide.json"})
    assert conn.status == 200
  end

  test "returns 404 when the artifact parameter is absent or empty" do
    assert Controller.show(conn(:get, "/docs"), %{}).status == 404
    assert Controller.show(conn(:get, "/docs"), %{"artifact" => ""}).status == 404
  end

  test "returns 500 for a non-JSON-encodable cache entry" do
    generation_id = ArtifactFixture.active_generation(Cache)

    :ets.insert(
      Cache,
      {{:artifact, generation_id, "bad.json"}, %{"data" => {:not, :encodable}}}
    )

    conn = Controller.show(conn(:get, "/docs/bad"), %{"artifact" => "bad"})
    assert conn.status == 500
  end
end
