defmodule DocShell.Generate.LivebooksTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import DocShell.TmpDir

  alias DocShell.Generate.Livebooks

  describe "extract/1" do
    test "indexes a notebook as a renderer-neutral content entry" do
      root = tmp_dir!()
      File.write!(Path.join(root, "demo.livemd"), "# Demo\n\n```elixir\n1 + 1\n```")

      assert {:ok, [entry]} = Livebooks.extract(root)
      assert entry["id"] == "demo"
      assert entry["title"] == "Demo"
      assert entry["kind"] == "livebook"
      assert entry["meta"]["source_path"] =~ "demo.livemd"
    end

    test "falls back to the filename when there is no H1" do
      root = tmp_dir!()
      File.write!(Path.join(root, "no-title.livemd"), "just text, no heading")

      assert {:ok, [%{"id" => "no-title", "title" => "no-title"}]} = Livebooks.extract(root)
    end

    test "yields an empty list for a base directory that does not exist" do
      assert {:ok, []} = Livebooks.extract(Path.join(tmp_dir!(), "missing"))
    end

    test "propagates a markdown parse error with the offending path" do
      root = tmp_dir!()
      File.write!(Path.join(root, "broken.livemd"), "# LB\n\n```elixir\nunclosed")

      assert {:error, {path, %{messages: _}}} = Livebooks.extract(root)
      assert path =~ "broken.livemd"
    end
  end
end
