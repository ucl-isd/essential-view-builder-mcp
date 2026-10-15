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

    <!-- ===== Model variables (reusing the slots proven in ucl_cap_data_completeness.xsl) ===== -->
    <xsl:variable name="allCaps" select="/node()/simple_instance[type='Composite_Application_Provider']"/>
    <xsl:variable name="allA2R" select="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']"/>
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Group_Actor','Individual_Actor')]"/>
    <xsl:variable name="allGroupActors" select="/node()/simple_instance[type='Group_Actor']"/>
    <xsl:variable name="allDeliveryModels" select="/node()/simple_instance[type='Application_Delivery_Model']"/>
    <xsl:variable name="allCodebaseStatuses" select="/node()/simple_instance[type='Codebase_Status']"/>
    <xsl:variable name="allDispositions" select="/node()/simple_instance[type='Disposition_Lifecycle_Status']"/>
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allProvRoles" select="/node()/simple_instance[type='Application_Provider_Role']"/>
    <!-- Managed Services (from Xurrent) referenced by al_managed_by_services -->
    <xsl:variable name="allManagedServices" select="/node()/simple_instance[type='Managed_Service']"/>
    <xsl:variable name="allBusRoles" select="/node()/simple_instance[type=('Group_Business_Role','Individual_Business_Role')]"/>
    <xsl:variable name="allElementStyles" select="/node()/simple_instance[type='Element_Style']"/>
    <xsl:variable name="allContracts" select="/node()/simple_instance[type='Contract']"/>
    <!-- Owner stakeholder role identified by name -->
    <xsl:variable name="ownerRole" select="$allBusRoles[own_slot_value[slot_reference='name']/value='Application Organisation Owner']"/>
    <!-- Stakeholder relations keyed by the element (app) they are a stakeholder of -->
    <xsl:key name="stakeRelByElement" match="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']" use="own_slot_value[slot_reference='stakeholder_of_elements']/value"/>
    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>

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

    <!-- Walk up the Group_Actor hierarchy (is_member_of_actor) to find the first actor
         whose name contains 'Portfolio'. If the start actor is itself a Portfolio, return it.
         Falls back to a 'Product'-named actor if no Portfolio is found in the chain. -->
    <xsl:function name="eas:portfolioActor">
        <xsl:param name="actor"/>
        <xsl:variable name="a1" select="$actor"/>
        <xsl:variable name="a2" select="$allGroupActors[name = $a1/own_slot_value[slot_reference='is_member_of_actor']/value]"/>
        <xsl:variable name="a3" select="$allGroupActors[name = $a2/own_slot_value[slot_reference='is_member_of_actor']/value]"/>
        <xsl:variable name="a4" select="$allGroupActors[name = $a3/own_slot_value[slot_reference='is_member_of_actor']/value]"/>
        <xsl:variable name="chain" select="($a1, $a2, $a3, $a4)"/>
        <xsl:variable name="pf" select="$chain[contains(own_slot_value[slot_reference='name']/value,'Portfolio')][1]"/>
        <xsl:variable name="prod" select="$chain[contains(own_slot_value[slot_reference='name']/value,'Product')][1]"/>
        <xsl:sequence select="($pf, $prod)[1]"/>
    </xsl:function>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Application Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1800px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.05rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px;font-weight:800}
                    .subtitle{color:#6B7280;margin-bottom:18px;font-size:0.9rem}
                    /* Controls */
                    .controls{display:flex;gap:14px;flex-wrap:wrap;align-items:center;margin-bottom:14px}
                    .controls input[type=text]{padding:11px 15px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.2rem;min-width:320px}
                    .controls select{padding:11px 15px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.2rem;background:#fff}
                    .controls label{font-weight:700;color:#361A54;font-size:1.2rem}
                    .controls span{font-size:1.1rem}
                    /* Disposition colour key */
                    .disp-key{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px;align-items:center}
                    .disp-key .k-title{font-weight:700;color:#361A54;font-size:1.15rem}
                    .disp-chip{display:inline-flex;align-items:center;gap:7px;font-size:1.1rem;color:#374151}
                    .disp-swatch{width:20px;height:20px;border-radius:4px;border:1px solid rgba(0,0,0,0.12)}
                    /* Table */
                    .tbl-wrap{overflow:auto;max-height:72vh;border:1px solid #E5E7EB;border-radius:10px}
                    table.apps{border-collapse:separate;border-spacing:0;width:100%;font-size:1.15rem;min-width:1100px}
                    table.apps th{background:#361A54;color:#fff;padding:12px 11px;text-align:left;font-weight:600;position:sticky;top:0;z-index:3;font-size:1.1rem}
                    table.apps th.name-col{position:sticky;left:0;z-index:4}
                    table.apps td{padding:12px 11px;border-bottom:1px solid #EEE;vertical-align:top}
                    table.apps td.name-col{position:sticky;left:0;background:#fff;z-index:1;font-weight:700;color:#361A54;white-space:nowrap;cursor:pointer}
                    table.apps tr:hover td{background:#FBF9FF}
                    table.apps tr:hover td.name-col{background:#FBF9FF}
                    .desc-cell{max-width:460px;color:#4B5563;font-size:1.05rem;line-height:1.45}
                    .svc-pill{display:inline-block;background:#E7F8EF;color:#0B7A47;border-radius:14px;padding:3px 11px;font-size:1rem;font-weight:600;margin:0 4px 4px 0}
                    .svc-pill.clickable{cursor:pointer;transition:background 0.15s}
                    .svc-pill.clickable:hover{background:#C7EFD8}
                    .disp-badge{display:inline-block;border-radius:14px;padding:4px 13px;font-size:1.05rem;font-weight:700;white-space:nowrap}
                    .pf-pill{display:inline-block;background:#EDE4FF;color:#361A54;border:1px solid #DDBDFF;border-radius:14px;padding:3px 11px;font-size:1rem;font-weight:600}
                    .empty{color:#9CA3AF;font-style:italic}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    /* Detail sidebar */
                    .sb-overlay{position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(54,26,84,0.35);z-index:999;display:none}
                    .sb-overlay.open{display:block}
                    .sidebar{position:fixed;top:0;right:-520px;width:500px;max-width:94vw;height:100vh;background:#fff;box-shadow:-4px 0 24px rgba(0,0,0,0.18);z-index:1000;transition:right 0.3s ease;overflow-y:auto;padding:28px}
                    .sidebar.open{right:0}
                    .sb-close{position:absolute;top:14px;right:16px;font-size:28px;cursor:pointer;color:#6B7280;background:none;border:none}
                    .sb-kicker{display:inline-block;font-size:0.92rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;color:#fff;background:#0E9E86;padding:5px 14px;border-radius:20px;margin-bottom:10px}
                    .sb-title{color:#361A54;margin:0 0 4px 0;padding-right:30px;font-size:1.9rem;font-weight:800}
                    .sb-stake{margin:0;padding-left:20px;font-size:1.2rem}
                    .sb-stake li{margin-bottom:6px;line-height:1.45}
                    .sb-btns{display:flex;flex-wrap:wrap;gap:10px;margin:14px 0 20px 0}
                    .sb-btn{display:inline-block;text-decoration:none;padding:11px 18px;border-radius:6px;font-weight:600;font-size:1.1rem}
                    .sb-btn.primary{background:#993AFF;color:#fff}
                    .sb-btn.primary:hover{background:#7d1fe0}
                    .sb-btn.secondary{background:#F5F0FF;color:#7d1fe0;border:1px solid #DDBDFF}
                    .sb-btn.secondary:hover{background:#EDE4FF}
                    .sb-row{margin-bottom:18px}
                    .sb-label{font-size:0.95rem;text-transform:uppercase;letter-spacing:0.04em;color:#7d1fe0;font-weight:700;margin-bottom:5px}
                    .sb-value{font-size:1.25rem;color:#222;line-height:1.55}
                    .sb-empty{color:#9CA3AF;font-style:italic}
                    .sb-pillwrap{display:flex;flex-wrap:wrap;gap:6px}
                    .sb-pillwrap .svc-pill{font-size:1.1rem;padding:4px 13px}
                    .sb-contract{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:11px 15px;display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:6px}
                    .sb-contract .ct-name{font-weight:600;color:#361A54;font-size:1.15rem}
                    .sb-contract .ct-end{font-size:1rem;color:#6B7280;white-space:nowrap;flex-shrink:0}
                </style>
                <script type="text/javascript">
                    var APPS = [<xsl:for-each select="$allCaps">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="cap" select="current()"/>
                        <!-- Owner stakeholder relations (both link directions), classified as Application Organisation Owner -->
                        <xsl:variable name="relsViaElement" select="key('stakeRelByElement', $cap/name)"/>
                        <xsl:variable name="relsViaSlot" select="$allA2R[name = $cap/own_slot_value[slot_reference='stakeholders']/value]"/>
                        <xsl:variable name="rels" select="$relsViaElement | $relsViaSlot"/>
                        <xsl:variable name="ownerRels" select="$rels[own_slot_value[slot_reference='act_to_role_to_role']/value = $ownerRole/name]"/>
                        <xsl:variable name="ownerActors" select="$allActors[name = $ownerRels/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
                        <!-- Portfolio: walk up the owner Group_Actor hierarchy to the containing Portfolio -->
                        <xsl:variable name="ownerGroupActors" select="$ownerActors[type='Group_Actor']"/>
                        <xsl:variable name="portfolioActor" select="(for $o in $ownerGroupActors return eas:portfolioActor($o))[1]"/>
                        <!-- Lookups -->
                        <xsl:variable name="supplier" select="$allSuppliers[name=$cap/own_slot_value[slot_reference='ap_supplier']/value]"/>
                        <xsl:variable name="dm" select="$allDeliveryModels[name=$cap/own_slot_value[slot_reference='ap_delivery_model']/value]"/>
                        <xsl:variable name="cb" select="$allCodebaseStatuses[name=$cap/own_slot_value[slot_reference='ap_codebase_status']/value]"/>
                        <xsl:variable name="disp" select="$allDispositions[name=$cap/own_slot_value[slot_reference='ap_disposition_lifecycle_status']/value]"/>
                        <xsl:variable name="dispStyle" select="$allElementStyles[name=$disp[1]/own_slot_value[slot_reference='element_styling_classes']/value]"/>
                        <!-- Services: use al_managed_by_services (Managed_Service instances from Xurrent).
                             Carry id + name here; full detail is in the SERVICES global map below. -->
                        <xsl:variable name="services" select="$allManagedServices[name = $cap/own_slot_value[slot_reference='al_managed_by_services']/value]"/>
                        <!-- Contracts with this app's supplier -->
                        <xsl:variable name="supplierContracts" select="$allContracts[own_slot_value[slot_reference='contract_supplier']/value = $supplier/name]"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($cap/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='description']/value))"/>",
                        "supplier":"<xsl:value-of select="eas:jsonText(string($supplier[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "deliveryModel":"<xsl:value-of select="eas:jsonText(string($dm[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "codebase":"<xsl:value-of select="eas:jsonText(string($cb[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "disposition":"<xsl:value-of select="eas:jsonText(string($disp[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "dispColour":"<xsl:value-of select="eas:jsonText(string($dispStyle[1]/own_slot_value[slot_reference='element_style_colour']/value))"/>",
                        "dispTextColour":"<xsl:value-of select="eas:jsonText(string($dispStyle[1]/own_slot_value[slot_reference='element_style_text_colour']/value))"/>",
                        "portfolio":"<xsl:value-of select="eas:jsonText(string($portfolioActor[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "services":[<xsl:for-each select="$services">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                        "contracts":[<xsl:for-each select="$supplierContracts">{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","endDate":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='contract_end_date_ISO8601']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    // Managed Service detail (for the service pop-out): name, description, criticality, stakeholders (relation_name)
                    var SERVICES = [<xsl:for-each select="$allManagedServices">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="ms" select="current()"/>
                        <!-- Stakeholder relations: via the MS 'stakeholders' slot and via stakeholder_of_elements -->
                        <xsl:variable name="msRelsViaSlot" select="$allA2R[name = $ms/own_slot_value[slot_reference='stakeholders']/value]"/>
                        <xsl:variable name="msRelsViaElement" select="$allA2R[own_slot_value[slot_reference='stakeholder_of_elements']/value = $ms/name]"/>
                        <xsl:variable name="msRels" select="$msRelsViaSlot | $msRelsViaElement"/>
                        <!-- Criticality: slot points to an instance; resolve its name -->
                        <xsl:variable name="crit" select="key('instByName', $ms/own_slot_value[slot_reference='ms_criticality']/value)"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($ms/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($ms/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($ms/own_slot_value[slot_reference='description']/value))"/>",
                        "criticality":"<xsl:value-of select="eas:jsonText(string($crit[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "stakeholders":[<xsl:for-each select="$msRels">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='relation_name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;').replace(/"/g,'&amp;quot;'); }

                    var APP_BY_ID = {};
                    APPS.forEach(function(a){ APP_BY_ID[a.id] = a; });
                    var SERVICE_BY_ID = {};
                    SERVICES.forEach(function(s){ SERVICE_BY_ID[s.id] = s; });

                    // Fallback disposition colours (confirmed in model) if style is missing
                    var DISP_FALLBACK = { 'Tolerate':'#89d1ff', 'Invest':'#97dd40', 'Migrate':'#e1c933', 'Eliminate':'#ee3939' };
                    function dispBg(a){ return a.dispColour || DISP_FALLBACK[a.disposition] || '#E5E7EB'; }
                    function dispText(a){ if (a.dispTextColour) return a.dispTextColour; return '#1f2937'; }

                    function buildFilters(){
                        var sel = document.getElementById('pfFilter');
                        var set = {};
                        APPS.forEach(function(a){ if (a.portfolio) set[a.portfolio] = true; });
                        Object.keys(set).sort().forEach(function(k){
                            var opt = document.createElement('option'); opt.value = k; opt.textContent = k; sel.appendChild(opt);
                        });
                        sel.addEventListener('change', renderTable);
                        document.getElementById('search').addEventListener('input', renderTable);
                    }

                    function renderDispKey(){
                        var order = ['Tolerate','Invest','Migrate','Eliminate'];
                        var html = '&lt;span class="k-title"&gt;Disposition (TIME):&lt;/span&gt;';
                        order.forEach(function(name){
                            var bg = DISP_FALLBACK[name];
                            // prefer a live colour from data if present
                            var sample = APPS.find(function(a){ return a.disposition === name &amp;&amp; a.dispColour; });
                            if (sample) bg = sample.dispColour;
                            html += '&lt;span class="disp-chip"&gt;&lt;span class="disp-swatch" style="background:' + bg + ';"&gt;&lt;/span&gt;' + esc(name) + '&lt;/span&gt;';
                        });
                        document.getElementById('dispKey').innerHTML = html;
                    }

                    function renderTable(){
                        var filterText = (document.getElementById('search').value || '').toLowerCase();
                        var pf = document.getElementById('pfFilter').value;
                        var rows = APPS.filter(function(a){
                            if (pf !== 'all' &amp;&amp; a.portfolio !== pf) return false;
                            if (filterText){
                                var svcNames = (a.services || []).map(function(s){ return s.name; }).join(' ');
                                var hay = (a.name + ' ' + a.description + ' ' + a.supplier + ' ' + svcNames).toLowerCase();
                                if (hay.indexOf(filterText) === -1) return false;
                            }
                            return true;
                        });
                        var container = document.getElementById('tableWrap');
                        if (!rows.length){ container.innerHTML = '&lt;div class="no-data"&gt;No applications match the current filters.&lt;/div&gt;'; document.getElementById('shownCount').textContent = 0; return; }
                        var html = '&lt;table class="apps"&gt;&lt;thead&gt;&lt;tr&gt;';
                        html += '&lt;th class="name-col"&gt;Application&lt;/th&gt;&lt;th&gt;Portfolio&lt;/th&gt;&lt;th&gt;Description&lt;/th&gt;&lt;th&gt;Supplier&lt;/th&gt;&lt;th&gt;Services&lt;/th&gt;&lt;th&gt;Disposition&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                        rows.forEach(function(a){
                            html += '&lt;tr&gt;';
                            html += '&lt;td class="name-col" onclick="openApp(\'' + a.id + '\')"&gt;' + esc(a.name) + '&lt;/td&gt;';
                            html += '&lt;td&gt;' + (a.portfolio ? '&lt;span class="pf-pill"&gt;' + esc(a.portfolio) + '&lt;/span&gt;' : '&lt;span class="empty"&gt;None&lt;/span&gt;') + '&lt;/td&gt;';
                            html += '&lt;td class="desc-cell"&gt;' + (a.description ? esc(a.description) : '&lt;span class="empty"&gt;No description&lt;/span&gt;') + '&lt;/td&gt;';
                            html += '&lt;td&gt;' + (a.supplier ? esc(a.supplier) : '&lt;span class="empty"&gt;Not set&lt;/span&gt;') + '&lt;/td&gt;';
                            html += '&lt;td&gt;';
                            if (a.services &amp;&amp; a.services.length){ a.services.forEach(function(s){ html += '&lt;span class="svc-pill clickable" onclick="openService(\'' + s.id + '\')" title="View managed service details"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); }
                            else html += '&lt;span class="empty"&gt;None&lt;/span&gt;';
                            html += '&lt;/td&gt;';
                            if (a.disposition){
                                html += '&lt;td&gt;&lt;span class="disp-badge" style="background:' + dispBg(a) + ';color:' + dispText(a) + ';"&gt;' + esc(a.disposition) + '&lt;/span&gt;&lt;/td&gt;';
                            } else {
                                html += '&lt;td&gt;&lt;span class="empty"&gt;Not set&lt;/span&gt;&lt;/td&gt;';
                            }
                            html += '&lt;/tr&gt;';
                        });
                        html += '&lt;/tbody&gt;&lt;/table&gt;';
                        container.innerHTML = html;
                        document.getElementById('shownCount').textContent = rows.length;
                    }

                    function detailRow(label, value){
                        return '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;' + esc(label) + '&lt;/div&gt;&lt;div class="sb-value"&gt;' + (value ? esc(value) : '&lt;span class="sb-empty"&gt;Not set&lt;/span&gt;') + '&lt;/div&gt;&lt;/div&gt;';
                    }

                    function openApp(id){
                        var a = APP_BY_ID[id];
                        if (!a) return;
                        var html = '&lt;h2 class="sb-title"&gt;' + esc(a.name) + '&lt;/h2&gt;';
                        if (a.portfolio) html += '&lt;div&gt;&lt;span class="pf-pill"&gt;' + esc(a.portfolio) + '&lt;/span&gt;&lt;/div&gt;';
                        // Action buttons
                        var depUrl = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(a.id) + '&amp;cl=en-gb&amp;XSL=application/core_al_app_provider_info_deps_model.xsl';
                        var editUrl = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(a.id) + '&amp;cl=en-gb&amp;XSL=ess_editor.xsl&amp;LABEL=' + encodeURIComponent('Application Editor for EAs') + '&amp;EDITOR=store_992_Class314';
                        html += '&lt;div class="sb-btns"&gt;';
                        html += '&lt;a class="sb-btn primary" href="' + depUrl + '" target="_blank" rel="noopener"&gt;View Application Dependency Model &#8594;&lt;/a&gt;';
                        html += '&lt;a class="sb-btn secondary" href="' + editUrl + '" target="_blank" rel="noopener"&gt;&#9998; Edit Application&lt;/a&gt;';
                        html += '&lt;/div&gt;';
                        html += detailRow('Description', a.description);
                        html += detailRow('Supplier', a.supplier);
                        html += detailRow('Delivery Model', a.deliveryModel);
                        html += detailRow('Codebase Status', a.codebase);
                        // Disposition with colour
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Disposition (TIME)&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.disposition){ html += '&lt;span class="disp-badge" style="background:' + dispBg(a) + ';color:' + dispText(a) + ';"&gt;' + esc(a.disposition) + '&lt;/span&gt;'; }
                        else html += '&lt;span class="sb-empty"&gt;Not set&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        // Services (click a pill for managed service detail)
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Services&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.services &amp;&amp; a.services.length){ html += '&lt;div class="sb-pillwrap"&gt;'; a.services.forEach(function(s){ html += '&lt;span class="svc-pill clickable" onclick="openService(\'' + s.id + '\')" title="View managed service details"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); html += '&lt;/div&gt;'; }
                        else html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        // Contracts (with this app's supplier)
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Contracts (with ' + (a.supplier ? esc(a.supplier) : 'supplier') + ')&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.contracts &amp;&amp; a.contracts.length){
                            a.contracts.forEach(function(ct){
                                html += '&lt;div class="sb-contract"&gt;&lt;span class="ct-name"&gt;' + esc(ct.name) + '&lt;/span&gt;&lt;span class="ct-end"&gt;' + (ct.endDate ? ('ends ' + esc(ct.endDate)) : 'no end date') + '&lt;/span&gt;&lt;/div&gt;';
                            });
                        } else html += '&lt;span class="sb-empty"&gt;None found for this supplier&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        showSidebar(html);
                    }

                    // Managed service pop-out: Name, Description, Stakeholders (relation_name), Criticality
                    function openService(id){
                        var s = SERVICE_BY_ID[id];
                        if (!s) return;
                        var html = '&lt;div class="sb-kicker"&gt;Managed Service&lt;/div&gt;';
                        html += '&lt;h2 class="sb-title"&gt;' + esc(s.name) + '&lt;/h2&gt;';
                        html += detailRow('Description', s.description);
                        html += detailRow('Criticality', s.criticality);
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Stakeholders&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (s.stakeholders &amp;&amp; s.stakeholders.length){
                            html += '&lt;ul class="sb-stake"&gt;';
                            s.stakeholders.forEach(function(r){ html += '&lt;li&gt;' + esc(r) + '&lt;/li&gt;'; });
                            html += '&lt;/ul&gt;';
                        } else html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        showSidebar(html);
                    }

                    function showSidebar(html){
                        document.getElementById('sidebarContent').innerHTML = html;
                        document.getElementById('sidebar').classList.add('open');
                        document.getElementById('sbOverlay').classList.add('open');
                    }

                    function closeSidebar(){
                        document.getElementById('sidebar').classList.remove('open');
                        document.getElementById('sbOverlay').classList.remove('open');
                    }

                    $(document).ready(function(){
                        console.log('Applications:', APPS);
                        buildFilters();
                        renderDispKey();
                        renderTable();
                        document.addEventListener('keydown', function(e){ if (e.key === 'Escape') closeSidebar(); });
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Application Explorer</h1>
                    <p class="subtitle">Composite Application Providers with supplier, services and TIME disposition. The portfolio is derived from the owner organisation, walking up the actor hierarchy to the containing Portfolio. Click an application for full details.</p>
                    <div class="disp-key" id="dispKey"></div>
                    <div class="controls">
                        <input type="text" id="search" placeholder="Search by name, description, supplier or service..."/>
                        <label for="pfFilter">Portfolio:</label>
                        <select id="pfFilter"><option value="all">All</option></select>
                        <span style="color:#6B7280;">Showing <strong id="shownCount">0</strong></span>
                    </div>
                    <div class="tbl-wrap" id="tableWrap"><p>Loading...</p></div>
                </div>
                <div class="sb-overlay" id="sbOverlay" onclick="closeSidebar()"></div>
                <div class="sidebar" id="sidebar">
                    <button class="sb-close" onclick="closeSidebar()">&#215;</button>
                    <div id="sidebarContent"></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
