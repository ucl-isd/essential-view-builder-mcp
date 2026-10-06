<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    <xsl:import href="../common/core_js_functions.xsl"/>
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>
    <xsl:include href="../common/core_footer.xsl"/>
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>

    <!-- ===== Model variables ===== -->
    <xsl:variable name="allCaps" select="/node()/simple_instance[type='Composite_Application_Provider']"/>
    <xsl:variable name="allA2R" select="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']"/>
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Group_Actor','Individual_Actor')]"/>
    <xsl:variable name="allDeliveryModels" select="/node()/simple_instance[type='Application_Delivery_Model']"/>
    <xsl:variable name="allCodebaseStatuses" select="/node()/simple_instance[type='Codebase_Status']"/>
    <xsl:variable name="allDispositions" select="/node()/simple_instance[type='Disposition_Lifecycle_Status']"/>
    <xsl:variable name="allLifecycles" select="/node()/simple_instance[type='Lifecycle_Status']"/>
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <xsl:variable name="allPurposes" select="/node()/simple_instance[type='Application_Provider_Purpose']"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allBusRoles" select="/node()/simple_instance[type=('Group_Business_Role','Individual_Business_Role')]"/>
    <!-- Stakeholder role instances identified by name (ids differ across baselines) -->
    <xsl:variable name="ownerRole" select="$allBusRoles[own_slot_value[slot_reference='name']/value='Application Organisation Owner']"/>
    <xsl:variable name="userRole" select="$allBusRoles[own_slot_value[slot_reference='name']/value='Application Organisation User']"/>
    <!-- Stakeholder relations keyed by the element (app) they are a stakeholder of -->
    <xsl:key name="stakeRelByElement" match="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']" use="own_slot_value[slot_reference='stakeholder_of_elements']/value"/>

    <!-- Keys -->
    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>
    <xsl:key name="a2rByName" match="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']" use="name"/>
    <xsl:key name="actorByName" match="/node()/simple_instance[type=('Group_Actor','Individual_Actor')]" use="name"/>

    <!-- JSON-safe text escaper -->
    <xsl:function name="eas:jsonText">
        <xsl:param name="theString"/>
        <xsl:variable name="s1" select="replace(string($theString), '\\', '\\\\')"/>
        <xsl:variable name="s2" select="replace($s1, '&quot;', '\\&quot;')"/>
        <xsl:variable name="s3" select="replace($s2, '&#10;', ' ')"/>
        <xsl:variable name="s4" select="replace($s3, '&#13;', ' ')"/>
        <xsl:variable name="s5" select="replace($s4, '&#9;', ' ')"/>
        <xsl:value-of select="$s5"/>
    </xsl:function>

    <!-- Helper: does an instance have a non-empty value for a slot? -->
    <xsl:function name="eas:hasVal" as="xs:boolean">
        <xsl:param name="inst"/>
        <xsl:param name="slot"/>
        <xsl:sequence select="exists($inst/own_slot_value[slot_reference=$slot]/value[normalize-space(.)!=''])"/>
    </xsl:function>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>Composite Application Provider - Data Completeness</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1800px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.05rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.05rem}
                    /* Guidance panel */
                    .guidance{background:#FBF9FF;border:1px solid #DDBDFF;border-radius:10px;padding:4px 20px;margin-bottom:22px}
                    .guidance > summary{cursor:pointer;font-weight:700;color:#361A54;font-size:1.15rem;padding:10px 0;list-style:none}
                    .guidance > summary::-webkit-details-marker{display:none}
                    .guidance > summary::before{content:'\25B8';display:inline-block;margin-right:10px;color:#993AFF;transition:transform 0.15s}
                    .guidance[open] > summary::before{transform:rotate(90deg)}
                    .guidance-body{padding:4px 0 14px 0;color:#374151;line-height:1.5}
                    .guidance-body h3{color:#361A54;font-size:1.05rem;margin:16px 0 4px 0}
                    .guidance-body h3:first-child{margin-top:6px}
                    .guidance-body p{margin:0 0 6px 0;font-size:0.98rem}
                    .guidance-body a{color:#7d1fe0;font-weight:600}
                    .guidance-body a:hover{text-decoration:underline}
                    /* Summary header */
                    .summary{display:flex;gap:20px;flex-wrap:wrap;margin-bottom:24px;align-items:stretch}
                    .summary-count{flex:0 0 auto;background:linear-gradient(135deg,#361A54,#5B2A87);color:#fff;border-radius:12px;padding:20px 28px;display:flex;flex-direction:column;justify-content:center;min-width:180px}
                    .summary-count .big{font-size:2.8rem;font-weight:800;line-height:1}
                    .summary-count .lbl{font-size:0.95rem;opacity:0.85;margin-top:6px}
                    .overall-rag-wrap{display:flex;flex-direction:column;gap:4px;margin-top:14px;padding-top:12px;border-top:1px solid rgba(255,255,255,0.25)}
                    .overall-rag-lbl{font-size:0.8rem;opacity:0.85}
                    .summary-count .pf-rag{align-self:flex-start}
                    .summary-portfolios{flex:1;min-width:460px;background:#fff;border:1px solid #E5E7EB;border-radius:12px;padding:16px 20px}
                    .summary-portfolios h3{color:#361A54;margin:0 0 12px 0;font-size:1.1rem}
                    .pf-head-note{font-weight:400;font-size:0.8rem;color:#9CA3AF}
                    .pf-bar-row{display:flex;align-items:center;gap:12px;margin-bottom:8px}
                    .pf-bar-name{flex:0 0 230px;font-size:0.95rem;color:#374151;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
                    .pf-bar-track{flex:1;background:#F0EAFB;border-radius:10px;height:20px;position:relative;overflow:hidden}
                    .pf-bar-fill{position:absolute;top:0;left:0;height:100%;background:#993AFF;border-radius:10px}
                    .pf-bar-val{flex:0 0 110px;text-align:right;font-size:0.9rem;color:#6B7280;white-space:nowrap}
                    .pf-rag{flex:0 0 auto;min-width:52px;text-align:center;color:#fff;font-weight:700;font-size:0.9rem;border-radius:12px;padding:3px 10px}
                    /* Controls */
                    .controls{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-bottom:14px}
                    .controls input[type=text]{padding:9px 13px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1rem;min-width:260px}
                    .controls select{padding:9px 13px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1rem;background:#fff}
                    .controls label{font-weight:600;color:#361A54}
                    /* Table - scrolls within its own container so the header row stays visible */
                    .tbl-wrap{overflow:auto;max-height:70vh;border:1px solid #E5E7EB;border-radius:10px}
                    table.completeness{border-collapse:separate;border-spacing:0;width:100%;font-size:0.95rem;min-width:1500px}
                    table.completeness th{background:#361A54;color:#fff;padding:10px 8px;text-align:center;font-weight:600;position:sticky;top:0;z-index:3;box-shadow:0 2px 0 rgba(0,0,0,0.15)}
                    table.completeness th.name-col,table.completeness th.pf-col{text-align:left}
                    /* keep the Application column visible when scrolling sideways too */
                    table.completeness th.name-col{position:sticky;left:0;z-index:4}
                    table.completeness td.name-col{position:sticky;left:0;background:#fff;z-index:1}
                    table.completeness tr:hover td.name-col{background:#FBF9FF}
                    table.completeness td{padding:9px 8px;border-bottom:1px solid #EEE;text-align:center;vertical-align:middle}
                    table.completeness td.name-col{text-align:left;font-weight:600;color:#361A54;white-space:nowrap}
                    table.completeness td.pf-col{text-align:left;white-space:nowrap;color:#374151}
                    table.completeness tr:hover td{background:#FBF9FF}
                    .cell{display:inline-flex;align-items:center;justify-content:center;width:26px;height:26px;border-radius:50%;font-weight:700;font-size:0.95rem}
                    .cell.ok{background:#D7F5DF;color:#0B7A47}
                    .cell.no{background:#FBE0DE;color:#C02B22}
                    .score{font-weight:700;border-radius:12px;padding:3px 10px;color:#fff;font-size:0.9rem}
                    .score.hi{background:#1AAB40}
                    .score.mid{background:#F59E0B}
                    .score.lo{background:#DC2626}
                    .pf-pill{display:inline-block;background:#EDE4FF;color:#361A54;border:1px solid #DDBDFF;border-radius:14px;padding:2px 10px;font-size:0.85rem;font-weight:600}
                    .pf-none{color:#C02B22;font-style:italic;font-weight:600}
                    .legend{margin:10px 0 0 0;font-size:0.85rem;color:#6B7280}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                </style>
                <script type="text/javascript">
                    var CAPS = [<xsl:for-each select="$allCaps">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="cap" select="current()"/>
                        <!-- Stakeholder relations for this app: ACTOR_TO_ROLE_RELATION whose
                             stakeholder_of_elements includes this app. Classify by the linked business role
                             (act_to_role_to_role -> 'Application Organisation Owner' / 'Application Organisation User'). -->
                        <xsl:variable name="rels" select="key('stakeRelByElement', $cap/name)"/>
                        <xsl:variable name="ownerRels" select="$rels[own_slot_value[slot_reference='act_to_role_to_role']/value = $ownerRole/name]"/>
                        <xsl:variable name="userRels" select="$rels[own_slot_value[slot_reference='act_to_role_to_role']/value = $userRole/name]"/>
                        <!-- Actors (owner / user) referenced by those relations -->
                        <xsl:variable name="ownerActors" select="$allActors[name = $ownerRels/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
                        <xsl:variable name="userActors" select="$allActors[name = $userRels/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
                        <!-- Portfolio owner: an owner actor that is a Group_Actor whose name contains 'Portfolio' -->
                        <xsl:variable name="portfolioOwners" select="$ownerActors[type='Group_Actor'][contains(own_slot_value[slot_reference='name']/value,'Portfolio')]"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($cap/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='name']/value))"/>",
                        "hasName":<xsl:value-of select="eas:hasVal($cap,'name')"/>,
                        "hasDescription":<xsl:value-of select="eas:hasVal($cap,'description')"/>,
                        "hasDeliveryModel":<xsl:value-of select="eas:hasVal($cap,'ap_delivery_model')"/>,
                        "hasLifecycle":<xsl:value-of select="eas:hasVal($cap,'lifecycle_status_application_provider')"/>,
                        "hasServices":<xsl:value-of select="eas:hasVal($cap,'provides_application_services')"/>,
                        "hasCodebase":<xsl:value-of select="eas:hasVal($cap,'ap_codebase_status')"/>,
                        "hasSupplier":<xsl:value-of select="eas:hasVal($cap,'ap_supplier')"/>,
                        "hasPurpose":<xsl:value-of select="eas:hasVal($cap,'application_provider_purpose')"/>,
                        "hasDisposition":<xsl:value-of select="eas:hasVal($cap,'ap_disposition_lifecycle_status')"/>,
                        "hasManagedServices":<xsl:value-of select="eas:hasVal($cap,'al_managed_by_services')"/>,
                        "hasOwner":<xsl:value-of select="exists($ownerActors)"/>,
                        "hasUser":<xsl:value-of select="exists($userActors)"/>,
                        "hasPortfolioOwner":<xsl:value-of select="exists($portfolioOwners)"/>,
                        "ownerNames":[<xsl:for-each select="$ownerActors">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                        "userNames":[<xsl:for-each select="$userActors">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                        "portfolio":"<xsl:value-of select="eas:jsonText(string($portfolioOwners[1]/own_slot_value[slot_reference='name']/value))"/>"
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }

                    // The completeness properties in display order. "owner" and "user" check the stakeholder roles.
                    var PROPS = [
                        {key:'hasName', label:'Name'},
                        {key:'hasDescription', label:'Description'},
                        {key:'hasDeliveryModel', label:'Delivery Model'},
                        {key:'hasLifecycle', label:'Lifecycle Status'},
                        {key:'hasServices', label:'Provides App Services'},
                        {key:'hasCodebase', label:'Codebase Status'},
                        {key:'hasSupplier', label:'Supplier'},
                        {key:'hasPurpose', label:'Purpose'},
                        {key:'hasDisposition', label:'Disposition (TIME)'},
                        {key:'hasManagedServices', label:'Managed By Services'},
                        {key:'hasOwner', label:'Owner Org'},
                        {key:'hasUser', label:'Org User'},
                        {key:'hasPortfolioOwner', label:'Portfolio Owner'}
                    ];

                    function completeness(c){
                        var ok = 0;
                        PROPS.forEach(function(p){ if (c[p.key]) ok++; });
                        return {ok: ok, total: PROPS.length, pct: Math.round(ok / PROPS.length * 100)};
                    }

                    function scoreClass(pct){ if (pct &gt;= 90) return 'hi'; if (pct &gt;= 60) return 'mid'; return 'lo'; }

                    // RAG colour from a completeness %
                    function ragColour(pct){ if (pct &gt;= 90) return '#1AAB40'; if (pct &gt;= 60) return '#F59E0B'; return '#DC2626'; }
                    // Average completeness % across a set of apps
                    function avgCompleteness(apps){
                        if (!apps.length) return 0;
                        var sum = 0; apps.forEach(function(c){ sum += completeness(c).pct; });
                        return Math.round(sum / apps.length);
                    }

                    // ===== Summary header =====
                    function renderSummary(){
                        document.getElementById('capTotal').textContent = CAPS.length;
                        // Overall RAG completeness
                        var overallPct = avgCompleteness(CAPS);
                        var ragEl = document.getElementById('overallRag');
                        ragEl.textContent = overallPct + '%';
                        ragEl.style.background = ragColour(overallPct);
                        // Group apps by portfolio
                        var groups = {};
                        var noPfApps = [];
                        CAPS.forEach(function(c){
                            if (c.hasPortfolioOwner &amp;&amp; c.portfolio){ (groups[c.portfolio] = groups[c.portfolio] || []).push(c); }
                            else noPfApps.push(c);
                        });
                        var rows = Object.keys(groups).map(function(k){ return {name:k, apps:groups[k]}; });
                        rows.sort(function(a,b){ return b.apps.length - a.apps.length; });
                        if (noPfApps.length &gt; 0) rows.push({name:'No portfolio owner', apps:noPfApps, none:true});
                        var total = CAPS.length || 1;
                        var html = '';
                        rows.forEach(function(r){
                            var n = r.apps.length;
                            var pct = Math.round(n / total * 100);
                            var comp = avgCompleteness(r.apps);
                            html += '&lt;div class="pf-bar-row"&gt;';
                            html += '&lt;div class="pf-bar-name"' + (r.none ? ' style="color:#C02B22;"' : '') + '&gt;' + esc(r.name) + '&lt;/div&gt;';
                            html += '&lt;div class="pf-bar-track"&gt;&lt;div class="pf-bar-fill"' + (r.none ? ' style="width:' + pct + '%;background:#C02B22;"' : ' style="width:' + pct + '%;"') + '&gt;&lt;/div&gt;&lt;/div&gt;';
                            html += '&lt;div class="pf-bar-val"&gt;' + n + ' (' + pct + '%)&lt;/div&gt;';
                            html += '&lt;div class="pf-rag" style="background:' + ragColour(comp) + ';" title="Average data completeness for this portfolio"&gt;' + comp + '%&lt;/div&gt;';
                            html += '&lt;/div&gt;';
                        });
                        document.getElementById('pfSplit').innerHTML = html;
                        // Portfolio filter options
                        var sel = document.getElementById('pfFilter');
                        rows.forEach(function(r){
                            var opt = document.createElement('option');
                            opt.value = r.none ? '__none__' : r.name; opt.textContent = r.name + ' (' + r.apps.length + ')';
                            sel.appendChild(opt);
                        });
                    }

                    // ===== Table =====
                    function cell(ok){ return '&lt;span class="cell ' + (ok ? 'ok' : 'no') + '" title="' + (ok ? 'Present' : 'Missing') + '"&gt;' + (ok ? '&#10003;' : '&#10007;') + '&lt;/span&gt;'; }

                    function renderTable(){
                        var filterText = (document.getElementById('search').value || '').toLowerCase();
                        var pf = document.getElementById('pfFilter').value;
                        var onlyIncomplete = document.getElementById('incompleteOnly').checked;
                        var rows = CAPS.filter(function(c){
                            if (filterText &amp;&amp; c.name.toLowerCase().indexOf(filterText) === -1) return false;
                            if (pf === '__none__'){ if (c.hasPortfolioOwner) return false; }
                            else if (pf !== 'all'){ if (c.portfolio !== pf) return false; }
                            if (onlyIncomplete &amp;&amp; completeness(c).ok === PROPS.length) return false;
                            return true;
                        });
                        var container = document.getElementById('tableWrap');
                        if (!rows.length){ container.innerHTML = '&lt;div class="no-data"&gt;No composite application providers match.&lt;/div&gt;'; return; }
                        var html = '&lt;table class="completeness"&gt;&lt;thead&gt;&lt;tr&gt;';
                        html += '&lt;th class="name-col"&gt;Application&lt;/th&gt;&lt;th class="pf-col"&gt;Portfolio&lt;/th&gt;';
                        PROPS.forEach(function(p){ html += '&lt;th&gt;' + esc(p.label) + '&lt;/th&gt;'; });
                        html += '&lt;th&gt;Complete&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                        rows.forEach(function(c){
                            var comp = completeness(c);
                            html += '&lt;tr&gt;';
                            html += '&lt;td class="name-col"&gt;' + esc(c.name) + '&lt;/td&gt;';
                            html += '&lt;td class="pf-col"&gt;' + (c.hasPortfolioOwner ? '&lt;span class="pf-pill"&gt;' + esc(c.portfolio) + '&lt;/span&gt;' : '&lt;span class="pf-none"&gt;None&lt;/span&gt;') + '&lt;/td&gt;';
                            PROPS.forEach(function(p){ html += '&lt;td&gt;' + cell(c[p.key]) + '&lt;/td&gt;'; });
                            html += '&lt;td&gt;&lt;span class="score ' + scoreClass(comp.pct) + '"&gt;' + comp.ok + '/' + comp.total + '&lt;/span&gt;&lt;/td&gt;';
                            html += '&lt;/tr&gt;';
                        });
                        html += '&lt;/tbody&gt;&lt;/table&gt;';
                        container.innerHTML = html;
                        document.getElementById('shownCount').textContent = rows.length;
                    }

                    $(document).ready(function(){
                        console.log('Composite App Providers:', CAPS);
                        renderSummary();
                        renderTable();
                        document.getElementById('search').addEventListener('input', renderTable);
                        document.getElementById('pfFilter').addEventListener('change', renderTable);
                        document.getElementById('incompleteOnly').addEventListener('change', renderTable);
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>Composite Application Provider &#8212; Data Completeness</h1>
                    <p class="subtitle">Completeness check of key properties for every Composite Application Provider. The portfolio is taken from the owner-organisation stakeholder (a Group Actor named "... (Portfolio)").</p>
                    <details class="guidance" open="open">
                        <summary>Updating the Application Catalogue &#8212; guidance</summary>
                        <div class="guidance-body">
                            <h3>Application Family</h3>
                            <p>Fairly ad-hoc grouping of applications, can be multiple entry. E.g. MS 365</p>
                            <h3>Supplier</h3>
                            <p>Use the existing supplier list wherever possible as this includes entries from contract database and will link to contracts via supplier, supplier should be who we buy from not manufacturer. Add new if needed.</p>
                            <h3>al managed by services</h3>
                            <p>Select the service or services (from Xurrent) that manage this application</p>
                            <h3>Modules</h3>
                            <p>Composite application provider from the database. These are discrete modules within the application that could be replaced and the function done elsewhere. E.g. Departmental Transactions within Oracle EBS</p>
                            <h3>Application Functionality (Services)</h3>
                            <p>The thing that the application primarily delivers. These are high level and taken from the HERM application capability model. Find the most relevant from the existing <a href="https://ucl.essentialintelligence.com/viewer/8b3b72ca41670a212b09_1/report?XML=reportXML.xml&amp;XSL=application/core_al_app_service_list_by_name.xsl" target="_blank" rel="noopener">Application Services</a></p>
                            <h3>Stakeholders</h3>
                            <p>One or more user organisation. Wherever possible use the <a href="https://ucl.essentialintelligence.com/viewer/8b3b72ca41670a212b09_1/report?XML=reportXML.xml&amp;XSL=user/ucl_hierarchy_explorer.xsl&amp;cl=en-gb" target="_blank" rel="noopener">organisational hierarchy</a>. <strong>This is important for linking apps to processes and capabilities so give it some thought</strong>.</p>
                            <p><strong>Minimum one product team for owner organisation</strong></p>
                        </div>
                    </details>
                    <div class="summary">
                        <div class="summary-count">
                            <span class="big" id="capTotal">0</span>
                            <span class="lbl">Composite Application Providers</span>
                            <div class="overall-rag-wrap"><span class="overall-rag-lbl">Overall completeness</span><span class="pf-rag" id="overallRag">0%</span></div>
                        </div>
                        <div class="summary-portfolios">
                            <h3>Split by portfolio (owner organisation) <span class="pf-head-note">count (% of total) &#183; RAG = avg completeness</span></h3>
                            <div id="pfSplit"></div>
                        </div>
                    </div>
                    <div class="controls">
                        <input type="text" id="search" placeholder="Search by name..."/>
                        <label for="pfFilter">Portfolio:</label>
                        <select id="pfFilter"><option value="all">All</option></select>
                        <label><input type="checkbox" id="incompleteOnly"/> Incomplete only</label>
                        <span style="color:#6B7280;">Showing <strong id="shownCount">0</strong></span>
                    </div>
                    <div class="tbl-wrap" id="tableWrap"><p>Loading...</p></div>
                    <p class="legend">&#10003; = property present &#160;&#160; &#10007; = missing. "Owner Org" / "Org User" check for stakeholder relations ending in "Application Organisation Owner" / "Application Organisation User". "Portfolio Owner" requires the owner to be a Group Actor named "... (Portfolio)".</p>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
