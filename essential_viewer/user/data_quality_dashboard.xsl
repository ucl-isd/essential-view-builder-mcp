<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    <xsl:import href="../common/core_js_functions.xsl"/>
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>
    <xsl:include href="../common/core_footer.xsl"/>
    <xsl:include href="../common/core_external_doc_ref.xsl"/>
    <xsl:include href="../common/core_api_fetcher.xsl"/>
    <xsl:include href="../common/core_handlebars_functions.xsl"/>
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>
    <xsl:variable name="viewScopeTerms" select="eas:get_scoping_terms_from_string($viewScopeTermIds)"/>
    <xsl:variable name="linkClasses" select="('Application_Provider', 'Composite_Application_Provider', 'Managed_Service')"/>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>
                <title>Data Quality Dashboard</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1400px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.1rem}
                    .metric-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px;margin-bottom:30px}
                    .metric-card{background:#fff;border:1px solid #E5E7EB;border-radius:12px;padding:24px;position:relative;overflow:hidden}
                    .metric-card .metric-count{font-size:3rem;font-weight:700;color:#DC2626}
                    .metric-card .metric-count.ok{color:#1AAB40}
                    .metric-card .metric-label{font-size:1rem;color:#4B5563;margin-top:4px;font-weight:500}
                    .metric-card .metric-total{font-size:0.85rem;color:#9CA3AF;margin-top:2px}
                    .metric-card .metric-bar{height:6px;background:#E5E7EB;border-radius:3px;margin-top:12px;overflow:hidden}
                    .metric-card .metric-bar-fill{height:100%;border-radius:3px;background:#DC2626;transition:width 0.5s}
                    .metric-card .metric-bar-fill.ok{background:#1AAB40}
                    .list-section{margin-top:20px}
                    .list-header{background:#361A54;color:#DDBDFF;padding:12px 20px;border-radius:8px 8px 0 0;font-weight:600;cursor:pointer;display:flex;justify-content:space-between;align-items:center;user-select:none}
                    .list-header:hover{background:#4A1B94}
                    .list-header .chevron{transition:transform 0.3s}
                    .list-header .chevron.open{transform:rotate(180deg)}
                    .list-body{max-height:0;overflow:hidden;transition:max-height 0.4s ease;border:1px solid #E5E7EB;border-top:none;border-radius:0 0 8px 8px}
                    .list-body.open{max-height:5000px;overflow-y:auto}
                    .list-items{padding:12px;max-height:400px;overflow-y:auto}
                    .list-item{padding:8px 12px;margin-bottom:4px;background:#F5F0FF;border-left:3px solid #993AFF;border-radius:4px;font-size:0.95rem}
                    .search-bar{margin-bottom:8px;padding:0 12px;padding-top:12px}
                    .search-bar input{width:100%;padding:8px 12px;border:1px solid #E5E7EB;border-radius:6px;font-size:0.9rem;font-family:'DM Sans',sans-serif}
                </style>
                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>
                    var busCapAppMartApps, suppImpApi;

                    function cleanText(str) { return str ? str.replace(/_/g, ' ') : ''; }

                    $(document).ready(function() {
                        var apiList = ['busCapAppMartApps', 'suppImpApi'];
                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                busCapAppMartApps = responses.busCapAppMartApps;
                                suppImpApi = responses.suppImpApi;
                                renderDashboard();
                            } catch (error) {
                                console.error('Error:', error);
                            }
                        }
                        executeFetchAndRender();
                    });

                    function renderDashboard() {
                        var apps = busCapAppMartApps.applications || [];
                        var suppliers = suppImpApi.suppliers || [];

                        // 1. Apps with no managed service
                        var appsNoMS = apps.filter(function(a) { return !a.al_managed_by_services || a.al_managed_by_services.length === 0; });
                        var appsWithMS = apps.length - appsNoMS.length;

                        // 2. Managed services with no dependencies - get all MS from supplier data or use apps managed_by
                        var allMSIds = new Set();
                        apps.forEach(function(a) { if (a.al_managed_by_services) a.al_managed_by_services.forEach(function(msId) { allMSIds.add(msId); }); });

                        // 3. Contracts with no applications linked (via contractCompIds -> contract_components -> appElements)
                        var allContracts = [];
                        var contractsNoApps = [];
                        var topLevelComponents = suppImpApi.contract_components || [];
                        var compMap = {};
                        topLevelComponents.forEach(function(comp) { compMap[comp.id] = comp; });
                        suppliers.forEach(function(sup) {
                            if (sup.contracts &amp;&amp; sup.contracts.length &gt; 0) {
                                sup.contracts.forEach(function(c) {
                                    allContracts.push({name: c.name || c.contract_ref || 'Unnamed', supplier: sup.name});
                                    var hasApps = false;
                                    var compIds = c.contractCompIds || [];
                                    compIds.forEach(function(compId) {
                                        var comp = compMap[compId];
                                        if (comp &amp;&amp; comp.appElements &amp;&amp; comp.appElements.length > 0) hasApps = true;
                                    });
                                    if (!hasApps) {
                                        contractsNoApps.push({name: c.name || c.contract_ref || 'Unnamed', supplier: sup.name});
                                    }
                                });
                            }
                        });

                        // Render metric cards
                        var pctApps = apps.length &gt; 0 ? Math.round((appsNoMS.length / apps.length) * 100) : 0;
                        var pctContracts = allContracts.length &gt; 0 ? Math.round((contractsNoApps.length / allContracts.length) * 100) : 0;

                        var html = '<div class="metric-cards">';
                        // Card 1: Apps without managed service
                        html += '<div class="metric-card">';
                        html += '<div class="metric-count' + (appsNoMS.length === 0 ? ' ok' : '') + '">' + appsNoMS.length + '</div>';
                        html += '<div class="metric-label">Applications without a Managed Service</div>';
                        html += '<div class="metric-total">out of ' + apps.length + ' total applications (' + pctApps + '%)</div>';
                        html += '<div class="metric-bar"><div class="metric-bar-fill' + (appsNoMS.length === 0 ? ' ok' : '') + '" style="width:' + pctApps + '%;"></div></div>';
                        html += '</div>';

                        // Card 2: Contracts without applications
                        html += '<div class="metric-card">';
                        html += '<div class="metric-count' + (contractsNoApps.length === 0 ? ' ok' : '') + '">' + contractsNoApps.length + '</div>';
                        html += '<div class="metric-label">Contracts without Applications linked</div>';
                        html += '<div class="metric-total">out of ' + allContracts.length + ' total contracts (' + pctContracts + '%)</div>';
                        html += '<div class="metric-bar"><div class="metric-bar-fill' + (contractsNoApps.length === 0 ? ' ok' : '') + '" style="width:' + pctContracts + '%;"></div></div>';
                        html += '</div>';

                        html += '</div>';

                        // List sections
                        // Apps WITHOUT managed service
                        html += '<div class="list-section">';
                        html += '<div class="list-header" onclick="toggleList(0)"><span>Applications WITHOUT Managed Service (' + appsNoMS.length + ')</span><span class="chevron" id="chev-0">&#x25BC;</span></div>';
                        html += '<div class="list-body" id="list-0">';
                        html += '<div class="search-bar"><input type="text" placeholder="Filter..." oninput="filterList(0, this.value)"/></div>';
                        html += '<div class="list-items" id="items-0">';
                        appsNoMS.sort(function(a, b) { return a.name.localeCompare(b.name); }).forEach(function(a) {
                            html += '<div class="list-item" data-name="' + a.name.toLowerCase() + '">' + cleanText(a.name) + '</div>';
                        });
                        html += '</div></div></div>';

                        // Apps WITH managed service
                        var appsWithMSList = apps.filter(function(a) { return a.al_managed_by_services &amp;&amp; a.al_managed_by_services.length > 0; });
                        html += '<div class="list-section" style="margin-top:15px;">';
                        html += '<div class="list-header" onclick="toggleList(2)"><span>Applications WITH Managed Service (' + appsWithMSList.length + ')</span><span class="chevron" id="chev-2">&#x25BC;</span></div>';
                        html += '<div class="list-body" id="list-2">';
                        html += '<div class="search-bar"><input type="text" placeholder="Filter..." oninput="filterList(2, this.value)"/></div>';
                        html += '<div class="list-items" id="items-2">';
                        appsWithMSList.sort(function(a, b) { return a.name.localeCompare(b.name); }).forEach(function(a) {
                            html += '<div class="list-item" data-name="' + a.name.toLowerCase() + '">' + cleanText(a.name) + '</div>';
                        });
                        html += '</div></div></div>';

                        // Contracts WITHOUT applications
                        html += '<div class="list-section" style="margin-top:15px;">';
                        html += '<div class="list-header" onclick="toggleList(1)"><span>Contracts WITHOUT Applications (' + contractsNoApps.length + ')</span><span class="chevron" id="chev-1">&#x25BC;</span></div>';
                        html += '<div class="list-body" id="list-1">';
                        html += '<div class="search-bar"><input type="text" placeholder="Filter..." oninput="filterList(1, this.value)"/></div>';
                        html += '<div class="list-items" id="items-1">';
                        contractsNoApps.sort(function(a, b) { return a.name.localeCompare(b.name); }).forEach(function(c) {
                            html += '<div class="list-item" data-name="' + c.name.toLowerCase() + '">' + cleanText(c.name) + ' <span style="color:#6B7280;font-size:0.8rem;">(' + cleanText(c.supplier) + ')</span></div>';
                        });
                        html += '</div></div></div>';

                        // Contracts WITH applications
                        var contractsWithApps = [];
                        suppliers.forEach(function(sup) {
                            if (sup.contracts &amp;&amp; sup.contracts.length &gt; 0) {
                                sup.contracts.forEach(function(c) {
                                    var hasApps = false;
                                    var compIds = c.contractCompIds || [];
                                    compIds.forEach(function(compId) {
                                        var comp = compMap[compId];
                                        if (comp &amp;&amp; comp.appElements &amp;&amp; comp.appElements.length > 0) hasApps = true;
                                    });
                                    if (hasApps) {
                                        contractsWithApps.push({name: c.name || c.contract_ref || 'Unnamed', supplier: sup.name});
                                    }
                                });
                            }
                        });
                        html += '<div class="list-section" style="margin-top:15px;">';
                        html += '<div class="list-header" onclick="toggleList(3)"><span>Contracts WITH Applications (' + contractsWithApps.length + ')</span><span class="chevron" id="chev-3">&#x25BC;</span></div>';
                        html += '<div class="list-body" id="list-3">';
                        html += '<div class="search-bar"><input type="text" placeholder="Filter..." oninput="filterList(3, this.value)"/></div>';
                        html += '<div class="list-items" id="items-3">';
                        contractsWithApps.sort(function(a, b) { return a.name.localeCompare(b.name); }).forEach(function(c) {
                            html += '<div class="list-item" data-name="' + c.name.toLowerCase() + '">' + cleanText(c.name) + ' <span style="color:#6B7280;font-size:0.8rem;">(' + cleanText(c.supplier) + ')</span></div>';
                        });
                        html += '</div></div></div>';

                        document.getElementById('mainContent').innerHTML = html;
                    }

                    function toggleList(idx) {
                        document.getElementById('list-' + idx).classList.toggle('open');
                        document.getElementById('chev-' + idx).classList.toggle('open');
                    }

                    function filterList(idx, query) {
                        var items = document.getElementById('items-' + idx).children;
                        var q = query.toLowerCase();
                        for (var i = 0; i &lt; items.length; i++) {
                            items[i].style.display = items[i].getAttribute('data-name').indexOf(q) !== -1 ? '' : 'none';
                        }
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <xsl:call-template name="ViewUserScopingUI"/>
                <div class="view-wrapper">
                    <h1 style="margin-bottom:5px;color:#361A54;">Data Quality Dashboard</h1>
                    <p style="color:#6B7280;margin-bottom:20px;">Coverage gaps: applications without managed services, and contracts without linked applications.</p>
                    <div id="mainContent"><p>Loading data quality metrics...</p></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
