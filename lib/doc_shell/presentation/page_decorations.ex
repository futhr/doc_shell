defmodule DocShell.Presentation.PageDecorations do
  @moduledoc """
  Checks renderer-neutral banner and hero records before page projection.

  A banner has optional `label`, `text`, and `href` fields, with at least a
  label or text. A hero requires `title` and may carry `tagline`, `description`,
  ordinary link `actions`, and an `image` naming a logical local `asset` plus
  `alt` text. Text is plain UTF-8, never HTML. URLs, link lists and logical image
  names use the shared presentation settings policy and finite limits.

  These records supply content, not a host product layout or a framework
  component. A renderer decides how to present them and must preserve their
  text and ordinary links without browser enhancement.
  """

  alias DocShell.Presentation.Settings

  @doc "Validates an optional banner or hero and preserves the admitted record."
  @spec validate(:banner | :hero, term()) :: {:ok, map() | nil} | {:error, term()}
  def validate(kind, value) when kind in [:banner, :hero] do
    if is_nil(value) or valid?(kind, value),
      do: {:ok, value},
      else: {:error, {:invalid_page_decoration, kind, value}}
  end

  def validate(kind, _), do: {:error, {:invalid_page_decoration_kind, kind}}

  defp valid?(:banner, value) do
    object?(value, ~w(label text href)) and
      (Map.has_key?(value, "label") or Map.has_key?(value, "text")) and
      optional?(value, "label", &text?/1) and optional?(value, "text", &text?/1) and
      optional?(value, "href", &url?/1)
  end

  defp valid?(:hero, value) do
    object?(value, ~w(title tagline description actions image)) and text?(value["title"]) and
      optional?(value, "tagline", &text?/1) and optional?(value, "description", &text?/1) and
      optional?(value, "actions", &actions?/1) and optional?(value, "image", &image?/1)
  end

  defp actions?(value),
    do: Settings.validate(%{"footer" => %{"links" => value}}) == :ok

  defp url?(value), do: actions?([%{"label" => "destination", "href" => value}])

  defp image?(value),
    do:
      Settings.validate(%{"brand" => %{"label" => "image", "href" => "/", "logo" => value}}) ==
        :ok

  defp optional?(value, key, predicate),
    do: not Map.has_key?(value, key) or predicate.(value[key])

  defp object?(value, keys),
    do: is_map(value) and not is_struct(value) and Map.keys(value) -- keys == []

  defp text?(value),
    do: is_binary(value) and value != "" and String.valid?(value) and byte_size(value) <= 4096
end
