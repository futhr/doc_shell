defmodule DocShell.ArtifactFixture do
  @moduledoc false

  alias DocShell.Artifact

  @generated_at ~U[2026-08-05 09:12:44Z]

  def write_snapshot!(dir, artifacts, generation_id \\ Artifact.new_generation_id()) do
    opts = [generated_at: @generated_at, generation_id: generation_id]

    Enum.each(artifacts, fn {name, payload} ->
      :ok = Artifact.write(Path.join(dir, name), payload, opts)
    end)

    names = Enum.map(artifacts, &elem(&1, 0))
    :ok = Artifact.write(Path.join(dir, "manifest.json"), %{"artifacts" => names}, opts)
    generation_id
  end

  def write_artifact!(dir, name, payload, generation_id) do
    :ok =
      Artifact.write(Path.join(dir, name), payload,
        generated_at: @generated_at,
        generation_id: generation_id
      )
  end

  def active_generation(table) do
    [{:active_generation, generation_id}] = :ets.lookup(table, :active_generation)
    generation_id
  end
end
