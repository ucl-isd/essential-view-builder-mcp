# Essential View Builder - Quick Reference Card

---

## ⛔ FORBIDDEN — OLD API PATTERN (Do Not Copy From Other Files In This Project)

Other XSL files in this project folder use an **obsolete** approach. If you see any of the patterns below, do NOT copy them. They will not work with the v2.0 API fetcher.

```xml
<!-- ❌ OBSOLETE — never use -->
<xsl:variable name="appData"
    select="$utilitiesAllDataSetAPIs[own_slot_value[slot_reference='name']/value='Core API: ...']"/>
<xsl:variable name="apiApps">
    <xsl:call-template name="GetViewerAPIPath">
        <xsl:with-param name="apiReport" select="$appData"/>
    </xsl:call-template>
</xsl:variable>
```

```javascript
// ❌ OBSOLETE — never use
$.getJSON(apiApps, function(data) { ... });
```

The **only** correct pattern is `fetchAndRenderData(apiList)` — see the golden pattern below.

### ⛔ FORBIDDEN — DEPRECATED COMPONENTS (Never Use)

*   **`core_modal_reports.xsl`**: This file is deprecated. Do NOT include it.
*   **`RenderModalReportContent`**: This template is forbidden. Do NOT call it.

---

## THE GOLDEN PATTERN (Copy This!)

```xml
<script type="text/javascript">
    <xsl:call-template name="RenderViewerAPIJSFunction"/>
    
    /**
     * MANDATORY: displayError is called by core_api_fetcher.xsl on failure.
     * Use &lt; and &gt; for HTML strings in XSL scripts.
     */
    function displayError(error) {
        console.error('Error:', error);
        $('#main-content').html(`&lt;div class="error"&gt;${error.message}&lt;/div&gt;`);
    }

    let appMartAPI;
    
    $(document).ready(function() {
        const apiList = ['appMartAPI'];
        
        async function executeFetchAndRender() {
            try {
                let responses = await fetchAndRenderData(apiList);
                ({ appMartAPI } = responses);
                
                renderView(appMartAPI);
            } catch (error) {
                if (typeof displayError === 'function') displayError(error);
            }
        }
        executeFetchAndRender();
    });
</script>
```
```

## Critical Rules (MUST FOLLOW)

### 1. Script Structure ✓
- ✓ Single `<script type="text/javascript">` tag
- ✓ Template call at top
- ✓ **MANDATORY**: `displayError(error)` must be defined
- ✓ **LIGHT THEME**: Use light backgrounds by default
- ✓ **NO CDATA section** (All code must be XML-compliant)
- ✓ Variables declared BEFORE $(document).ready
- ✗ NO multiple script blocks
- ✗ NO CDATA sections (causes parser conflicts)

### 2. Ampersand & Operator Encoding ✓
Since no CDATA is used, escape all operators:

| Operator | Escape | Rule |
| :--- | :--- | :--- |
| `&&` | `&amp;&amp;` | **NO SPACE** after `&amp;&amp;` |
| `<` | `&lt;` | Always — **including `for` loop conditions** |
| `<=` | `&lt;=` | Always |
| `>` | `&gt;` | Always |
| `>=` | `&gt;=` | Always |

**Example:**
```javascript
if (data &amp;&amp;data.items) { } // CORRECT
if (data &amp;&amp; data.items) { } // WRONG - Space breaks it
if (val &lt; 10) { }          // CORRECT
```

### ⚠️ COMMENTS MUST BE ESCAPED TOO — XML Sees Everything Inside `<script>`

The Saxon XSLT processor parses the **entire `<script>` block as XML** before JavaScript ever executes. This means bare `<`, `&`, etc. break the parse even when they appear inside a `//` comment or a string literal.

```javascript
// ❌ WRONG — comment with < still breaks the XML parser
// Iterate while i < items.length
// Check if score >= 0 && score < 100

// ✅ CORRECT — escape < in comments too
// Iterate while i &lt; items.length
// Check if score >= 0 &amp;&amp;score &lt; 100

// ✅ BEST — rephrase comments to avoid the characters entirely
// Iterate over all items
// Check if score is between 0 and 100

### ⚠️ JS-in-XSL XML Compliance Checklist
Saxon parses the entire `<script>` block as XML. Follow these strictly:
*   [ ] **No CDATA**: Ensure no `<![CDATA[` blocks are used.
*   [ ] **Ampersands**: All `&&` must be `&amp;&amp;` (with **NO space** after).
*   [ ] **Comparison Operators**: Use `&lt;` for `<` and `&gt;` for `>`.
*   [ ] **Greater-Than Logic**: To avoid `<` entirely, use "greater than" conditions (e.g., `for (let i = 0; 120 > i; i++)`).
*   [ ] **URLs**: Escape ampersands in strings/URLs (e.g., `report?XML=...&amp;PMA=...`).
*   [ ] **Comments**: Even comments must be XML-compliant!
```

**⚠️ FOR LOOP — Most Common Mistake:**
The `<` in a `for` loop counter is the #1 cause of:
`SAXParseException: The content of elements must consist of well-formed character data or markup`

```javascript
// ✗ WRONG - bare < causes Saxon XML parse failure
for (var i = 0; i < items.length; i++) { }

// ✓ CORRECT - escape < as &lt;
for (var i = 0; i &lt; items.length; i++) { }

// ✓ ALSO CORRECT - forEach avoids the problem entirely
items.forEach(function(item, i) { });
```

### 3. Async/await Pattern ✓
```javascript
// CORRECT
let responses = await fetchAndRenderData(apiList);
({ appMartAPI } = responses);

// WRONG
fetchAndRenderData(apiList, callback);  // No callbacks!
if (window.appMartAPI) { }              // No window access!
```

### 4. Property Names ✓
**VERIFY actual names, don't trust docs:**

| API | Doc Says | Actually Is |
|-----|----------|-------------|
| appLifecycle | .lifecycles | .application_lifecycles |
| appCostApi | .application_costs | .applicationCost |
| appOrgId | .organisations | .applicationOrgUsers |
| appKpiAPI | .kpis | .applications |

### 5. Imports ✓ (ALL REQUIRED)
```xml
<!-- IMPORT FIRST -->
<xsl:import href="../common/core_js_functions.xsl"/>

<!-- THEN ALL REQUIRED INCLUDES -->
<xsl:include href="../common/core_doctype.xsl"/>
<xsl:include href="../common/core_common_head_content.xsl"/>
<xsl:include href="../common/core_header.xsl"/>
<xsl:include href="../common/core_footer.xsl"/>
<xsl:include href="../common/core_external_doc_ref.xsl"/>
<xsl:include href="../common/core_api_fetcher.xsl"/>
<xsl:include href="../common/core_handlebars_functions.xsl"/>
```
**WARNING**: Omitting ANY of these includes will cause the view to fail silently or throw XSLT errors. Every view needs ALL six core includes.

### Transitive Security Inclusion
`viewer_security.xsl` is already included via `core_header.xsl`. **DO NOT** include it manually.

### 8. Template Mapping Table
Map the included file to its provided template name for `<xsl:call-template/>`:

| Include File | Template Name | Typical Usage |
| :--- | :--- | :--- |
| `core_header.xsl` | `Heading` | `<xsl:call-template name="Heading"/>` |
| `core_footer.xsl` | `Footer` | `<xsl:call-template name="Footer"/>` |
| `core_api_fetcher.xsl` | `RenderViewerAPIJSFunction` | Required for `fetchAndRenderData` |
| `core_common_head_content.xsl` | `commonHeadContent` | Called in `<head>` |
| `core_doctype.xsl` | `docType` | Called at the very top |

## Common Mistakes ✗

```javascript
// ✗ Multiple script blocks
<script><xsl:call-template.../></script>
<script><![CDATA[...]]></script>

// ✗ CDATA section
<script><![CDATA[ code here ]]></script>

// ✗ Space after &amp;&amp;
if (data &amp;&amp; data.items)

// ✗ Callback pattern
fetchAndRenderData(apiList, callback)

// ✗ Window access
if (window.appMartAPI)

// ✗ Wrong property names
responses.appLifecycle.lifecycles  // Should be .application_lifecycles
```

### 6. Roadmap/Timeline Charts ✓
- ✓ Calculate explicit `min`/`max` for X-axis
- ✓ Handle both `.allProjects` and `.allProject`
- ✓ Filter out invalid/1970 dates

### 7. Layout Isolation ✓
- ✓ Use a dedicated wrapper (e.g. `.view-wrapper`)
- ✓ Keep platform headers (`Heading`, `ScopingUI`) OUTSIDE custom wrappers
- ✓ Provide `margin-top: 40px/80px` for fixed bars

If dashboard shows no data:

1. [ ] Check console for "Responses loaded" message
2. [ ] Verify property names: `console.log(Object.keys(responses.apiName))`
3. [ ] Check if conditions: Look for spaces after `&amp;&amp;`
4. [ ] Verify destructuring: Variables declared before $(document).ready?
5. [ ] Check buildViewModel: Are property names correct?

## Cost Data Special Case

**Costs are EMBEDDED in applications, not separate:**

```javascript
// CORRECT - Get costs from each application
const totalCost = viewModel.applications.reduce((sum, app) => {
    const appCosts = app.costs || [];
    const appTotal = appCosts.reduce((s, cost) => s + parseFloat(cost.cost || 0), 0);
    return sum + appTotal;
}, 0);

// WRONG - appCostApi.applicationCost is usually empty
const totalCost = viewModel.costs.reduce(...)
```

**Cost object fields** (each entry in `app.costs[]`):

| Field | Example | Notes |
|-------|---------|-------|
| `cost.name` | "Hosting Cost" | Cost component type name |
| `cost.cost` | "1500" | Amount as STRING - must parseFloat() |
| `cost.ccy_code` | "GBP" | Currency code (preferred) |
| `cost.currency` | "£" | Currency symbol (fallback) |
| `cost.fromDate` | "2024-01-01" | ISO 8601 start date |
| `cost.toDate` | "2024-12-31" | ISO 8601 end date |
| `cost.description` | "" | Cost description text |
| `cost.costType` | "Annual_Cost_Component" | Component type class |

---

## Building HTML in JavaScript (XSL Context) ✓

**NEVER use string concatenation for HTML tags inside XSL scripts.** The `<` and `>` characters conflict with XML parsing.

```javascript
// ✓ CORRECT - Use DOM API (no escaping needed)
var tr = document.createElement('tr');
var td = document.createElement('td');
td.textContent = myValue;
tr.appendChild(td);
tbody.appendChild(tr);

// ✓ CORRECT - jQuery DOM creation
var tr = $('&lt;tr&gt;');
tr.append($('&lt;td&gt;').text(myValue));
tbody.append(tr);

// ✓ CORRECT - Self-closing void tags in strings
var br = '<br/>'; 

// ✓ CORRECT - Escaping prevents Saxon AVT errors
var html = '&lt;span class="status-${type}"&gt;${text}&lt;/span&gt;';

// ✗ WRONG - String HTML with angle brackets breaks XSL
var html = '<tr><td>' + myValue + '</td></tr>';

// ✗ WRONG - Unclosed void tags break Saxon parser
var html = '<br>';

// ✗ WRONG - Literal attributes with ${} trigger Saxon AVT parser
var html = '<span class="status-${type}">${text}</span>';
```

**Rule**: Always use `document.createElement()` or jQuery `$('&lt;tag&gt;')` to build DOM dynamically.

---

## Excel Export Views ✓

**ExcelJS is available** at `js/exceljs/exceljs.min.js` for client-side .xlsx generation.

### Excel Export Pattern:
```xml
<!-- Add to head -->
<script src="js/exceljs/exceljs.min.js" type="text/javascript"/>
```

```javascript
// In your export function:
async function exportToExcel() {
    var workbook = new ExcelJS.Workbook();
    var sheet = workbook.addWorksheet('Sheet Name');

    sheet.columns = [
        { header: 'Column A', key: 'colA', width: 30 },
        { header: 'Column B', key: 'colB', width: 20 }
    ];

    // Style header row
    var headerRow = sheet.getRow(1);
    headerRow.font = { bold: true, color: { argb: 'FFFFFFFF' }, size: 11 };
    headerRow.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF4472C4' } };

    // Add data
    dataArray.forEach(function(item) {
        sheet.addRow({ colA: item.name, colB: item.value });
    });

    // Freeze header + auto-filter
    sheet.views = [{ state: 'frozen', ySplit: 1 }];
    sheet.autoFilter = { from: 'A1', to: 'B1' };

    // Download
    var buffer = await workbook.xlsx.writeBuffer();
    var blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
    var url = window.URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'export.xlsx';
    a.click();
    window.URL.revokeObjectURL(url);
}
```

**Key**: Excel export views are standard HTML views (same imports, same API fetcher pattern) with ExcelJS for the download. Do NOT try to output SpreadsheetML XML directly from XSL - it conflicts with the Essential Viewer report engine which requires HTML views.

---

## Reference Files

- Mandatory workflow: `essential-view://agent-workflow` ← **Read this first**
- Working template: `essential-view://view-template`
- Excel export example: `application/core_al_app_cost_excel_export.xsl`
- Full guide: `MCP_RESOURCE_UPDATES.md`
- Data structures: `DATA_STRUCTURE_FINDINGS.md`

> **Note**: `core_al_app_provider_list_table.xsl` in this folder uses the **OLD/OBSOLETE** `GetViewerAPIPath` pattern and is kept only as a historical reference. Do NOT copy it.
