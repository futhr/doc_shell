defmodule DocShell.Presentation.SiteProjection.Navigation do
  @moduledoc false

  alias DocShell.Presentation.{Breadcrumb, Limits, Link, NavigationItem}
  alias DocShell.Presentation.SiteProjection.Paths

  @navigation_keys ~w(id title path children badge collapsed meta)

  @doc false
  @spec project(map(), map(), [map()], String.t(), Limits.t()) ::
          {:ok, [NavigationItem.t()], map(), %{String.t() => String.t()}} | {:error, term()}
  def project(declaration, pages, declarations, base_path, limits) do
    with {:ok, navigation, flow, breadcrumbs} <- navigation(declaration, pages, limits),
         {:ok, pages} <- reading_flow(pages, flow, breadcrumbs, declarations),
         {:ok, redirects} <-
           redirects(Map.get(declaration, "redirects", %{}), pages, base_path, limits) do
      {:ok, navigation, pages, redirects}
    end
  end

  defp navigation(declaration, pages, limits) do
    source = Map.get(declaration, "navigation")

    items =
      if is_nil(source) do
        pages
        |> Map.values()
        |> Enum.filter(& &1.navigation?)
        |> Enum.sort_by(&{&1.kind, &1.title, &1.id})
        |> Enum.map(&%{"id" => &1.id})
      else
        source
      end

    with true <- is_list(items),
         context = %{pages: pages, limits: limits},
         state = %{depth: 1, trail: [], breadcrumbs: %{}, seen: MapSet.new()},
         {:ok, navigation, flow, state} <- navigation_items(items, context, state) do
      {:ok, navigation, flow, state.breadcrumbs}
    else
      false -> {:error, :invalid_site_navigation}
      {:error, _} = error -> error
    end
  end

  defp navigation_items([], _, state), do: {:ok, [], [], state}

  defp navigation_items([item | rest], context, state) do
    with :ok <- Limits.check(context.limits, :max_navigation_depth, state.depth),
         {:ok, item} <- normalize_json(item),
         {:ok, item, item_flow, state} <- navigation_item(item, context, state),
         {:ok, rest, rest_flow, state} <- navigation_items(rest, context, state) do
      {:ok, [item | rest], item_flow ++ rest_flow, state}
    end
  end

  defp navigation_item(%{"children" => children} = item, context, state) do
    id = item["id"]
    title = item["title"]

    with :ok <- validate_navigation_group(item),
         false <- MapSet.member?(state.seen, id),
         child_state = %{
           state
           | depth: state.depth + 1,
             trail: state.trail ++ [%Breadcrumb{title: title}],
             seen: MapSet.put(state.seen, id)
         },
         {:ok, children, flow, child_state} <- navigation_items(children, context, child_state) do
      meta = Map.merge(Map.get(item, "meta", %{}), Map.take(item, ["badge", "collapsed"]))
      next_state = %{child_state | depth: state.depth, trail: state.trail}

      {:ok,
       %NavigationItem{
         id: id,
         title: title,
         path: "",
         kind: "group",
         meta: meta,
         children: children
       }, flow, next_state}
    else
      true -> {:error, {:duplicate_navigation_id, id}}
      {:error, _} = error -> error
    end
  end

  defp navigation_item(%{"id" => id} = item, context, state) do
    with {:ok, page} <- navigation_page(context.pages, id),
         :ok <- validate_navigation_leaf(item, page, state.seen) do
      meta = Map.merge(Map.get(item, "meta", %{}), Map.take(item, ["badge"]))

      nav = %NavigationItem{
        id: id,
        title: item["title"] || page.title,
        path: page.route,
        kind: page.kind,
        meta: meta
      }

      crumbs = state.trail ++ [%Breadcrumb{title: nav.title, path: nav.path}]

      next_state = %{
        state
        | breadcrumbs: Map.put(state.breadcrumbs, id, crumbs),
          seen: MapSet.put(state.seen, id)
      }

      {:ok, nav, [id], next_state}
    end
  end

  defp navigation_item(item, _, _), do: {:error, {:invalid_navigation_item, item}}

  defp validate_navigation_group(item) do
    valid? =
      Map.keys(item) -- @navigation_keys == [] and nonempty?(item["id"]) and
        nonempty?(item["title"]) and is_list(item["children"]) and
        is_map(Map.get(item, "meta", %{})) and Map.get(item, "path", "") == ""

    if valid?, do: :ok, else: {:error, {:invalid_navigation_group, item}}
  end

  defp navigation_page(pages, id) do
    case Map.fetch(pages, id) do
      {:ok, page} -> {:ok, page}
      :error -> {:error, {:unknown_navigation_page, id}}
    end
  end

  defp validate_navigation_leaf(item, page, seen) do
    with :ok <- validate_navigation_leaf_shape(item),
         :ok <- validate_navigation_visibility(item, page),
         :ok <- validate_navigation_identity(item, seen),
         :ok <- validate_navigation_route(item, page) do
      validate_navigation_title(item)
    end
  end

  defp validate_navigation_leaf_shape(item) do
    if Map.keys(item) -- @navigation_keys == [] and is_map(Map.get(item, "meta", %{})),
      do: :ok,
      else: {:error, {:invalid_navigation_item, item}}
  end

  defp validate_navigation_visibility(item, page) do
    if page.navigation?,
      do: :ok,
      else: {:error, {:hidden_navigation_page, item["id"]}}
  end

  defp validate_navigation_identity(item, seen) do
    if MapSet.member?(seen, item["id"]),
      do: {:error, {:duplicate_navigation_id, item["id"]}},
      else: :ok
  end

  defp validate_navigation_route(item, page) do
    if Map.has_key?(item, "path") and item["path"] != page.route,
      do: {:error, {:navigation_route_mismatch, item["id"], item["path"], page.route}},
      else: :ok
  end

  defp validate_navigation_title(item) do
    if not is_nil(item["title"]) and not nonempty?(item["title"]),
      do: {:error, {:invalid_navigation_item, item}},
      else: :ok
  end

  defp reading_flow(pages, flow, breadcrumbs, declarations) do
    indexed = Enum.with_index(flow)
    policies = Map.new(declarations, &{&1["id"], &1})

    Enum.reduce_while(indexed, {:ok, pages}, fn {id, index}, {:ok, current} ->
      page = Map.fetch!(current, id)
      policy = Map.get(policies, id, %{})

      with {:ok, previous} <-
             flow_choice(policy, "previous", pages, Enum.at(flow, index - 1), index > 0),
           {:ok, next} <-
             flow_choice(
               policy,
               "next",
               pages,
               Enum.at(flow, index + 1),
               index + 1 < length(flow)
             ) do
        page = %{page | previous: previous, next: next, breadcrumbs: breadcrumbs[id] || []}
        {:cont, {:ok, Map.put(current, id, page)}}
      else
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp flow_choice(policy, key, pages, automatic_id, automatic?) do
    case Map.fetch(policy, key) do
      :error -> {:ok, flow_link(pages, automatic_id, automatic?)}
      {:ok, nil} -> {:ok, flow_link(pages, automatic_id, automatic?)}
      {:ok, false} -> {:ok, nil}
      {:ok, id} when is_binary(id) -> explicit_flow_link(pages, id)
      {:ok, value} -> {:error, {:invalid_reading_flow, policy["id"], key, value}}
    end
  end

  defp explicit_flow_link(pages, id) do
    case Map.fetch(pages, id) do
      {:ok, page} -> {:ok, %Link{title: page.title, path: page.route}}
      :error -> {:error, {:unknown_reading_flow_page, id}}
    end
  end

  defp flow_link(_, _, false), do: nil

  defp flow_link(pages, id, true) do
    page = Map.fetch!(pages, id)
    %Link{title: page.title, path: page.route}
  end

  defp redirects(source, pages, base_path, limits) do
    routes = Map.new(pages, fn {id, page} -> {id, page.route} end)

    with :ok <- Limits.check(limits, :max_redirects, map_size(source)),
         {:ok, redirects} <- reduce_redirects(source, routes, pages, base_path, limits),
         :ok <- validate_redirect_targets(redirects, pages),
         :ok <- acyclic_redirects(redirects) do
      {:ok, redirects}
    end
  end

  defp reduce_redirects(source, routes, pages, base_path, limits) do
    context = %{routes: routes, pages: pages, base_path: base_path, limits: limits}

    Enum.reduce_while(source, {:ok, %{}}, fn pair, {:ok, redirects} ->
      case add_redirect(pair, redirects, context) do
        {:ok, redirects} -> {:cont, {:ok, redirects}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp add_redirect({from, target}, redirects, context) do
    with {:ok, from} <- Paths.normalize_route(from, context.base_path, context.limits),
         {:ok, target} <- redirect_target(target, context.routes, context),
         false <- Map.has_key?(redirects, from),
         false <- Enum.any?(context.pages, fn {_, page} -> page.route == from end) do
      {:ok, Map.put(redirects, from, target)}
    else
      true -> {:error, {:invalid_redirect, from, target}}
      {:error, _} = error -> error
    end
  end

  defp redirect_target(target, routes, context) do
    case Map.fetch(routes, target) do
      {:ok, route} -> {:ok, route}
      :error -> Paths.normalize_route(target, context.base_path, context.limits)
    end
  end

  defp validate_redirect_targets(redirects, pages) do
    page_routes = pages |> Map.values() |> MapSet.new(& &1.route)
    redirect_routes = MapSet.new(Map.keys(redirects))

    case Enum.find_value(redirects, &unknown_redirect(&1, page_routes, redirect_routes)) do
      nil -> :ok
      pair -> {:error, {:unknown_redirect_target, pair}}
    end
  end

  defp unknown_redirect({from, target}, page_routes, redirect_routes) do
    if MapSet.member?(page_routes, target) or MapSet.member?(redirect_routes, target),
      do: nil,
      else: {from, target}
  end

  defp acyclic_redirects(redirects) do
    case Enum.find(Map.keys(redirects), &redirect_cycle?(&1, redirects, MapSet.new())) do
      nil -> :ok
      route -> {:error, {:redirect_cycle, route}}
    end
  end

  defp redirect_cycle?(route, redirects, seen) do
    cond do
      MapSet.member?(seen, route) ->
        true

      Map.has_key?(redirects, route) ->
        redirect_cycle?(redirects[route], redirects, MapSet.put(seen, route))

      true ->
        false
    end
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
