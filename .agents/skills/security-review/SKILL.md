---
name: security-review
description: "Assess requested security reviews or audits and changed documentation imports, artifact/path validation, cache publication or optional HTTP serving gates. Trace private-data exposure and resource bounds; keep host identity and renderer policy with their owners."
---

# Security review

Read [the repository contract](../../../AGENTS.md) and the affected section of
[the documentation-site contract](../../../docs/specs/DSH.01-documentation-sites.md).
Identify whether input is trusted build content or a lower-trust imported
artifact, and which host-selected gate and cache own access to its output.

Trace extraction/import through JSON/AST validation, collection/site projection,
publication/cache selection and optional HTTP responses. Review reference/path
handling, parser/collection bounds, error payloads and stale or mixed cache
content. Follow [AST validation](../../../lib/doc_shell/ast.ex) and actual
consumers rather than treating a valid JSON envelope as harmless rendered content.

For [HTTP serving](../../../lib/doc_shell/web/plug.ex), follow the host-provided
gate before responses, including conditional requests and missing artifacts.
An omitted gate deliberately serves public artifacts; establish whether the
host selected private content before reporting exposure. DocShell owns portable
validation and serving mechanics. Host authorization and Phoenix Assets'
HTML/browser rendering remain separate review targets.

Inspect existing import, serving and publication refusal tests for the affected
path. Select checks through [the configured gate](../../../.check.exs) and
CONTRIBUTING; distinguish library fixtures from a real private-docs host. Do not
introduce tenant policy or HTML rendering into this library as an audit fix.

## Scope, evidence and execution

For the requested review, record the revision and relevant working-tree changes,
checked entry/control/effect paths and deferred or excluded areas. A focused
review does not require a whole-repository audit.

Establish each claim against the strongest current control and owning contract.
Confirmed findings need a complete reachable boundary trace and evidence for
the stated consequence. Keep decisive unobserved facts as `needs_validation`,
with the exact missing check and no severity; reject disproved claims.
Distinguish source inspection, inspected tests, executed local tests and live
evidence. Group duplicate root causes and recheck previous findings against
current source and conditions.

Use the existing validation owner for authorized dummy-data regressions.
Executing untrusted code or hostile native/availability checks requires verified
OS isolation, no external networking, a sanitized environment and resource/time
limits. If unavailable, leave that execution unverified and continue source
review. A review grants no live/provider operations or agent-permission changes.
Independent verification is conditional on authorized, available delegation;
otherwise state the single-reviewer limit. Return findings in chat unless the
requested deliverable and repository contract permit a report.

Audit-method background: [Cloudflare's source-first workflow](https://github.com/cloudflare/security-audit-skill/tree/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8/skills/security-audit).
