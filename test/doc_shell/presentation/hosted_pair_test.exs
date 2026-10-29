defmodule DocShell.Presentation.HostedPairTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias DocShell.Presentation.{GraphProjector, HostedPair}

  test "keeps one admitted graph view with its matching OpenAPI document" do
    expected = publication_binding()
    presentation = presentation(expected)
    openapi = openapi(expected)

    assert {:ok, %{publication: ^expected, presentation: ^presentation, openapi: ^openapi}} =
             HostedPair.validate(presentation, openapi, expected)
  end

  test "ships one language-neutral fixture and its binding schema" do
    root = Path.join(to_string(:code.priv_dir(:doc_shell)), "contracts")
    fixture = root |> Path.join("hosted-pair-v1.json") |> File.read!() |> Jason.decode!()

    schema =
      root |> Path.join("publication-binding-v1.schema.json") |> File.read!() |> Jason.decode!()

    expected = fixture["binding"]
    presentation = %{presentation(expected) | content: fixture["presentation"]["content"]}
    spec = Map.put(fixture["openapi"], "x-doc-shell-publication", expected)
    assert {:ok, _} = HostedPair.validate(presentation, spec, expected)
    assert Enum.sort(schema["required"]) == Enum.sort(Map.keys(expected))

    assert Enum.sort(fixture["mismatch_fields"]) ==
             Enum.sort(Map.keys(expected) -- ["schema_version"])
  end

  test "refuses every missing, reused or cross-view binding before consumption" do
    expected = publication_binding()

    for side <- [:presentation, :openapi],
        field <- ~w(publication_id source_view graph_position locale release disclosure_surface) do
      changed = Map.update!(expected, field, &(&1 <> "-other"))

      {presentation, spec} =
        if side == :presentation,
          do: {presentation(changed), openapi(expected)},
          else: {presentation(expected), openapi(changed)}

      assert {:error, {:publication_mismatch, ^side, ^field}} =
               HostedPair.validate(presentation, spec, expected)
    end

    stale = Map.put(expected, "publication_id", "old")

    assert {:error, {:publication_mismatch, :presentation, "publication_id"}} =
             HostedPair.validate(presentation(stale), openapi(stale), expected)

    for invalid <- [
          nil,
          %{},
          [],
          Map.put(expected, "unknown", true),
          Map.put(expected, "schema_version", "future"),
          Map.put(expected, "locale", ""),
          Map.put(expected, "release", String.duplicate("x", 4097)),
          Map.put(expected, "source_view", <<255>>)
        ] do
      assert {:error, {:invalid_publication_binding, :expected}} =
               HostedPair.validate(presentation(expected), openapi(expected), invalid)

      assert {:error, {:invalid_publication_binding, :presentation}} =
               HostedPair.validate(presentation(invalid), openapi(expected), expected)

      assert {:error, {:invalid_publication_binding, :openapi}} =
               HostedPair.validate(presentation(expected), openapi(invalid), expected)
    end
  end

  test "also validates source shapes and leaves unpaired legacy presentations valid" do
    expected = publication_binding()

    assert {:error, {:invalid_presentation, :missing_schema_version}} =
             HostedPair.validate(%{publication: expected}, openapi(expected), expected)

    assert {:error, :invalid_openapi_document} =
             HostedPair.validate(
               presentation(expected),
               %{"x-doc-shell-publication" => expected},
               expected
             )

    assert {:error, :invalid_hosted_pair} = HostedPair.validate(nil, nil, expected)
    assert {:error, :invalid_publication_binding} = GraphProjector.validate(presentation(nil))
    assert {:ok, _} = GraphProjector.validate(Map.delete(presentation(expected), :publication))
  end

  property "immutable bindings survive JSON without changing pair acceptance" do
    check all(id <- string(:alphanumeric, min_length: 1, max_length: 80)) do
      expected = Map.put(publication_binding(), "publication_id", id)
      decoded = Jason.decode!(Jason.encode!(expected))
      assert {:ok, _} = HostedPair.validate(presentation(decoded), openapi(decoded), expected)
    end
  end

  defp publication_binding do
    %{
      "schema_version" => "doc-shell-publication/v1",
      "publication_id" => "snapshot-1",
      "source_view" => "view-1",
      "graph_position" => "position-1",
      "locale" => "en",
      "release" => "v1",
      "disclosure_surface" => "public"
    }
  end

  defp presentation(binding),
    do: %{
      schema_version: "doc-shell/v2",
      navigation: [],
      search: [],
      content: %{},
      publication: binding
    }

  defp openapi(binding), do: %{"openapi" => "3.1.0", "x-doc-shell-publication" => binding}
end
