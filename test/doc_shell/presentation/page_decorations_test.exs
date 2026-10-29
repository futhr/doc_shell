defmodule DocShell.Presentation.PageDecorationsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Presentation.PageDecorations

  test "preserves optional records and complete portable hero/banner content" do
    assert {:ok, nil} = PageDecorations.validate(:banner, nil)
    assert {:ok, nil} = PageDecorations.validate(:hero, nil)
    banner = %{"label" => "Preview", "text" => "Read the current release", "href" => "/stable/"}

    hero = %{
      "title" => "Documentation",
      "tagline" => "Start here",
      "description" => "Portable docs",
      "actions" => [%{"label" => "Read", "href" => "/guide/"}],
      "image" => %{"asset" => "images/hero.svg", "alt" => "Example documentation"}
    }

    assert {:ok, ^banner} = PageDecorations.validate(:banner, banner)
    assert {:ok, ^hero} = PageDecorations.validate(:hero, hero)
    assert {:ok, _} = PageDecorations.validate(:banner, %{"text" => "Text only"})
    assert {:ok, _} = PageDecorations.validate(:hero, %{"title" => "Title only"})
  end

  test "rejects malformed, executable, oversized and unsupported records" do
    for {kind, value} <- [
          {:banner, %{}},
          {:banner, []},
          {:banner, %{"label" => 1}},
          {:banner, %{"text" => ""}},
          {:banner, %{"label" => "Notice", "href" => "javascript:bad"}},
          {:hero, %{}},
          {:hero, %{"title" => fn -> "title" end}},
          {:hero, %{"title" => "Title", "tagline" => false}},
          {:hero, %{"title" => "Title", "description" => String.duplicate("x", 4097)}},
          {:hero, %{"title" => "Title", "component" => "HostComponent"}},
          {:hero,
           %{"title" => "Title", "actions" => [%{"label" => "Read", "href" => "//other.invalid"}]}},
          {:hero, %{"title" => "Title", "image" => %{"asset" => "../hero.svg", "alt" => "Hero"}}}
        ] do
      assert {:error, {:invalid_page_decoration, ^kind, ^value}} =
               PageDecorations.validate(kind, value)
    end

    assert {:error, {:invalid_page_decoration_kind, :other}} =
             PageDecorations.validate(:other, %{})
  end

  property "plain hero text survives JSON round trips unchanged" do
    check all(title <- string(:printable, min_length: 1, max_length: 100)) do
      value = %{"title" => title}
      assert {:ok, ^value} = PageDecorations.validate(:hero, value)
      assert {:ok, ^value} = DocShell.Json.decode(Jason.encode!(value))
    end
  end
end
