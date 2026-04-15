# Essential Viewer — AI Developer Guide

## MANDATORY: Read API Documentation Before Writing Code

Before writing ANY data access code, read `api_documentation.md`.
It contains authoritative DSA Data Labels, property names and response
structures. Guessing causes silent failures — APIs return IDs and nested
arrays, not plain strings.

## Common mistakes the docs prevent
- `app.lifecycleStatus` does not exist → use `app.lifecycle` (an ID, needs
  lookup against `busCapAppMartApps.lifecycles[].shortname`)
- `app.totalCost` does not exist → sum `app.costs[].cost`
- Using `busCapAppMartApps` for Business Capabilities → use `busCapAppMartCaps`

## Key API quick reference
| Need | DSA Label | Key properties |
| :--- | :--- | :--- |
| Applications + costs | `appMartAPI` | `.applications[].costs[].cost`, `.family[].name` |
| Lifecycle lookup | `busCapAppMartApps` | `.applications[].lifecycle` (ID), `.lifecycles[].{id,shortname,colour}` |
| Business Capabilities | `busCapAppMartCaps` | `.busCaptoAppDetails[].{name,thisapps,apps}` |

Full details in `api_documentation.md`.

## XSL v2.0 pattern rules
- ONE `<script>` block, no CDATA
- `&amp;&amp;` for `&&` in XSL element content (no space after)
- `fetchAndRenderData(['label1','label2'])` returns named keys
- Call `RenderViewerAPIJSFunction` at top of script block
