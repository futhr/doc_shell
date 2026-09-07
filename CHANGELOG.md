# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.3.0](https://github.com/futhr/doc_shell/compare/v0.2.0...v0.3.0) (2026-09-07)




### Features:

* openapi: accept OpenAPI 3.2 source documents by Tobias Bohwalli

### Bug Fixes:

* include optional adapters in analysis by Tobias Bohwalli

* build: stage output and restore failed publications by Tobias Bohwalli

* artifact: define legacy generation compatibility by Tobias Bohwalli

* cache: protect snapshots with process ownership by Tobias Bohwalli

* cache: use registered names as supervisor child IDs by Tobias Bohwalli

* changelog: preserve Markdown context across releases by Tobias Bohwalli

* presentation: calculate each document path once by Tobias Bohwalli

* search: preserve words across inline formatting by Tobias Bohwalli

* generate: derive titles from parsed Markdown headings by Tobias Bohwalli

* artifact: isolate temporary files across BEAM instances by Tobias Bohwalli

* build: reject conflicting output destinations by Tobias Bohwalli

* config: validate build options and guide fields by Tobias Bohwalli

* presentation: validate recursive content and metadata by Tobias Bohwalli

* json: normalize metadata without silent key collisions by Tobias Bohwalli

* presentation: reject duplicate document identities by Tobias Bohwalli

* guides: parse frontmatter delimiters by lines by Tobias Bohwalli

* types: include recursive text nodes in the AST contract by Tobias Bohwalli

* changelog: reject nil source entries by Tobias Bohwalli

* openapi: include the default API version by Tobias Bohwalli

* deps: update Mint and Ash past security advisories by Tobias Bohwalli

### Performance Improvements:

* web: cache encoded responses and HTTP validators by Tobias Bohwalli

## [v0.2.0](https://github.com/futhr/doc_shell/compare/v0.1.0...v0.2.0) (2026-09-01)




### Features:

* build: decouple host extraction from files and supervision by futhr

* generate: extract changelog releases as documentation entries by futhr

### Bug Fixes:

* deps: support compatible AshOaskit hosts by futhr

* build: report every generated document by futhr

* generate: support conventional changelog releases by futhr

## [v0.1.0](https://github.com/futhr/doc_shell/compare/v0.1.0...v0.1.0) (2026-08-24)




### Features:

* config: use notebooks as the default notebook source by Tobias Bohwalli

* web: serve generated artifacts through a gated cache by futhr

* mix: add the artifact build task by futhr

* build: build the complete documentation artifact tree by futhr

* config: resolve build settings from options, host config, and defaults by futhr

* presentation: project content into typed presentation indexes by futhr

* open_api: load OpenAPI documents through source adapters by futhr

* generate: import Markdown guides and Livebook notebooks by futhr

* generate: extract documentation from compiled modules by futhr

* generate: share common document collection behavior by futhr

* ast: parse Markdown into renderer-neutral syntax trees by futhr

* json: coerce arbitrary terms into JSON-encodable values by futhr

* artifact: store artifacts in versioned JSON envelopes by futhr

### Bug Fixes:

* notebooks: install DocShell in Livebook tutorials by futhr

* package: remove the nonexistent changelog link by Tobias Bohwalli

* deps: update Ash past security advisories by Tobias Bohwalli

* cache: publish complete artifact generations atomically by futhr

### Performance Improvements:

* bench: measure the parsing, projection, and artifact hot paths by futhr
