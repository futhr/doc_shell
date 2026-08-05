defmodule DocShell.ArtifactTest do
  @moduledoc false

  use ExUnit.Case, async: true
  use ExUnitProperties

  import DocShell.TmpDir

  alias DocShell.Artifact

  doctest DocShell.Artifact

  describe "envelope/2" do
    test "wraps a payload with schema version and an ISO8601 timestamp" do
      at = ~U[2026-07-23 10:20:30Z]
      env = Artifact.envelope(%{"a" => 1}, at)

      assert env["schema_version"] == DocShell.schema_version()
      assert env["generated_at"] == "2026-07-23T10:20:30Z"
      assert env["data"] == %{"a" => 1}
    end
  end

  describe "write/2 and read/2 round trip" do
    test "reads back exactly what was written" do
      path = Path.join(tmp_dir!(), "a.json")
      payload = %{"nested" => %{"list" => [1, 2, 3], "flag" => true}}

      assert :ok = Artifact.write(path, payload)
      assert {:ok, ^payload} = Artifact.read(path)
    end

    test "creates missing parent directories" do
      path = Path.join(tmp_dir!(), "deep/nested/dir/a.json")
      assert :ok = Artifact.write(path, %{"x" => 1})
      assert File.exists?(path)
    end

    test "is atomic: no .tmp file remains after a successful write" do
      dir = tmp_dir!()
      path = Path.join(dir, "a.json")
      assert :ok = Artifact.write(path, %{"x" => 1})

      assert File.ls!(dir) == ["a.json"]
      refute File.exists?(path <> ".tmp")
    end

    test "concurrent writes leave one complete artifact and no temporary files" do
      dir = tmp_dir!()
      path = Path.join(dir, "a.json")

      1..10
      |> Task.async_stream(&Artifact.write(path, %{"writer" => &1}), ordered: false)
      |> Enum.each(fn result -> assert result == {:ok, :ok} end)

      assert {:ok, %{"writer" => writer}} = Artifact.read(path)
      assert writer in 1..10
      assert File.ls!(dir) == ["a.json"]
    end

    test "trailing newline is written for POSIX-friendly files" do
      path = Path.join(tmp_dir!(), "a.json")
      assert :ok = Artifact.write(path, %{"x" => 1})
      assert String.ends_with?(File.read!(path), "\n")
    end
  end

  describe "read/1 rejects invalid artifacts" do
    test "rejects an unsupported schema version" do
      path = Path.join(tmp_dir!(), "a.json")

      File.write!(
        path,
        Jason.encode!(%{
          "schema_version" => "doc-shell/v999",
          "generated_at" => "2026-07-23T10:20:30Z",
          "data" => %{}
        })
      )

      assert {:error, :unsupported_schema_version} = Artifact.read(path)
    end

    test "rejects a well-formed JSON that is not an artifact envelope" do
      path = Path.join(tmp_dir!(), "a.json")
      File.write!(path, Jason.encode!(%{"totally" => "different"}))

      assert {:error, :invalid_artifact_envelope} = Artifact.read(path)
    end

    test "rejects an envelope without a generation timestamp" do
      path = Path.join(tmp_dir!(), "a.json")

      File.write!(
        path,
        Jason.encode!(%{"schema_version" => DocShell.schema_version(), "data" => %{}})
      )

      assert {:error, :invalid_artifact_envelope} = Artifact.read(path)
    end

    test "rejects an envelope with an invalid generation timestamp" do
      path = Path.join(tmp_dir!(), "a.json")

      File.write!(
        path,
        Jason.encode!(%{
          "schema_version" => DocShell.schema_version(),
          "generated_at" => "yesterday",
          "data" => %{}
        })
      )

      assert {:error, :invalid_artifact_envelope} = Artifact.read(path)
    end

    test "propagates a file-not-found error" do
      assert {:error, :enoent} = Artifact.read(Path.join(tmp_dir!(), "missing.json"))
    end

    test "propagates a JSON decode error on a corrupt file" do
      path = Path.join(tmp_dir!(), "a.json")
      File.write!(path, "{not valid json")

      assert {:error, %Jason.DecodeError{}} = Artifact.read(path)
    end
  end

  describe "read_envelope/1" do
    test "keeps the build timestamp that read/1 discards" do
      path = Path.join(tmp_dir!(), "artifact.json")
      :ok = Artifact.write(path, %{"a" => 1})

      {:ok, envelope} = Artifact.read_envelope(path)
      {:ok, data} = Artifact.read(path)

      assert data == %{"a" => 1}
      assert envelope["data"] == %{"a" => 1}
      assert envelope["schema_version"] == DocShell.schema_version()
      assert {:ok, _, _} = DateTime.from_iso8601(envelope["generated_at"])
    end

    test "rejects a foreign schema version like read/1 does" do
      path = Path.join(tmp_dir!(), "artifact.json")

      File.write!(
        path,
        Jason.encode!(%{
          "schema_version" => "doc-shell/v999",
          "generated_at" => "2026-07-23T10:20:30Z",
          "data" => %{}
        })
      )

      assert {:error, :unsupported_schema_version} = Artifact.read_envelope(path)
    end
  end

  describe "write_raw/2" do
    test "writes the payload with no envelope around it" do
      path = Path.join(tmp_dir!(), "openapi.json")
      spec = %{"openapi" => "3.1.0", "paths" => %{}}

      assert :ok = Artifact.write_raw(path, spec)
      assert path |> File.read!() |> Jason.decode!() == spec
    end

    test "creates missing parent directories" do
      path = Path.join(tmp_dir!(), "deep/nested/openapi.json")

      assert :ok = Artifact.write_raw(path, %{"openapi" => "3.1.0"})
      assert File.exists?(path)
    end
  end

  describe "properties" do
    property "a written artifact reads back as the payload that was written" do
      dir = tmp_dir!("artifact-property")

      check all(value <- payload_generator(), max_runs: 50) do
        path = Path.join(dir, "artifact-#{System.unique_integer([:positive])}.json")

        assert :ok = Artifact.write(path, value)
        assert {:ok, ^value} = Artifact.read(path)
      end
    end

    property "writing leaves no temporary files behind" do
      dir = tmp_dir!("artifact-temp")

      check all(value <- payload_generator(), max_runs: 50) do
        assert :ok = Artifact.write(Path.join(dir, "leftovers.json"), value)
        assert Path.wildcard(Path.join(dir, "*.tmp")) == []
      end
    end

    property "every envelope carries the current version and a parseable timestamp" do
      check all(value <- payload_generator()) do
        envelope = Artifact.envelope(value)

        assert envelope["schema_version"] == DocShell.schema_version()
        assert envelope["data"] == value
        assert {:ok, _, _} = DateTime.from_iso8601(envelope["generated_at"])
      end
    end

    property "an envelope from another schema version is refused, not decoded" do
      dir = tmp_dir!("artifact-version")

      check all(
              value <- payload_generator(),
              version <- string(:alphanumeric, min_length: 1),
              version != DocShell.schema_version(),
              max_runs: 25
            ) do
        path = Path.join(dir, "foreign-#{System.unique_integer([:positive])}.json")

        File.write!(
          path,
          Jason.encode!(%{
            "schema_version" => version,
            "generated_at" => DateTime.to_iso8601(DateTime.utc_now()),
            "data" => value
          })
        )

        assert {:error, :unsupported_schema_version} = Artifact.read(path)
      end
    end
  end

  defp payload_generator do
    scalar = one_of([integer(), string(:printable), boolean(), constant(nil)])

    tree(scalar, fn child ->
      one_of([
        list_of(child, max_length: 4),
        map_of(string(:alphanumeric, min_length: 1), child, max_length: 4)
      ])
    end)
  end
end
