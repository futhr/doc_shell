defmodule DocShell.Web.PlugTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import Plug.Test
  import DocShell.TmpDir

  alias DocShell.Artifact
  alias DocShell.Web.Cache
  alias DocShell.Web.Plug

  setup do
    root = tmp_dir!()
    :ok = Artifact.write(Path.join(root, "guide.json"), %{"id" => "intro"})
    start_supervised!({Cache, dir: root})
    {:ok, root: root}
  end

  describe "serving" do
    test "serves a cached artifact inside its versioned envelope" do
      conn = request("/guide")

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body)["schema_version"] == DocShell.schema_version()
    end

    test "accepts an artifact path that already has a JSON extension" do
      assert request("/guide.json").status == 200
    end

    test "the served generated_at is the build's, and stays put across requests", %{root: root} do
      on_disk = [root, "guide.json"] |> Path.join() |> File.read!() |> Jason.decode!()

      first = Jason.decode!(request("/guide").resp_body)
      second = Jason.decode!(request("/guide").resp_body)

      assert first["generated_at"] == on_disk["generated_at"]
      assert second["generated_at"] == on_disk["generated_at"]
      assert first["data"] == %{"id" => "intro"}
    end

    test "responses halt the conn so the plug is safe inside a pipeline" do
      assert request("/guide").halted
      assert request("/missing").halted
      assert request("/guide", gate: fn _ -> false end).halted
    end
  end

  describe "the authorization gate" do
    test "allows a request when the gate returns :ok" do
      assert request("/guide", gate: {__MODULE__, :allow, []}).status == 200
    end

    test "allows a request when the gate returns true" do
      assert request("/guide", gate: fn _ -> true end).status == 200
    end

    test "refuses with 403 when the gate returns anything else" do
      assert request("/guide", gate: fn _ -> false end).status == 403
    end

    test "serves everything when no gate is configured" do
      assert request("/guide").status == 200
    end
  end

  describe "rejected requests" do
    test "unknown artifacts are 404" do
      assert request("/nope").status == 404
    end

    test "empty and multi-segment paths are not served" do
      assert request("/").status == 404
      assert request("/a/b").status == 404
    end

    test "a non-JSON-encodable cache entry yields 500, not a crash" do
      # Tuples are not JSON-encodable; inject one directly into the cache table.
      :ets.insert(Cache, {"bad.json", %{"data" => {:not, :encodable}}})

      assert request("/bad").status == 500
    end
  end

  describe "init/1" do
    test "resolves options once, at compile time" do
      assert Plug.init([]) == %{cache: Cache, gate: nil}

      gate = fn _ -> :ok end
      assert Plug.init(cache: :other, gate: gate) == %{cache: :other, gate: gate}
    end
  end

  @spec allow(Plug.Conn.t()) :: :ok
  def allow(_), do: :ok

  defp request(path, opts \\ []) do
    :get |> conn(path) |> Plug.call(Plug.init(opts))
  end
end
