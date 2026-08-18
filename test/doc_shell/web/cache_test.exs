defmodule DocShell.Web.CacheTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import DocShell.TmpDir

  alias DocShell.ArtifactFixture
  alias DocShell.Web.Cache

  test "holds validated artifacts, keyed by filename" do
    root = tmp_dir!()
    ArtifactFixture.write_snapshot!(root, [{"guide.json", %{"id" => "intro"}}])
    start_supervised!({Cache, dir: root})

    assert {:ok, %{"id" => "intro"}} = Cache.fetch("guide.json")
  end

  test "fetch_envelope/2 keeps the build timestamp that fetch/2 unwraps" do
    root = tmp_dir!()
    path = Path.join(root, "guide.json")
    ArtifactFixture.write_snapshot!(root, [{"guide.json", %{"id" => "intro"}}])
    start_supervised!({Cache, dir: root})

    on_disk = path |> File.read!() |> Jason.decode!()

    assert {:ok, envelope} = Cache.fetch_envelope("guide.json")
    assert envelope["generated_at"] == on_disk["generated_at"]
    assert envelope["schema_version"] == DocShell.schema_version()
    assert envelope["data"] == %{"id" => "intro"}
  end

  test "reload/1 picks up files added after start" do
    root = tmp_dir!()
    ArtifactFixture.write_snapshot!(root, [{"one.json", %{"id" => "one"}}])
    start_supervised!({Cache, dir: root})

    assert Cache.fetch("two.json") == :error

    ArtifactFixture.write_snapshot!(root, [
      {"one.json", %{"id" => "one"}},
      {"two.json", %{"id" => "two"}}
    ])

    assert :ok = Cache.reload()
    assert {:ok, %{"id" => "two"}} = Cache.fetch("two.json")
  end

  test "reload/1 removes entries whose files were deleted" do
    root = tmp_dir!()
    path = Path.join(root, "one.json")
    ArtifactFixture.write_snapshot!(root, [{"one.json", %{"id" => "one"}}])
    start_supervised!({Cache, dir: root})

    assert {:ok, %{"id" => "one"}} = Cache.fetch("one.json")
    :ok = File.rm(path)
    ArtifactFixture.write_snapshot!(root, [])
    assert :ok = Cache.reload()
    assert :error = Cache.fetch("one.json")
  end

  test "a failed reload keeps the last valid snapshot" do
    root = tmp_dir!()
    ArtifactFixture.write_snapshot!(root, [{"one.json", %{"id" => "one"}}])
    start_supervised!({Cache, dir: root})
    File.write!(Path.join(root, "corrupt.json"), "{ not json")

    assert {:error, {_, %Jason.DecodeError{}}} = Cache.reload()
    assert {:ok, %{"id" => "one"}} = Cache.fetch("one.json")
  end

  test "start_link fails cleanly on a corrupt artifact in the directory" do
    root = tmp_dir!()
    File.write!(Path.join(root, "corrupt.json"), "{ not json")

    Process.flag(:trap_exit, true)
    assert {:error, {path, _}} = Cache.start_link(dir: root, name: :corrupt_cache_test)
    assert path =~ "corrupt.json"
  end

  test "independently named caches use independent tables" do
    d1 = tmp_dir!()
    d2 = tmp_dir!()
    ArtifactFixture.write_snapshot!(d1, [{"a.json", %{"id" => "one"}}])
    ArtifactFixture.write_snapshot!(d2, [{"a.json", %{"id" => "two"}}])

    start_supervised!(Supervisor.child_spec({Cache, dir: d1, name: :cache_one}, id: :cache_one))
    start_supervised!(Supervisor.child_spec({Cache, dir: d2, name: :cache_two}, id: :cache_two))

    assert {:ok, %{"id" => "one"}} = Cache.fetch("a.json", :cache_one)
    assert {:ok, %{"id" => "two"}} = Cache.fetch("a.json", :cache_two)
  end

  test "fetch on a never-started cache table returns :error, not a crash" do
    assert Cache.fetch("x.json", :cache_never_started) == :error
    assert Cache.fetch_envelope("x.json", :cache_never_started) == :error
  end

  test "a mixed disk generation is rejected and keeps the prior snapshot" do
    root = tmp_dir!()

    ArtifactFixture.write_snapshot!(
      root,
      [
        {"left.json", %{"generation" => "old"}},
        {"right.json", %{"generation" => "old"}}
      ],
      "old"
    )

    start_supervised!({Cache, dir: root})
    ArtifactFixture.write_artifact!(root, "left.json", %{"generation" => "new"}, "new")

    assert {:error, {path, {:generation_mismatch, "old", "new"}}} = Cache.reload()
    assert path == Path.join(root, "left.json")
    assert {:ok, %{"generation" => "old"}} = Cache.fetch("left.json")
    assert {:ok, %{"generation" => "old"}} = Cache.fetch("right.json")
  end

  test "readers see the old snapshot until a staged generation is published" do
    root = tmp_dir!()

    ArtifactFixture.write_snapshot!(
      root,
      [
        {"left.json", %{"generation" => "old"}},
        {"right.json", %{"generation" => "old"}}
      ],
      "old"
    )

    cache = start_supervised!({Cache, dir: root})

    ArtifactFixture.write_snapshot!(
      root,
      [
        {"left.json", %{"generation" => "new"}},
        {"right.json", %{"generation" => "new"}}
      ],
      "new"
    )

    test_process = self()

    :sys.replace_state(cache, fn state ->
      %{
        state
        | before_publish: fn ->
            send(test_process, :snapshot_staged)

            receive do
              :publish_snapshot -> :ok
            end
          end
      }
    end)

    reload = Task.async(&Cache.reload/0)
    assert_receive :snapshot_staged
    assert generation_pair() == {"old", "old"}

    send(cache, :publish_snapshot)
    assert Task.await(reload) == :ok
    assert generation_pair() == {"new", "new"}
  end

  defp generation_pair do
    {:ok, left} = Cache.fetch("left.json")
    {:ok, right} = Cache.fetch("right.json")
    {left["generation"], right["generation"]}
  end
end
