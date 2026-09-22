defmodule DocShell.Presentation.SiteProjection.Paths do
  @moduledoc false

  alias DocShell.Generate.Collection
  alias DocShell.Presentation.Limits

  @doc false
  @spec normalize_base(term(), Limits.t()) :: {:ok, String.t()} | {:error, term()}
  def normalize_base(path, limits) do
    with {:ok, path} <- normalize_absolute_path(path, true),
         :ok <- Limits.check(limits, :max_route_bytes, byte_size(path)) do
      {:ok, path}
    end
  end

  @doc false
  @spec normalize_route(term(), String.t(), Limits.t()) ::
          {:ok, String.t()} | {:error, term()}
  def normalize_route(path, base_path, limits) do
    with {:ok, path} <- normalize_absolute_path(path, false),
         path = apply_base(path, base_path),
         :ok <- Limits.check(limits, :max_route_bytes, byte_size(path)) do
      {:ok, path}
    end
  end

  @doc false
  @spec source_url(Collection.t()) :: String.t()
  def source_url(%Collection{} = descriptor), do: descriptor.source_url

  @doc false
  @spec edit_url(Collection.t(), String.t() | nil) :: String.t() | nil
  def edit_url(_, nil), do: nil

  def edit_url(%Collection{} = descriptor, path) do
    encoded = URI.encode(path, &(&1 == ?/ or URI.char_unreserved?(&1)))
    String.trim_trailing(descriptor.edit_base_url, "/") <> "/" <> encoded
  end

  @doc false
  @spec canonical_url(String.t() | nil, String.t()) :: String.t() | nil
  def canonical_url(nil, _), do: nil

  def canonical_url(origin, route) when is_binary(origin) do
    String.trim_trailing(origin, "/") <> route
  end

  @doc false
  @spec validate_canonical_origin(term(), Limits.t()) :: :ok | {:error, term()}
  def validate_canonical_origin(nil, _), do: :ok

  def validate_canonical_origin(origin, limits) do
    with :ok <- validate_url(origin, :canonical_origin, limits),
         %URI{path: path, query: nil, fragment: nil} when path in [nil, "", "/"] <-
           URI.parse(origin) do
      :ok
    else
      {:error, _} = error -> error
      _ -> {:error, {:invalid_site_url, :canonical_origin, origin}}
    end
  end

  @doc false
  @spec validate_url(term(), atom(), Limits.t()) :: :ok | {:error, term()}
  def validate_url(nil, _, _), do: :ok

  def validate_url(url, field, limits) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        Limits.check(limits, :max_route_bytes, byte_size(url))

      _ ->
        {:error, {:invalid_site_url, field, url}}
    end
  end

  def validate_url(url, field, _), do: {:error, {:invalid_site_url, field, url}}

  defp normalize_absolute_path(path, base?) when is_binary(path) do
    uri = URI.parse(path)

    with :ok <- validate_path_uri(uri, path),
         :ok <- validate_path_syntax(path, uri.path) do
      clean = path |> String.replace(~r{/+}, "/") |> normalize_route_ending(base?)
      {:ok, clean}
    end
  end

  defp normalize_absolute_path(path, _), do: {:error, {:invalid_site_path, path}}

  defp validate_path_uri(uri, path) do
    if is_nil(uri.scheme) and is_nil(uri.host) and is_nil(uri.query) and is_nil(uri.fragment),
      do: :ok,
      else: {:error, {:invalid_site_path, path}}
  end

  defp validate_path_syntax(path, uri_path) do
    valid? =
      String.starts_with?(path, "/") and ".." not in Path.split(uri_path || "") and
        not String.contains?(path, ["\\", <<0>>]) and not encoded_traversal?(path)

    if valid?, do: :ok, else: {:error, {:invalid_site_path, path}}
  end

  defp apply_base(path, "/"), do: path

  defp apply_base(path, base) do
    if String.starts_with?(path, base), do: path, else: base <> String.trim_leading(path, "/")
  end

  defp normalize_route_ending("", _), do: "/"
  defp normalize_route_ending(path, true), do: ensure_trailing_slash(path)

  defp normalize_route_ending(path, false) do
    if String.ends_with?(path, "/") or Path.extname(path) != "",
      do: path,
      else: path <> "/"
  end

  defp ensure_trailing_slash(path),
    do: if(String.ends_with?(path, "/"), do: path, else: path <> "/")

  defp encoded_traversal?(path) do
    path
    |> String.downcase()
    |> String.split("/")
    |> Enum.any?(&(&1 in ["%2e", "%2e%2e", ".%2e", "%2e."]))
  end
end
