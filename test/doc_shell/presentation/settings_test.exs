defmodule DocShell.Presentation.SettingsTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Presentation.Settings

  test "accepts empty defaults and inert host-authored settings" do
    assert :ok = Settings.validate(%{})

    assert :ok =
             Settings.validate(%{
               "brand" => %{
                 "label" => "Example",
                 "href" => "/docs/",
                 "logo" => %{"asset" => "brand/logo.svg", "alt" => ""}
               },
               "footer" => %{
                 "text" => "Example documentation",
                 "links" => [%{"label" => "Support", "href" => "https://example.invalid/help"}]
               },
               "labels" => %{"search" => "Sök", "theme_system" => "System"},
               "locales" => [
                 %{"id" => "sv", "label" => "Svenska", "href" => "/sv/", "current" => true}
               ],
               "releases" => [%{"id" => "v1", "label" => "Version 1", "href" => "/v1/"}],
               "metadata" => %{
                 "description" => "Portable docs",
                 "image" => "/preview.png",
                 "robots" => ["noindex", "nofollow"]
               },
               "robots" => %{"allow" => ["/docs/"], "disallow" => ["/drafts/"]}
             })
  end

  test "rejects unsafe destinations, invalid structures and executable values" do
    for href <- [
          "javascript:alert(1)",
          "data:text/html,hi",
          "//other.invalid",
          "relative",
          "https://user:pass@example.invalid",
          "/a\nb",
          "/a\\b",
          "http://[",
          <<255>>
        ] do
      assert {:error, {:invalid_presentation_settings, _}} =
               Settings.validate(%{"brand" => %{"label" => "Brand", "href" => href}})
    end

    for value <- [
          nil,
          [],
          :invalid,
          %{"unknown" => true},
          %{"brand" => %{}},
          %{"footer" => %{"html" => "<script>"}},
          %{"labels" => %{"search" => fn -> :ok end}},
          %{
            "locales" => [
              %{"id" => "en", "label" => "English", "href" => "/", "current" => "yes"}
            ]
          },
          %{"metadata" => %{"robots" => ["index", "noindex"]}},
          %{"metadata" => %{"robots" => ["follow", "nofollow"]}},
          %{"metadata" => %{"robots" => ["index", "index"]}},
          %{"metadata" => %{"robots" => ["invented"]}},
          %{"robots" => %{"disallow" => ["https://example.invalid/"]}},
          %{"robots" => %{"allow" => ["/docs/?query"]}},
          %{
            "brand" => %{
              "label" => "Brand",
              "href" => "/",
              "logo" => %{"asset" => "../logo.svg", "alt" => "Logo"}
            }
          }
        ] do
      assert {:error, {:invalid_presentation_settings, ^value}} = Settings.validate(value)
    end
  end

  test "bounds lists and labels and refuses ambiguous selections" do
    destination = %{"id" => "en", "label" => "English", "href" => "/", "current" => true}

    for settings <- [
          %{"locales" => [destination, destination]},
          %{"releases" => [destination, %{destination | "id" => "other"}]},
          %{"footer" => %{"links" => List.duplicate(%{"label" => "Docs", "href" => "/"}, 65)}},
          %{"labels" => %{"search" => String.duplicate("x", 4097)}},
          %{"labels" => Map.new(1..129, &{"label#{&1}", "text"})}
        ] do
      assert {:error, _} = Settings.validate(settings)
    end
  end

  property "valid labels retain exact JSON text through a round trip" do
    check all(label <- string(:printable, min_length: 1, max_length: 100)) do
      value = %{"labels" => %{"search" => label}}
      assert :ok = Settings.validate(value)
      assert {:ok, ^value} = DocShell.Json.decode(Jason.encode!(value))
    end
  end
end
