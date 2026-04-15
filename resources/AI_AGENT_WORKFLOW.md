# AI Agent Mandatory Workflow — Essential View Builder

## ⚠️ READ THIS ENTIRE DOCUMENT BEFORE WRITING ANY CODE ⚠️

This document defines the **mandatory three-step workflow** every AI agent MUST follow when building an Essential XSL view. Skipping any step is the single most common cause of broken views.

---

## STEP 1 — Identify the Right APIs (ALWAYS DO THIS FIRST)

**You MUST read the API catalogue before deciding which APIs to use. Never guess.**

```
Call: read_view_builder_resource(uri='essential-view://api-docs')
```

In that document, search for APIs relevant to the view topic. For each candidate API note:
- The exact **DSA Data Label** (e.g. `busCapAppMartApps`) — this is what you put in `apiList`
- The exact **top-level property names** in the JSON response (e.g. `applications`, `capabilities`, `filters`)
- Any nested properties on individual items (e.g. `applications[].services`, `applications[].costs`)

### When to ask the user

Ask the user **before writing any code** if:
- You cannot find an API that provides the required data
- Multiple APIs might work and you are unsure which is correct
- The data required does not appear in the catalogue at all

Example question to ask:
> "I've looked at the API catalogue. I believe we should use `busCapAppMartApps` (applications with business capabilities) and `appLifecycleAPI` (lifecycle status). Does this sound right, or are there other APIs I should use?"

It is always better to ask and get it right than to produce a view that loads but shows wrong data.

---

## STEP 2 — Use the v2.0 API Fetcher Pattern (NEVER Copy Old Files)

### The ONLY correct JavaScript pattern

```javascript
// ✅ CORRECT — always use fetchAndRenderData()
const apiList = ['appMartAPI', 'busCapAppMartApps'];
let responses = await fetchAndRenderData(apiList);
({ appMartAPI, busCapAppMartApps } = responses);
```

### FORBIDDEN — Old API Pattern (will not work in modern Essential Viewer)

There are old XSL files in this project folder that use a completely different, **obsolete** approach. You may see these patterns when reading project files. **Do not copy them under any circumstances.**

```xml
<!-- ❌ OLD PATTERN — NEVER USE — OBSOLETE -->
<xsl:variable name="appData"
    select="$utilitiesAllDataSetAPIs[own_slot_value[slot_reference='name']/value='Core API: Application Mart']"/>
<xsl:variable name="apiApps">
    <xsl:call-template name="GetViewerAPIPath">
        <xsl:with-param name="apiReport" select="$appData"/>
    </xsl:call-template>
</xsl:variable>
```

```javascript
// ❌ OLD PATTERN — NEVER USE — OBSOLETE
$.getJSON(apiApps, function(data) { ... });
```

If you see `GetViewerAPIPath`, `$utilitiesAllDataSetAPIs`, or `$.getJSON(apiApps` in any file, that file is using the **deprecated** pre-v2.0 pattern. Do not copy it. Use `generate_view_scaffold` or the golden pattern from `essential-view://quick-reference` instead.

### Use the scaffold tool

```
Call: generate_view_scaffold(view_name="...", api_labels=["appMartAPI", ...])
```

This guarantees the correct imports, the correct script structure, and the correct async/await pattern.

---

## STEP 3 — Escape ALL XML-Special Characters in `<script>` Blocks

The `<script>` block lives inside an XML document. **Every character in it — including JavaScript comments — is XML content.** The Saxon XSLT processor parses the XML before JavaScript ever runs. A single bare `<` or unescaped `&` will abort the entire XSLT transformation with a SAXParseException.

### Escape table (applies everywhere in `<script>`, including comments)

| Raw character | Escaped form | Notes |
|---------------|-------------|-------|
| `&&` | `&amp;&amp;` | **NO space** between `&amp;&amp;` and next token |
| `<` | `&lt;` | for-loop conditions, comparisons, HTML strings, comments |
| `<=` | `&lt;=` | comparisons |
| `>` | `&gt;` | comparisons (good practice) |
| `>=` | `&gt;=` | comparisons |
| `&` (lone) | `&amp;` | URL parameters, bitwise AND |

### Comments are NOT exempt

```javascript
// ❌ WRONG — bare < in a comment still breaks the XML parser
// Iterate while i < items.length

// ✅ CORRECT — escape < even in comments
// Iterate while i &lt; items.length

// ✅ EVEN BETTER — rephrase to avoid the character
// Iterate over all items
```

### for-loop conditions — the #1 source of parse failures

```javascript
// ❌ WRONG — causes: SAXParseException content of elements must consist of well-formed character data
for (var i = 0; i < items.length; i++) { }

// ✅ CORRECT
for (var i = 0; i &lt; items.length; i++) { }

// ✅ ALSO CORRECT — forEach avoids the problem entirely (preferred)
items.forEach(function(item, i) { });
```

### The `&&` no-space rule

```javascript
// ❌ WRONG — space after &amp;&amp; silently breaks the condition (evaluates as true)
if (data &amp;&amp; data.items) { }

// ✅ CORRECT — no space between &amp;&amp; and the next token
if (data &amp;&amp;data.items) { }
```

### HTML strings in JavaScript — use DOM API, not string literals

```javascript
// ❌ WRONG — < and > in string literals break the XML parser
container.innerHTML = '<div class="status">' + name + '</div>';

// ✅ CORRECT — DOM API (zero escaping needed)
var div = document.createElement('div');
div.className = 'status';
div.textContent = name;
container.appendChild(div);

// ✅ ALSO CORRECT — escaped string literals (verbose but valid)
container.innerHTML = '&lt;div class="status"&gt;' + name + '&lt;/div&gt;';
```

### Transitive Includes & Security

*   **`viewer_security.xsl`**: DO NOT manually include or import this file. It is transitively included via `core_header.xsl` -> `core_utilities.xsl`. Manual inclusion will cause a "module included more than once" warning.

### FORBIDDEN Elements

*   **`core_modal_reports.xsl`**: This file is **DEPRECATED** and should **NEVER** be included or imported in modern views.
*   **`RenderModalReportContent`**: This template call is **FORBIDDEN**. Do not use it. If you need modal functionality, use standard Bootstrap modals or modern UI components.

---

## Pre-Submit Checklist

Before handing over any XSL view, verify every item:

### API Selection
- [ ] Read `essential-view://api-docs` before choosing APIs
- [ ] API DSA labels verified (not guessed)
- [ ] Property names verified against api-docs documentation
- [ ] If uncertain, asked user to confirm API selection
- [ ] No hardcoded data arrays — all data comes from API responses

### Code Pattern
- [ ] No `GetViewerAPIPath`, `$utilitiesAllDataSetAPIs`, or `$.getJSON(apiApps` anywhere
- [ ] Single `<script type="text/javascript">` block (not multiple)
- [ ] `<xsl:call-template name="RenderViewerAPIJSFunction"/>` is the first thing in the script
- [ ] No CDATA sections
- [ ] Variables declared **before** `$(document).ready`
- [ ] `fetchAndRenderData(apiList)` used with async/await
- [ ] `displayError(error)` function defined in the script

### XML Escaping
- [ ] All `&&` → `&amp;&amp;` with **no space** after
- [ ] All `<` → `&lt;` (for-loops, comparisons, HTML strings, **comments**)
- [ ] All `<=` → `&lt;=`
- [ ] No bare `<` or `>` in any string literal or comment
- [ ] HTML built with `document.createElement()` not string concatenation

### Required Imports (ALL mandatory, no exceptions)
- [ ] `<xsl:import href="../common/core_js_functions.xsl"/>` — FIRST, as import
- [ ] `<xsl:include href="../common/core_doctype.xsl"/>`
- [ ] `<xsl:include href="../common/core_common_head_content.xsl"/>`
- [ ] `<xsl:include href="../common/core_header.xsl"/>`
- [ ] `<xsl:include href="../common/core_footer.xsl"/>`
- [ ] `<xsl:include href="../common/core_external_doc_ref.xsl"/>`
- [ ] `<xsl:include href="../common/core_api_fetcher.xsl"/>` — **not transitively included, must be explicit**
- [ ] NO manual inclusion/import of `viewer_security.xsl` (already provided via `core_header.xsl`)
- [ ] NO use of `core_modal_reports.xsl` or `RenderModalReportContent` (FORBIDDEN)

---

## Resources You Should Read

| Resource URI | When to Read |
|---|---|
| `essential-view://api-docs` | **Always — Step 1, before anything else** |
| `essential-view://quick-reference` | Always — golden pattern and escaping rules |
| `essential-view://api-property-verification` | When checking property names |
| `essential-view://view-build-docs` | For deep-dive on any pattern |
| `essential-view://roadmap-guide` | Only if the view needs org/geo scoping filters |

---

## Summary: The Three Most Common Failures

| Failure | Root Cause | Prevention |
|---------|-----------|------------|
| View shows no data | Guessed API label or property name | Read `essential-view://api-docs` first; ask user if unsure |
| SAXParseException on load | Bare `<`, `<=`, or `&` anywhere in `<script>` — including comments | Escape everything; use `forEach` not `for` loops |
| View fails completely | Copied old `GetViewerAPIPath` pattern from project files | Only use `fetchAndRenderData()` — never copy old XSL files |
