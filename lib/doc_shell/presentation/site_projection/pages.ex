defmodule DocShell.Presentation.SiteProjection.Pages do
  @moduledoc false

  alias DocShell.Json.Canonical
  alias DocShell.Presentation.{Limits, Page}
  alias DocShell.Presentation.SiteProjection.{Anchors, Paths, Requirements}

  @page_keys ~w(id route title description locale audience template canonical_url source_url
                 edit_url last_modified status tags metadata navigation search banner hero
                 previous next)

  @doc false
  @spec project([map()], [map()], String.t(), map()) ::
          {:ok, %{String.t() => Page.t()}, [map()]} | {:error, term()}
  def project(collections, declarations, profile, context) do
    with {:ok, documents} <- document_index(collections),
         {:ok, declarations} <- page_declarations(declarations, profile, context.limits),
         :ok <- Limits.check(context.limits, :max_pages, length(declarations)),
         {:ok, pages} <- build_pages(declarations, Map.put(context, :documents, documents)) do
      {:ok, pages, declarations}
    end
  end

  defp document_index(collections) do
    Enum.reduce_while(collections, {:ok, %{}}, fn collection, {:ok, acc} ->
      case index_documents(collection.documents, collection.descriptor, acc) do
        {:ok, documents} -> {:cont, {:ok, documents}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp index_documents(documents, descriptor, index) do
    Enum.reduce_while(documents, {:ok, index}, fn document, {:ok, current} ->
      id = document["id"]

      cond do
        not nonempty?(id) -> {:halt, {:error, {:invalid_site_document, document}}}
        Map.has_key?(current, id) -> {:halt, {:error, {:duplicate_site_document, id}}}
        true -> {:cont, {:ok, Map.put(current, id, {descriptor, document})}}
      end
    end)
  end

  defp page_declarations(declarations, profile, limits) do
    result =
      Enum.reduce_while(declarations, {:ok, [], MapSet.new()}, fn declaration, state ->
        reduce_page_declaration(declaration, state, profile, limits)
      end)

    case result do
      {:ok, pages, _} -> {:ok, Enum.reverse(pages)}
      error -> error
    end
  end

  defp reduce_page_declaration(declaration, {:ok, pages, ids}, profile, limits) do
    case normalize_json(declaration) do
      {:ok, declaration} when is_map(declaration) ->
        admit_page_declaration(declaration, pages, ids, profile, limits)

      _ ->
        {:halt, {:error, {:invalid_page_declaration, declaration}}}
    end
  end

  defp admit_page_declaration(declaration, pages, ids, profile, limits) do
    id = declaration["id"]
    unknown = Map.keys(declaration) -- @page_keys

    cond do
      unknown != [] or not nonempty?(id) ->
        {:halt, {:error, {:invalid_page_declaration, declaration}}}

      byte_size(id) > limits.max_identity_bytes ->
        {:halt,
         {:error, {:site_limit, :max_identity_bytes, byte_size(id), limits.max_identity_bytes}}}

      MapSet.member?(ids, id) ->
        {:halt, {:error, {:duplicate_page_id, id}}}

      excluded?(declaration, profile) ->
        {:cont, {:ok, pages, MapSet.put(ids, id)}}

      true ->
        {:cont, {:ok, [declaration | pages], MapSet.put(ids, id)}}
    end
  end

  defp excluded?(declaration, "public"), do: declaration["status"] in ["draft", "private"]
  defp excluded?(_, _), do: false

  defp build_pages(declarations, context) do
    result =
      Enum.reduce_while(declarations, {:ok, %{}, MapSet.new()}, fn declaration,
                                                                   {:ok, pages, routes} ->
        case build_page(declaration, context) do
          {:ok, :excluded} -> {:cont, {:ok, pages, routes}}
          {:ok, page} -> add_page(page, pages, routes)
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, pages, _} -> {:ok, pages}
      error -> error
    end
  end

  defp add_page(page, pages, routes) do
    if MapSet.member?(routes, page.route) do
      {:halt, {:error, {:duplicate_site_route, page.route}}}
    else
      {:cont, {:ok, Map.put(pages, page.id, page), MapSet.put(routes, page.route)}}
    end
  end

  defp build_page(declaration, context) do
    with {:ok, source} <- page_source(declaration, context),
         {:ok, display} <- page_display(declaration, source.document, context),
         {:ok, controls} <- page_controls(declaration, source.document),
         page = make_page(declaration, source, display, controls, context),
         :ok <- validate_page_urls(page, context.limits) do
      if excluded?(%{"status" => page.status}, context.profile),
        do: {:ok, :excluded},
        else: {:ok, page}
    else
      false -> {:error, {:invalid_page_field, declaration["id"]}}
      {:error, _} = error -> error
    end
  end

  defp page_source(declaration, context) do
    with {:ok, {descriptor, document}} <- fetch_document(context.documents, declaration["id"]),
         {:ok, route} <-
           Paths.normalize_route(declaration["route"], context.base_path, context.limits),
         {:ok, content, headings} <- Anchors.project(document["ast"], context.limits),
         {:ok, encoded} <- Canonical.encode(content),
         :ok <- Limits.check(context.limits, :max_page_bytes, byte_size(encoded)) do
      {:ok,
       %{
         descriptor: descriptor,
         document: document,
         route: route,
         content: content,
         headings: headings
       }}
    end
  end

  defp page_display(declaration, document, context) do
    locale =
      declaration["locale"] || get_in(document, ["meta", "locale"]) || context.default_locale

    with true <- nonempty?(locale) and locale in context.locales,
         {:ok, template} <- template(declaration["template"]),
         {:ok, tags} <-
           string_list(declaration["tags"] || get_in(document, ["meta", "tags"]) || []),
         {:ok, metadata} <- page_metadata(declaration["metadata"] || %{}),
         {:ok, audience} <-
           audience(declaration["audience"] || get_in(document, ["meta", "audience"])) do
      {:ok,
       %{locale: locale, template: template, tags: tags, metadata: metadata, audience: audience}}
    end
  end

  defp page_controls(declaration, document) do
    with {:ok, navigation?} <- boolean(declaration, "navigation", true),
         {:ok, search?} <- boolean(declaration, "search", true),
         {:ok, banner} <- optional_json_map(declaration["banner"]),
         {:ok, hero} <- optional_json_map(declaration["hero"]),
         title = declaration["title"] || document["title"],
         true <- nonempty?(title) do
      {:ok,
       %{navigation?: navigation?, search?: search?, banner: banner, hero: hero, title: title}}
    end
  end

  defp make_page(declaration, source, display, controls, context) do
    document = source.document
    descriptor = source.descriptor
    source_path = get_in(document, ["meta", "source_path"])
    status = declaration["status"] || get_in(document, ["meta", "status"]) || descriptor.status

    %Page{
      id: declaration["id"],
      collection_id: document["collection_id"],
      document_id: document["document_id"],
      kind: document["kind"],
      route: source.route,
      title: controls.title,
      description: declaration["description"] || get_in(document, ["meta", "description"]),
      locale: display.locale,
      audience: display.audience,
      template: display.template,
      content: source.content,
      content_digest: digest!(source.content),
      canonical_url:
        declaration["canonical_url"] ||
          Paths.canonical_url(context.canonical_origin, source.route),
      source_url: declaration["source_url"] || Paths.source_url(descriptor),
      edit_url: declaration["edit_url"] || Paths.edit_url(descriptor, source_path),
      source_revision: descriptor.revision,
      source_path: source_path,
      package_version: descriptor.version,
      last_modified: declaration["last_modified"] || get_in(document, ["meta", "last_modified"]),
      status: status,
      headings: source.headings,
      tags: display.tags,
      metadata: display.metadata,
      navigation?: controls.navigation?,
      search?: controls.search?,
      banner: controls.banner,
      hero: controls.hero,
      requirements: Requirements.derive(source.content)
    }
  end

  defp validate_page_urls(page, limits) do
    with :ok <- Paths.validate_url(page.canonical_url, :canonical_url, limits),
         :ok <- Paths.validate_url(page.source_url, :source_url, limits) do
      Paths.validate_url(page.edit_url, :edit_url, limits)
    end
  end

  defp fetch_document(documents, id) do
    case Map.fetch(documents, id) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:unknown_site_document, id}}
    end
  end

  defp template(nil), do: {:ok, :document}
  defp template(value) when value in ["document", :document], do: {:ok, :document}
  defp template(value) when value in ["splash", :splash], do: {:ok, :splash}
  defp template(value), do: {:error, {:invalid_page_template, value}}

  defp digest!(value) do
    {:ok, digest} = Canonical.digest(value)
    digest
  end

  defp string_list(value) when is_list(value) do
    if value == Enum.uniq(value) and Enum.all?(value, &nonempty?/1),
      do: {:ok, value},
      else: {:error, {:invalid_string_list, value}}
  end

  defp string_list(value), do: {:error, {:invalid_string_list, value}}

  defp page_metadata(value) when is_map(value) do
    forbidden = ~w(head head_html scripts script component framework renderer_class)

    if DocShell.Json.valid?(value) and not Enum.any?(forbidden, &Map.has_key?(value, &1)),
      do: {:ok, value},
      else: {:error, {:invalid_page_metadata, value}}
  end

  defp page_metadata(value), do: {:error, {:invalid_page_metadata, value}}

  defp optional_json_map(nil), do: {:ok, nil}

  defp optional_json_map(value) when is_map(value) do
    if DocShell.Json.valid?(value),
      do: {:ok, value},
      else: {:error, {:invalid_page_record, value}}
  end

  defp optional_json_map(value), do: {:error, {:invalid_page_record, value}}

  defp audience(nil), do: {:ok, nil}

  defp audience(value) when is_binary(value),
    do: if(nonempty?(value), do: {:ok, value}, else: {:error, {:invalid_audience, value}})

  defp audience(value) when is_list(value) do
    if value != [] and value == Enum.uniq(value) and Enum.all?(value, &nonempty?/1),
      do: {:ok, value},
      else: {:error, {:invalid_audience, value}}
  end

  defp audience(value), do: {:error, {:invalid_audience, value}}

  defp boolean(map, key, default) do
    value = Map.get(map, key, default)
    if is_boolean(value), do: {:ok, value}, else: {:error, {:invalid_page_boolean, key, value}}
  end

  defp normalize_json(value) do
    with {:ok, value} <- DocShell.Json.normalize(value),
         true <- DocShell.Json.valid?(value) do
      {:ok, value}
    else
      false -> {:error, {:invalid_site_json, value}}
      {:error, _} = error -> error
    end
  end

  defp nonempty?(value), do: is_binary(value) and value != "" and String.valid?(value)
end
