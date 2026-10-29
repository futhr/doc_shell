defmodule DocShell.ArtifactConformance do
  @moduledoc false
  @path "priv/contracts/artifact-conformance-v1.json"
  @external_resource @path
  @cases @path |> File.read!() |> Jason.decode!() |> Map.fetch!("cases")

  @spec cases() :: [map()]
  def cases, do: @cases

  @spec fixture(String.t()) :: map()
  def fixture(id), do: Enum.find(@cases, &(&1["id"] == id))

  @spec checked(map(), map(), [String.t()]) :: {:ok, map()} | {:error, atom()}
  def checked(block, subjects, limitations) do
    valid =
      Enum.all?(block["bindings"], fn binding ->
        subjects[binding["subject_id"]] == binding["subject_kind"] and
          binding["subject_ref"] == block["artifact_ref"] <> "#" <> binding["subject_id"]
      end)

    if valid,
      do:
        {:ok,
         %{
           "profile" => block["profile"],
           "artifact_ref" => block["artifact_ref"],
           "manifest_digest" => block["manifest_digest"],
           "subjects" => block["bindings"],
           "limitations" => limitations
         }},
      else: {:error, :unknown_fixture_subject}
  end
end

defmodule DocShell.FrozenChartProfile do
  @moduledoc false
  @behaviour DocShell.Presentation.ArtifactProfile
  @spec describe() :: map()
  def describe, do: DocShell.ArtifactConformance.fixture("chart")["descriptor"]

  @spec validate(map(), map()) :: {:ok, map()} | {:error, term()}
  def validate(block, %{manifest: manifest}) do
    schema = JSV.build!(DocShell.ArtifactConformance.fixture("chart")["input_schema"])

    with {:ok, _} <- JSV.validate(manifest, schema) do
      subjects = Map.new(manifest["measurements"], &{&1["id"], "example/measurement"})
      DocShell.ArtifactConformance.checked(block, subjects, [manifest["warning"]])
    end
  end
end

defmodule DocShell.FrozenDrawingProfile do
  @moduledoc false
  @behaviour DocShell.Presentation.ArtifactProfile
  @spec describe() :: map()
  def describe, do: DocShell.ArtifactConformance.fixture("drawing")["descriptor"]

  @spec validate(map(), map()) :: {:ok, map()} | {:error, term()}
  def validate(block, %{manifest: manifest}) do
    schema = JSV.build!(DocShell.ArtifactConformance.fixture("drawing")["input_schema"])

    with {:ok, _} <- JSV.validate(manifest, schema) do
      subjects = Map.new(manifest["subjects"], &{&1["id"], &1["kind"]})
      DocShell.ArtifactConformance.checked(block, subjects, [manifest["limitation"]])
    end
  end
end

defmodule DocShell.ArtifactDescriptorOverride do
  @moduledoc false
  @spec describe() :: map()
  def describe, do: Process.get(:artifact_descriptor_override)

  @spec validate(map(), map()) :: {:ok, map()} | {:error, term()}
  defdelegate validate(block, context), to: DocShell.ArtifactChartFixture
end
