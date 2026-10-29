defmodule DocShell.ArtifactTestProducer do
  @moduledoc false
  @spec descriptor(String.t()) :: map()
  def descriptor(profile),
    do: %{
      "profile" => profile,
      "revision" => "1",
      "input_schema_digest" => digest("example-schema"),
      "subject_vocabulary" => ["example/value"],
      "media_types" => ["image/svg+xml", "text/html"],
      "fallback" => "complete-text",
      "limits" => %{"subjects" => 64}
    }

  @spec digest(binary()) :: String.t()
  def digest(bytes), do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  @spec validate(map(), map()) :: term()
  def validate(block, %{manifest: manifest}) do
    case manifest["failure"] do
      "raise" -> raise "private callback input"
      "throw" -> throw(:private_callback_input)
      "exit" -> exit(:private_callback_input)
      "malformed" -> :invalid
      "refuse" -> {:error, :producer_subject_refusal}
      _ -> membership(block, manifest)
    end
  end

  defp membership(block, manifest) do
    valid =
      Enum.all?(
        block["bindings"],
        &(&1["subject_id"] in manifest["subjects"] and
            &1["subject_ref"] == block["artifact_ref"] <> "#" <> &1["subject_id"])
      )

    if valid,
      do:
        {:ok,
         %{
           "profile" => block["profile"],
           "artifact_ref" => block["artifact_ref"],
           "manifest_digest" => block["manifest_digest"],
           "subjects" => block["bindings"]
         }},
      else: {:error, :unknown_subject}
  end
end

defmodule DocShell.ArtifactChartFixture do
  @moduledoc false
  @behaviour DocShell.Presentation.ArtifactProfile
  @spec describe() :: map()
  def describe, do: DocShell.ArtifactTestProducer.descriptor("example/chart/v1")
  @spec validate(map(), map()) :: term()
  def validate(block, context), do: DocShell.ArtifactTestProducer.validate(block, context)
end

defmodule DocShell.ArtifactDrawingFixture do
  @moduledoc false
  @behaviour DocShell.Presentation.ArtifactProfile
  @spec describe() :: map()
  def describe, do: DocShell.ArtifactTestProducer.descriptor("example/drawing/v1")
  @spec validate(map(), map()) :: term()
  def validate(block, context), do: DocShell.ArtifactTestProducer.validate(block, context)
end

defmodule DocShell.ArtifactBadDescriptorFixture do
  @moduledoc false
  @spec describe() :: no_return()
  def describe, do: raise("bad descriptor")
  @spec validate(term(), term()) :: :invalid
  def validate(_, _), do: :invalid
end

defmodule DocShell.ArtifactProfiles do
  @moduledoc false
  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{ArtifactBlock, Asset}
  @spec fixture(module(), map()) :: {map(), keyword()}
  def fixture(adapter, extra \\ %{}) do
    descriptor = adapter.describe()
    {:ok, profile_digest} = Canonical.digest(descriptor)
    {:ok, manifest} = Canonical.encode(Map.merge(%{"subjects" => ["total"]}, extra))
    digest = DocShell.ArtifactTestProducer.digest(manifest)

    assets = [
      %Asset{
        path: "static.svg",
        media_type: "image/svg+xml",
        bytes: "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1\" height=\"1\"/>"
      },
      %Asset{path: "enhanced.html", media_type: "text/html", bytes: "<p>enhanced fixture</p>"}
    ]

    variants =
      assets
      |> Enum.zip(["fallback", "enhanced"])
      |> Enum.map(fn {asset, state} ->
        %{
          "id" => if(state == "fallback", do: "static", else: "enhanced"),
          "profile" => descriptor["profile"],
          "profile_digest" => profile_digest,
          "state" => state,
          "media_type" => asset.media_type,
          "blob_digest" => DocShell.ArtifactTestProducer.digest(asset.bytes),
          "byte_length" => byte_size(asset.bytes),
          "asset" => asset.path,
          "runtime" => if(state == "fallback", do: [], else: ["browser_js"])
        }
      end)

    binding = %{
      "anchor" => "total",
      "subject_ref" => "chart:sample#total",
      "subject_kind" => "example/value",
      "subject_id" => "total"
    }

    node = %{
      "tag" => "artifact",
      "attrs" => %{"id" => "chart"},
      "content" => [
        %{"tag" => "span", "attrs" => %{"id" => "total"}, "content" => [], "meta" => %{}},
        %{
          "tag" => "p",
          "attrs" => %{},
          "content" => ["Total: 12. Required warning remains visible."],
          "meta" => %{}
        }
      ],
      "meta" => %{
        "artifact" => %{
          "schema_version" => "doc-shell-artifact-block/v1",
          "profile" => descriptor["profile"],
          "profile_digest" => profile_digest,
          "artifact_ref" => "chart:sample",
          "manifest_digest" => digest,
          "caption" => "Chart",
          "description" => "Complete accessible chart",
          "locale" => "en",
          "bindings" => [binding],
          "variants" => variants,
          "acceptable_states" => ["fallback", "enhanced"],
          "essential" => true,
          "fallback_digest" => ""
        }
      }
    }

    features =
      Enum.map(
        variants,
        &%{
          "id" => &1["id"],
          "profile" => descriptor["profile"],
          "profile_digest" => profile_digest,
          "schema_digest" => descriptor["input_schema_digest"],
          "output_mode" => "static",
          "state" => &1["state"],
          "media_types" => [&1["media_type"]],
          "runtime" => &1["runtime"]
        }
      )

    capabilities = %{
      "schema_version" => "doc-shell-renderer-capabilities/v2",
      "renderer_id" => "example/static",
      "renderer_version" => "1.0.0",
      "output_modes" => ["static"],
      "features" => features
    }

    options = [
      profiles: [adapter],
      manifests: %{digest => manifest},
      projections: %{},
      assets: assets,
      capabilities: capabilities,
      constraints: %{
        "output_mode" => "static",
        "preferences" => ["enhanced", "static"],
        "available_runtime" => [],
        "forbidden_runtime" => ["browser_js", "live_transport", "native_host"]
      }
    ]

    {stamp(node), options}
  end

  @spec stamp(map()) :: map()
  def stamp(node) do
    {:ok, digest} = ArtifactBlock.fallback_digest(node)
    put_in(node, ["meta", "artifact", "fallback_digest"], digest)
  end
end

defmodule DocShell.ArtifactLimitProbeFixture do
  @moduledoc false
  @spec describe() :: map()
  def describe do
    send(self(), :descriptor_called)
    DocShell.ArtifactChartFixture.describe()
  end

  @spec validate(map(), map()) :: term()
  def validate(block, context) do
    send(self(), :validator_called)
    DocShell.ArtifactChartFixture.validate(block, context)
  end
end

defmodule DocShell.ArtifactDuplicateSubjectsFixture do
  @moduledoc false
  @spec describe() :: map()
  defdelegate describe(), to: DocShell.ArtifactChartFixture

  @spec validate(map(), map()) :: term()
  def validate(block, context) do
    with {:ok, checked} <- DocShell.ArtifactChartFixture.validate(block, context),
         do: {:ok, Map.update!(checked, "subjects", &(&1 ++ &1))}
  end
end
