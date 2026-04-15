# View Building Documentation

This document provides instructions for AI agents on how to build custom Views for the Essential Viewer using the **API Fetch Template**.

## 1. The Template Pattern
**All** new views must be based on the **API Fetch Template** pattern. This separates the view into:
1.  **XSLT Shell**: Handles the page structure, imports, and CSS/JS inclusion.
2.  **Client-Side Data Fetching**: Uses the `core_api_fetcher.xsl` mechanism to asynchronously fetch JSON data from the server.
3.  **JavaScript Rendering**: Processes the JSON data and builds the HTML DOM.

**Template File:** `user/api_fetch_template.xsl`
*   Use this file as your starting point.
*   **DO NOT** modify the standard imports (e.g., `core_header.xsl`, `core_footer.xsl`, `core_api_fetcher.xsl`).
*   **DO NOT** remove `<xsl:call-template name="RenderViewerAPIJSFunction"/>`. This is critical for the API mechanism.

### 1.1 Required XSL Structure

**CRITICAL**: All views MUST follow this exact structure at the top of the XSL file:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
    xpath-default-namespace="http://protege.stanford.edu/xml" 
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
    xmlns:xalan="http://xml.apache.org/xslt" 
    xmlns:pro="http://protege.stanford.edu/xml" 
    xmlns:eas="http://www.enterprise-architecture.org/essential" 
    xmlns:functx="http://www.functx.com" 
    xmlns:xs="http://www.w3.org/2001/XMLSchema" 
    xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    
    <!-- IMPORT MUST COME FIRST - BEFORE ANY INCLUDES -->
    <xsl:import href="../common/core_js_functions.xsl"/>
    
    <!-- THEN INCLUDES IN THIS ORDER -->
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>
    <xsl:include href="../common/core_footer.xsl"/>
    <xsl:include href="../common/core_external_doc_ref.xsl"/>
    <xsl:include href="../common/core_api_fetcher.xsl"/>
    <xsl:include href="../common/core_handlebars_functions.xsl"/>
    
    <!-- CRITICAL: DO NOT manually include core_utilities.xsl OR viewer_security.xsl. 
         They are already included by the core header/footer/js chain. 
         Adding them here will cause "duplicate declaration" or "included more than once" errors. -->
    
    <!-- FORBIDDEN: NEVER include core_modal_reports.xsl or call RenderModalReportContent -->
    
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>
    
    <xsl:variable name="viewScopeTerms" select="eas:get_scoping_terms_from_string($viewScopeTermIds)"/>
    <xsl:variable name="linkClasses" select="('Composite_Application_Provider', 'Application_Provider')"/>
```

**Why this matters:**
- The `<xsl:import>` MUST come before `<xsl:include>` statements (XSLT specification requirement)
- Missing `core_js_functions.xsl` import will cause "I/O error" when processing the XSL
- Wrong order will cause Saxon parser errors

### 1.2 JavaScript Section Structure (No CDATA Pattern)

**CRITICAL**: v2.0 Dashboards MUST NOT use CDATA sections. All JavaScript must be XML-compliant and escape characters like `&&`, `<`, and `>`. XSL template calls and JavaScript go directly in a single `<script>` block.

**CORRECT Pattern:**
```xml
<script type="text/javascript">
    <xsl:call-template name="RenderViewerAPIJSFunction"/>
    
    // Declare variables before $(document).ready for destructuring
    let appMartAPI, infoMartAPI;
    
    $(document).ready(function() {
        const apiList = ['appMartAPI', 'infoMartAPI'];
        
        async function executeFetchAndRender() {
            try {
                let responses = await fetchAndRenderData(apiList);
                ({ appMartAPI, infoMartAPI } = responses);
                
                // Build view model and render
                buildViewModel(responses);
                renderView();
            } catch (error) {
                console.error('Error:', error);
            }
        }
        
        executeFetchAndRender();
    });
</script>
```

**WRONG Pattern (causes XML parsing errors or broken logic):**
```xml
<!-- DON'T DO THIS - mixing template calls with CDATA -->
<script>
    <xsl:call-template name="RenderViewerAPIJSFunction"/>
    <![CDATA[
    const apiList = ['appMartAPI']
    ]]>
</script>

<!-- DON'T DO THIS - using plain && outside CDATA -->
<script>
    if (data && data.items) { ... }
</script>
```

### 1.3 Ampersand & Operator Encoding (CRITICAL)

Since we don't use CDATA, all JavaScript operators must be XML-encoded.

**CRITICAL RULE**: `&amp;&amp;` must have **NO SPACE** after it to prevent Saxon parser issues.

| Character | Escape Sequence | Example |
| :--- | :--- | :--- |
| `&&` | `&amp;&amp;` | `if(data&amp;&amp;data.items)` |
| `<` | `&lt;` | `if(val &lt; 10)` |
| `<=` | `&lt;=` | `if(val &lt;= 10)` |
| `>` | `&gt;` | `if(val &gt; 10)` |
| `>=` | `&gt;=` | `if(val &gt;= 10)` |

**Example (CORRECT):**
```javascript
if (responses.appMartAPI &amp;&amp;responses.appMartAPI.applications) {
    const apps = responses.appMartAPI.applications.filter(a => a.id &gt; 0);
}
```

**Outside CDATA sections** (in XML attributes):
- Use `&amp;` for URL parameters
- Use `&amp;&amp;` for logical AND
- Use `&lt;=` and `&gt;=` for comparisons

**Example (CORRECT outside CDATA):**
```xml
<xsl:attribute name="href">report?cl=en-gb&amp;XSL=view.xsl</xsl:attribute>
```

### 1.4 HTML Strings in JavaScript (CRITICAL)

When writing HTML strings within JavaScript (e.g., for `innerHTML`, jQuery, or template literals), you must remember that you are in an **XML context**.

**CRITICAL RULES:**
1. **Self-Close Void Tags**: Tags like `<br>`, `<hr>`, `<img>`, `<input>` MUST be written as self-closing: `<br/>`, `<hr/>`, `<img ... />`, `<input ... />`. Failure to do this will cause a termination error.
2. **Escape or Balance**: Prefer using `&lt;` and `&gt;` for all HTML-like strings to avoid the XML parser attempting to interpret them as elements.
3. **Avoid Template Literals `${}`**: **MANDATORY**: Do not use `${variable}` in JavaScript blocks unless they are wrapped in `<![CDATA[`. Saxon may attempt to parse these as XSL Attribute Value Templates (AVTs), causing fatal errors. Use string concatenation `' + variable + '` instead.
4. **Template Literals & AVTs**: **CRITICAL**: If you use literal HTML tags with attributes (e.g. `<span class="...">`) and use `${}` inside that attribute, Saxon will attempt to parse the `${}` as an **Attribute Value Template (AVT)**. This will almost certainly cause a "Fatal Error: Unexpected token" crash.
    - **Fix**: ALWAYS escape attributes in JS strings as `&lt;span class="..."&gt;` or use `document.createElement`.

**Example (CORRECT - prevents AVT crash):**
```javascript
// Using escaped characters (PREVENTS AVT PARSING)
const html = `&lt;span class="status-${type}"&gt;${text}&lt;/span&gt;`;
```

**Example (WRONG - triggers Saxon crash if attribute has ${}):**
```javascript
// Saxon sees {type} as an XSL expression and crashes
const html = `<span class="status-${type}">${text}</span>`; 
```

**Example (WRONG - unclosed tag):**
```javascript
// Unclosed tag
marker.bindPopup(`<b>${name}</b><br>Status: Live`); 
```

## 2. API Selection Hierarchy (REUSE FIRST)

Before creating a new API, follow this hierarchy to ensure maintainability and performance. Creating new XSL APIs should be a **last resort**.

1. **Check Existing Mart APIs**:
   - Primary: `application/api/core_api_application_mart_ngv.xsl` (The most comprehensive JSON API).
   - Others: `core_api_al_app_rationalisation_ng.xsl`, `core_api_cap_mart.xsl`.
2. **Reuse Patterns**: If an existing API has 80% of what you need, prefer using it and handling the rest in client-side JS or by requesting a minor slot addition to the existing API.
3. **Confirm New XSL**: **MANDATORY**: If you believe a new XSL API is absolutely necessary, you MUST ask the user for confirmation before proceeding.

## 3. XSL Performance (KEY FOR SPEED)

When writing XSLT for Essential (especially APIs), performance is critical as repositories can have tens of thousands of instances.

**CRITICAL RULES:**
1. **NEVER use `//node()` or `//pro:simple_instance` in repeated logic**: These cause the parser to traverse the entire tree for every item, leading to exponential slowdown.
2. **ALWAYS use `<xsl:key>`**: Define keys at the top level for all common lookups (type, name, slots).
3. **Fetch Once**: Use a single `$allInstances` variable or key lookup at the start rather than repeated path searches.

**Example (HIGH PERFORMANCE):**
```xml
<!-- Define keys -->
<xsl:key name="instancesByType" match="pro:simple_instance" use="pro:type"/>
<xsl:key name="instancesByName" match="pro:simple_instance" use="pro:name"/>

<!-- Use keys -->
<xsl:variable name="targetProcesses" select="key('instancesByType', 'Business_Process')"/>
```

**Example (BAD PERFORMANCE - DO NOT USE):**
```xml
<xsl:variable name="targetProcesses" select="//pro:simple_instance[pro:type='Business_Process']"/>
```

## 4. Consulting the Catalogue
Consult the **Essential API Catalogue** below to find the data you need.
*   Each API has a **DSA Data Label** (e.g., `appMartAPI`).
*   **Usage**: You MUST use this exact label to request the data.
*   **Properties**: Use this to know what fields are available, but **always verify actual response structure in the console**.

## 3. Configuring the View
In the JavaScript section of your new view (derived from the template), configure the `apiList`:

**Simple format (array of strings):**
```javascript
// For basic use - recommended for most cases
const apiList = ['appMartAPI', 'infoMartAPI'];
```

**Full format (array of objects) - use when you need control over API structure:**
```javascript
// Note: Inside CDATA, use plain & not &amp;
const apiList = [
    {
        label: 'appMartAPI',
        type: 'data',
        url: 'data/core/core_app_mart.json'
    },
    {
        label: 'appCostApi',
        type: 'data',
        url: 'reportXML.xml?cl=en-gb&XSL=reportApiRoadmap/application/core_api_app_costs.xsl'
    }
];
```

**Important:** The `label` value determines how you'll access the data (e.g., `window.appMartAPI`). This label MUST match the DSA Data Label from the API Catalogue below.

## 4. Data Processing & View Creation

**CRITICAL**: Do not just verify the API calls. You must build a working view.

### 4.1 Create a View Model
The view should not depend directly on the raw API structure. Instead:
1.  **Define a View Model**: Create a JavaScript object/array structure that best suits your view's display logic.
2.  **Transform Data**: Write code to map the API response to this View Model.

### 4.2 Handling Missing Data
If the API does not provide a piece of data that your view concept requires:
1.  **Create Placeholders**: Inject placeholder objects or mock data into your View Model so the view can still be built and visually verified.
2.  **Notify User**: Add a clear `// TODO: USER ACTION REQUIRED` comment in the code explaining what data is missing and how to hook it up.

### 4.3 Example Implementation

```javascript
let apiList = ['appMartAPI', 'infoMartAPI'];
async function executeFetchAndRender() {
    try {
        // 1. Fetch data
        let responses = await fetchAndRenderData(apiList);
        let { appMartAPI } = responses; // Destructure
        
        // 2. Process Data into a View Model
        // Example: We want a simple list of apps with a 'status' that might be missing from the API
        let viewModel = (appMartAPI.applications || []).map(app => ({
            name: app.name,
            id: app.id,
            // API doesn't have 'health', so we create a placeholder
            health: "Unknown" // TODO: USER ACTION REQUIRED - Hook in health status data source here
        }));

        // 3. Render View using the View Model
        // The view logic relies on 'viewModel', not the raw 'appMartAPI'
        renderAppTable(viewModel);
        
    } catch (error) {
        console.error("Error fetching data:", error);
        // Render a user-friendly error state if needed
    }
}

function renderAppTable(data) {
    // Build HTML based on 'data' (the View Model)
    let html = '<table class="table">';
    data.forEach(item => {
        html += `<tr>
                    <td>${item.name}</td>
                    <td><span class="label label-default">${item.health}</span></td>
                 </tr>`;
    });
    html += '</table>';
    
    // Inject into the main container
    $('.col-xs-12[role="main"]').html(html);
}
```

## 5. Aesthetics & Frameworks

**CRITICAL RULES for Dashboard Design:**

### 5.1 Light Background Default
- **Rule**: All dashboards and views MUST use a light background palette unless the user explicitly requests a "HUD", "Dark Mode", or "Neon" aesthetic.
- **Background Color**: Use transparent whites or light grays (e.g., `#f8fafc`, `#f1f5f9`).
- **Typography**: Prefer modern sans-serif fonts like **Inter**, **Outfit**, or **Roboto**. Ensure high contrast for readability (e.g., `#1e293b` for primary text).

### 5.2 Mandatory Error Handling
- **Rule**: Every view MUST define a `displayError(error)` function in the `<script>` block.
- **Purpose**: This function is called by the `fetchAndRenderData` mechanism in `core_api_fetcher.xsl`. If missing, the view will fail with a "displayError is not defined" ReferenceError.
- **Implementation**: See the **API Fetch Template** for the standard implementation pattern.

### 5.3 Frameworks & Libraries
- **Handlebars.js (MANDATORY)**: Use Handlebars for all data binding and component rendering.
    - **Include**: `<xsl:include href="../common/core_handlebars_functions.xsl"/>` at the top.
    - **Logic**: Process your View Model and pass it to a Handlebars template for injection.
- **Chart.js**: Use for all data visualizations.
- **Font Awesome**: Use for icons (v5 or v6, check `commonHeadContent` for availability).
- **Bootstrap 3**: Use standard Bootstrap grid and component classes for layout (available in the Viewer core).

---

## 6. Rendering Best Practices
*   **Container**: The template provides a main container (e.g., `<div class="col-xs-12" role="main">`). Inject your content here.
*   **Styling**: Add custom CSS in the `<style>` block in the `<head>`. Use CSS variables for theme-ability.
*   **Interactivity**: You can use standard jQuery (available by default).

---

## Application

### core_api_al_app_apr.xsl
- **Path**: `application/api/core_api_al_app_apr.xsl`
- **DSA Data Label**: `aprsAPI`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `apr` | Array | `[{"aprId": "store_283_Class10001", "serviceId": "store_55_Class904", "appId": "store_55_Class1234"}]` |
| `apr[].aprId` | String | `"store_283_Class10001"` |
| `apr[].serviceId` | String | `"store_55_Class904"` |
| `apr[].appId` | String | `"store_55_Class1234"` |


### core_api_al_application_capabilities_l1_to_services.xsl
- **Path**: `application/api/core_api_al_application_capabilities_l1_to_services.xsl`
- **DSA Data Label**: `appCapL1ITAData`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_capabilities` | Array | `N/A` |
| `application_capabilities_all` | Array | `N/A` |
| `id` | String | `N/A` |
| `application_services` | Array | `N/A` |
| `name` | String | `N/A` |
| `apps` | Array | `N/A` |

### core_api_al_application_provider_cost.xsl
- **Path**: `application/api/core_api_al_application_provider_cost.xsl`
- **DSA Data Label**: `appCostApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `ccy` | Array | `N/A` |
| `applicationCost` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |
| `description` | String | `N/A` |
| `costccy` | Array | `N/A` |
| `costs` | Array | `N/A` |
| `cost` | String | `N/A` |
| `currency` | String | `N/A` |
| `startDate` | String | `N/A` |
| `endDate` | String | `N/A` |
| `change` | String | `N/A` |
| `default` | String | `N/A` |

### core_api_al_get_all_application_lifecycles.xsl
- **Path**: `application/api/core_api_al_get_all_application_lifecycles.xsl`
- **DSA Data Label**: `appLifecycle`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_lifecycles` | Array | `N/A` |
| `all_lifecycles` | Array | `N/A` |
| `lifecycleJSON` | Array | `N/A` |
| `name` | String | `N/A` |
| `id` | String | `N/A` |
| `supplierId` | String | `N/A` |
| `allDates` | Array | `N/A` |
| `dates` | Array | `N/A` |
| `className` | String | `N/A` |
| `dateOf` | String | `N/A` |
| `thisid` | String | `N/A` |
| `type` | String | `N/A` |
| `seq` | Unknown | `N/A` |
| `backgroundColour` | String | `N/A` |
| `colour` | String | `N/A` |
| `productId` | String | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |

### core_api_app_orgs.xsl
- **Path**: `application/api/core_api_app_orgs.xsl`
- **DSA Data Label**: `appOrgId`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applicationOrgUsers` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager", "organisations": ["store_55_Class67...` |
| `applicationOrgUsers[].id` | String | `"store_55_Class1161"` |
| `applicationOrgUsers[].name` | String | `"ADEXCell Energy Manager"` |
| `applicationOrgUsers[].organisations` | Array | `["store_55_Class679"]` |

### core_api_application_mart.xsl
- **Path**: `application/api/core_api_application_mart.xsl`
- **DSA Data Label**: `appMartAPI`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `capability_hierarchy` | Array | `[{"id": "store_55_Class772", "level": "0", "name": "Business Management", "appCapCategory": "Core", ...` |
| `capability_hierarchy[].id` | String | `"store_55_Class772"` |
| `capability_hierarchy[].level` | String | `"0"` |
| `capability_hierarchy[].name` | String | `"Business Management"` |
| `capability_hierarchy[].appCapCategory` | String | `"Core"` |
| `capability_hierarchy[].visId` | Array | `[""]` |
| `capability_hierarchy[].domainIds` | Array | `[{"id": "store_55_Class11"}]` |
| `capability_hierarchy[].sequence_number` | String | `""` |
| `capability_hierarchy[].businessDomain` | Array | `[{"id": "store_55_Class11"}]` |
| `capability_hierarchy[].childrenCaps` | Array | `[{"id": "store_55_Class774", "level": "1", "name": "Business Planning", "appCapCategory": "", "visId...` |
| `capability_hierarchy[].supportingServices` | Array | `[]` |
| `capability_hierarchy[].securityClassifications` | Array | `[]` |
| `application_capabilities` | Array | `[{"id": "store_55_Class762", "name": "Account Planning", "appCapCategory": "", "description": "Sales...` |
| `application_capabilities[].id` | String | `"store_55_Class762"` |
| `application_capabilities[].name` | String | `"Account Planning"` |
| `application_capabilities[].appCapCategory` | String | `""` |
| `application_capabilities[].description` | String | `"Sales account planning software"` |
| `application_capabilities[].visId` | Array | `[""]` |
| `application_capabilities[].sequence_number` | String | `""` |
| `application_capabilities[].domainIds` | Array | `[{"id": "store_55_Class20"}]` |
| `application_capabilities[].businessDomain` | Array | `[{"id": "store_55_Class20", "name": "Sales and Marketing"}]` |
| `application_capabilities[].ParentAppCapability` | Array | `[{"id": "store_55_Class759", "name": "Sales Management", "ReferenceModelLayer": ""}]` |
| `application_capabilities[].SupportedBusCapability` | Array | `[{"id": "store_55_Class197", "name": "Strategic Relationship Management"}]` |
| `application_capabilities[].securityClassifications` | Array | `[]` |
| `application_capabilities[].supportingServices` | Array | `["store_55_Class1094"]` |
| `application_capabilities[].documents` | Array | `[]` |
| `application_services` | Array | `[{"id": "store_55_Class898", "sequence_number": "", "name": "Architecture Design", "description": "D...` |
| `application_services[].id` | String | `"store_55_Class898"` |
| `application_services[].sequence_number` | String | `""` |
| `application_services[].name` | String | `"Architecture Design"` |
| `application_services[].description` | String | `"Design architectural plans"` |
| `application_services[].securityClassifications` | Array | `[]` |
| `application_services[].visId` | Array | `[""]` |
| `application_services[].APRs` | Array | `[{"visId": ["store_90_Class44"], "id": "store_316_Class40000", "lifecycle": "", "appId": "store_55_C...` |
| `application_services[].busProc` | Array | `["store_55_Class221"]` |
| `application_services[].functions` | Array | `["store_90_Class150002"]` |
| `application_functions` | Array | `[{"id": "store_219_Class2", "name": "Calculate Comparisons", "description": "", "securityClassificat...` |
| `application_functions[].id` | String | `"store_219_Class2"` |
| `application_functions[].name` | String | `"Calculate Comparisons"` |
| `application_functions[].description` | String | `""` |
| `application_functions[].securityClassifications` | Array | `[]` |
| `application_technology` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager", "environments": [{"id": "store_55_C...` |
| `application_technology[].id` | String | `"store_55_Class1161"` |
| `application_technology[].name` | String | `"ADEXCell Energy Manager"` |
| `application_technology[].environments` | Array | `[{"id": "store_55_Class2108", "name": "DEXCell Energy Manager - Production", "colour": "", "role": "...` |
| `applications` | Array | `[{"id": "store_55_Class1161", "ea_reference": "CAP001", "name": "ADEXCell Energy Manager", "short_na...` |
| `applications[].id` | String | `"store_55_Class1161"` |
| `applications[].ea_reference` | String | `"CAP001"` |
| `applications[].name` | String | `"ADEXCell Energy Manager"` |
| `applications[].short_name` | String | `""` |
| `applications[].type` | String | `"Composite_Application_Provider"` |
| `applications[].afis` | Array | `[{"id": "store_219_Class11", "funcId": "store_219_Class1"}]` |
| `applications[].synonyms` | Array | `[]` |
| `applications[].documents` | Array | `[]` |
| `applications[].supplier` | Object | `{"id": "store_53_Class2", "name": "Dexma"}` |
| `applications[].costs` | Array | `[{"name": "Hosting Cost", "description": "", "cost": "10000.0", "costType": "Annual_Cost_Component",...` |
| `applications[].maxUsers` | String | `"25"` |
| `applications[].family` | Array | `[]` |
| `app_function_implementations` | Array | `[{"id": "store_219_Class17", "name": "ADEXCell Energy Manager::Calculate Comparisons", "afiname": "C...` |
| `app_function_implementations[].id` | String | `"store_219_Class17"` |
| `app_function_implementations[].name` | String | `"ADEXCell Energy Manager::Calculate Comparisons"` |
| `app_function_implementations[].afiname` | String | `"Calculate Comparisons"` |
| `app_function_implementations[].description` | String | `""` |
| `app_function_implementations[].appId` | String | `"store_55_Class1161"` |
| `app_function_implementations[].afuncId` | String | `"store_219_Class2"` |
| `stdStyles` | Array | `[{"id": "store_55_Class5266", "shortname": "View Styling for Mandatory", "colour": "#1B51A5", "colou...` |
| `stdStyles[].id` | String | `"store_55_Class5266"` |
| `stdStyles[].shortname` | String | `"View Styling for Mandatory"` |
| `stdStyles[].colour` | String | `"#1B51A5"` |
| `stdStyles[].colourText` | String | `"#ffffff"` |
| `ccy` | Array | `[{"id": "essential_baseline_v505_Class16", "name": "British Pound", "default": "", "exchangeRate": "...` |
| `ccy[].id` | String | `"essential_baseline_v505_Class16"` |
| `ccy[].name` | String | `"British Pound"` |
| `ccy[].default` | String | `""` |
| `ccy[].exchangeRate` | String | `""` |
| `ccy[].ccySymbol` | String | `"£"` |
| `ccy[].ccyCode` | String | `"GBP"` |
| `apus` | Array | `[{"id": "store_174_Class10006", "name": "Static Architecture of::DMS: Relation from Creds API::in::S...` |
| `apus[].id` | String | `"store_174_Class10006"` |
| `apus[].name` | String | `"Static Architecture of::DMS: Relation from Creds API::in::Static Architecture of::DMS to Creds::in:...` |
| `apus[].fromtype` | String | `"Application_Provider_Interface"` |
| `apus[].totype` | String | `"Composite_Application_Provider"` |
| `apus[].edgeName` | String | `"store_174_Class10000 to store_55_Class1224"` |
| `apus[].fromAppId` | String | `"store_174_Class10000"` |
| `apus[].toAppId` | String | `"store_55_Class1224"` |
| `apus[].fromApp` | String | `"Creds API"` |
| `apus[].toApp` | String | `"Creds"` |
| `apus[].infoData` | Array | `[{"id": "store_174_Class10008", "type": "APP_PRO_TO_INFOREP_EXCHANGE_RELATION", "name": "", "acquisi...` |
| `apus[].info` | Array | `[{"id": "store_297_Class40009", "type": "Information_Representation", "name": "Energy Trends"}]` |


## Business

### core_api_bl_actor_to_roles.xsl
- **Path**: `business/api/core_api_bl_actor_to_roles.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `a2rs` | Array | `N/A` |
| `id` | String | `N/A` |
| `actorName` | String | `N/A` |
| `actorId` | String | `N/A` |
| `roleName` | String | `N/A` |
| `roleId` | String | `N/A` |


### core_api_bl_bus_capability_process_activities.xsl
- **Path**: `business/api/core_api_bl_bus_capability_process_activities.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `buscaps` | Array | `N/A` |
| `busCapId` | String | `N/A` |
| `busCapName` | String | `N/A` |
| `processes` | Array | `N/A` |
| `processId` | String | `N/A` |
| `processName` | String | `N/A` |
| `physical` | Array | `N/A` |
| `orgName` | String | `N/A` |
| `site` | String | `N/A` |
| `siteid` | String | `N/A` |
| `activities` | Array | `N/A` |
| `activityId` | String | `N/A` |
| `activityName` | String | `N/A` |
| `actor` | String | `N/A` |

### core_api_bl_bus_domain.xsl
- **Path**: `business/api/core_api_bl_bus_domain.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `businessDomains` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |

### core_api_bl_bus_perf_measures.xsl
- **Path**: `business/api/core_api_bl_bus_perf_measures.xsl`
- **DSA Data Label**: `busKpiAPI`
- **Parameters**: None
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `processes` | Array | `[{"id": "store_113_Class10852", "name": "Track Generation Portfolio Availability", "physical": ["sto...` |
| `processes[].id` | String | `"store_113_Class10852"` |
| `processes[].name` | String | `"Track Generation Portfolio Availability"` |
| `processes[].physical` | Array | `["store_113_Class10854"]` |
| `processes[].description` | String | `""` |
| `processes[].perfMeasures` | Array | `[{"categoryid": "store_315_Class170", "id": "store_315_Class277", "date": "2025-01-01", "createdDate...` |
| `processes[].securityClassifications` | Array | `[]` |
| `businessCapabilities` | Array | `[{"id": "store_219_Class149", "name": "Portfolio Risk", "description": "", "perfMeasures": [{"catego...` |
| `businessCapabilities[].id` | String | `"store_219_Class149"` |
| `businessCapabilities[].name` | String | `"Portfolio Risk"` |
| `businessCapabilities[].description` | String | `""` |
| `businessCapabilities[].perfMeasures` | Array | `[{"categoryid": "store_315_Class69", "id": "store_315_Class171", "date": "2025-01-01", "createdDate"...` |
| `businessCapabilities[].securityClassifications` | Array | `[]` |
| `perfCategory` | Array | `[{"id": "store_315_Class170", "type": "Performance_Measure_Category", "name": "Process Maturity", "c...` |
| `perfCategory[].id` | String | `"store_315_Class170"` |
| `perfCategory[].type` | String | `"Performance_Measure_Category"` |
| `perfCategory[].name` | String | `"Process Maturity"` |
| `perfCategory[].classes` | Array | `["Business_Process"]` |
| `perfCategory[].qualities` | Array | `["store_315_Class71"]` |
| `serviceQualities` | Array | `[{"id": "store_315_Class70", "type": "Business_Service_Quality", "name": "Governance and Compliance"...` |
| `serviceQualities[].id` | String | `"store_315_Class70"` |
| `serviceQualities[].type` | String | `"Business_Service_Quality"` |
| `serviceQualities[].name` | String | `"Governance and Compliance"` |
| `serviceQualities[].shortName` | String | `""` |
| `serviceQualities[].maxScore` | String | `""` |
| `serviceQualities[].description` | String | `"Measures the policies, frameworks, and governance mechanisms in place to ensure alignment with orga...` |
| `serviceQualities[].serviceWeighting` | String | `""` |
| `serviceQualities[].serviceIndex` | String | `""` |
| `serviceQualities[].sqvs` | Array | `[{"id": "store_315_Class72", "type": "Business_Service_Quality_Value", "name": "Governance and Compl...` |

## Enterprise

### core_api_el_bus_cap_to_app_mart_apps.xsl
- **Path**: `enterprise/api/core_api_el_bus_cap_to_app_mart_apps.xsl`
- **DSA Data Label**: `busCapAppMartApps`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `meta` | Array | `[{"classes": ["Group_Actor"], "menuId": "grpActorGenMenu"}]` |
| `meta[].classes` | Array | `["Group_Actor"]` |
| `meta[].menuId` | String | `"grpActorGenMenu"` |
| `reports` | Array | `[{"name": "appRat", "link": "application/core_al_app_rationalisation_analysis_simple.xsl"}]` |
| `reports[].name` | String | `"appRat"` |
| `reports[].link` | String | `"application/core_al_app_rationalisation_analysis_simple.xsl"` |
| `applications` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager", "description": "Real time energy co...` |
| `applications[].id` | String | `"store_55_Class1161"` |
| `applications[].name` | String | `"ADEXCell Energy Manager"` |
| `applications[].description` | String | `"Real time energy consumption monitoring of facilities"` |
| `applications[].class` | String | `"Composite_Application_Provider"` |
| `applications[].className` | String | `"Composite_Application_Provider"` |
| `applications[].visId` | Array | `[""]` |
| `applications[].children` | Array | `[]` |
| `applications[].family` | Array | `[]` |
| `applications[].regulations` | Array | `[{"id": "store_877_Class1", "name": "GDPR", "description": "", "className": "Regulation"}]` |
| `applications[].issues` | Array | `[]` |
| `applications[].inI` | String | `"4"` |
| `applications[].inDataCount` | Array | `["store_174_Class10109"]` |
| `applications[].inIList` | Array | `[{"id": "store_55_Class1168", "name": "Microsoft Project Server"}]` |
| `applications[].outI` | String | `"4"` |
| `applications[].valueClass` | String | `"Composite_Application_Provider"` |
| `applications[].dispositionId` | String | `"store_183_Class27"` |
| `applications[].outIList` | Array | `[{"name": "Entronix EMP", "id": "store_55_Class1158"}]` |
| `applications[].outDataCount` | Array | `["store_174_Class68"]` |
| `applications[].criticality` | String | `""` |
| `applications[].type` | String | `"Business Application"` |
| `applications[].typeid` | String | `"essential_prj_CC_v1_4_2_Instance_670003"` |
| `applications[].orgUserIds` | Array | `["store_55_Class679"]` |
| `applications[].geoIds` | Array | `["essential_baseline_v2_0_Class50065"]` |
| `applications[].siteIds` | Array | `["store_55_Class1328"]` |
| `applications[].codebaseID` | String | `"essential_prj_AA_v1_4_Instance_119"` |
| `applications[].deliveryID` | String | `"essential_baseline_v505_Class20"` |
| `applications[].sA2R` | Array | `["store_307_Class0"]` |
| `applications[].al_managed_by_services` | Array | `[]` |
| `applications[].lifecycle` | String | `"EAS_Meta_Model_v1_3_Instance_189"` |
| `applications[].physP` | Array | `["store_177_Class0"]` |
| `applications[].allServicesIdOnly` | Array | `[{"id": "store_55_Class2257", "securityClassifications": []}]` |
| `applications[].allServices` | Array | `[{"id": "store_55_Class2257", "lifecycleId": "", "serviceId": "store_55_Class910", "className": "App...` |
| `applications[].ap_business_criticality` | Array | `[]` |
| `applications[].ap_codebase_status` | Array | `["essential_prj_AA_v1_4_Instance_119"]` |
| `applications[].ap_delivery_model` | Array | `["essential_baseline_v505_Class20"]` |
| `applications[].ap_disaster_recovery_failover_model` | Array | `[]` |
| `applications[].ap_disposition_lifecycle_status` | Array | `["store_183_Class27"]` |
| `applications[].application_provider_purpose` | Array | `["essential_prj_CC_v1_4_2_Instance_670003"]` |
| `applications[].apt_customisation_level` | Array | `[]` |
| `applications[].apt_pace_of_change_level` | Array | `[]` |
| `applications[].apt_user_interaction_methods` | Array | `[]` |
| `applications[].ea_recovery_point_objective` | Array | `["store_174_Class20006"]` |
| `applications[].ea_recovery_time_objective` | Array | `["store_174_Class20001"]` |
| `applications[].lifecycle_status_application_provider` | Array | `["EAS_Meta_Model_v1_3_Instance_189"]` |
| `applications[].purchase_status` | Array | `[]` |
| `applications[].user_count_range` | Array | `[]` |
| `applications[].vendor_product_lifecycle_status` | Array | `[]` |
| `applications[].ap_supports_multi_language` | Array | `["none"]` |
| `applications[].distribute_costs` | Array | `["none"]` |
| `applications[].services` | Array | `[{"id": "store_55_Class910", "name": "Benchmarking", "securityClassifications": []}]` |
| `applications[].securityClassifications` | Array | `[]` |
| `compositeServices` | Array | `[{"id": "store_911_Class10017", "name": "ERP System", "containedService": ["store_55_Class1104", "st...` |
| `compositeServices[].id` | String | `"store_911_Class10017"` |
| `compositeServices[].name` | String | `"ERP System"` |
| `compositeServices[].containedService` | Array | `["store_55_Class1104"]` |
| `compositeServices[].securityClassifications` | Array | `[]` |
| `apis` | Array | `[{"id": "store_174_Class63", "name": "ADEXCell Energy Manager API", "description": "", "class": "App...` |
| `apis[].id` | String | `"store_174_Class63"` |
| `apis[].name` | String | `"ADEXCell Energy Manager API"` |
| `apis[].description` | String | `""` |
| `apis[].class` | String | `"Application_Provider_Interface"` |
| `apis[].className` | String | `"Application_Provider_Interface"` |
| `apis[].visId` | Array | `["store_90_Class44"]` |
| `apis[].children` | Array | `[]` |
| `apis[].family` | Array | `[]` |
| `apis[].regulations` | Array | `[]` |
| `apis[].issues` | Array | `[]` |
| `apis[].inI` | String | `"1"` |
| `apis[].inDataCount` | Array | `["store_174_Class68"]` |
| `apis[].inIList` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager"}]` |
| `apis[].outI` | String | `"1"` |
| `apis[].valueClass` | String | `"Application_Provider_Interface"` |
| `apis[].dispositionId` | String | `""` |
| `apis[].outIList` | Array | `[{"name": "AMS Fleet Solutions", "id": "store_55_Class1190"}]` |
| `apis[].outDataCount` | Array | `["store_174_Class70"]` |
| `apis[].criticality` | String | `""` |
| `apis[].orgUserIds` | Array | `[]` |
| `apis[].geoIds` | Array | `[]` |
| `apis[].siteIds` | Array | `[]` |
| `apis[].codebaseID` | String | `""` |
| `apis[].deliveryID` | String | `""` |
| `apis[].sA2R` | Array | `[]` |
| `apis[].al_managed_by_services` | Array | `[]` |
| `apis[].lifecycle` | String | `""` |
| `apis[].physP` | Array | `[]` |
| `apis[].allServicesIdOnly` | Array | `[]` |
| `apis[].allServices` | Array | `[]` |
| `apis[].ap_business_criticality` | Array | `[]` |
| `apis[].ap_codebase_status` | Array | `[]` |
| `apis[].ap_delivery_model` | Array | `[]` |
| `apis[].ap_disaster_recovery_failover_model` | Array | `[]` |
| `apis[].ap_disposition_lifecycle_status` | Array | `[]` |
| `apis[].application_provider_purpose` | Array | `[]` |
| `apis[].apt_customisation_level` | Array | `[]` |
| `apis[].apt_pace_of_change_level` | Array | `[]` |
| `apis[].apt_user_interaction_methods` | Array | `[]` |
| `apis[].ea_recovery_point_objective` | Array | `[]` |
| `apis[].ea_recovery_time_objective` | Array | `[]` |
| `apis[].lifecycle_status_application_provider` | Array | `[]` |
| `apis[].purchase_status` | Array | `[]` |
| `apis[].user_count_range` | Array | `[]` |
| `apis[].vendor_product_lifecycle_status` | Array | `[]` |
| `apis[].ap_supports_multi_language` | Array | `["none"]` |
| `apis[].distribute_costs` | Array | `["true"]` |
| `apis[].services` | Array | `[]` |
| `apis[].securityClassifications` | Array | `[]` |
| `lifecycles` | Array | `[{"id": "essential_prj_AA_v1_4_Instance_10068", "shortname": "Under Planning", "colour": "#4196D9", ...` |
| `lifecycles[].id` | String | `"essential_prj_AA_v1_4_Instance_10068"` |
| `lifecycles[].shortname` | String | `"Under Planning"` |
| `lifecycles[].colour` | String | `"#4196D9"` |
| `lifecycles[].colourText` | String | `"#ffffff"` |
| `codebase` | Array | `[{"id": "essential_prj_AA_v1_0_Instance_10002", "shortname": "Packaged", "colour": "#4196D9", "colou...` |
| `codebase[].id` | String | `"essential_prj_AA_v1_0_Instance_10002"` |
| `codebase[].shortname` | String | `"Packaged"` |
| `codebase[].colour` | String | `"#4196D9"` |
| `codebase[].colourText` | String | `"#ffffff"` |
| `delivery` | Array | `[{"id": "essential_baseline_v505_Class23", "shortname": "Desktop", "colour": "#EF3F4A", "colourText"...` |
| `delivery[].id` | String | `"essential_baseline_v505_Class23"` |
| `delivery[].shortname` | String | `"Desktop"` |
| `delivery[].colour` | String | `"#EF3F4A"` |
| `delivery[].colourText` | String | `"#ffffff"` |
| `filters` | Array | `[{"id": "Lifecycle_Status", "name": "Lifecycle Status", "valueClass": "Lifecycle_Status", "descripti...` |
| `filters[].id` | String | `"Lifecycle_Status"` |
| `filters[].name` | String | `"Lifecycle Status"` |
| `filters[].valueClass` | String | `"Lifecycle_Status"` |
| `filters[].description` | String | `""` |
| `filters[].slotName` | String | `"lifecycle_status_application_provider"` |
| `filters[].isGroup` | Boolean | `false` |
| `filters[].icon` | String | `"fa-circle"` |
| `filters[].color` | String | `"#93592f"` |
| `filters[].values` | Array | `[{"id": "essential_prj_AA_v1_4_Instance_10068", "sequence": "1", "enum_name": "Under Planning", "nam...` |
| `version` | String | `"6152"` |

### core_api_el_bus_cap_to_app_mart_caps.xsl
- **Path**: `enterprise/api/core_api_el_bus_cap_to_app_mart_caps.xsl`
- **DSA Data Label**: `busCapAppMartCaps`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `meta` | Array | `[{"classes": ["Group_Actor"], "menuId": "grpActorGenMenu"}]` |
| `meta[].classes` | Array | `["Group_Actor"]` |
| `meta[].menuId` | String | `"grpActorGenMenu"` |
| `busCapHierarchy` | Array | `[{"id": "store_55_Class30", "visId": [""], "name": "Maintenance", "className": "Business_Capability"...` |
| `busCapHierarchy[].id` | String | `"store_55_Class30"` |
| `busCapHierarchy[].visId` | Array | `[""]` |
| `busCapHierarchy[].name` | String | `"Maintenance"` |
| `busCapHierarchy[].className` | String | `"Business_Capability"` |
| `busCapHierarchy[].description` | String | `"Maintenance of equipment and sites"` |
| `busCapHierarchy[].position` | String | `""` |
| `busCapHierarchy[].order` | String | `""` |
| `busCapHierarchy[].diffLevelIds` | Array | `[]` |
| `busCapHierarchy[].business_capability_purpose` | Array | `[]` |
| `busCapHierarchy[].business_differentiation_level` | Array | `[]` |
| `busCapHierarchy[].operating_model_geographic_scope` | Array | `[]` |
| `busCapHierarchy[].level` | String | `"0"` |
| `busCapHierarchy[].childrenCaps` | Array | `[{"id": "store_55_Class121", "visId": [""], "name": "Performance Management", "className": "Business...` |
| `busCapHierarchy[].securityClassifications` | Array | `[]` |
| `busCaptoAppDetails` | Array | `[{"id": "store_219_Class149", "link": "<a href = \"?XML=reportXML.xml&PMA=store_219_Class149&cl=en-g...` |
| `busCaptoAppDetails[].id` | String | `"store_219_Class149"` |
| `busCaptoAppDetails[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_219_Class149&cl=en-gb" class = " context-menu-busCapGenMenu...` |
| `busCaptoAppDetails[].className` | String | `"Business_Capability"` |
| `busCaptoAppDetails[].index` | String | `""` |
| `busCaptoAppDetails[].isRoot` | String | `""` |
| `busCaptoAppDetails[].name` | String | `"Portfolio Risk"` |
| `busCaptoAppDetails[].allProcesses` | Array | `[]` |
| `busCaptoAppDetails[].infoConcepts` | Array | `[]` |
| `busCaptoAppDetails[].processes` | Array | `[]` |
| `busCaptoAppDetails[].physP` | Array | `[]` |
| `busCaptoAppDetails[].classifications` | Array | `[]` |
| `busCaptoAppDetails[].orgUserIds` | Array | `[]` |
| `busCaptoAppDetails[].domainIds` | Array | `[]` |
| `busCaptoAppDetails[].prodConIds` | Array | `[]` |
| `busCaptoAppDetails[].geoIds` | Array | `[]` |
| `busCaptoAppDetails[].visId` | Array | `["store_90_Class44"]` |
| `busCaptoAppDetails[].business_capability_purpose` | Array | `[]` |
| `busCaptoAppDetails[].business_differentiation_level` | Array | `[]` |
| `busCaptoAppDetails[].operating_model_geographic_scope` | Array | `[]` |
| `busCaptoAppDetails[].thisapps` | Array | `[]` |
| `busCaptoAppDetails[].apps` | Array | `[]` |
| `busCaptoAppDetails[].securityClassifications` | Array | `[]` |
| `rootCap` | String | `"Energy"` |
| `physicalProcessToProcess` | Array | `[{"pPID": "store_113_Class10806", "procID": "store_55_Class381"}]` |
| `physicalProcessToProcess[].pPID` | String | `"store_113_Class10806"` |
| `physicalProcessToProcess[].procID` | String | `"store_55_Class381"` |
| `filters` | Array | `[{"id": "Business_Capability_Purpose", "name": "Business Capability Purpose", "valueClass": "Busines...` |
| `filters[].id` | String | `"Business_Capability_Purpose"` |
| `filters[].name` | String | `"Business Capability Purpose"` |
| `filters[].valueClass` | String | `"Business_Capability_Purpose"` |
| `filters[].description` | String | `""` |
| `filters[].slotName` | String | `"business_capability_purpose"` |
| `filters[].isGroup` | Boolean | `false` |
| `filters[].icon` | String | `"fa-circle"` |
| `filters[].color` | String | `"hsla(25, 52%, 38%, 1)"` |
| `filters[].values` | Array | `[{"id": "essential_baseline_v2_0_Class60006", "enum_name": "Direct", "name": "Direct", "sequence": "...` |
| `rootOrgs` | Array | `[]` |
| `bus_model_management` | Object | `{"businessModels": [{"id": "store_911_Class10119", "domain": "", "name": "Gentailer", "description":...` |
| `version` | String | `"620"` |

### core_api_el_org_summary_data_v2.xsl
- **Path**: `enterprise/api/core_api_el_org_summary_data_v2.xsl`
- **DSA Data Label**: `orgSummary`
- **Parameters**: None
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `orgData` | Array | `[{"id": "store_55_Class677", "parent": [], "name": "Distribution", "short_name": "", "description": ...` |
| `orgData[].id` | String | `"store_55_Class677"` |
| `orgData[].parent` | Array | `[]` |
| `orgData[].name` | String | `"Distribution"` |
| `orgData[].short_name` | String | `""` |
| `orgData[].description` | String | `"Responsible client facing, non-operational services"` |
| `orgData[].regulations` | Array | `[]` |
| `orgData[].documents` | Array | `[]` |
| `orgData[].orgEmployees` | Array | `[]` |
| `orgData[].site` | Array | `[{"name": "Paris", "id": "store_55_Class749"}]` |
| `orgData[].businessProcess` | Array | `[{"name": "Monitor Environmental Trends", "id": "store_55_Class451", "criticality": "High"}]` |
| `orgData[].applicationsUsedbyProcess` | Array | `[]` |
| `orgData[].applicationsUsedbyOrgUser` | Array | `[]` |
| `orgData[].children` | Array | `["store_55_Class679"]` |
| `orgRoles` | Array | `[{"id": "store_55_Class677", "name": "Distribution", "actor": "store_283_Class2239 store_55_Class464...` |
| `orgRoles[].id` | String | `"store_55_Class677"` |
| `orgRoles[].name` | String | `"Distribution"` |
| `orgRoles[].actor` | String | `"store_283_Class2239 store_55_Class4645"` |
| `orgRoles[].a2rs` | Array | `["store_283_Class2239"]` |
| `orgRoles[].roles` | Array | `[{"id": "essential_baseline_v62_Class15", "name": "Technology Organisation User"}]` |
| `indivData` | Array | `[{"name": "Alan Law", "id": "store_90_Class90000", "roles": [{"id": "store_113_Class102", "roleid": ...` |
| `indivData[].name` | String | `"Alan Law"` |
| `indivData[].id` | String | `"store_90_Class90000"` |
| `indivData[].roles` | Array | `[{"id": "store_113_Class102", "roleid": "store_113_Class98", "name": ""}]` |
| `roleData` | Array | `[{"name": "Data Standard Owning Organisation", "id": "essential_baseline_v3_0_3_Class10001"}]` |
| `roleData[].name` | String | `"Data Standard Owning Organisation"` |
| `roleData[].id` | String | `"essential_baseline_v3_0_3_Class10001"` |
| `a2rs` | Array | `[{"id": "store_113_Class100", "actor": "Sales", "actorid": "store_55_Class681", "type": "Group_Actor...` |
| `a2rs[].id` | String | `"store_113_Class100"` |
| `a2rs[].actor` | String | `"Sales"` |
| `a2rs[].actorid` | String | `"store_55_Class681"` |
| `a2rs[].type` | String | `"Group_Actor"` |
| `a2rs[].role` | String | `" Data Subject Organisational Owner "` |
| `version` | String | `"621"` |

### core_api_el_planned_elements.xsl
- **Path**: `enterprise/api/core_api_el_planned_elements.xsl`
- **DSA Data Label**: `planActionData`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applications` | Array | `N/A` |
| `plan_actions` | Array | `N/A` |
| `id` | String | `N/A` |
| `strategic_plan` | String | `N/A` |
| `strategic_plan_start` | String | `N/A` |
| `strategic_plan_end` | String | `N/A` |
| `change_activity` | String | `N/A` |
| `change_activity_start_forecast` | String | `N/A` |
| `change_activity_start_actual` | String | `N/A` |
| `change_activity_end_forecast` | String | `N/A` |
| `change_activity_end_actual` | String | `N/A` |
| `action` | String | `N/A` |

### core_api_el_plans_prog_proj.xsl
- **Path**: `enterprise/api/core_api_el_plans_prog_proj.xsl`
- **DSA Data Label**: `planDataAPi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `programmes` | Array | `[{"name": "Business Process Rationalisation Programme", "description": "Programme to rationalise the...` |
| `programmes[].name` | String | `"Business Process Rationalisation Programme"` |
| `programmes[].description` | String | `"Programme to rationalise the business processes across the business"` |
| `programmes[].className` | String | `"Programme"` |
| `programmes[].id` | String | `"store_283_Class1932"` |
| `programmes[].ea_reference` | String | `""` |
| `programmes[].orgUserIds` | Array | `[]` |
| `programmes[].stakeholders` | Array | `[]` |
| `programmes[].milestones` | Array | `[]` |
| `programmes[].proposedStartDate` | String | `"2022-01-01"` |
| `programmes[].targetEndDate` | String | `"2024-01-01"` |
| `programmes[].actualStartDate` | String | `"2020-01-01"` |
| `programmes[].forecastEndDate` | String | `"2020-06-01"` |
| `programmes[].budget` | String | `""` |
| `programmes[].approvalStatus` | String | `"Not Set"` |
| `programmes[].approvalId` | String | `""` |
| `programmes[].plans` | Array | `[]` |
| `programmes[].projects` | Array | `[{"id": "store_283_Class1902", "priority": "", "ea_reference": "", "name": "Business Process Automat...` |
| `programmes[].documents` | Array | `[]` |
| `programmes[].securityClassifications` | Array | `[]` |
| `allPlans` | Array | `[{"name": "Application Data Analysis", "description": "", "id": "store_948_Class17", "ea_reference":...` |
| `allPlans[].name` | String | `"Application Data Analysis"` |
| `allPlans[].description` | String | `""` |
| `allPlans[].id` | String | `"store_948_Class17"` |
| `allPlans[].ea_reference` | String | `""` |
| `allPlans[].className` | String | `"Enterprise_Strategic_Plan"` |
| `allPlans[].dependsOn` | Array | `[]` |
| `allPlans[].validStartDate` | String | `"2023-08-14"` |
| `allPlans[].validEndDate` | String | `"2023-10-16"` |
| `allPlans[].planP2E` | Array | `[]` |
| `allPlans[].objectives` | Array | `[]` |
| `allPlans[].drivers` | Array | `[]` |
| `allPlans[].planStatus` | String | `"Future"` |
| `allPlans[].projects` | Array | `[]` |
| `allPlans[].orgUserIds` | Array | `[]` |
| `allPlans[].stakeholders` | Array | `[]` |
| `allPlans[].documents` | Array | `[]` |
| `allPlans[].securityClassifications` | Array | `[]` |
| `styles` | Array | `[{"id": "essential_prj_CC_v1_4_2_Instance_80015", "colour": "#d3d3d3", "icon": "", "textColour": "#0...` |
| `styles[].id` | String | `"essential_prj_CC_v1_4_2_Instance_80015"` |
| `styles[].colour` | String | `"#d3d3d3"` |
| `styles[].icon` | String | `""` |
| `styles[].textColour` | String | `"#000000"` |
| `roadmaps` | Array | `[{"name": "Agility and Operational Efficiency", "description": "", "orgUserIds": [], "stakeholders":...` |
| `roadmaps[].name` | String | `"Agility and Operational Efficiency"` |
| `roadmaps[].description` | String | `""` |
| `roadmaps[].orgUserIds` | Array | `[]` |
| `roadmaps[].stakeholders` | Array | `[]` |
| `roadmaps[].id` | String | `"store_53_Class1231"` |
| `roadmaps[].ea_reference` | String | `""` |
| `roadmaps[].strategicPlans` | Array | `["store_53_Class1229"]` |
| `roadmaps[].className` | String | `"Roadmap"` |
| `roadmaps[].securityClassifications` | Array | `[]` |
| `allProject` | Array | `[{"id": "store_283_Class1902", "priority": "", "ea_reference": "", "name": "Business Process Automat...` |
| `allProject[].id` | String | `"store_283_Class1902"` |
| `allProject[].priority` | String | `""` |
| `allProject[].ea_reference` | String | `""` |
| `allProject[].name` | String | `"Business Process Automation Project"` |
| `allProject[].description` | String | `"Look to automate business processes to sace costs"` |
| `allProject[].orgUserIds` | Array | `[]` |
| `allProject[].programme` | String | `"store_283_Class1932"` |
| `allProject[].visId` | Array | `["store_90_Class44"]` |
| `allProject[].budget` | Array | `[]` |
| `allProject[].costs` | Array | `[]` |
| `allProject[].strategicPlans` | Array | `[{"id": "store_283_Class1890", "name": "Business Process Automation", "securityClassifications": []}...` |
| `allProject[].stakeholders` | Array | `[{"actorName": "Andy Taylor", "roleName": "Project Sponsor", "type": "ACTOR_TO_ROLE_RELATION", "acto...` |
| `allProject[].milestones` | Array | `[]` |
| `allProject[].className` | String | `"Project"` |
| `allProject[].proposedStartDate` | String | `"2020-01-01"` |
| `allProject[].targetEndDate` | String | `"2024-01-01"` |
| `allProject[].actualStartDate` | String | `"2020-03-01"` |
| `allProject[].forecastEndDate` | String | `"2024-06-01"` |
| `allProject[].lifecycleStatus` | String | `"Execution"` |
| `allProject[].lifecycleStatusID` | String | `"essential_baseline_v2_0_Class30003"` |
| `allProject[].lifecycleStatusOrder` | String | `"4"` |
| `allProject[].approvalStatus` | String | `"Approved"` |
| `allProject[].approvalId` | String | `"essential_baseline_v2_0_Class30005"` |
| `allProject[].p2e` | Array | `[{"id": "store_283_Class1900", "actionid": "essential_baseline_v3_0_3_Class10000", "impactedElement"...` |
| `allProject[].documents` | Array | `[]` |
| `allProject[].securityClassifications` | Array | `[]` |
| `currency` | String | `"£"` |
| `currencyId` | String | `"essential_baseline_v505_Class16"` |
| `currencyData` | Array | `[{"id": "essential_baseline_v505_Class15", "exchangeRate": "", "name": "US Dollar", "code": "USD", "...` |
| `currencyData[].id` | String | `"essential_baseline_v505_Class15"` |
| `currencyData[].exchangeRate` | String | `""` |
| `currencyData[].name` | String | `"US Dollar"` |
| `currencyData[].code` | String | `"USD"` |
| `currencyData[].symbol` | String | `"$"` |
| `currencyData[].default` | String | `""` |

### core_api_el_principles.xsl
- **Path**: `enterprise/api/core_api_el_principles.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `principles` | Array | `N/A` |
| `levels` | Array | `N/A` |
| `id` | String | `N/A` |
| `className` | String | `N/A` |
| `name` | Unknown | `N/A` |
| `description` | Unknown | `N/A` |
| `principle_rationale` | Unknown | `N/A` |
| `information_implications` | Unknown | `N/A` |
| `technology_implications` | Unknown | `N/A` |
| `business_implications` | Unknown | `N/A` |
| `application_implications` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `scores` | Array | `N/A` |
| `id2` | String | `N/A` |
| `thislevel` | String | `N/A` |
| `assessment` | Unknown | `N/A` |
| `score` | Unknown | `N/A` |
| `style` | Unknown | `N/A` |
| `value` | Unknown | `N/A` |
| `backgroundColour` | String | `N/A` |
| `colour` | String | `N/A` |

### core_api_el_strat_planner_analysis_data.xsl
- **Path**: `enterprise/api/core_api_el_strat_planner_analysis_data.xsl`
- **DSA Data Label**: `strategy-planner-data`
- **Parameters**: None
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `planningActions` | Array | `[{"id": "essential_prj_CC_v1.4.2_Instance_160169", "name": "Replace", "description": "Strategic plan...` |
| `planningActions[].id` | String | `"essential_prj_CC_v1.4.2_Instance_160169"` |
| `planningActions[].name` | String | `"Replace"` |
| `planningActions[].description` | String | `"Strategic planning actions capturing that an element has been identified as something that will be ...` |
| `goals` | Array | `[{"id": "store_90_Class130004", "name": "All Employees Briefed on Strategic Goals by 2020", "descrip...` |
| `goals[].id` | String | `"store_90_Class130004"` |
| `goals[].name` | String | `"All Employees Briefed on Strategic Goals by 2020"` |
| `goals[].description` | String | `""` |
| `goals[].link` | String | `"All Employees Briefed on Strategic Goals by 2020"` |
| `goals[].objectiveIds` | Array | `[]` |
| `goals[].objectives` | Array | `[]` |
| `goals[].inScope` | Boolean | `false` |
| `goals[].isSelected` | Boolean | `false` |
| `objectives` | Array | `[{"id": "store_53_Class90", "name": "Aligning our Employees to our Strategic Goals", "description": ...` |
| `objectives[].id` | String | `"store_53_Class90"` |
| `objectives[].name` | String | `"Aligning our Employees to our Strategic Goals"` |
| `objectives[].description` | String | `"Ensure employees are clear and working to the strategic goals"` |
| `objectives[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_53_Class90&cl=en-gb" class = " context-menu-busObjGenMenu" ...` |
| `objectives[].targetDate` | String | `"2020-08-31"` |
| `objectives[].goalIds` | Array | `["store_53_Class74"]` |
| `objectives[].inScope` | Boolean | `true` |
| `valueStreams` | Array | `[{"id": "store_55_Class7101", "name": "Client Advert to Engage", "description": "", "link": "<a href...` |
| `valueStreams[].id` | String | `"store_55_Class7101"` |
| `valueStreams[].name` | String | `"Client Advert to Engage"` |
| `valueStreams[].description` | String | `""` |
| `valueStreams[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class7101&cl=en-gb" class = " context-menu-valStreamGenM...` |
| `valueStreams[].valueStages` | Array | `[{"id": "store_55_Class7121", "name": "Client Advert to Engage: 1. Advert Creation", "index": "1", "...` |
| `valueStreams[].physProcessIds` | Array | `["store_55_Class5360"]` |
| `valueStreams[].appProRoleIds` | Array | `["store_55_Class2243"]` |
| `valueStreams[].prodTypeIds` | Array | `["store_55_Class7095"]` |
| `valueStreams[].roles` | Array | `[{"id": "store_55_Class7283", "type": "Individual_Business_Role", "name": "Marketer"}]` |
| `valueStreams[].triggerEvents` | Array | `[{"id": "store_316_Class20001", "name": "Business Sales Initiative"}]` |
| `valueStreams[].outcomeEvents` | Array | `[{"id": "store_316_Class20003", "name": "Sales Increase"}]` |
| `valueStreams[].triggerConditions` | Array | `[{"id": "store_316_Class20000", "name": "Requirement to Increase Brand Recognition & Sales"}]` |
| `valueStreams[].outcomeConditions` | Array | `[{"id": "store_316_Class20004", "name": "Clients recognise the brand"}]` |
| `valueStages` | Array | `[{"id": "store_55_Class7121", "name": "Client Advert to Engage: 1. Advert Creation", "index": "1", "...` |
| `valueStages[].id` | String | `"store_55_Class7121"` |
| `valueStages[].name` | String | `"Client Advert to Engage: 1. Advert Creation"` |
| `valueStages[].index` | String | `"1"` |
| `valueStages[].label` | String | `"Advert Creation"` |
| `valueStages[].description` | String | `"Creation of the advert and collateral"` |
| `valueStages[].link` | String | `"Advert Creation"` |
| `valueStages[].customerJourneyPhaseIds` | Array | `[]` |
| `valueStages[].customerJourneyPhases` | Array | `[]` |
| `valueStages[].emotionScore` | Number | `0` |
| `valueStages[].cxScore` | Number | `0` |
| `valueStages[].kpiScore` | Number | `-1` |
| `valueStages[].emotionStyleClass` | String | `"mediumHeatmapColour"` |
| `valueStages[].cxStyleClass` | String | `"mediumHeatmapColour"` |
| `valueStages[].kpiStyleClass` | String | `"noHeatmapColour"` |
| `valueStages[].styleClass` | String | `"mediumHeatmapColour"` |
| `valueStages[].inScope` | Boolean | `false` |
| `valueStages[].valueStream` | Object | `{"name": "Client Advert to Engage", "id": "store_55_Class7101"}` |
| `valueStages[].parentValueStage` | Object | `{"name": "", "id": ""}` |
| `valueStages[].roles` | Array | `[{"id": "store_55_Class7256", "type": "Business_Role_Type", "name": "Business Division"}]` |
| `valueStages[].emotions` | Array | `[{"id": "store_55_Class7149", "relation_description": "", "emotion": "Excited"}]` |
| `valueStages[].perfMeasures` | Array | `[{"id": "store_55_Class7187", "uom": "Minutes", "kpiVal": "Time to create - 2000Minutes", "quality":...` |
| `valueStages[].entranceEvents` | Array | `[{"id": "store_960_Class1", "type": "Business_Event", "name": "Management Sign-off"}]` |
| `valueStages[].entranceCondition` | Array | `[{"id": "store_316_Class20006", "type": "Business_Condition", "name": "Campaign Budget Approved"}]` |
| `valueStages[].exitCondition` | Array | `[{"id": "store_960_Class2", "type": "Business_Condition", "name": "Advert Produced"}]` |
| `valueStages[].exitEvent` | Array | `[{"id": "store_316_Class20007", "type": "Business_Event", "name": "Advert Approved"}]` |
| `customerJourneys` | Array | `[{"id": "store_55_Class7374", "name": "Advert Interaction to Sign-up", "description": "How the clien...` |
| `customerJourneys[].id` | String | `"store_55_Class7374"` |
| `customerJourneys[].name` | String | `"Advert Interaction to Sign-up"` |
| `customerJourneys[].description` | String | `"How the clients move from an advert to a decision to buy"` |
| `customerJourneys[].link` | String | `"Advert Interaction to Sign-up"` |
| `customerJourneyPhases` | Array | `[{"id": "store_55_Class7428", "name": "Advert Interaction to Sign-up: 1. Awareness of Advert", "desc...` |
| `customerJourneyPhases[].id` | String | `"store_55_Class7428"` |
| `customerJourneyPhases[].name` | String | `"Advert Interaction to Sign-up: 1. Awareness of Advert"` |
| `customerJourneyPhases[].description` | String | `"Awareness of the products offered"` |
| `customerJourneyPhases[].link` | String | `"Awareness of Advert"` |
| `customerJourneyPhases[].customerJourneyId` | String | `"store_55_Class7374"` |
| `customerJourneyPhases[].cxScore` | Number | `0` |
| `customerJourneyPhases[].emotionScore` | Number | `5.5` |
| `customerJourneyPhases[].kpiScore` | Number | `7.5` |
| `busCaps` | Array | `[{"id": "store_55_Class13", "ref": "busCap20", "name": "Acquisition Management", "description": "Mon...` |
| `busCaps[].id` | String | `"store_55_Class13"` |
| `busCaps[].ref` | String | `"busCap20"` |
| `busCaps[].name` | String | `"Acquisition Management"` |
| `busCaps[].description` | String | `"Monitoring and assessment of potential acquisitions for the organisation"` |
| `busCaps[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class13&cl=en-gb" class = " context-menu-busCapGenMenu" ...` |
| `busCaps[].type` | Object | `{"list": "busCaps", "colour": "black", "label": "Business Capability", "defaultButton": "View", "isL...` |
| `busCaps[].goalIds` | Array | `[]` |
| `busCaps[].objectiveIds` | Array | `[]` |
| `busCaps[].physProcessIds` | Array | `["store_177_Class3"]` |
| `busCaps[].appProRoleIds` | Array | `["store_53_Class1050"]` |
| `busCaps[].applicationIds` | Array | `[]` |
| `busCaps[].customerJourneyIds` | Array | `[]` |
| `busCaps[].customerJourneyPhaseIds` | Array | `[]` |
| `busCaps[].valueStreamIds` | Array | `[]` |
| `busCaps[].valueStageIds` | Array | `[]` |
| `busCaps[].overallScores` | Object | `{"cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": "Undefined", "icon": "images/...` |
| `busCaps[].heatmapScores` | Array | `[{"id": "store_55_Class7099", "cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": ...` |
| `busCaps[].editorId` | String | `"busCapModal"` |
| `busCaps[].inScope` | Boolean | `false` |
| `bcmData` | Object | `{"l0BusCapName": "Energy", "l0BusCapId": "store_55_Class56", "l0BusCapLink": "<a href = \"?XML=repor...` |
| `busProcesses` | Array | `[{"id": "store_55_Class215", "index": 0, "name": "Action Hedging", "description": "Process to \"agre...` |
| `busProcesses[].id` | String | `"store_55_Class215"` |
| `busProcesses[].index` | Number | `0` |
| `busProcesses[].name` | String | `"Action Hedging"` |
| `busProcesses[].description` | String | `"Process to "agree" and action the most viable hedging opportunities identified"` |
| `busProcesses[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class215&cl=en-gb" class = " context-menu-busProcessGenM...` |
| `busProcesses[].type` | Object | `{"list": "busProcesses", "colour": "#5cb85c", "label": "Business Process", "defaultButton": "No Chan...` |
| `busProcesses[].busCapIds` | Array | `["store_55_Class119"]` |
| `busProcesses[].goalIds` | Array | `[]` |
| `busProcesses[].objectiveIds` | Array | `[]` |
| `busProcesses[].physProcessIds` | Array | `["store_55_Class5274"]` |
| `busProcesses[].appProRoleIds` | Array | `["store_55_Class2343"]` |
| `busProcesses[].applicationIds` | Array | `[]` |
| `busProcesses[].customerJourneyIds` | Array | `[]` |
| `busProcesses[].customerJourneyPhaseIds` | Array | `[]` |
| `busProcesses[].valueStreamIds` | Array | `[]` |
| `busProcesses[].valueStageIds` | Array | `[]` |
| `busProcesses[].overallScores` | Object | `{"cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": "Undefined", "icon": "images/...` |
| `busProcesses[].heatmapScores` | Array | `[{"id": "store_55_Class7099", "cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": ...` |
| `busProcesses[].editorId` | String | `"busProcessModal"` |
| `busProcesses[].inScope` | Boolean | `false` |
| `busProcesses[].planningActionIds` | Array | `["essential_baseline_v3.0.3_Class10000"]` |
| `busProcesses[].planningActions` | Null | `null` |
| `busProcesses[].planningAction` | Null | `null` |
| `busProcesses[].planningNotes` | String | `""` |
| `busProcesses[].hasPlan` | Boolean | `false` |
| `physProcesses` | Array | `[{"id": "store_90_Class40071", "type": {"list": "physProcesses", "colour": "#5cb85c", "label": "Phys...` |
| `physProcesses[].id` | String | `"store_90_Class40071"` |
| `physProcesses[].type` | Object | `{"list": "physProcesses", "colour": "#5cb85c", "label": "Physical Process", "defaultButton": "No Cha...` |
| `physProcesses[].busCapId` | String | `"store_55_Class119"` |
| `physProcesses[].busCapLink` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class119&cl=en-gb" class = " context-menu-busCapGenMenu"...` |
| `physProcesses[].busProcessId` | String | `"store_55_Class215"` |
| `physProcesses[].busProcessRef` | String | `"busProc2"` |
| `physProcesses[].busProcessDescription` | String | `"Process to "agree" and action the most viable hedging opportunities identified"` |
| `physProcesses[].orgName` | String | `"Accounting"` |
| `physProcesses[].orgDescription` | String | `"Manage the production of the accounts for the organisation"` |
| `physProcesses[].busProcessName` | String | `"Action Hedging"` |
| `physProcesses[].busProcessLink` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class215&cl=en-gb" class = " context-menu-busProcessGenM...` |
| `physProcesses[].orgId` | String | `"store_55_Class713"` |
| `physProcesses[].orgRef` | String | `"org15"` |
| `physProcesses[].orgLink` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class713&cl=en-gb" class = " context-menu-grpActorGenMen...` |
| `physProcesses[].appProRoleIds` | Array | `["store_55_Class2471"]` |
| `physProcesses[].applicationIds` | Array | `[]` |
| `physProcesses[].customerJourneyPhaseIds` | Array | `[]` |
| `physProcesses[].customerJourneyPhases` | Array | `[]` |
| `physProcesses[].planningActionIds` | Array | `["essential_baseline_v3.0.3_Class10000"]` |
| `physProcesses[].planningActions` | Array | `[]` |
| `physProcesses[].planningAction` | Null | `null` |
| `physProcesses[].editorId` | String | `"physProcModal"` |
| `physProcesses[].emotionScore` | Number | `0` |
| `physProcesses[].cxScore` | Number | `0` |
| `physProcesses[].kpiScore` | Number | `-1` |
| `physProcesses[].emotionStyleClass` | String | `"mediumHeatmapColour"` |
| `physProcesses[].emotionIcon` | String | `"fa-smile-o"` |
| `physProcesses[].cxStyleClass` | String | `"mediumHeatmapColour"` |
| `physProcesses[].kpiStyleClass` | String | `"noHeatmapColour"` |
| `organisations` | Array | `[{"id": "store_55_Class713", "index": 0, "type": {"list": "organisations", "colour": "#9467bd", "lab...` |
| `organisations[].id` | String | `"store_55_Class713"` |
| `organisations[].index` | Number | `0` |
| `organisations[].type` | Object | `{"list": "organisations", "colour": "#9467bd", "label": "Organisation", "defaultButton": "No Change"...` |
| `organisations[].name` | String | `"Accounting"` |
| `organisations[].description` | String | `"Manage the production of the accounts for the organisation"` |
| `organisations[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class713&cl=en-gb" class = " context-menu-grpActorGenMen...` |
| `organisations[].objectiveIds` | Array | `[]` |
| `organisations[].physProcessIds` | Array | `["store_90_Class40071"]` |
| `organisations[].appProRoleIds` | Array | `["store_55_Class2471"]` |
| `organisations[].applicationIds` | Array | `[]` |
| `organisations[].customerJourneyIds` | Array | `[]` |
| `organisations[].customerJourneyPhaseIds` | Array | `[]` |
| `organisations[].valueStreamIds` | Array | `[]` |
| `organisations[].valueStageIds` | Array | `[]` |
| `organisations[].overallScores` | Object | `{"cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": "Undefined", "icon": "images/...` |
| `organisations[].heatmapScores` | Array | `[{"id": "store_55_Class7099", "cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": ...` |
| `organisations[].editorId` | String | `"orgModal"` |
| `organisations[].inScope` | Boolean | `false` |
| `organisations[].planningActionIds` | Array | `["essential_baseline_v3.0.3_Class10000"]` |
| `organisations[].planningActions` | Null | `null` |
| `organisations[].planningAction` | Null | `null` |
| `organisations[].planningNotes` | String | `""` |
| `organisations[].hasPlan` | Boolean | `false` |
| `appServices` | Array | `[{"id": "store_55_Class898", "index": 0, "type": {"list": "appServices", "colour": "#4ab1eb", "label...` |
| `appServices[].id` | String | `"store_55_Class898"` |
| `appServices[].index` | Number | `0` |
| `appServices[].type` | Object | `{"list": "appServices", "colour": "#4ab1eb", "label": "Application Service", "defaultButton": "No Ch...` |
| `appServices[].name` | String | `"Architecture Design"` |
| `appServices[].description` | String | `"Design architectural plans"` |
| `appServices[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class898&cl=en-gb" class = " context-menu-appSvcGenMenu"...` |
| `appServices[].objectiveIds` | Array | `["store_53_Class138"]` |
| `appServices[].physProcessIds` | Array | `["store_55_Class5284"]` |
| `appServices[].appProRoleIds` | Array | `["store_316_Class40000"]` |
| `appServices[].customerJourneyIds` | Array | `[]` |
| `appServices[].customerJourneyPhaseIds` | Array | `[]` |
| `appServices[].valueStreamIds` | Array | `[]` |
| `appServices[].valueStageIds` | Array | `[]` |
| `appServices[].overallScores` | Object | `{"cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": "Undefined", "icon": "images/...` |
| `appServices[].heatmapScores` | Array | `[{"id": "store_55_Class7099", "cxScore": 0, "cxStyleClass": "noHeatmapColour", "cxStyle": {"label": ...` |
| `appServices[].techHealthScore` | Number | `31` |
| `appServices[].techHealthStyle` | String | `"neutralHeatmapColour"` |
| `appServices[].editorId` | String | `"appServiceModal"` |
| `appServices[].inScope` | Boolean | `false` |
| `appServices[].planningActionIds` | Array | `["essential_baseline_v3.0.3_Class10000"]` |
| `appServices[].planningActions` | Null | `null` |
| `appServices[].planningAction` | Null | `null` |
| `appServices[].planningNotes` | String | `""` |
| `appServices[].hasPlan` | Boolean | `false` |
| `applications` | Array | `[{"id": "store_55_Class1161", "type": {"list": "applications", "colour": "#337ab7", "label": "Applic...` |
| `applications[].id` | String | `"store_55_Class1161"` |
| `applications[].type` | Object | `{"list": "applications", "colour": "#337ab7", "label": "Application", "defaultButton": "No Change", ...` |
| `applications[].index` | Number | `0` |
| `applications[].name` | String | `"ADEXCell Energy Manager"` |
| `applications[].description` | String | `"Real time energy consumption monitoring of facilities"` |
| `applications[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class1161&cl=en-gb" class = " context-menu-appProviderGe...` |
| `applications[].objectiveIds` | Array | `["store_53_Class102"]` |
| `applications[].objectives` | Null | `null` |
| `applications[].appProRoleIds` | Array | `["store_55_Class2257"]` |
| `applications[].appProRoles` | Null | `null` |
| `applications[].physProcessIds` | Array | `["store_177_Class0"]` |
| `applications[].physProcesses` | Null | `null` |
| `applications[].organisationIds` | Array | `["store_55_Class679"]` |
| `applications[].organisations` | Null | `null` |
| `applications[].customerJourneyPhaseIds` | Array | `["store_55_Class7388"]` |
| `applications[].customerJourneyPhases` | Array | `[]` |
| `applications[].valueStreamIds` | Array | `["store_55_Class7099"]` |
| `applications[].valueStreams` | Null | `null` |
| `applications[].valueStageIds` | Array | `["store_55_Class7105"]` |
| `applications[].editorId` | String | `"appModal"` |
| `applications[].planningActionIds` | Array | `["essential_baseline_v3.0.3_Class10000"]` |
| `applications[].planningActions` | Null | `null` |
| `applications[].planningAction` | Null | `null` |
| `applications[].planningNotes` | String | `""` |
| `applications[].hasPlan` | Boolean | `false` |
| `applications[].techHealthScore` | Number | `61` |
| `applications[].techHealthStyle` | String | `"mediumHeatmapColour"` |
| `applications[].cxScore` | Number | `0` |
| `applications[].kpiScore` | Number | `0` |
| `appProviderRoles` | Array | `[{"id": "store_55_Class2257", "type": {"list": "appProviderRoles", "colour": "#4ab1eb", "label": "Ap...` |
| `appProviderRoles[].id` | String | `"store_55_Class2257"` |
| `appProviderRoles[].type` | Object | `{"list": "appProviderRoles", "colour": "#4ab1eb", "label": "Application Function", "defaultButton": ...` |
| `appProviderRoles[].appId` | String | `"store_55_Class1161"` |
| `appProviderRoles[].appRef` | String | `"app2"` |
| `appProviderRoles[].serviceName` | String | `"Benchmarking"` |
| `appProviderRoles[].serviceDescription` | String | `"Benchmarks energy performance against market"` |
| `appProviderRoles[].appName` | String | `"ADEXCell Energy Manager"` |
| `appProviderRoles[].appDescription` | String | `"Real time energy consumption monitoring of facilities"` |
| `appProviderRoles[].appLink` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class1161&cl=en-gb" class = " context-menu-appProviderGe...` |
| `appProviderRoles[].serviceId` | String | `"store_55_Class910"` |
| `appProviderRoles[].serviceRef` | String | `"appService82"` |
| `appProviderRoles[].serviceLink` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class910&cl=en-gb" class = " context-menu-appSvcGenMenu"...` |
| `appProviderRoles[].physProcessIds` | Array | `["store_55_Class5560"]` |
| `appProviderRoles[].customerJourneyPhaseIds` | Array | `["store_55_Class7388"]` |
| `appProviderRoles[].customerJourneyPhases` | Array | `[]` |
| `appProviderRoles[].editorId` | String | `"appProRoleModal"` |
| `appProviderRoles[].planningAction` | Null | `null` |
| `appProviderRoles[].cxScore` | Number | `0` |
| `appProviderRoles[].kpiScore` | Number | `0` |
| `productTypes` | Array | `[{"id": "store_55_Class7095", "name": "Consumer Solar", "description": "Household solar panel soluti...` |
| `productTypes[].id` | String | `"store_55_Class7095"` |
| `productTypes[].name` | String | `"Consumer Solar"` |
| `productTypes[].description` | String | `"Household solar panel solution"` |
| `businessRoleTypes` | Array | `[{"id": "store_55_Class7256", "name": "Business Division", "description": "Defines any internal orga...` |
| `businessRoleTypes[].id` | String | `"store_55_Class7256"` |
| `businessRoleTypes[].name` | String | `"Business Division"` |
| `businessRoleTypes[].description` | String | `"Defines any internal organisational department"` |
| `orgBusinessRole` | Array | `[{"id": "store_113_Class96", "name": " Data Subject Organisational Owner ", "description": ""}]` |
| `orgBusinessRole[].id` | String | `"store_113_Class96"` |
| `orgBusinessRole[].name` | String | `" Data Subject Organisational Owner "` |
| `orgBusinessRole[].description` | String | `""` |
| `individualBusinessRoles` | Array | `[{"id": "store_113_Class98", "name": " Data Subject Individual Owner ", "description": ""}]` |
| `individualBusinessRoles[].id` | String | `"store_113_Class98"` |
| `individualBusinessRoles[].name` | String | `" Data Subject Individual Owner "` |
| `individualBusinessRoles[].description` | String | `""` |
| `businessConditions` | Array | `[{"id": "store_960_Class2", "name": "Advert Produced", "description": ""}]` |
| `businessConditions[].id` | String | `"store_960_Class2"` |
| `businessConditions[].name` | String | `"Advert Produced"` |
| `businessConditions[].description` | String | `""` |
| `businessEvents` | Array | `[{"id": "store_316_Class20007", "name": "Advert Approved", "description": ""}]` |
| `businessEvents[].id` | String | `"store_316_Class20007"` |
| `businessEvents[].name` | String | `"Advert Approved"` |
| `businessEvents[].description` | String | `""` |
| `unitsofMeasure` | Array | `[{"id": "store_153_Class37", "name": "British Pounds", "colour": "", "enumeration_sequence_number": ...` |
| `unitsofMeasure[].id` | String | `"store_153_Class37"` |
| `unitsofMeasure[].name` | String | `"British Pounds"` |
| `unitsofMeasure[].colour` | String | `""` |
| `unitsofMeasure[].enumeration_sequence_number` | String | `""` |
| `unitsofMeasure[].class` | String | `""` |
| `unitsofMeasure[].textColour` | String | `""` |
| `unitsofMeasure[].enumeration_value` | String | `"GBP"` |
| `unitsofMeasure[].enumeration_score` | String | `""` |
| `unitsofMeasure[].description` | String | `""` |
| `customerEmotions` | Array | `[{"id": "store_55_Class7213", "name": "Bored", "colour": "", "enumeration_sequence_number": "1", "cl...` |
| `customerEmotions[].id` | String | `"store_55_Class7213"` |
| `customerEmotions[].name` | String | `"Bored"` |
| `customerEmotions[].colour` | String | `""` |
| `customerEmotions[].enumeration_sequence_number` | String | `"1"` |
| `customerEmotions[].class` | String | `"boredEmotion"` |
| `customerEmotions[].textColour` | String | `""` |
| `customerEmotions[].enumeration_value` | String | `"Bored"` |
| `customerEmotions[].enumeration_score` | String | `"8"` |
| `customerEmotions[].description` | String | `""` |
| `custEx` | Array | `[{"id": "store_55_Class7380", "name": "Average Experience", "label": "Average Experience", "descript...` |
| `custEx[].id` | String | `"store_55_Class7380"` |
| `custEx[].name` | String | `"Average Experience"` |
| `custEx[].label` | String | `"Average Experience"` |
| `custEx[].description` | String | `""` |
| `custEx[].colour` | String | `"#EDD827"` |
| `custEx[].class` | String | `"ragTextYellow"` |
| `custEx[].seqNo` | String | `"3"` |
| `custEx[].score` | String | `"0"` |
| `custEx[].synonyms` | Array | `[]` |
| `custEmotions` | Array | `[{"id": "store_55_Class7135", "name": "Excited", "label": "Excited", "description": "", "colour": ""...` |
| `custEmotions[].id` | String | `"store_55_Class7135"` |
| `custEmotions[].name` | String | `"Excited"` |
| `custEmotions[].label` | String | `"Excited"` |
| `custEmotions[].description` | String | `""` |
| `custEmotions[].colour` | String | `""` |
| `custEmotions[].class` | String | `"excitedEmotion"` |
| `custEmotions[].seqNo` | String | `"6"` |
| `custEmotions[].score` | String | `"8"` |
| `custEmotions[].synonyms` | Array | `[]` |
| `custServiceQual` | Array | `[{"id": "store_55_Class7567", "name": "Customer Service Empathy", "description": "To what extent ent...` |
| `custServiceQual[].id` | String | `"store_55_Class7567"` |
| `custServiceQual[].name` | String | `"Customer Service Empathy"` |
| `custServiceQual[].description` | String | `"To what extent enterprise actors care and give individual attention to customers"` |
| `custServiceQual[].securityClassifications` | Array | `[]` |
| `custServiceQualVal` | Array | `[{"id": "store_55_Class7513", "score": "5", "name": "Customer Service Empathy - Medium", "colour": "...` |
| `custServiceQualVal[].id` | String | `"store_55_Class7513"` |
| `custServiceQualVal[].score` | String | `"5"` |
| `custServiceQualVal[].name` | String | `"Customer Service Empathy - Medium"` |
| `custServiceQualVal[].colour` | String | `"#F59C3D"` |
| `custServiceQualVal[].value` | String | `"Medium"` |
| `custServiceQualVal[].textColour` | String | `""` |
| `custServiceQualVal[].classStyle` | String | `"backColourOrange"` |
| `custServiceQualVal[].description` | String | `""` |
| `custServiceQualVal[].securityClassifications` | Array | `[]` |
| `custJourney` | Array | `[{"id": "store_55_Class7370", "name": "Prospect to Client", "description": "Evolution from a prospec...` |
| `custJourney[].id` | String | `"store_55_Class7370"` |
| `custJourney[].name` | String | `"Prospect to Client"` |
| `custJourney[].description` | String | `"Evolution from a prospect to a full client - retail"` |
| `custJourney[].products` | Array | `[{"id": "store_55_Class7340", "name": "Consumer Solar"}]` |
| `custJourney[].securityClassifications` | Array | `[]` |
| `custJourneyPhase` | Array | `[{"id": "store_55_Class7382", "index": "1", "name": "Prospect to Client: 1. Awareness", "cjp_custome...` |
| `custJourneyPhase[].id` | String | `"store_55_Class7382"` |
| `custJourneyPhase[].index` | String | `"1"` |
| `custJourneyPhase[].name` | String | `"Prospect to Client: 1. Awareness"` |
| `custJourneyPhase[].cjp_customer_journey` | String | `"Prospect to Client"` |
| `custJourneyPhase[].cjp_experience_rating` | String | `"Average Experience"` |
| `custJourneyPhase[].description` | String | `"Awareness of the products available"` |
| `custJourneyPhase[].emotions` | Array | `[{"id": "store_55_Class7135", "name": "Excited", "description": ""}]` |
| `custJourneyPhase[].physProcs` | Array | `[{"id": "store_55_Class5534", "name": "Marketing performing Initiate Advertising"}]` |
| `custJourneyPhase[].bsqvs` | Array | `[{"id": "store_55_Class7513", "name": "Customer Service Empathy - Medium"}]` |
| `custJourneyPhase[].securityClassifications` | Array | `[]` |
| `busServiceQuals` | Array | `[{"id": "store_113_Class10012", "name": "Agility", "description": "Time taken to meet new business n...` |
| `busServiceQuals[].id` | String | `"store_113_Class10012"` |
| `busServiceQuals[].name` | String | `"Agility"` |
| `busServiceQuals[].description` | String | `"Time taken to meet new business needs"` |

### core_api_el_strategic_driver_goal_objectives.xsl
- **Path**: `enterprise/api/core_api_el_strategic_driver_goal_objectives.xsl`
- **DSA Data Label**: `strategyData`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `drivers` | Array | `[{"id": "store_90_Class130001", "type": "Business_Driver", "name": "Customer Retention", "descriptio...` |
| `drivers[].id` | String | `"store_90_Class130001"` |
| `drivers[].type` | String | `"Business_Driver"` |
| `drivers[].name` | String | `"Customer Retention"` |
| `drivers[].description` | String | `""` |
| `drivers[].goals` | Array | `[{"id": "store_53_Class66", "name": "Improve Customer Satisfaction", "description": "", "type": "Bus...` |
| `drivers[].motivatingObjectives` | Array | `[]` |
| `objectives` | Array | `[{"id": "store_53_Class90", "name": "Aligning our Employees to our Strategic Goals", "description": ...` |
| `objectives[].id` | String | `"store_53_Class90"` |
| `objectives[].name` | String | `"Aligning our Employees to our Strategic Goals"` |
| `objectives[].description` | String | `"Ensure employees are clear and working to the strategic goals"` |
| `objectives[].type` | String | `"Business_Objective"` |
| `objectives[].targetDate` | String | `"2020-08-31"` |
| `objectives[].boDriverMotivated` | Array | `["store_90_Class130000"]` |
| `objectives[].supportingCapabilities` | Array | `["store_55_Class87"]` |

### core_api_el_supplier_impact.xsl
- **Path**: `enterprise/api/core_api_el_supplier_impact.xsl`
- **DSA Data Label**: `suppImpApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `suppliers` | Array | `[{"id": "essential_prj_AA_v1_1_graphArchTest_Instance_20", "repoId": "essential_prj_AA_v1.1_graphArc...` |
| `suppliers[].id` | String | `"essential_prj_AA_v1_1_graphArchTest_Instance_20"` |
| `suppliers[].repoId` | String | `"essential_prj_AA_v1.1_graphArchTest_Instance_20"` |
| `suppliers[].name` | String | `"Oracle Corporation"` |
| `suppliers[].supplier_url` | String | `"http://www.oracle.com"` |
| `suppliers[].description` | String | `"Oracle Corporation"` |
| `suppliers[].supplierRelStatus` | String | `""` |
| `suppliers[].technologies` | Array | `[]` |
| `suppliers[].apps` | Array | `[]` |
| `suppliers[].visId` | Array | `[""]` |
| `suppliers[].licences` | Array | `[]` |
| `suppliers[].contracts` | Array | `[]` |
| `suppliers[].techlicences` | Array | `[]` |
| `suppliers[].className` | String | `"Supplier"` |
| `suppliers[].securityClassifications` | Array | `[]` |
| `capabilities` | Array | `[{"id": "store_55_Class103", "repoId": "store_55_Class103", "name": "Risk Management", "className": ...` |
| `capabilities[].id` | String | `"store_55_Class103"` |
| `capabilities[].repoId` | String | `"store_55_Class103"` |
| `capabilities[].name` | String | `"Risk Management"` |
| `capabilities[].className` | String | `"Business_Capability"` |
| `capabilities[].subCaps` | Array | `[{"id": "store_55_Class105", "className": "Business_Capability", "repoId": "store_55_Class105", "nam...` |
| `capabilities[].securityClassifications` | Array | `[]` |
| `contracts` | Array | `[{"id": "store_283_Class2244", "repoId": "store_283_Class2244", "contract_ref": "CTR1 - Checkpoint -...` |
| `contracts[].id` | String | `"store_283_Class2244"` |
| `contracts[].repoId` | String | `"store_283_Class2244"` |
| `contracts[].contract_ref` | String | `"CTR1 - Checkpoint - Statement of Work - 2020-02-28"` |
| `contracts[].contract_type` | String | `"Statement of Work"` |
| `contracts[].contract_customer` | String | `"Distribution"` |
| `contracts[].name` | String | `"CTR1 - Checkpoint - Statement of Work - 2020-02-28"` |
| `contracts[].owner` | String | `"Distribution"` |
| `contracts[].signature_date` | String | `"2020-02-28"` |
| `contracts[].description` | String | `"Blah"` |
| `contracts[].supplier_name` | String | `"Checkpoint"` |
| `contracts[].contract_end_date` | String | `""` |
| `contracts[].supplierId` | String | `"store_55_Class3001"` |
| `contracts[].relStatusId` | String | `""` |
| `contracts[].startDate` | String | `"2020-02-28"` |
| `contracts[].renewalDate` | Null | `null` |
| `contracts[].renewalNoticeDays` | Number | `0` |
| `contracts[].renewalReviewDays` | Number | `0` |
| `contracts[].renewalModel` | String | `"Auto-renew"` |
| `contracts[].type` | String | `"Statement of Work"` |
| `contracts[].docLinks` | Array | `[{"label": "Contract Link for CTR1 - Checkpoint - Statement of Work - 2020-02-28", "url": "www.enter...` |
| `contracts[].contractComps` | Array | `[{"id": "store_283_Class2250", "repoid": "store_283_Class2250", "contractId": "store_283_Class2244",...` |
| `contracts[].contractCompIds` | Array | `["store_283_Class2250"]` |
| `contracts[].busProcIds` | Array | `["store_53_Class1062"]` |
| `contracts[].appIds` | Array | `["store_53_Class1062"]` |
| `contracts[].techProdIds` | Array | `["store_53_Class1062"]` |
| `contracts[].securityClassifications` | Array | `[]` |
| `contract_components` | Array | `[{"id": "store_283_Class2250", "debug": "essential_baseline_v505_Class16", "ccr_end_date_ISO8601": "...` |
| `contract_components[].id` | String | `"store_283_Class2250"` |
| `contract_components[].debug` | String | `"essential_baseline_v505_Class16"` |
| `contract_components[].ccr_end_date_ISO8601` | String | `"2021-02-28"` |
| `contract_components[].ccr_total_annual_cost` | String | `"10000.0"` |
| `contract_components[].ccr_renewal_notice_days` | String | `"60"` |
| `contract_components[].name` | String | `""` |
| `contract_components[].ccr_contracted_units` | String | `"1"` |
| `contract_components[].ccr_contract_unit_of_measure` | String | `"Enteprise"` |
| `contract_components[].ccr_renewal_model` | String | `"Auto-renew"` |
| `contract_components[].contract_component_from_contract` | String | `"CTR1 - Checkpoint - Statement of Work - 2020-02-28"` |
| `contract_components[].ccr_start_date_ISO8601` | String | `""` |
| `contract_components[].ccr_currency` | String | `"British Pound"` |
| `contract_components[].busElements` | Array | `[]` |
| `contract_components[].appElements` | Array | `[]` |
| `contract_components[].techElements` | Array | `[{"id": "store_53_Class1062", "name": "Endpoint Security"}]` |
| `contract_components[].securityClassifications` | Array | `[]` |
| `enums` | Array | `[{"id": "store_90_Class40030", "type": "Contract_Renewal_Model", "styleClass": "", "name": "Auto-ren...` |
| `enums[].id` | String | `"store_90_Class40030"` |
| `enums[].type` | String | `"Contract_Renewal_Model"` |
| `enums[].styleClass` | String | `""` |
| `enums[].name` | String | `"Auto-renew"` |
| `enums[].label` | String | `"Auto-renew"` |
| `enums[].textColour` | String | `""` |
| `enums[].backgroundColour` | String | `""` |
| `enums[].enumeration_score` | String | `""` |
| `enums[].description` | String | `""` |
| `enums[].sequence_no` | String | `"1"` |
| `plans` | Array | `[{"id": "store_283_Class1890", "repoId": "store_283_Class1890", "name": "Business Process Automation...` |
| `plans[].id` | String | `"store_283_Class1890"` |
| `plans[].repoId` | String | `"store_283_Class1890"` |
| `plans[].name` | String | `"Business Process Automation"` |
| `plans[].fromDate` | String | `"2022-01-01"` |
| `plans[].endDate` | String | `"2030-06-01"` |
| `plans[].impacts` | Array | `[{"id": "store_283_Class1900", "impacted_element": "store_55_Class239", "repoId": "store_283_Class19...` |
| `plans[].objectives` | Array | `[{"id": "store_53_Class118", "repoId": "store_53_Class118", "name": "Provide an Efficient Operationa...` |

### core_api_el_support_perf_measures.xsl
- **Path**: `enterprise/api/core_api_el_support_perf_measures.xsl`
- **DSA Data Label**: `support-kpi-data`
- **Parameters**: None
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `projects` | Array | `[]` |
| `suppliers` | Array | `[{"id": "essential_prj_AA_v1_4_Instance_98", "name": "Microsoft", "instance": "Microsoft", "security...` |
| `suppliers[].id` | String | `"essential_prj_AA_v1_4_Instance_98"` |
| `suppliers[].name` | String | `"Microsoft"` |
| `suppliers[].instance` | String | `"Microsoft"` |
| `suppliers[].securityClassifications` | Array | `[]` |
| `suppliers[].perfMeasures` | Array | `[{"categoryid": "", "id": "store_911_Class10020", "date": "", "createdDate": "2023-12-08T12:46:56.24...` |
| `perfCategory` | Array | `[{"id": "store_911_Class10018", "name": "ESG Ratings", "classes": ["Supplier"], "qualities": ["store...` |
| `perfCategory[].id` | String | `"store_911_Class10018"` |
| `perfCategory[].name` | String | `"ESG Ratings"` |
| `perfCategory[].classes` | Array | `["Supplier"]` |
| `perfCategory[].qualities` | Array | `["store_736_Class8"]` |
| `serviceQualities` | Array | `[{"id": "store_736_Class8", "shortName": "ESG Rating", "name": "ESG Rating", "sqvs": [{"id": "store_...` |
| `serviceQualities[].id` | String | `"store_736_Class8"` |
| `serviceQualities[].shortName` | String | `"ESG Rating"` |
| `serviceQualities[].name` | String | `"ESG Rating"` |
| `serviceQualities[].sqvs` | Array | `[{"id": "store_736_Class108", "name": "ESG Rating - Good", "score": "1", "value": "Good", "elementCo...` |

### core_api_issues.xsl
- **Path**: `enterprise/api/core_api_issues.xsl`
- **DSA Data Label**: `coreIssue`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `issues` | Array | `N/A` |
| `issue_categories` | Array | `N/A` |
| `requirement_status_list` | Array | `N/A` |
| `sr_lifecycle_status_list` | Array | `N/A` |
| `version` | String | `N/A` |
| `id` | String | `N/A` |
| `name` | Unknown | `N/A` |
| `description` | Unknown | `N/A` |
| `enumeration_value` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `sequence_number` | String | `N/A` |
| `synonyms` | Array | `N/A` |
| `sr_required_from_date_ISO8601` | String | `N/A` |
| `sr_required_by_date_ISO8601` | String | `N/A` |
| `sr_root_causes` | Array | `N/A` |
| `short_name` | Unknown | `N/A` |
| `className` | String | `N/A` |
| `sr_type` | String | `N/A` |
| `sr_geo_scope` | Array | `N/A` |
| `sr_lifecycle_status` | String | `N/A` |
| `sr_life_id` | Array | `N/A` |
| `system_last_modified_datetime_iso8601` | String | `N/A` |
| `valueClass` | String | `N/A` |
| `issue_source` | String | `N/A` |
| `requirement_status_id` | String | `N/A` |
| `orgScopes` | Array | `N/A` |
| `issue_priority` | String | `N/A` |
| `external_reference_links` | Array | `N/A` |
| `external_reference_url` | Unknown | `N/A` |
| `issue_impacts` | Array | `N/A` |
| `visId` | Array | `N/A` |
| `sA2R` | Array | `N/A` |
| `shortname` | String | `N/A` |
| `colour` | String | `N/A` |
| `colourText` | String | `N/A` |

## Information

### core_api_data_object_data.xsl
- **Path**: `information/api/core_api_data_object_data.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `busProcs` | Array | `N/A` |
| `physProcs` | Array | `N/A` |
| `appProToProcess` | Array | `N/A` |
| `regulations` | Array | `N/A` |
| `version` | String | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |
| `elements` | Array | `N/A` |
| `physProcesses` | Array | `N/A` |
| `actor` | String | `N/A` |
| `actorid` | String | `N/A` |
| `usages` | Array | `N/A` |
| `appInfoRep` | String | `N/A` |
| `app_info_rep` | String | `N/A` |
| `processes` | Array | `N/A` |
| `physicalProcesses` | Array | `N/A` |

### core_api_information_data_mart.xsl
- **Path**: `information/api/core_api_information_data_mart.xsl`
- **DSA Data Label**: `infoMartAPI`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `data_subjects` | Array | `[{"id": "store_113_Class13", "indivOwner": "", "name": "Customer", "description": "Someone who buys ...` |
| `data_subjects[].id` | String | `"store_113_Class13"` |
| `data_subjects[].indivOwner` | String | `""` |
| `data_subjects[].name` | String | `"Customer"` |
| `data_subjects[].description` | String | `"Someone who buys services from the organisation"` |
| `data_subjects[].synonyms` | Array | `[]` |
| `data_subjects[].dataObjects` | Array | `[{"id": "store_113_Class19", "name": "Customer Address", "securityClassifications": []}]` |
| `data_subjects[].category` | String | `"Master Data"` |
| `data_subjects[].orgOwner` | String | `""` |
| `data_subjects[].stakeholders` | Array | `[{"type": "Group_Actor", "actorName": "Sales", "roleName": " Data Subject Organisational Owner ", "a...` |
| `data_subjects[].externalDocs` | Array | `[]` |
| `data_subjects[].securityClassifications` | Array | `[]` |
| `data_objects` | Array | `[{"id": "store_113_Class19", "name": "Customer Address", "description": "The address of the customer...` |
| `data_objects[].id` | String | `"store_113_Class19"` |
| `data_objects[].name` | String | `"Customer Address"` |
| `data_objects[].description` | String | `"The address of the customer"` |
| `data_objects[].debug` | String | `""` |
| `data_objects[].synonyms` | Array | `[]` |
| `data_objects[].category` | String | `"Master Data"` |
| `data_objects[].isAbstract` | String | `"false"` |
| `data_objects[].orgOwner` | String | `""` |
| `data_objects[].indivOwner` | String | `""` |
| `data_objects[].dataAttributes` | Array | `[{"name": "Customer Address - Street Number", "description": "", "id": "store_121_Class10000", "type...` |
| `data_objects[].requiredByApps` | Array | `[]` |
| `data_objects[].systemOfRecord` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager"}]` |
| `data_objects[].infoRepsToApps` | Array | `[{"id": "store_174_Class10231", "persisted": "false", "datarepsimplemented": [], "appid": "store_55_...` |
| `data_objects[].infoReps` | Array | `[{"id": "store_265_Class168", "name": "Entronix Meter Reading Database"}]` |
| `data_objects[].infoViews` | Array | `[{"id": "store_113_Class79", "name": "Meter Reading"}]` |
| `data_objects[].dataReps` | Array | `[{"id": "store_265_Class166", "name": "Entronix Meter Reading Database - Entronix Meter Reading Cust...` |
| `data_objects[].stakeholders` | Array | `[{"type": "Individual_Actor", "actorName": "Martin Thompson", "roleName": "Data Steward", "actorId":...` |
| `data_objects[].classifications` | Array | `[]` |
| `data_objects[].tables` | Array | `[{"name": "", "dataRep": "Entronix Meter Reading Database - Entronix Meter Reading Customer Table", ...` |
| `data_objects[].externalDocs` | Array | `[]` |
| `data_objects[].parents` | Array | `[{"name": "Customer", "securityClassifications": []}]` |
| `data_objects[].securityClassifications` | Array | `[]` |
| `data_representation` | Array | `[{"id": "store_121_Class20000", "name": "Customer Contract Table", "description": "", "synonyms": []...` |
| `data_representation[].id` | String | `"store_121_Class20000"` |
| `data_representation[].name` | String | `"Customer Contract Table"` |
| `data_representation[].description` | String | `""` |
| `data_representation[].synonyms` | Array | `[]` |
| `data_representation[].tables` | Array | `[{"name": "", "id": "store_121_Class20003", "create": "Yes", "read": "Unknown", "update": "Unknown",...` |
| `data_representation[].apps` | Array | `[{"name": "", "id": "store_55_Class1161", "create": "Unknown", "read": "Unknown", "update": "Unknown...` |
| `data_representation[].technicalName` | String | `"Customer Contract Table"` |
| `information_representation` | Array | `[{"id": "store_121_Class20001", "representation_label": "", "ea_reference": "", "name": "Customer Da...` |
| `information_representation[].id` | String | `"store_121_Class20001"` |
| `information_representation[].representation_label` | String | `""` |
| `information_representation[].ea_reference` | String | `""` |
| `information_representation[].name` | String | `"Customer Database"` |
| `information_representation[].short_name` | String | `""` |
| `information_representation[].description` | String | `""` |
| `information_representation[].ea_notes` | String | `""` |
| `information_representation[].synonyms` | Array | `[]` |
| `information_representation[].valueClass` | String | `"Information_Representation"` |
| `information_representation[].inforep_category` | Array | `[]` |
| `information_representation[].il_managed_by_services` | Array | `[]` |
| `information_representation[].visId` | Array | `["store_90_Class44"]` |
| `information_representation[].sA2R` | Array | `[]` |
| `information_representation[].infoViews` | Array | `[]` |
| `information_representation[].dataReps` | Array | `[{"id": "store_121_Class20000"}]` |
| `information_representation[].securityClassifications` | Array | `[]` |
| `information_views` | Array | `[{"id": "store_113_Class79", "className": "Information_View", "name": "Meter Reading", "owner": [], ...` |
| `information_views[].id` | String | `"store_113_Class79"` |
| `information_views[].className` | String | `"Information_View"` |
| `information_views[].name` | String | `"Meter Reading"` |
| `information_views[].owner` | Array | `[]` |
| `information_views[].dataObjects` | Array | `[{"id": "store_113_Class19"}]` |
| `information_views[].synonyms` | Array | `[]` |
| `information_views[].securityClassifications` | Array | `[]` |
| `information_concepts` | Array | `[{"id": "store_113_Class89", "className": "Information_Concept", "name": "Production Order", "descri...` |
| `information_concepts[].id` | String | `"store_113_Class89"` |
| `information_concepts[].className` | String | `"Information_Concept"` |
| `information_concepts[].name` | String | `"Production Order"` |
| `information_concepts[].description` | String | `"The request for increased production"` |
| `information_concepts[].sequence_number` | String | `"4"` |
| `information_concepts[].infoViews` | Array | `[{"id": "store_174_Class10360", "className": "Information_View", "name": "Inventory Information", "o...` |
| `app_infoRep_Pairs` | Array | `[{"id": "store_121_Class20002", "persisted": "true", "infoRep": {"name": "Customer Database", "id": ...` |
| `app_infoRep_Pairs[].id` | String | `"store_121_Class20002"` |
| `app_infoRep_Pairs[].persisted` | String | `"true"` |
| `app_infoRep_Pairs[].infoRep` | Object | `{"name": "Customer Database", "id": "store_121_Class20001"}` |
| `app_infoRep_Pairs[].appId` | String | `"store_55_Class1161"` |
| `info_domains` | Array | `[{"id": "store_858_Class46", "name": "Energy", "description": "", "sequence_number": "", "infoConcep...` |
| `info_domains[].id` | String | `"store_858_Class46"` |
| `info_domains[].name` | String | `"Energy"` |
| `info_domains[].description` | String | `""` |
| `info_domains[].sequence_number` | String | `""` |
| `info_domains[].infoConcepts` | Array | `[{"id": "store_90_Class130031"}]` |
| `info_domains[].synonyms` | Array | `[]` |
| `info_domains[].securityClassifications` | Array | `[]` |
| `info_rep_categories` | Array | `[{"id": "essential_baseline_v6_Class6", "name": "Database", "enumeration_value": "Database", "descri...` |
| `info_rep_categories[].id` | String | `"essential_baseline_v6_Class6"` |
| `info_rep_categories[].name` | String | `"Database"` |
| `info_rep_categories[].enumeration_value` | String | `"Database"` |
| `info_rep_categories[].description` | String | `""` |
| `info_rep_categories[].synonyms` | Array | `[]` |
| `info_rep_categories[].securityClassifications` | Array | `[]` |
| `version` | String | `"615"` |

## Integration


### core_api_import_application_capabilities.xsl
- **Path**: `integration/api/core_api_import_application_capabilities.xsl`
- **DSA Data Label**: `ImpAppCapApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_capabilities` | Array | `[{"id": "store_55_Class762", "name": "Account Planning", "appCapCategory": "", "ReferenceModelLayer"...` |
| `application_capabilities[].id` | String | `"store_55_Class762"` |
| `application_capabilities[].name` | String | `"Account Planning"` |
| `application_capabilities[].appCapCategory` | String | `""` |
| `application_capabilities[].ReferenceModelLayer` | String | `""` |
| `application_capabilities[].description` | String | `"Sales account planning software"` |
| `application_capabilities[].businessDomain` | Array | `[{"id": "store_55_Class20", "name": "Sales and Marketing"}]` |
| `application_capabilities[].ParentAppCapability` | Array | `[{"id": "store_55_Class759", "name": "Sales Management"}]` |
| `application_capabilities[].SupportedBusCapability` | Array | `[{"id": "store_55_Class197", "name": "Strategic Relationship Management"}]` |
| `application_capabilities[].securityClassifications` | Array | `[]` |
| `version` | String | `"615"` |

### core_api_import_application_capabilities_to_services.xsl
- **Path**: `integration/api/core_api_import_application_capabilities_to_services.xsl`
- **DSA Data Label**: `ImpAppCapSvcApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_capabilities_services` | Array | `[{"id": "store_55_Class762", "name": "Account Planning", "services": [{"id": "store_55_Class1094", "...` |
| `application_capabilities_services[].id` | String | `"store_55_Class762"` |
| `application_capabilities_services[].name` | String | `"Account Planning"` |
| `application_capabilities_services[].services` | Array | `[{"id": "store_55_Class1094", "sequence_number": "", "name": "Sales Reporting Services"}]` |
| `application_capabilities_services[].securityClassifications` | Array | `[]` |
| `version` | String | `"620"` |

### core_api_import_application_dependency.xsl
- **Path**: `integration/api/core_api_import_application_dependency.xsl`
- **DSA Data Label**: `ImpAppDepApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_dependencies` | Array | `[{"target": "", "source": "Creds", "sourceType": "Composite_Application_Provider", "targetType": "",...` |
| `application_dependencies[].target` | String | `""` |
| `application_dependencies[].source` | String | `"Creds"` |
| `application_dependencies[].sourceType` | String | `"Composite_Application_Provider"` |
| `application_dependencies[].targetType` | String | `""` |
| `application_dependencies[].info` | Array | `[]` |
| `application_dependencies[].frequency` | Array | `[{"name": "Timeliness - daily"}]` |
| `application_dependencies[].acquisition` | String | `"Manual Data Entry"` |
| `application_dependencies[].securityClassifications` | Array | `[]` |

### core_api_import_application_services.xsl
- **Path**: `integration/api/core_api_import_application_services.xsl`
- **DSA Data Label**: `ImpAppSvcApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_services` | Array | `[{"id": "store_55_Class898", "name": "Architecture Design", "description": "Design architectural pla...` |
| `application_services[].id` | String | `"store_55_Class898"` |
| `application_services[].name` | String | `"Architecture Design"` |
| `application_services[].description` | String | `"Design architectural plans"` |
| `application_services[].aprs` | Array | `["store_55_Class2489"]` |
| `application_services[].securityClassifications` | Array | `[]` |
| `version` | String | `"620"` |

### core_api_import_application_to_technology.xsl
- **Path**: `integration/api/core_api_import_application_to_technology.xsl`
- **DSA Data Label**: `ImpApptoTechApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `application_technology_architecture` | Array | `[{"id": "store_55_Class1161", "application": "ADEXCell Energy Manager", "supportingTech": [{"fromTec...` |
| `application_technology_architecture[].id` | String | `"store_55_Class1161"` |
| `application_technology_architecture[].application` | String | `"ADEXCell Energy Manager"` |
| `application_technology_architecture[].supportingTech` | Array | `[{"fromTechProduct": "Okta Identity Cloud", "fromTechComponent": "Single Sign-On Solution", "toTechP...` |
| `application_technology_architecture[].allTechProds` | Array | `[{"tpr": "store_53_Class1165", "productId": "store_53_Class1163", "componentId": "store_55_Class2712...` |
| `application_technology_architecture[].securityClassifications` | Array | `[]` |
| `version` | String | `"615"` |

### core_api_import_applications to_services.xsl
- **Path**: `integration/api/core_api_import_applications to_services.xsl`
- **DSA Data Label**: `ImpApp2SvcApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applications_to_services` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager", "services": [{"id": "store_55_Class...` |
| `applications_to_services[].id` | String | `"store_55_Class1161"` |
| `applications_to_services[].name` | String | `"ADEXCell Energy Manager"` |
| `applications_to_services[].services` | Array | `[{"id": "store_55_Class1046", "name": "Load Control", "securityClassifications": []}]` |
| `applications_to_services[].securityClassifications` | Array | `[]` |
| `version` | String | `"616"` |

### core_api_import_applications.xsl
- **Path**: `integration/api/core_api_import_applications.xsl`
- **DSA Data Label**: `ImpAppsApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applications` | Array | `[{"id": "store_55_Class1161", "lifecycle_name": "Prototype", "lifecycle": "Prototype", "name": "ADEX...` |
| `applications[].id` | String | `"store_55_Class1161"` |
| `applications[].lifecycle_name` | String | `"Prototype"` |
| `applications[].lifecycle` | String | `"Prototype"` |
| `applications[].name` | String | `"ADEXCell Energy Manager"` |
| `applications[].codebase_name` | String | `"Bespoke"` |
| `applications[].delivery` | String | `"Private Cloud Service"` |
| `applications[].delivery_name` | String | `"Private Cloud Service"` |
| `applications[].description` | String | `"Real time energy consumption monitoring of facilities"` |
| `applications[].codebase` | String | `"Bespoke"` |
| `applications[].class` | String | `"Composite_Application_Provider"` |
| `applications[].dispositionId` | String | `"store_183_Class27"` |
| `applications[].visId` | Array | `[""]` |
| `applications[].securityClassifications` | Array | `[]` |

### core_api_import_applications_to_orgs.xsl
- **Path**: `integration/api/core_api_import_applications_to_orgs.xsl`
- **DSA Data Label**: `ImpAppOrgApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applications_to_orgs` | Array | `[{"id": "store_55_Class1161", "name": "ADEXCell Energy Manager", "owner": [], "actors": [{"id": "sto...` |
| `applications_to_orgs[].id` | String | `"store_55_Class1161"` |
| `applications_to_orgs[].name` | String | `"ADEXCell Energy Manager"` |
| `applications_to_orgs[].owner` | Array | `[]` |
| `applications_to_orgs[].actors` | Array | `[{"id": "store_55_Class679", "name": "Marketing", "securityClassifications": []}]` |
| `applications_to_orgs[].securityClassifications` | Array | `[]` |

### core_api_import_applications_to_services.xsl
- **Path**: `integration/api/core_api_import_applications_to_services.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `applications_to_services` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `services` | Array | `N/A` |
| `apr` | String | `N/A` |

### core_api_import_apps_to_servers.xsl
- **Path**: `integration/api/core_api_import_apps_to_servers.xsl`
- **DSA Data Label**: `ImpApp2ServerApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `app2server` | Array | `[{"id": "store_55_Class1168", "server": "ED1UAT", "name": "Microsoft Project Server", "deployment": ...` |
| `app2server[].id` | String | `"store_55_Class1168"` |
| `app2server[].server` | String | `"ED1UAT"` |
| `app2server[].name` | String | `"Microsoft Project Server"` |
| `app2server[].deployment` | Array | `[{"id": "essential_prj_EE_v0_1_Instance_20013", "name": "Test", "securityClassifications": []}]` |
| `app2server[].securityClassifications` | Array | `[]` |

### core_api_import_business_capabilities.xsl
- **Path**: `integration/api/core_api_import_business_capabilities.xsl`
- **DSA Data Label**: `ImpBusCapApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `businessCapabilities` | Array | `[{"id": "store_55_Class13", "businessDomain": "Management Services", "name": "Acquisition Management...` |
| `businessCapabilities[].id` | String | `"store_55_Class13"` |
| `businessCapabilities[].businessDomain` | String | `"Management Services"` |
| `businessCapabilities[].name` | String | `"Acquisition Management"` |
| `businessCapabilities[].description` | String | `"Monitoring and assessment of potential acquisitions for the organisation"` |
| `businessCapabilities[].infoConcepts` | Array | `[]` |
| `businessCapabilities[].link` | String | `"<a href = "?XML=reportXML.xml&PMA=store_55_Class13&cl=en-gb" class = " context-menu-busCapGenMenu" ...` |
| `businessCapabilities[].domainIds` | Array | `["store_55_Class11"]` |
| `businessCapabilities[].geoIds` | Array | `[]` |
| `businessCapabilities[].visId` | Array | `[""]` |
| `businessCapabilities[].prodConIds` | Array | `[]` |
| `businessCapabilities[].parentBusinessCapability` | Array | `[{"id": "store_55_Class9", "name": "Corporate Support"}]` |
| `businessCapabilities[].positioninParent` | String | `""` |
| `businessCapabilities[].sequenceNumber` | String | `"2"` |
| `businessCapabilities[].rootCapability` | String | `""` |
| `businessCapabilities[].businessDomains` | Array | `[{"id": "store_55_Class11", "name": "Management Services"}]` |
| `businessCapabilities[].children` | Array | `[]` |
| `businessCapabilities[].documents` | Array | `[]` |
| `businessCapabilities[].level` | String | `"0"` |
| `businessCapabilities[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_business_domains.xsl
- **Path**: `integration/api/core_api_import_business_domains.xsl`
- **DSA Data Label**: `ImpBusDomApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `businessDomains` | Array | `[{"id": "store_55_Class44", "name": "Digital Services", "description": "Failure Prediction, performa...` |
| `businessDomains[].id` | String | `"store_55_Class44"` |
| `businessDomains[].name` | String | `"Digital Services"` |
| `businessDomains[].description` | String | `"Failure Prediction, performance monitoring. xyzzy"` |
| `businessDomains[].visId` | Array | `[""]` |
| `businessDomains[].parentDomain` | Array | `[]` |
| `businessDomains[].subDomain` | Array | `[]` |
| `businessDomains[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_business_families.xsl
- **Path**: `integration/api/core_api_import_business_families.xsl`
- **DSA Data Label**: `ImpBusPrecFamApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `businessProcessFamilies` | Array | `[{"id": "store_219_Class164", "name": "Collect Meter Data", "description": "", "visId": ["store_90_C...` |
| `businessProcessFamilies[].id` | String | `"store_219_Class164"` |
| `businessProcessFamilies[].name` | String | `"Collect Meter Data"` |
| `businessProcessFamilies[].description` | String | `""` |
| `businessProcessFamilies[].visId` | Array | `["store_90_Class44"]` |
| `businessProcessFamilies[].containedProcesses` | Array | `[{"id": "store_219_Class159", "name": "Collect Meter Data - AsiaPac", "securityClassifications": []}...` |
| `businessProcessFamilies[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_business_process_to_app_services.xsl
- **Path**: `integration/api/core_api_import_business_process_to_app_services.xsl`
- **DSA Data Label**: `ImpBusProcAppSvcApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `process_to_service` | Array | `[{"id": "store_55_Class215", "name": "Action Hedging", "services": [{"id": "store_55_Class1058", "na...` |
| `process_to_service[].id` | String | `"store_55_Class215"` |
| `process_to_service[].name` | String | `"Action Hedging"` |
| `process_to_service[].services` | Array | `[{"id": "store_55_Class1058", "name": "Office Productivity Tools", "criticality": "", "securityClass...` |
| `process_to_service[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_business_processes.xsl
- **Path**: `integration/api/core_api_import_business_processes.xsl`
- **DSA Data Label**: `ImpBusProcApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `meta` | Array | `[{"classes": ["Individual_Actor"], "menuId": "indActorGenMenu"}]` |
| `meta[].classes` | Array | `["Individual_Actor"]` |
| `meta[].menuId` | String | `"indActorGenMenu"` |
| `businessProcesses` | Array | `[{"id": "store_55_Class215", "business_process_id": "", "name": "Action Hedging", "standardisation":...` |
| `businessProcesses[].id` | String | `"store_55_Class215"` |
| `businessProcesses[].business_process_id` | String | `""` |
| `businessProcesses[].name` | String | `"Action Hedging"` |
| `businessProcesses[].standardisation` | String | `"Standard"` |
| `businessProcesses[].description` | String | `"Process to "agree" and action the most viable hedging opportunities identified"` |
| `businessProcesses[].bus_process_type_creates_information` | Array | `[]` |
| `businessProcesses[].bus_process_type_reads_information` | Array | `[]` |
| `businessProcesses[].bus_process_type_updates_information` | Array | `[]` |
| `businessProcesses[].bus_process_type_deletes_information` | Array | `[]` |
| `businessProcesses[].busproctype_relation` | Array | `[{"id": "store_90_Class130012", "create": "Unknown", "read": "Yes", "update": "Unknown", "delete": "...` |
| `businessProcesses[].busproctype_uses_infoviews` | Array | `[{"id": "store_90_Class130013", "name": "Market Spot Prices", "description": "Market prices for ener...` |
| `businessProcesses[].performedbyRole` | Array | `[{"id": "store_67_Class346", "name": "Energy Data Analyst"}]` |
| `businessProcesses[].ownedbyRole` | Array | `[{"id": "store_90_Class130011", "name": "Treasury"}]` |
| `businessProcesses[].bp_sub_business_processes` | Array | `[]` |
| `businessProcesses[].realises_business_capability` | Array | `["store_55_Class119"]` |
| `businessProcesses[].flow` | String | `"Y"` |
| `businessProcesses[].flowid` | String | `"store_261_Class80"` |
| `businessProcesses[].flowdetails` | Object | `{"name": "Action Hedging::PROCESS_FLOW", "diagram": "store_153_Class77", "diagramName": "Action Hedg...` |
| `businessProcesses[].actors` | Array | `[{"id": "store_55_Class695", "name": "Finance", "securityClassifications": []}]` |
| `businessProcesses[].parentCaps` | Array | `[{"id": "store_55_Class119", "name": "Hedging Management", "securityClassifications": []}]` |
| `businessProcesses[].debug` | String | `""` |
| `businessProcesses[].costs` | Array | `[]` |
| `businessProcesses[].orgUserIds` | Array | `["store_55_Class695"]` |
| `businessProcesses[].prodConIds` | Array | `[]` |
| `businessProcesses[].visId` | Array | `[""]` |
| `businessProcesses[].geoIds` | Array | `["store_265_Class598"]` |
| `businessProcesses[].documents` | Array | `[{"id": "store_174_Class30512", "name": "https://university.enterprise-architecture.org/", "document...` |
| `businessProcesses[].securityClassifications` | Array | `[]` |
| `businessActivities` | Array | `[{"id": "store_261_Class84", "name": "Check Market Rates", "description": "", "bus_process_type_crea...` |
| `businessActivities[].id` | String | `"store_261_Class84"` |
| `businessActivities[].name` | String | `"Check Market Rates"` |
| `businessActivities[].description` | String | `""` |
| `businessActivities[].bus_process_type_creates_information` | Array | `[]` |
| `businessActivities[].bus_process_type_reads_information` | Array | `[]` |
| `businessActivities[].bus_process_type_updates_information` | Array | `[]` |
| `businessActivities[].bus_process_type_deletes_information` | Array | `[]` |
| `businessActivities[].securityClassifications` | Array | `[]` |
| `ccy` | Array | `[{"id": "essential_baseline_v505_Class16", "name": "British Pound", "default": "", "exchangeRate": "...` |
| `ccy[].id` | String | `"essential_baseline_v505_Class16"` |
| `ccy[].name` | String | `"British Pound"` |
| `ccy[].default` | String | `""` |
| `ccy[].exchangeRate` | String | `""` |
| `ccy[].ccySymbol` | String | `"£"` |
| `ccy[].ccyCode` | String | `"GBP"` |
| `version` | String | `"620"` |

### core_api_import_data_object.xsl
- **Path**: `integration/api/core_api_import_data_object.xsl`
- **DSA Data Label**: `ImpDataObjApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `data_objects` | Array | `[{"id": "store_113_Class19", "indivOwner": "", "name": "Customer Address", "isAbstract": "false", "o...` |
| `data_objects[].id` | String | `"store_113_Class19"` |
| `data_objects[].indivOwner` | String | `""` |
| `data_objects[].name` | String | `"Customer Address"` |
| `data_objects[].isAbstract` | String | `"false"` |
| `data_objects[].orgOwner` | String | `""` |
| `data_objects[].description` | String | `"The address of the customer"` |
| `data_objects[].category` | String | `"Master Data"` |
| `data_objects[].synonyms` | Array | `[]` |
| `data_objects[].dataAttributes` | Array | `[{"id": "store_121_Class10000", "name": "Street Number", "type": "Integer", "description": "", "secu...` |
| `data_objects[].stakeholders` | Array | `[{"type": "Individual_Actor", "actorName": "Martin Thompson", "roleName": "Data Steward", "actorId":...` |
| `data_objects[].externalDocs` | Array | `[]` |
| `data_objects[].parents` | Array | `[{"name": "Customer", "securityClassifications": []}]` |
| `data_objects[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_data_object_attributes.xsl
- **Path**: `integration/api/core_api_import_data_object_attributes.xsl`
- **DSA Data Label**: `ImpDataObjAttrApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `data_object_attributes` | Array | `[{"id": "store_113_Class19", "name": "Customer Address", "attributes": [{"id": "store_121_Class10000...` |
| `data_object_attributes[].id` | String | `"store_113_Class19"` |
| `data_object_attributes[].name` | String | `"Customer Address"` |
| `data_object_attributes[].attributes` | Array | `[{"id": "store_121_Class10000", "name": "Customer Address - Street Number", "description": "", "syno...` |
| `data_object_attributes[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_data_object_inherit.xsl
- **Path**: `integration/api/core_api_import_data_object_inherit.xsl`
- **DSA Data Label**: `ImpDataObjInheritApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `data_object_inherit` | Array | `[{"id": "store_113_Class19", "name": "Customer Address", "children": [], "securityClassifications": ...` |
| `data_object_inherit[].id` | String | `"store_113_Class19"` |
| `data_object_inherit[].name` | String | `"Customer Address"` |
| `data_object_inherit[].children` | Array | `[]` |
| `data_object_inherit[].securityClassifications` | Array | `[]` |
| `version` | String | `"620"` |

### core_api_import_data_subject.xsl
- **Path**: `integration/api/core_api_import_data_subject.xsl`
- **DSA Data Label**: `ImpDataSubjApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `data_subjects` | Array | `[{"id": "store_113_Class13", "name": "Customer", "description": "Someone who buys services from the ...` |
| `data_subjects[].id` | String | `"store_113_Class13"` |
| `data_subjects[].name` | String | `"Customer"` |
| `data_subjects[].description` | String | `"Someone who buys services from the organisation"` |
| `data_subjects[].synonyms` | Array | `[]` |
| `data_subjects[].dataObjects` | Array | `[{"id": "store_113_Class19", "name": "Customer Address", "securityClassifications": []}]` |
| `data_subjects[].category` | String | `"Master Data"` |
| `data_subjects[].orgOwner` | String | `""` |
| `data_subjects[].stakeholders` | Array | `[{"type": "Group_Actor", "actorName": "Sales", "roleName": " Data Subject Organisational Owner ", "a...` |
| `data_subjects[].externalDocs` | Array | `[]` |
| `data_subjects[].indivOwner` | String | `""` |
| `data_subjects[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_framework_data.xsl
- **Path**: `integration/api/core_api_import_framework_data.xsl`
- **DSA Data Label**: `controlsApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `assessment` | Array | `[{"id": "store_174_Class30006", "control_solution_assessor": "Joe Smith", "name": "AC-04 Control Sol...` |
| `assessment[].id` | String | `"store_174_Class30006"` |
| `assessment[].control_solution_assessor` | String | `"Joe Smith"` |
| `assessment[].name` | String | `"AC-04 Control Solution assessed on 2022-01-01"` |
| `assessment[].assessment_date` | String | `"2022-01-01"` |
| `assessment[].assessment_finding` | String | `"Pass"` |
| `assessment[].assessment_comments` | String | `"Successfully Passed"` |
| `assessment[].controls` | Array | `[]` |
| `assessment[].securityClassifications` | Array | `[]` |
| `controlSolutions` | Array | `[{"id": "store_174_Class30007", "name": "AC-04 Control Solution", "processes": [{"id": "store_174_Cl...` |
| `controlSolutions[].id` | String | `"store_174_Class30007"` |
| `controlSolutions[].name` | String | `"AC-04 Control Solution"` |
| `controlSolutions[].processes` | Array | `[{"id": "store_174_Class40000", "name": "Manage User Account"}]` |
| `controlSolutions[].assessments` | Array | `[{"id": "store_174_Class30006", "name": "AC-04 Control Solution assessed on 2022-01-01", "assessment...` |
| `controlSolutions[].solutionForControl` | Array | `[{"id": "store_182_Class1", "name": "AC-04", "description": "Perform more frequent reviews of user a...` |
| `controlSolutions[].securityClassifications` | Array | `[]` |
| `control` | Array | `[{"id": "store_90_Class100355", "name": "A.10.1.1", "description": "Documented operating procedures ...` |
| `control[].id` | String | `"store_90_Class100355"` |
| `control[].name` | String | `"A.10.1.1"` |
| `control[].description` | String | `"Documented operating procedures - Operating procedures shall be documented, maintained, and made av...` |
| `control[].framework` | String | `"ISO27001"` |
| `control[].controlAssessessments` | Array | `[]` |
| `control[].controlSolutions` | Array | `[]` |
| `framework_controls` | Array | `[{"id": "store_90_Class100541", "name": "ISO27001", "controls": ["store_90_Class100355", "store_90_C...` |
| `framework_controls[].id` | String | `"store_90_Class100541"` |
| `framework_controls[].name` | String | `"ISO27001"` |
| `framework_controls[].controls` | Array | `["store_90_Class100355"]` |
| `version` | String | `"620"` |

### core_api_import_information_representations.xsl
- **Path**: `integration/api/core_api_import_information_representations.xsl`
- **DSA Data Label**: `ImpInfoRepApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `infoReps` | Array | `[{"id": "store_174_Class10364", "name": "BlackCurve API Customer Data Flow", "description": ""}]` |
| `infoReps[].id` | String | `"store_174_Class10364"` |
| `infoReps[].name` | String | `"BlackCurve API Customer Data Flow"` |
| `infoReps[].description` | String | `""` |
| `version` | String | `"620"` |

### core_api_import_nodes.xsl
- **Path**: `integration/api/core_api_import_nodes.xsl`
- **DSA Data Label**: `ImpNodeApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `nodes` | Array | `[{"id": "store_55_Class1962", "className": "Technology_Node", "criticalityId": "", "name": "AWS Dubl...` |
| `nodes[].id` | String | `"store_55_Class1962"` |
| `nodes[].className` | String | `"Technology_Node"` |
| `nodes[].criticalityId` | String | `""` |
| `nodes[].name` | String | `"AWS Dublin"` |
| `nodes[].hostedIn` | String | `"Dublin"` |
| `nodes[].criticality` | String | `""` |
| `nodes[].hostInfo` | Object | `{"id": "store_55_Class1334", "name": "Dublin", "className": "Site"}` |
| `nodes[].hostedInid` | String | `"store_55_Class1334"` |
| `nodes[].hostedLocation` | String | `"store_265_Class588"` |
| `nodes[].ipAddress` | String | `""` |
| `nodes[].ipAddresses` | Array | `[]` |
| `nodes[].lon` | String | `"-6.2602732"` |
| `nodes[].lat` | String | `"53.3497645"` |
| `nodes[].securityClassifications` | Array | `[]` |
| `nodes[].inboundConnections` | Array | `[]` |
| `nodes[].outboundConnections` | Array | `[]` |
| `nodes[].techStack` | Array | `[]` |
| `nodes[].attributes` | Array | `[]` |
| `nodes[].technology_node_type` | Object | `{"id": "", "className": "Technology_Node_Type", "name": "", "icon": ""}` |
| `nodes[].instances` | Array | `[{"id": "store_55_Class2121", "runtime_status_id": "essential_prj_CC_v1.4.2_Instance_10005", "name":...` |
| `nodes[].stakeholders` | Array | `[]` |
| `nodes[].parentNodes` | Array | `[]` |
| `appSoftwareMap` | Array | `[{"id": "store_55_Class1161", "software_usages": []}]` |
| `appSoftwareMap[].id` | String | `"store_55_Class1161"` |
| `appSoftwareMap[].software_usages` | Array | `[]` |
| `styles` | Array | `[{"id": "essential_prj_CC_v1.4.2_Instance_40008", "icon": "", "textColour": "", "backgroundColour": ...` |
| `styles[].id` | String | `"essential_prj_CC_v1.4.2_Instance_40008"` |
| `styles[].icon` | String | `""` |
| `styles[].textColour` | String | `""` |
| `styles[].backgroundColour` | String | `""` |
| `version` | String | `"621"` |

### core_api_import_orgs_sites.xsl
- **Path**: `integration/api/core_api_import_orgs_sites.xsl`
- **DSA Data Label**: `ImpOrgSitesApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `organisations` | Array | `[{"id": "store_90_Class110008", "name": "AMS", "external": "true", "description": ""}]` |
| `organisations[].id` | String | `"store_90_Class110008"` |
| `organisations[].name` | String | `"AMS"` |
| `organisations[].external` | String | `"true"` |
| `organisations[].description` | String | `""` |
| `version` | String | `"614"` |

### core_api_import_physical_process_app_svc.xsl
- **Path**: `integration/api/core_api_import_physical_process_app_svc.xsl`
- **DSA Data Label**: `ImpPhysProcAppApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `process_to_apps` | Array | `[{"id": "store_90_Class40071", "processCriticality": "High", "org": "Accounting", "name": "Accountin...` |
| `process_to_apps[].id` | String | `"store_90_Class40071"` |
| `process_to_apps[].processCriticality` | String | `"High"` |
| `process_to_apps[].org` | String | `"Accounting"` |
| `process_to_apps[].name` | String | `"Accounting performing Action Hedging"` |
| `process_to_apps[].processName` | String | `"Action Hedging"` |
| `process_to_apps[].criticalityStyle` | Object | `{"colour": "", "backgroundColour": ""}` |
| `process_to_apps[].orgid` | String | `"store_55_Class713"` |
| `process_to_apps[].orgUserId` | Array | `["store_55_Class713"]` |
| `process_to_apps[].processid` | String | `"store_55_Class215"` |
| `process_to_apps[].appProcessCriticalities` | Array | `[{"appid": "store_55_Class2471", "appCriticality": "", "criticalityStyle": {"colour": "", "backgroun...` |
| `process_to_apps[].sites` | Array | `[{"id": "store_55_Class747", "name": "London", "long": "-0.1276474", "lat": "51.5073219"}]` |
| `process_to_apps[].appsviaservice` | Array | `[{"id": "store_55_Class2471", "svcid": "store_55_Class1124", "name": "WorkMan as Work Order Manageme...` |
| `process_to_apps[].appsdirect` | Array | `[]` |
| `process_to_apps[].securityClassifications` | Array | `[]` |
| `activity_to_apps` | Array | `[{"id": "store_261_Class101", "org": "Finance", "activityId": "store_261_Class89", "name": "Finance ...` |
| `activity_to_apps[].id` | String | `"store_261_Class101"` |
| `activity_to_apps[].org` | String | `"Finance"` |
| `activity_to_apps[].activityId` | String | `"store_261_Class89"` |
| `activity_to_apps[].name` | String | `"Finance as Hedge Management performing Initiate Transaction"` |
| `activity_to_apps[].appsviaservice` | Array | `[]` |
| `activity_to_apps[].appsdirect` | Array | `[]` |
| `activity_to_apps[].securityClassifications` | Array | `[]` |
| `version` | String | `"621"` |

### core_api_import_sites.xsl
- **Path**: `integration/api/core_api_import_sites.xsl`
- **DSA Data Label**: `ImpSitesApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `sites` | Array | `[{"id": "store_55_Class1337", "name": "Amsterdam", "long": "4.8979755", "description": "Microsoft Am...` |
| `sites[].id` | String | `"store_55_Class1337"` |
| `sites[].name` | String | `"Amsterdam"` |
| `sites[].long` | String | `"4.8979755"` |
| `sites[].description` | String | `"Microsoft Amsterdam"` |
| `sites[].lat` | String | `"52.3745403"` |
| `sites[].securityClassifications` | Array | `[]` |
| `countries` | Array | `[{"id": "essential_baseline_v2_0_Class50126", "name": "Afghanistan"}]` |
| `countries[].id` | String | `"essential_baseline_v2_0_Class50126"` |
| `countries[].name` | String | `"Afghanistan"` |
| `version` | String | `"614"` |

### core_api_import_suppliers.xsl
- **Path**: `integration/api/core_api_import_suppliers.xsl`
- **DSA Data Label**: `allSupplier`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `suppliers` | Array | `N/A` |
| `suppliersProcess` | Array | `N/A` |
| `suppliersApps` | Array | `N/A` |
| `filters` | Array | `N/A` |
| `version` | String | `N/A` |
| `id` | String | `N/A` |
| `name` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `className` | String | `N/A` |
| `sites` | Unknown | `N/A` |
| `supplierActor` | String | `N/A` |
| `esg_rating` | String | `N/A` |
| `processes` | Array | `N/A` |
| `busProc` | Object | `N/A` |
| `physname` | Unknown | `N/A` |
| `apps` | Array | `N/A` |
| `valueClass` | String | `N/A` |
| `description` | String | `N/A` |
| `slotName` | String | `N/A` |
| `isGroup` | Unknown | `N/A` |
| `icon` | String | `N/A` |
| `color` | String | `N/A` |
| `values` | Array | `N/A` |
| `enum_name` | Unknown | `N/A` |
| `sequence` | String | `N/A` |
| `backgroundColor` | String | `N/A` |
| `colour` | String | `N/A` |

### core_api_import_technology_capabilities.xsl
- **Path**: `integration/api/core_api_import_technology_capabilities.xsl`
- **DSA Data Label**: `ImpTechCapApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_capabilities` | Array | `[{"id": "EAS_Meta_Model_Instance_10013", "legacyId": "EAS_Meta_Model_Instance_10013", "type": "Techn...` |
| `technology_capabilities[].id` | String | `"EAS_Meta_Model_Instance_10013"` |
| `technology_capabilities[].legacyId` | String | `"EAS_Meta_Model_Instance_10013"` |
| `technology_capabilities[].type` | String | `"Technology_Capability"` |
| `technology_capabilities[].className` | String | `"Technology_Capability"` |
| `technology_capabilities[].domain` | String | `"Client Technology"` |
| `technology_capabilities[].name` | String | `"User Presentation Services"` |
| `technology_capabilities[].description` | String | `"Capability for users to interact with a system"` |
| `technology_capabilities[].domainId` | String | `"essential_baseline_v1_Instance_30016"` |
| `technology_capabilities[].securityClassifications` | Array | `[]` |
| `technology_capability_hierarchy` | Array | `[{"id": "EAS_Meta_Model_Instance_10013", "type": "Technology_Capability", "className": "Technology_C...` |
| `technology_capability_hierarchy[].id` | String | `"EAS_Meta_Model_Instance_10013"` |
| `technology_capability_hierarchy[].type` | String | `"Technology_Capability"` |
| `technology_capability_hierarchy[].className` | String | `"Technology_Capability"` |
| `technology_capability_hierarchy[].name` | String | `"User Presentation Services"` |
| `technology_capability_hierarchy[].supportingCapabilities` | Array | `[]` |
| `technology_capability_hierarchy[].components` | Array | `[{"id": "EAS_Meta_Model_v1_0_Instance_10030", "type": "Technology_Component", "className": "Technolo...` |
| `technology_capability_hierarchy[].securityClassifications` | Array | `[]` |
| `version` | String | `"620"` |

### core_api_import_technology_components.xsl
- **Path**: `integration/api/core_api_import_technology_components.xsl`
- **DSA Data Label**: `ImpTechCompApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_components` | Array | `[{"id": "EAS_Meta_Model_v1_0_Instance_10018", "legacyId": "EAS_Meta_Model_v1.0_Instance_10018", "nam...` |
| `technology_components[].id` | String | `"EAS_Meta_Model_v1_0_Instance_10018"` |
| `technology_components[].legacyId` | String | `"EAS_Meta_Model_v1.0_Instance_10018"` |
| `technology_components[].name` | String | `"J2EE Application Server"` |
| `technology_components[].description` | String | `"An application runtime environment that supports the full J2EE specification"` |
| `technology_components[].caps` | Array | `["Application Runtime Services"]` |
| `technology_components[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_technology_domains.xsl
- **Path**: `integration/api/core_api_import_technology_domains.xsl`
- **DSA Data Label**: `ImpTechDomApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_domains` | Array | `[{"id": "essential_baseline_v1_Instance_30011", "name": "Security Technology", "ReferenceModelLayer"...` |
| `technology_domains[].id` | String | `"essential_baseline_v1_Instance_30011"` |
| `technology_domains[].name` | String | `"Security Technology"` |
| `technology_domains[].ReferenceModelLayer` | String | `""` |
| `technology_domains[].description` | String | `"Domain for all technology capabilities related to security"` |
| `technology_domains[].supportingCapabilities` | Array | `["essential_prj_CC_v1_4_2_Instance_140264"]` |
| `technology_domains[].securityClassifications` | Array | `[]` |
| `version` | String | `"620"` |

### core_api_import_technology_product_families.xsl
- **Path**: `integration/api/core_api_import_technology_product_families.xsl`
- **DSA Data Label**: `ImpTechProdFmApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_product_family` | Array | `[{"id": "store_55_Class3241", "name": "Acer TravelMate", "description": "", "securityClassifications...` |
| `technology_product_family[].id` | String | `"store_55_Class3241"` |
| `technology_product_family[].name` | String | `"Acer TravelMate"` |
| `technology_product_family[].description` | String | `""` |
| `technology_product_family[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_technology_products.xsl
- **Path**: `integration/api/core_api_import_technology_products.xsl`
- **DSA Data Label**: `ImpTechProdApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_products` | Array | `[{"vendor": "EAS", "lifecycle": "", "name": "NW_TEST", "supplier": "EAS", "delivery": "", "id": "sto...` |
| `technology_products[].vendor` | String | `"EAS"` |
| `technology_products[].lifecycle` | String | `""` |
| `technology_products[].name` | String | `"NW_TEST"` |
| `technology_products[].supplier` | String | `"EAS"` |
| `technology_products[].delivery` | String | `""` |
| `technology_products[].id` | String | `"store_121_Class50000"` |
| `technology_products[].description` | String | `"The Document Storage service is a self contained service that offers storage and retrieval of docum...` |
| `technology_products[].technology_provider_version` | String | `""` |
| `technology_products[].visId` | Array | `["store_90_Class44"]` |
| `technology_products[].orgUserIds` | Array | `[]` |
| `technology_products[].costs` | Array | `[]` |
| `technology_products[].family` | Array | `[]` |
| `technology_products[].functions` | Array | `[]` |
| `technology_products[].instances` | Array | `[]` |
| `technology_products[].usages` | Array | `[]` |
| `technology_products[].documents` | Array | `[]` |
| `technology_products[].stakeholders` | Array | `[]` |
| `technology_products[].purchase_status` | Array | `[]` |
| `technology_products[].technology_product_family` | Array | `[]` |
| `technology_products[].technology_provider_delivery_model` | Array | `[]` |
| `technology_products[].technology_provider_lifecycle_status` | Array | `[]` |
| `technology_products[].vendor_product_lifecycle_status` | Array | `[]` |
| `technology_products[].securityClassifications` | Array | `[]` |
| `tprStandards` | Array | `[{"id": "store_53_Class1063", "compliance2": [], "compliance": "", "adoption": {"id": "essential_bas...` |
| `tprStandards[].id` | String | `"store_53_Class1063"` |
| `tprStandards[].compliance2` | Array | `[]` |
| `tprStandards[].compliance` | String | `""` |
| `tprStandards[].adoption` | Object | `{"id": "essential_baseline_v5_Class15", "name": ""}` |
| `ccy` | Array | `[{"id": "essential_baseline_v505_Class16", "name": "British Pound", "default": "", "exchangeRate": "...` |
| `ccy[].id` | String | `"essential_baseline_v505_Class16"` |
| `ccy[].name` | String | `"British Pound"` |
| `ccy[].default` | String | `""` |
| `ccy[].exchangeRate` | String | `""` |
| `filters` | Array | `[{"id": "Lifecycle_Status", "name": "Lifecycle Status", "valueClass": "Lifecycle_Status", "descripti...` |
| `filters[].id` | String | `"Lifecycle_Status"` |
| `filters[].name` | String | `"Lifecycle Status"` |
| `filters[].valueClass` | String | `"Lifecycle_Status"` |
| `filters[].description` | String | `""` |
| `filters[].slotName` | String | `"technology_provider_lifecycle_status"` |
| `filters[].isGroup` | Boolean | `false` |
| `filters[].icon` | String | `"fa-circle"` |
| `filters[].color` | String | `"#93592f"` |
| `filters[].values` | Array | `[{"id": "essential_prj_AA_v1_4_Instance_10068", "sequence": "1", "enum_name": "Under Planning", "nam...` |
| `version` | String | `"620"` |

### core_api_import_technology_products_orgs.xsl
- **Path**: `integration/api/core_api_import_technology_products_orgs.xsl`
- **DSA Data Label**: `ImpTechProdOrgApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_product_orgs` | Array | `[{"id": "store_55_Class3311", "name": ".NET", "org": [{"id": "store_55_Class687", "name": "IT", "sec...` |
| `technology_product_orgs[].id` | String | `"store_55_Class3311"` |
| `technology_product_orgs[].name` | String | `".NET"` |
| `technology_product_orgs[].org` | Array | `[{"id": "store_55_Class687", "name": "IT", "securityClassifications": []}]` |
| `technology_product_orgs[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

### core_api_import_technology_suppliers.xsl
- **Path**: `integration/api/core_api_import_technology_suppliers.xsl`
- **DSA Data Label**: `ImpTechSuppApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_suppliers` | Array | `[{"id": "essential_prj_AA_v1_1_graphArchTest_Instance_20", "name": "Oracle Corporation", "descriptio...` |
| `technology_suppliers[].id` | String | `"essential_prj_AA_v1_1_graphArchTest_Instance_20"` |
| `technology_suppliers[].name` | String | `"Oracle Corporation"` |
| `technology_suppliers[].description` | String | `"Oracle Corporation"` |
| `technology_suppliers[].securityClassifications` | Array | `[]` |
| `version` | String | `"614"` |

## Technology

### core_api_get_all_tech_nodes_detail.xsl
- **Path**: `technology/api/core_api_get_all_tech_nodes_detail.xsl`
- **DSA Data Label**: `techNoApi`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_nodes` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | Unknown | `N/A` |
| `description` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `ip` | String | `N/A` |
| `apps` | Array | `N/A` |
| `link` | String | `N/A` |
| `deployment` | Array | `N/A` |
| `country` | String | `N/A` |
| `attributes` | Array | `N/A` |
| `key` | String | `N/A` |
| `attribute_value_of` | String | `N/A` |
| `attribute_value` | String | `N/A` |
| `attribute_value_unit` | String | `N/A` |
| `deployment_status` | Object | `N/A` |
| `className` | String | `N/A` |
| `technology_node_type` | Object | `N/A` |
| `deployment_of` | Object | `N/A` |
| `instances` | Array | `N/A` |
| `app` | Object | `N/A` |
| `tech` | Object | `N/A` |
| `stakeholders` | Array | `N/A` |
| `type` | String | `N/A` |
| `actor` | String | `N/A` |
| `actorId` | String | `N/A` |
| `role` | String | `N/A` |
| `roleId` | String | `N/A` |
| `parentNodes` | Array | `N/A` |
| `techType` | String | `N/A` |

### core_api_tl_get_all_technology_lifecycles.xsl
- **Path**: `technology/api/core_api_tl_get_all_technology_lifecycles.xsl`
- **DSA Data Label**: `techLifecycle`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_lifecycles` | Array | `N/A` |
| `all_lifecycles` | Array | `N/A` |
| `lifecycleJSON` | Array | `N/A` |
| `standardsJSON` | Array | `N/A` |
| `lifecycleType` | Array | `N/A` |
| `id` | String | `N/A` |
| `linkid` | Unknown | `N/A` |
| `name` | Unknown | `N/A` |
| `description` | Unknown | `N/A` |
| `supplier` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `supplierId` | String | `N/A` |
| `allDates` | Array | `N/A` |
| `dates` | Array | `N/A` |
| `applications` | Array | `N/A` |
| `standards` | Array | `N/A` |
| `className` | String | `N/A` |
| `componentName` | Unknown | `N/A` |
| `standardStrength` | String | `N/A` |
| `geoScope` | Array | `N/A` |
| `orgScope` | Array | `N/A` |
| `dateOf` | String | `N/A` |
| `thisid` | String | `N/A` |
| `type` | String | `N/A` |
| `seq` | Unknown | `N/A` |
| `enumeration_value` | String | `N/A` |
| `backgroundColour` | String | `N/A` |
| `colour` | String | `N/A` |
| `productId` | String | `N/A` |

### core_api_tl_get_all_technology_suppliers.xsl
- **Path**: `technology/api/core_api_tl_get_all_technology_suppliers.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_suppliers` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |
| `description` | String | `N/A` |

### core_api_tl_tech_perf_measures.xsl
- **Path**: `technology/api/core_api_tl_tech_perf_measures.xsl`
- **DSA Data Label**: `techKpiAPI`
- **Parameters**: None
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_product` | Array | `[{"id": "store_121_Class50000", "name": "NW_TEST", "perfMeasures": [], "securityClassifications": []...` |
| `technology_product[].id` | String | `"store_121_Class50000"` |
| `technology_product[].name` | String | `"NW_TEST"` |
| `technology_product[].perfMeasures` | Array | `[]` |
| `technology_product[].securityClassifications` | Array | `[]` |
| `technology_product_role` | Array | `[{"id": "store_53_Class1063", "name": "Endpoint Security::as::Firewall", "description": "", "perfMea...` |
| `technology_product_role[].id` | String | `"store_53_Class1063"` |
| `technology_product_role[].name` | String | `"Endpoint Security::as::Firewall"` |
| `technology_product_role[].description` | String | `""` |
| `technology_product_role[].perfMeasures` | Array | `[]` |
| `technology_product_role[].securityClassifications` | Array | `[]` |
| `perfCategory` | Array | `[]` |
| `serviceQualities` | Array | `[]` |

### core_api_tl_technology_capabilities_l1_to_components.xsl
- **Path**: `technology/api/core_api_tl_technology_capabilities_l1_to_components.xsl`
- **DSA Data Label**: `techCapL1ITAData`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_capabilities` | Array | `N/A` |
| `id` | String | `N/A` |
| `techComponents` | Array | `N/A` |
| `name` | String | `N/A` |
| `description` | String | `N/A` |
| `tprs` | Array | `N/A` |

### core_api_tl_technology_capability_list.xsl
- **Path**: `technology/api/core_api_tl_technology_capability_list.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_capabilities` | Array | `N/A` |
| `tech_components` | Array | `N/A` |

### core_api_tl_technology_component_list.xsl
- **Path**: `technology/api/core_api_tl_technology_component_list.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_components` | Array | `N/A` |
| `debug` | String | `N/A` |
| `caps` | Array | `N/A` |
| `products` | Array | `N/A` |

### core_api_tl_technology_component_list_from_tprs.xsl
- **Path**: `technology/api/core_api_tl_technology_component_list_from_tprs.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_product_roles` | Array | `N/A` |
| `id` | String | `N/A` |
| `comps` | Array | `N/A` |
| `name` | String | `N/A` |

### core_api_tl_technology_product_list.xsl
- **Path**: `technology/api/core_api_tl_technology_product_list.xsl`
- **DSA Data Label**: `techProdListData`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `technology_products` | Array | `N/A` |
| `link` | String | `N/A` |
| `supplier` | String | `N/A` |
| `caps` | Array | `N/A` |
| `comp` | Array | `N/A` |

### core_api_tl_technology_product_list_with_standards.xsl
- **Path**: `technology/api/core_api_tl_technology_product_list_with_standards.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `techProducts` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |
| `description` | String | `N/A` |
| `supplierId` | String | `N/A` |

### core_api_tl_technology_product_list_with_supplier_componentIDs.xsl
- **Path**: `technology/api/core_api_tl_technology_product_list_with_supplier_componentIDs.xsl`
- **DSA Data Label**: `techProdSvc`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `meta` | Array | `N/A` |
| `technology_products` | Array | `N/A` |
| `filters` | Array | `N/A` |
| `name` | Unknown | `N/A` |
| `description` | Unknown | `N/A` |
| `method` | String | `N/A` |
| `indent` | Unknown | `N/A` |
| `id` | String | `N/A` |
| `supplierId` | String | `N/A` |
| `member_of_technology_product_families` | Array | `N/A` |
| `vendor_lifecycle` | Array | `N/A` |
| `start_date` | String | `N/A` |
| `status` | Unknown | `N/A` |
| `statusId` | String | `N/A` |
| `order` | String | `N/A` |
| `caps` | Array | `N/A` |
| `comp` | Array | `N/A` |
| `tprid` | String | `N/A` |
| `strategic_lifecycle_status` | String | `N/A` |
| `std` | String | `N/A` |
| `stdStyle` | String | `N/A` |
| `stdColour` | String | `N/A` |
| `stdTextColour` | String | `N/A` |
| `allStandards` | Array | `N/A` |
| `stdStrength` | Unknown | `N/A` |
| `orgScope` | Array | `N/A` |
| `type` | Unknown | `N/A` |
| `geoScope` | Array | `N/A` |
| `supplier` | Unknown | `N/A` |
| `lifecycleStatus` | Unknown | `N/A` |
| `statusScore` | Unknown | `N/A` |
| `ea_reference` | String | `N/A` |
| `delivery` | String | `N/A` |
| `techOrgUsers` | Array | `N/A` |
| `orgUserIds` | Array | `N/A` |
| `visId` | Array | `N/A` |
| `valueClass` | String | `N/A` |
| `slotName` | String | `N/A` |
| `isGroup` | Unknown | `N/A` |
| `icon` | String | `N/A` |
| `color` | String | `N/A` |
| `values` | Array | `N/A` |
| `enum_name` | String | `N/A` |
| `sequence` | String | `N/A` |
| `backgroundColor` | String | `N/A` |
| `colour` | String | `N/A` |
| `classes` | Array | `N/A` |
| `menuId` | String | `N/A` |

### core_api_tl_technology_product_suppliers.xsl
- **Path**: `technology/api/core_api_tl_technology_product_suppliers.xsl`
- **DSA Data Label**: `N/A`
- **Parameters**: param1
- **Properties**:
| Property | Type | Example |
| --- | --- | --- |
| `allTechSuppliers` | Array | `N/A` |
| `id` | String | `N/A` |
| `name` | String | `N/A` |
| `description` | String | `N/A` |

## 🛠️ Essential Project: Correcting Nested KPI Data Fetching

When building views that consume performance and quality data (like from `appkpiAPI`), the JSON structure often nests the final score values, leading to empty results if the parsing logic doesn't drill down far enough.

This document explains the required adjustment to JavaScript utility functions (like `createKpiMap`) to successfully extract application KPI scores.

-----

### 🛑 The Problem: Nested Data Structure

The `appkpiAPI` often returns KPI data where the score and category name are not direct properties of the `perfMeasures` array elements. Instead, they are nested within an inner array called `serviceQuals`.

#### ❌ Incorrect Assumption (Initial Logic)

The initial, non-functional logic assumed this flatter structure:

```json
// Assumed but INCORRECT structure:
{
  "id": "app_123",
  "perfMeasures": [
    { 
      "category": "Technical Fit", 
      "score": "3" // Assumed score was here
    }
  ]
}
```

#### ✅ Actual Structure (Corrected Logic Target)

The actual structure requires drilling down an extra level:

```json
// Actual data structure:
{
  "id": "app_123",
  "perfMeasures": [
    {
      "serviceQuals": [ // <--- Must iterate here
        {
          "serviceName": "Technical Fit", // <--- Correct Category Name
          "score": "3" // <--- Correct Score location
        }
      ]
    }
  ]
}
```

-----

### 🔧 The Solution: Corrected JavaScript Parsing

To resolve this, the parsing function (`createKpiMap`) must include three nested loops to traverse the hierarchy: `applications` $\to$ `perfMeasures` $\to$ `serviceQuals`.

#### 🧑‍💻 Corrected `createKpiMap` Function

Use the following function definition in any XSL view that consumes `appkpiAPI` data to ensure all KPI scores are correctly mapped to their application IDs:

```javascript
/**
 * Creates a map of application IDs to an object of KPI service names and their normalized scores.
 * This is corrected for the nested 'serviceQuals' structure in appkpiAPI data.
 * @param {object} kpiData The data object from the appkpiAPI.
 * @returns {object} A map {appId: {KPIName: score, ...}, ...}
 */
function createKpiMap(kpiData) {
    const kpisMap = {};
    
    // 1. Iterate over the main array of applications
    (kpiData?.applications || []).forEach(app => {
        kpisMap[app.id] = {};
        
        // 2. Iterate over the 'perfMeasures' (the outer groups)
        (app.perfMeasures || []).forEach(perfMeasure => {
            
            // 3. Iterate over the 'serviceQuals' (where the actual scores are)
            (perfMeasure.serviceQuals || []).forEach(kpiQualityValue => {
                
                // Extract score and use 'serviceName' for the category key
                const categoryName = kpiQualityValue.serviceName; 
                const score = parseInt(kpiQualityValue.score, 10);
                
                if (categoryName) {
                    // Normalize score to 0-100 range and map it
                    kpisMap[app.id][categoryName] = Math.min(100, Math.max(0, score || 0));
                }
            });
        });
    });
    
    return kpisMap;
}
```

-----

### 🔑 Key Takeaways for Future Views

1.  **Always Inspect JSON:** If a mapping function returns zero results, immediately inspect the raw JSON from the API to check the nesting level.
2.  **Use `serviceName`:** For application quality data, the correct key for the category name is typically **`serviceName`**, not the top-level `category` or `categoryName` array.
3.  **Three-Tier Iteration:** Assume the structure for application KPI data requires iteration through: `applications` $\to$ `perfMeasures` $\to$ `serviceQuals`.
4. **For any view Always ensure there is guard code to minimise the code breaking from missing or null data**
5. **Ampersand and Special Character Encoding:**
   - **Inside CDATA sections** (your JavaScript code): Use plain `&`, `&&`, `<=`, `>=`
   - **Outside CDATA sections** (XML attributes and script blocks): Use `&amp;`, `&amp;&amp;`, `&lt;`, `&lt;=`, `&gt;`, `&gt;=`
   - **`for` loops are the #1 offender** — `for (var i = 0; i < n; i++)` MUST be `for (var i = 0; i &lt; n; i++)`. Bare `<` causes `SAXParseException: The content of elements must consist of well-formed character data or markup`. Prefer `forEach`/`map` to avoid this entirely.
   - In comments: Use 'and' and 'less than' instead of symbols for clarity
6. **Remind the user to check their DSA names align to the ones you use if there is an error in the data fetch**

---

## Common Errors and Solutions

### Error: "I/O error reported by XML parser"
**Cause:** Missing `<xsl:import href="../common/core_js_functions.xsl"/>` or it's in the wrong position  
**Solution:** Ensure the import statement is present BEFORE all `<xsl:include>` statements

### Error: "The content of elements must consist of well-formed character data or markup"
**Saxon error:** `org.xml.sax.SAXParseException ... The content of elements must consist of well-formed character data or markup`
**Cause:** An unescaped `<`, `>`, or `&` character inside a `<script>` block. The XML parser sees the bare character and expects XML markup, not JavaScript.
**Most common trigger:** `for` loop counters — e.g. `for (var i = 0; i < items.length; i++)` — where `< items` looks to the XML parser like an opening tag.
**Solution:**
- Replace every `<` with `&lt;` and `>` with `&gt;` in JavaScript conditions and loops:
  ```javascript
  // ✗ WRONG - Saxon fails at the < character
  for (var i = 0; i < data.length; i++) { }
  // ✓ CORRECT
  for (var i = 0; i &lt; data.length; i++) { }
  ```
- Prefer `forEach` / `map` to eliminate the `<` entirely (recommended):
  ```javascript
  data.forEach(function(item, i) { /* no < needed */ });
  ```
- The Saxon `lineNumber`/`columnNumber` in the error points to the **first unescaped character** — scan that line for bare `<`, `>`, or `&`.

### Error: "XML parsing error" or "Fatal Error"
**Cause:** Mixed XSL template calls with CDATA in the same script block, or wrong ampersand encoding
**Solution:**
- Separate each `<xsl:call-template>` into its own `<script>` block
- Put your JavaScript code in a separate `<script>` block with CDATA
- Use plain `&` inside CDATA, `&amp;` outside CDATA

### Error: "fetchAndRenderData is not defined"
**Cause:** Missing `<xsl:call-template name="RenderViewerAPIJSFunction"/>`  
**Solution:** Add the template call in its own `<script>` block before your custom JavaScript

### Error: API returns no data (window.apiLabel is undefined)
**Cause:** Wrong API label or incorrect URL path  
**Solution:** Verify the DSA Data Label matches the Essential API Catalogue exactly

---

## 6. API Property Name Verification (CRITICAL)

**NEVER ASSUME** property names from documentation alone. The API catalogue may not reflect the actual JSON structure due to workspace customizations.

### 6.1 Required Verification Process
1. When using an API, ALWAYS verify the actual property names by logging the response.
2. Check the first element of arrays to see actual structure.
3. Update your code to match the ACTUAL structure, not the documented one.

**Common Mismatches:**

| API | Documentation Says | Actually Is |
|-----|-------------------|-------------|
| `appLifecycle` | `.lifecycles` | `.application_lifecycles` |
| `appCostApi` | `.application_costs` | `.applicationCost` |
| `orgSummary` | `.organisations` | `.applicationOrgUsers` |
| `busKpiAPI` | `.kpis` | `.applications` |

### 6.2 Diagnostic Pattern
```javascript
async function executeFetchAndRender() {
    let responses = await fetchAndRenderData(['appMartAPI']);
    
    // DEBUG: Verify keys if data is missing
    console.log('API Keys:', Object.keys(responses.appMartAPI));
    console.log('Sample Item:', responses.appMartAPI.applications?.[0]);
    
    buildViewModel(responses);
}
```

## 7. XSLT API Development: Robust Patterns
... (rest of the content)