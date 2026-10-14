defmodule DocShell.Generate.ExDocTest do
  @moduledoc false

  use ExUnit.Case, async: false

  import DocShell.TmpDir

  alias DocShell.Generate.ExDoc

  setup do
    dir = tmp_dir!("exdoc-beams")
    Code.prepend_path(String.to_charlist(dir))
    on_exit(fn -> Code.delete_path(String.to_charlist(dir)) end)
    {:ok, dir: dir}
  end

  # Compiles `src` and writes its .beam so Code.fetch_docs/1 can read it back.
  defp compile_beam(dir, src, docs?) do
    prev = Code.get_compiler_option(:docs)
    Code.put_compiler_option(:docs, docs?)
    [{mod, bin}] = Code.compile_string(src)
    Code.put_compiler_option(:docs, prev)

    File.write!(Path.join(dir, "#{mod}.beam"), bin)
    on_exit(fn -> purge(mod) end)
    mod
  end

  test "extracts moduledoc AST and per-member docs (documented and undocumented)", %{dir: dir} do
    mod =
      compile_beam(
        dir,
        """
        defmodule ExDocFixtureDoc do
          @moduledoc "# Title\\n\\nBody **text**"
          @doc "does a thing"
          def documented(x), do: x
          def undocumented(y), do: y
        end
        """,
        true
      )

    assert {:ok, [entry]} = ExDoc.extract([mod])
    assert entry["kind"] == "module"
    assert [%{"tag" => "h1"} | _] = entry["ast"]

    members = Map.new(entry["meta"]["members"], &{&1["name"], &1})
    assert members["documented"]["doc"] == "does a thing"
    assert members["documented"]["arity"] == 1
    # Undocumented member => :none => empty string (doc_text fallback).
    assert members["undocumented"]["doc"] == ""
  end

  test "skips modules that have no docs chunk", %{dir: dir} do
    mod = compile_beam(dir, "defmodule ExDocFixtureNoDocs do def hi, do: :ok end", false)
    assert {:ok, []} = ExDoc.extract([mod])
  end

  test "ambiguous member metadata fails instead of silently discarding an encoded key", %{
    dir: dir
  } do
    mod =
      compile_beam(
        dir,
        """
        defmodule ExDocFixtureMetadataKeys do
          @moduledoc "A documented module."
          @doc custom: %{:enabled => true, "enabled" => false}
          def sample, do: :ok
        end
        """,
        true
      )

    assert {:error, {:member_metadata, "sample", 0, {:duplicate_json_key, "enabled"}}} =
             ExDoc.extract_module(mod, member_metadata: :all)

    assert {:error, {^mod, {:member_metadata, "sample", 0, _}}} =
             ExDoc.extract([mod], member_metadata: ["custom"])
  end

  test "member metadata keeps ExDoc keys by default and everything on request", %{dir: dir} do
    mod =
      compile_beam(
        dir,
        """
        defmodule ExDocFixtureMetadataFilter do
          @moduledoc "A documented module."
          @doc since: "1.2.0", spark_opts: [huge: [nested: :schema]]
          def sample, do: :ok
          @doc false
          def hidden, do: :ok
        end
        """,
        true
      )

    assert {:ok, entry} = ExDoc.extract_module(mod)
    members = Map.new(entry["meta"]["members"], &{&1["name"], &1})
    assert members["sample"]["metadata"]["since"] == "1.2.0"
    refute Map.has_key?(members["sample"]["metadata"], "spark_opts")
    assert members["sample"]["doc_state"] == "none"
    assert members["hidden"]["doc_state"] == "hidden"

    assert {:ok, [all]} = ExDoc.extract([mod], member_metadata: :all)
    sample = Enum.find(all["meta"]["members"], &(&1["name"] == "sample"))
    assert sample["metadata"]["spark_opts"] == [["huge", [["nested", "schema"]]]]

    assert {:ok, [chosen]} = ExDoc.extract([mod], member_metadata: [:spark_opts])
    sample = Enum.find(chosen["meta"]["members"], &(&1["name"] == "sample"))
    assert Map.keys(sample["metadata"]) == ["spark_opts"]
  end

  test "member documentation state distinguishes present, hidden and absent", %{dir: dir} do
    mod =
      compile_beam(
        dir,
        """
        defmodule ExDocFixtureDocState do
          @moduledoc "States."
          @doc "Shown."
          def shown, do: :ok
          @doc false
          def hidden, do: :ok
          def absent, do: :ok
        end
        """,
        true
      )

    assert {:ok, entry} = ExDoc.extract_module(mod)

    assert Map.new(entry["meta"]["members"], &{&1["name"], &1["doc_state"]}) == %{
             "shown" => "present",
             "hidden" => "hidden",
             "absent" => "none"
           }
  end

  test "the first failure in sorted order is reported", %{dir: dir} do
    good = compile_beam(dir, ~s|defmodule ExDocFixtureGood do @moduledoc "ok" end|, true)

    assert {:error, {DocShell.Nonexistent.A, _}} =
             ExDoc.extract([DocShell.Nonexistent.B, good, DocShell.Nonexistent.A])
  end

  test "returns a tagged error for an unloadable module" do
    assert {:error, {DocShell.Nonexistent.Module, _}} =
             ExDoc.extract([DocShell.Nonexistent.Module])
  end

  test "extracts modules in sorted order", %{dir: dir} do
    b = compile_beam(dir, ~s|defmodule ExDocFixtureB do @moduledoc "b" end|, true)
    a = compile_beam(dir, ~s|defmodule ExDocFixtureA do @moduledoc "a" end|, true)

    assert {:ok, [%{"id" => "ExDocFixtureA"}, %{"id" => "ExDocFixtureB"}]} =
             ExDoc.extract([b, a])
  end

  defp purge(module) do
    :code.purge(module)
    :code.delete(module)
  end

  describe "meta.moduledoc" do
    test "reports a documented module as present", %{dir: dir} do
      mod = compile_beam(dir, ~s|defmodule ExDocFixturePresent do @moduledoc "Real." end|, true)

      assert {:ok, entry} = ExDoc.extract_module(mod)
      assert entry["meta"]["moduledoc"] == "present"
      assert entry["ast"] != []
    end

    test "still returns modules marked @moduledoc false, for coverage reporting", %{dir: dir} do
      mod = compile_beam(dir, "defmodule ExDocFixtureHidden do @moduledoc false end", true)

      assert {:ok, entry} = ExDoc.extract_module(mod)
      assert entry["meta"]["moduledoc"] == "hidden"
      assert entry["ast"] == []
    end

    test "tells a module with no @moduledoc apart from @moduledoc false", %{dir: dir} do
      mod = compile_beam(dir, "defmodule ExDocFixtureNone do def hi, do: :ok end", true)

      assert {:ok, entry} = ExDoc.extract_module(mod)
      assert entry["meta"]["moduledoc"] == "none"
      assert entry["ast"] == []
    end
  end
end
