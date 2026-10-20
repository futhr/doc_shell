# Documentation site capability survey

This survey records the behavior that informed DSH.01. These references inform
the design; they do not select dependencies or establish compatibility.

## Reference behavior

Starlight's documentation features informed the acceptance baseline:

| Area | Reference features |
| --- | --- |
| Navigation | Hierarchical and collapsible sidebars, responsive navigation, page table of contents, previous/next links. |
| Search and visibility | Keyboard search using Pagefind by default; draft/search visibility. |
| Reading | Readable typography, code highlighting, dark mode, custom page layouts. |
| Publishing | Localization, SEO metadata, edit links, last-updated data. |

DSH.01 specifies these user-facing capabilities without adopting Astro's routing,
content collection, or component model.

Pagefind demonstrates that a large static corpus can provide chunked,
multilingual, filtered browser search without a hosted service. DSH.01 keeps
that implementation optional because DocShell's core contract must remain
usable without Node or a downloaded native executable.

Phoenix function components can render HEEx in controller and LiveView
applications. LiveView JavaScript hooks can enhance server-rendered markup, but
static output has no LiveSocket lifecycle. A portable renderer therefore needs
ordinary browser initializers with a thin LiveView hook that reuses them after
DOM patches. Article text and navigation remain present before enhancement.

GitHub Pages accepts static output from a custom Actions workflow and is
available to public repositories on GitHub Free. Deployment belongs to a host;
DocShell emits a provider-neutral directory.

## Capability ownership

| Capability | Portable core | Renderer | Host/deployment |
| --- | --- | --- | --- |
| Corpus identities and provenance | Yes | Reads | Selects sources |
| Routes, headings, navigation and reading order | Validates/projects | Displays | Supplies taxonomy |
| Search records and filters | Yes | Query UI/client | May select adapter |
| Responsive shell and visual tokens | Conformance contract | Yes | Branding overrides |
| Code, diagrams and OpenAPI | AST/reference contract | Yes | Enables request execution |
| Static file transaction and manifest | Yes | Supplies HTML/assets | Publishes directory |
| LiveView lifecycle | No | Phoenix adapter | Mounts routes and authorization |
| Canonical origin and robots policy | Validates and emits static files | Emits page metadata | Chooses origin and policy |
| Release retention | Preserves named cohorts in a site generation | Displays selected release | Selects and retains published generations |

## Sources

1. Starlight, [project overview](https://starlight.astro.build/).
2. Starlight, [sidebar navigation](https://starlight.astro.build/guides/sidebar/).
3. Starlight, [site search](https://starlight.astro.build/guides/site-search/).
4. Starlight, [frontmatter reference](https://starlight.astro.build/reference/frontmatter/).
5. Pagefind, [project overview](https://pagefind.app/).
6. Pagefind, [browser API and filtering](https://pagefind.app/docs/api/).
7. Phoenix, [components and HEEx](https://hexdocs.pm/phoenix/components.html).
8. Phoenix LiveView, [JavaScript interoperability](https://hexdocs.pm/phoenix_live_view/js-interop.html).
9. GitHub, [custom workflows for GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
10. GitHub, [GitHub Pages availability](https://docs.github.com/en/pages/getting-started-with-github-pages).
