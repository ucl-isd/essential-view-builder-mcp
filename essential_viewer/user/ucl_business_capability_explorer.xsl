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

    <!-- ===== Model variables (confirmed via live diagnostics on Student Recruitment) ===== -->
    <xsl:variable name="allBusCaps" select="/node()/simple_instance[type='Business_Capability']"/>
    <xsl:variable name="allBusProcs" select="/node()/simple_instance[type=('Business_Process','Business_Activity')]"/>
    <xsl:variable name="allFlows" select="/node()/simple_instance[type='Business_Process_Flow']"/>
    <xsl:variable name="allUsages" select="/node()/simple_instance[type=('Business_Process_Usage','Business_Activity_Usage')]"/>
    <xsl:variable name="allOccursBefore" select="/node()/simple_instance[type=':BPU-OCCURS_BEFORE-BPU']"/>
    <xsl:variable name="allAppFuncs" select="/node()/simple_instance[type='Application_Function']"/>
    <xsl:variable name="allApps" select="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider')]"/>
    <!-- Direct chain (confirmed):
         Business_Process.bp_supported_by_app_fun -> APP_FUN_TO_BUS_RELATION
           -> appfun_to_bus_from_appfun -> Application_Function
         Function.provided_by_application_service -> Application_Service
         Service.provided_by_application_provider_roles -> Application_Provider_Role
           -> role_for_application_provider -> Composite_Application_Provider -->
    <xsl:variable name="allAppFunToBus" select="/node()/simple_instance[own_slot_value[slot_reference='appfun_to_bus_from_appfun']]"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allAppProviderRoles" select="/node()/simple_instance[type='Application_Provider_Role']"/>
    <!-- App detail lookups -->
    <xsl:variable name="allDeliveryModels" select="/node()/simple_instance[type='Application_Delivery_Model']"/>
    <xsl:variable name="allCodebaseStatuses" select="/node()/simple_instance[type='Codebase_Status']"/>
    <xsl:variable name="allDispositions" select="/node()/simple_instance[type='Disposition_Lifecycle_Status']"/>
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <xsl:variable name="allContracts" select="/node()/simple_instance[type='Contract']"/>
    <!-- Contract component relations: contract_component_to_element = app, contract_component_from_contract = contract -->
    <xsl:key name="ccrByElement" match="/node()/simple_instance[type='CONTRACT_COMPONENT_RELATION']" use="own_slot_value[slot_reference='contract_component_to_element']/value"/>

    <!-- L1 = children of L0; L0 = children of the Root Business Capability -->
    <xsl:variable name="rootConstant" select="/node()/simple_instance[type='Report_Constant'][own_slot_value[slot_reference='name']/value='Root Business Capability']"/>
    <xsl:variable name="rootCap" select="$allBusCaps[name=$rootConstant/own_slot_value[slot_reference='report_constant_ea_elements']/value]"/>
    <xsl:variable name="l0Caps" select="$allBusCaps[name=$rootCap/own_slot_value[slot_reference='contained_business_capabilities']/value]"/>
    <xsl:variable name="l1Caps" select="$allBusCaps[name=$l0Caps/own_slot_value[slot_reference='contained_business_capabilities']/value]"/>

    <!-- Keys -->
    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>
    <xsl:key name="appFunToBusByName" match="/node()/simple_instance[own_slot_value[slot_reference='appfun_to_bus_from_appfun']]" use="name"/>
    <xsl:key name="procsByCapability" match="/node()/simple_instance[type=('Business_Process','Business_Activity')]" use="own_slot_value[slot_reference='realises_business_capability']/value"/>

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

    <!-- Recursively render a business process/activity as a JSON node, ordered by occurs-before within its flow -->
    <xsl:template name="renderProcNode">
        <xsl:param name="proc"/>
        <xsl:param name="depth"/>
        <!-- Direct chain: process.bp_supported_by_app_fun -> APP_FUN_TO_BUS rel -> appfun_to_bus_from_appfun -> function -->
        <xsl:variable name="funRels" select="key('appFunToBusByName', $proc/own_slot_value[slot_reference='bp_supported_by_app_fun']/value)"/>
        <xsl:variable name="appFuncs" select="$allAppFuncs[name = $funRels/own_slot_value[slot_reference='appfun_to_bus_from_appfun']/value]"/>
        <!-- Function -> Application_Service -> Application_Provider_Role -> Composite_Application_Provider -->
        <xsl:variable name="funcServices" select="$allAppServices[name = $appFuncs/own_slot_value[slot_reference='provided_by_application_service']/value]"/>
        <xsl:variable name="funcServiceRoles" select="$allAppProviderRoles[name = $funcServices/own_slot_value[slot_reference='provided_by_application_provider_roles']/value]"/>
        <xsl:variable name="allAppsForProc" select="$allApps[name = $funcServiceRoles/own_slot_value[slot_reference='role_for_application_provider']/value]"/>
        <!-- Ordered children from this process's own flow -->
        <xsl:variable name="flow" select="$allFlows[name=$proc/own_slot_value[slot_reference='defining_business_process_flow']/value]"/>
        <xsl:variable name="usages" select="$allUsages[own_slot_value[slot_reference='used_in_process_flow']/value = $flow/name]"/>
        <xsl:variable name="rels" select="$allOccursBefore[own_slot_value[slot_reference='contained_in_process_flow']/value = $flow/name]"/>
        <!-- start usages = those never a :TO target -->
        <xsl:variable name="targetUsageIds" select="$rels/own_slot_value[slot_reference=':TO']/value"/>
        <!-- Start usages = chain heads + any usage not linked in the occurs-before chain (standalone activities/processes).
             Filter to those that resolve to a real process/activity so each emits exactly one group. -->
        <xsl:variable name="startUsages" select="$usages[not(name = $targetUsageIds)][$allBusProcs/name = (own_slot_value[slot_reference='business_process_used']/value, own_slot_value[slot_reference='business_activity_used']/value)]"/>
        {
        "id":"<xsl:value-of select="eas:jsonText(string($proc/name))"/>",
        "name":"<xsl:value-of select="eas:jsonText(string($proc/own_slot_value[slot_reference='name']/value))"/>",
        "type":"<xsl:value-of select="eas:jsonText(string($proc/type))"/>",
        "description":"<xsl:value-of select="eas:jsonText(string($proc/own_slot_value[slot_reference='description']/value))"/>",
        "appFunctions":[<xsl:for-each select="$appFuncs">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "services":[<xsl:for-each select="$funcServices">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "apps":[<xsl:for-each select="$allAppsForProc">
            <xsl:variable name="app" select="current()"/>
            <xsl:variable name="dm" select="$allDeliveryModels[name=$app/own_slot_value[slot_reference='ap_delivery_model']/value]"/>
            <xsl:variable name="cb" select="$allCodebaseStatuses[name=$app/own_slot_value[slot_reference='ap_codebase_status']/value]"/>
            <xsl:variable name="disp" select="$allDispositions[name=$app/own_slot_value[slot_reference='ap_disposition_lifecycle_status']/value]"/>
            <xsl:variable name="sup" select="$allSuppliers[name=$app/own_slot_value[slot_reference='ap_supplier']/value]"/>
            <xsl:variable name="provServices" select="$allAppServices[name=$app/own_slot_value[slot_reference='provides_application_services']/value]"/>
            <xsl:variable name="ccrs" select="key('ccrByElement', $app/name)"/>
            <xsl:variable name="appContracts" select="$allContracts[name=$ccrs/own_slot_value[slot_reference='contract_component_from_contract']/value]"/>
            {"id":"<xsl:value-of select="eas:jsonText(string($app/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($app/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string($app/own_slot_value[slot_reference='description']/value))"/>","deliveryModel":"<xsl:value-of select="eas:jsonText(string($dm/own_slot_value[slot_reference='name']/value))"/>","codebase":"<xsl:value-of select="eas:jsonText(string($cb/own_slot_value[slot_reference='name']/value))"/>","disposition":"<xsl:value-of select="eas:jsonText(string($disp/own_slot_value[slot_reference='name']/value))"/>","supplier":"<xsl:value-of select="eas:jsonText(string($sup/own_slot_value[slot_reference='name']/value))"/>","providesServices":[<xsl:for-each select="$provServices">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],"contracts":[<xsl:for-each select="$appContracts">{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","endDate":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='contract_end_date_ISO8601']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "children":[<xsl:if test="$depth &lt; 5"><xsl:for-each select="$startUsages"><xsl:if test="position() &gt; 1">,</xsl:if><xsl:call-template name="renderUsageChain"><xsl:with-param name="usage" select="current()"/><xsl:with-param name="rels" select="$rels"/><xsl:with-param name="usages" select="$usages"/><xsl:with-param name="depth" select="$depth"/><xsl:with-param name="guard" select="0"/></xsl:call-template></xsl:for-each></xsl:if>]
        }
    </xsl:template>

    <!-- Walk the occurs-before chain from a start usage, emitting ordered child proc nodes -->
    <xsl:template name="renderUsageChain">
        <xsl:param name="usage"/>
        <xsl:param name="rels"/>
        <xsl:param name="usages"/>
        <xsl:param name="depth"/>
        <xsl:param name="guard"/>
        <xsl:if test="$usage and $guard &lt; 50">
            <xsl:variable name="childProc" select="$allBusProcs[name = ($usage/own_slot_value[slot_reference='business_process_used']/value, $usage/own_slot_value[slot_reference='business_activity_used']/value)]"/>
            <xsl:if test="$childProc">
                <xsl:call-template name="renderProcNode"><xsl:with-param name="proc" select="$childProc[1]"/><xsl:with-param name="depth" select="$depth + 1"/></xsl:call-template>
            </xsl:if>
            <!-- next usage via occurs-before -->
            <xsl:variable name="nextRel" select="$rels[own_slot_value[slot_reference=':FROM']/value = $usage/name][1]"/>
            <xsl:variable name="nextUsage" select="$usages[name = $nextRel/own_slot_value[slot_reference=':TO']/value]"/>
            <xsl:if test="$nextUsage and $childProc">,</xsl:if>
            <xsl:call-template name="renderUsageChain"><xsl:with-param name="usage" select="$nextUsage[1]"/><xsl:with-param name="rels" select="$rels"/><xsl:with-param name="usages" select="$usages"/><xsl:with-param name="depth" select="$depth"/><xsl:with-param name="guard" select="$guard + 1"/></xsl:call-template>
        </xsl:if>
    </xsl:template>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Business Capability Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1500px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.15rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.1rem}
                    .cap-search{margin-bottom:20px}
                    .cap-search input{width:100%;max-width:420px;padding:10px 14px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem}
                    .l0-filters{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}
                    .l0-btn{background:#F5F0FF;border:1px solid #DDBDFF;color:#361A54;border-radius:20px;padding:8px 18px;cursor:pointer;font-family:'DM Sans',sans-serif;font-weight:600;font-size:1.05rem;transition:background 0.15s,color 0.15s}
                    .l0-btn:hover{background:#DDBDFF}
                    .l0-btn.active{background:#361A54;color:#fff;border-color:#361A54}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    /* L1 capability list */
                    .cap-list{display:flex;flex-direction:column;gap:12px}
                    .cap-card{border:1px solid #E5E7EB;border-radius:12px;background:#fff;overflow:hidden;box-shadow:0 1px 3px rgba(54,26,84,0.06)}
                    .cap-head{display:flex;align-items:center;gap:14px;padding:16px 22px;cursor:pointer;background:linear-gradient(90deg,#361A54,#5B2A87);color:#fff}
                    .cap-head .caret{font-size:1rem;transition:transform 0.2s;flex-shrink:0}
                    .cap-head.open .caret{transform:rotate(90deg)}
                    .cap-head .cap-name{font-size:1.5rem;font-weight:700;flex:1}
                    .cap-head .cap-l0{font-size:0.95rem;background:rgba(255,255,255,0.2);padding:4px 12px;border-radius:20px}
                    .cap-body{display:none;padding:18px 22px;background:#FBF9FF}
                    .cap-body.open{display:block}
                    .cap-desc{color:#4B5563;margin-bottom:16px;line-height:1.55}
                    /* Boxes - stacked full-width (landscape) */
                    .boxes{display:flex;flex-direction:column;gap:16px}
                    .box{width:100%;background:#fff;border:1px solid #E5E7EB;border-radius:10px;padding:16px}
                    .box-title{font-size:0.9rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;margin-bottom:12px;padding-bottom:6px;border-bottom:2px solid}
                    .box-subcap .box-title{color:#361A54;border-color:#361A54}
                    .box-proc .box-title{color:#7d1fe0;border-color:#7d1fe0}
                    .box-func .box-title{color:#2E75B6;border-color:#2E75B6}
                    .box-svc .box-title{color:#0E7C6B;border-color:#0E7C6B}
                    .box-app .box-title{color:#12B76A;border-color:#12B76A}
                    /* pills */
                    .pill{display:inline-block;border-radius:20px;padding:8px 16px;margin:0 6px 8px 0;font-weight:600;font-size:1.05rem;cursor:default}
                    .pill.subcap{background:#EDE4FF;color:#361A54;border:1px solid #DDBDFF}
                    .pill.func{background:#3E7DD6;color:#fff}
                    .pill.svc{background:#0E9E86;color:#fff}
                    .pill.app{background:#12B76A;color:#fff}
                    /* process tiers - each depth level on its own horizontal row */
                    .proc-tier{display:flex;flex-wrap:wrap;gap:10px;align-items:stretch;margin-bottom:14px;padding-bottom:14px;border-bottom:1px dashed #E5E7EB}
                    .proc-tier:last-child{border-bottom:none;margin-bottom:0;padding-bottom:0}
                    .proc-tier-label{flex-basis:100%;font-size:0.8rem;text-transform:uppercase;letter-spacing:0.04em;color:#9CA3AF;font-weight:700;margin-bottom:2px}
                    .proc-card{display:flex;flex-direction:column;gap:4px;background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:10px 14px;min-width:170px}
                    .proc-card.activity{background:#fff;border-style:dashed}
                    .proc-card .pc-head{display:flex;align-items:center;gap:8px}
                    .proc-seq{background:#7d1fe0;color:#fff;border-radius:6px;padding:2px 8px;font-size:0.85rem;font-weight:700;flex-shrink:0}
                    .proc-card.activity .proc-seq{background:#B982FF}
                    .proc-name{font-weight:600;color:#361A54}
                    .proc-meta{font-size:0.82rem;color:#6B7280}
                    .proc-card{cursor:pointer;transition:transform 0.1s,box-shadow 0.1s}
                    .proc-card:hover{transform:translateY(-2px);box-shadow:0 3px 10px rgba(0,0,0,0.12)}
                    .pill.clickable{cursor:pointer}
                    .pill.clickable:hover{transform:translateY(-2px);box-shadow:0 3px 10px rgba(0,0,0,0.15)}
                    /* Slide-in sidebar (right) */
                    .sb-overlay{position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.35);z-index:999;display:none}
                    .sb-overlay.open{display:block}
                    .sidebar{position:fixed;top:0;right:-480px;width:460px;max-width:92vw;height:100vh;background:#fff;box-shadow:-4px 0 24px rgba(0,0,0,0.18);z-index:1000;transition:right 0.3s ease;overflow-y:auto;padding:28px}
                    .sidebar.open{right:0}
                    .sb-close{position:absolute;top:14px;right:16px;font-size:24px;cursor:pointer;color:#6B7280;background:none;border:none}
                    .sb-kicker{display:inline-block;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;color:#fff;padding:4px 12px;border-radius:20px;margin-bottom:10px}
                    .sb-kicker.app{background:#12B76A}
                    .sb-kicker.proc{background:#7d1fe0}
                    .sb-title{color:#361A54;margin:0 0 14px 0;padding-right:30px;font-size:1.5rem;font-weight:700}
                    .sb-summary-btn{display:inline-block;background:#993AFF;color:#fff;text-decoration:none;padding:9px 18px;border-radius:6px;font-weight:600;font-size:1.05rem;margin-bottom:20px}
                    .sb-summary-btn:hover{background:#7d1fe0;color:#fff}
                    .sb-row{margin-bottom:16px}
                    .sb-label{font-size:0.85rem;text-transform:uppercase;letter-spacing:0.04em;color:#6B7280;font-weight:700;margin-bottom:4px}
                    .sb-value{font-size:1.15rem;color:#222;line-height:1.55}
                    .sb-empty{color:#9CA3AF;font-style:italic}
                    .sb-child-list{display:flex;flex-direction:column;gap:8px}
                    .sb-child{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:10px 14px;font-weight:600;color:#361A54;cursor:pointer;display:flex;justify-content:space-between;align-items:center;gap:8px}
                    .sb-child:hover{background:#EDE4FF}
                    .sb-child.activity{border-style:dashed}
                    .sb-child-type{font-size:0.78rem;text-transform:uppercase;color:#7d1fe0;font-weight:700;flex-shrink:0}
                    .sb-pillwrap{display:flex;flex-wrap:wrap;gap:6px}
                    .sb-pill{display:inline-block;border-radius:16px;padding:4px 12px;font-size:0.95rem;font-weight:600}
                    .sb-pill.svc{background:#0E9E86;color:#fff}
                    .sb-contract{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:10px 14px;display:flex;justify-content:space-between;align-items:center;gap:10px}
                    .sb-contract .ct-name{font-weight:600;color:#361A54}
                    .sb-contract .ct-end{font-size:0.9rem;color:#6B7280;white-space:nowrap;flex-shrink:0}
                </style>
                <script type="text/javascript">
                    var CAPS = [<xsl:for-each select="$l1Caps">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="cap" select="current()"/>
                        <xsl:variable name="l0" select="$l0Caps[own_slot_value[slot_reference='contained_business_capabilities']/value = $cap/name]"/>
                        <xsl:variable name="subCaps" select="$allBusCaps[name=$cap/own_slot_value[slot_reference='contained_business_capabilities']/value]"/>
                        <!-- Processes realising this cap OR its sub-caps -->
                        <xsl:variable name="capProcs" select="key('procsByCapability', ($cap/name, $subCaps/name))"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($cap/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='name']/value))"/>",
                        "l0":"<xsl:value-of select="eas:jsonText(string($l0[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='description']/value))"/>",
                        "subCaps":[<xsl:for-each select="$subCaps">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                        "processes":[<xsl:for-each select="$capProcs"><xsl:call-template name="renderProcNode"><xsl:with-param name="proc" select="current()"/><xsl:with-param name="depth" select="0"/></xsl:call-template><xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }
                    function niceType(t){ return (t||'').replace(/_/g,' '); }

                    // Build lookup maps for the detail sidebar (apps + processes by id, across the whole tree)
                    var APP_BY_ID = {};
                    var PROC_BY_ID = {};
                    function indexProcs(procs){
                        procs.forEach(function(p){
                            PROC_BY_ID[p.id] = p;
                            (p.apps||[]).forEach(function(a){ APP_BY_ID[a.id] = a; });
                            if (p.children &amp;&amp; p.children.length) indexProcs(p.children);
                        });
                    }
                    CAPS.forEach(function(c){ indexProcs(c.processes); });

                    function detailRow(label, value){
                        return '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;' + esc(label) + '&lt;/div&gt;&lt;div class="sb-value"&gt;' + (value ? esc(value) : '&lt;span class="sb-empty"&gt;Not set&lt;/span&gt;') + '&lt;/div&gt;&lt;/div&gt;';
                    }

                    function openApp(id){
                        var a = APP_BY_ID[id];
                        if (!a) return;
                        var html = '&lt;div class="sb-kicker app"&gt;Application&lt;/div&gt;';
                        html += '&lt;h2 class="sb-title"&gt;' + esc(a.name) + '&lt;/h2&gt;';
                        var url = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(a.id) + '&amp;XSL=application/core_al_application_provider_summary.xsl&amp;cl=en-gb';
                        html += '&lt;a class="sb-summary-btn" href="' + url + '" target="_blank"&gt;View full application summary &#8594;&lt;/a&gt;';
                        html += detailRow('Description', a.description);
                        html += detailRow('Supplier', a.supplier);
                        html += detailRow('Delivery Model', a.deliveryModel);
                        html += detailRow('Codebase Status', a.codebase);
                        html += detailRow('Disposition (TIME)', a.disposition);
                        // Provided application services
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Provides Application Services&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.providesServices &amp;&amp; a.providesServices.length){ html += '&lt;div class="sb-pillwrap"&gt;'; a.providesServices.forEach(function(s){ html += '&lt;span class="sb-pill svc"&gt;' + esc(s) + '&lt;/span&gt;'; }); html += '&lt;/div&gt;'; }
                        else html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        // Contracts (name + end date)
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Contracts&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.contracts &amp;&amp; a.contracts.length){
                            html += '&lt;div class="sb-child-list"&gt;';
                            a.contracts.forEach(function(ct){
                                html += '&lt;div class="sb-contract"&gt;&lt;span class="ct-name"&gt;' + esc(ct.name) + '&lt;/span&gt;&lt;span class="ct-end"&gt;' + (ct.endDate ? ('ends ' + esc(ct.endDate)) : 'no end date') + '&lt;/span&gt;&lt;/div&gt;';
                            });
                            html += '&lt;/div&gt;';
                        } else html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        openSidebar(html);
                    }

                    function openProc(id){
                        var p = PROC_BY_ID[id];
                        if (!p) return;
                        var isActivity = /Activity/i.test(p.type);
                        var html = '&lt;div class="sb-kicker proc"&gt;' + (isActivity ? 'Business Activity' : 'Business Process') + '&lt;/div&gt;';
                        html += '&lt;h2 class="sb-title"&gt;' + esc(p.name) + '&lt;/h2&gt;';
                        html += detailRow('Description', p.description);
                        // Sub-processes / activities (direct children)
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Sub-processes &amp;amp; activities&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (p.children &amp;&amp; p.children.length){
                            html += '&lt;div class="sb-child-list"&gt;';
                            p.children.forEach(function(ch){
                                var chAct = /Activity/i.test(ch.type);
                                html += '&lt;div class="sb-child ' + (chAct ? 'activity' : '') + '" onclick="openProc(\'' + ch.id + '\')"&gt;' + esc(ch.name) + '&lt;span class="sb-child-type"&gt;' + (chAct ? 'Activity' : 'Process') + '&lt;/span&gt;&lt;/div&gt;';
                            });
                            html += '&lt;/div&gt;';
                        } else { html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;'; }
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        openSidebar(html);
                    }

                    function openSidebar(html){
                        document.getElementById('sidebarContent').innerHTML = html;
                        document.getElementById('sidebar').classList.add('open');
                        document.getElementById('sbOverlay').classList.add('open');
                    }
                    function closeSidebar(){
                        document.getElementById('sidebar').classList.remove('open');
                        document.getElementById('sbOverlay').classList.remove('open');
                    }

                    // Collect all app functions and apps across a capability's whole process tree
                    function collectFromProcs(procs, key, map) {
                        procs.forEach(function(p){
                            (p[key]||[]).forEach(function(x){ map[x.id] = x; });
                            if (p.children &amp;&amp; p.children.length) collectFromProcs(p.children, key, map);
                        });
                    }

                    // Flatten the process tree into tiers by depth: tiers[0] = [1,2], tiers[1] = [1.1,1.2,...], etc.
                    function collectTiers(procs, seqPrefix, depth, tiers) {
                        if (!tiers[depth]) tiers[depth] = [];
                        procs.forEach(function(p, i){
                            var seq = seqPrefix ? (seqPrefix + '.' + (i+1)) : String(i+1);
                            tiers[depth].push({node: p, seq: seq});
                            if (p.children &amp;&amp; p.children.length) collectTiers(p.children, seq, depth + 1, tiers);
                        });
                    }

                    function renderProcTree(procs) {
                        var tiers = [];
                        collectTiers(procs, '', 0, tiers);
                        var html = '';
                        tiers.forEach(function(tier, depth){
                            if (!tier || !tier.length) return;
                            html += '&lt;div class="proc-tier"&gt;';
                            html += '&lt;div class="proc-tier-label"&gt;Level ' + (depth + 1) + '&lt;/div&gt;';
                            tier.forEach(function(item){
                                var p = item.node;
                                var isActivity = /Activity/i.test(p.type);
                                html += '&lt;div class="proc-card' + (isActivity ? ' activity' : '') + '" onclick="openProc(\'' + p.id + '\')"&gt;';
                                html += '&lt;div class="pc-head"&gt;&lt;span class="proc-seq"&gt;' + item.seq + '&lt;/span&gt;&lt;span class="proc-name"&gt;' + esc(p.name) + '&lt;/span&gt;&lt;/div&gt;';
                                var extra = [];
                                if (p.appFunctions.length) extra.push(p.appFunctions.length + ' function' + (p.appFunctions.length===1?'':'s'));
                                if (p.apps.length) extra.push(p.apps.length + ' app' + (p.apps.length===1?'':'s'));
                                if (extra.length) html += '&lt;span class="proc-meta"&gt;' + extra.join(' &#8226; ') + '&lt;/span&gt;';
                                html += '&lt;/div&gt;';
                            });
                            html += '&lt;/div&gt;';
                        });
                        return html;
                    }

                    var selectedL0 = 'all';

                    function buildL0Filters() {
                        var l0s = [];
                        CAPS.forEach(function(c){ if (c.l0 &amp;&amp; l0s.indexOf(c.l0) === -1) l0s.push(c.l0); });
                        l0s.sort();
                        var container = document.getElementById('l0Filters');
                        var html = '&lt;button class="l0-btn active" data-l0="all" onclick="setL0(this)"&gt;All&lt;/button&gt;';
                        l0s.forEach(function(l0){
                            html += '&lt;button class="l0-btn" data-l0="' + esc(l0) + '" onclick="setL0(this)"&gt;' + esc(l0) + '&lt;/button&gt;';
                        });
                        container.innerHTML = html;
                    }

                    function setL0(btn) {
                        selectedL0 = btn.getAttribute('data-l0');
                        var btns = document.querySelectorAll('#l0Filters .l0-btn');
                        for (var i = 0; i &lt; btns.length; i++) { btns[i].classList.remove('active'); }
                        btn.classList.add('active');
                        renderList(document.getElementById('capSearch').value);
                    }

                    function renderList(filter) {
                        var container = document.getElementById('capList');
                        var caps = CAPS;
                        if (selectedL0 !== 'all') {
                            caps = caps.filter(function(c){ return c.l0 === selectedL0; });
                        }
                        if (filter &amp;&amp; filter.trim() !== '') {
                            var f = filter.toLowerCase();
                            caps = caps.filter(function(c){ return c.name.toLowerCase().indexOf(f) !== -1; });
                        }
                        if (caps.length === 0) { container.innerHTML = '&lt;div class="no-data"&gt;No business capabilities match.&lt;/div&gt;'; return; }
                        var html = '';
                        caps.forEach(function(c){
                            html += '&lt;div class="cap-card"&gt;';
                            html += '&lt;div class="cap-head" onclick="toggle(this, \'body-' + c.id + '\')"&gt;';
                            html += '&lt;span class="caret"&gt;&#9656;&lt;/span&gt;';
                            html += '&lt;span class="cap-name"&gt;' + esc(c.name) + '&lt;/span&gt;';
                            if (c.l0) html += '&lt;span class="cap-l0"&gt;' + esc(c.l0) + '&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            html += '&lt;div class="cap-body" id="body-' + c.id + '"&gt;';
                            if (c.description) html += '&lt;div class="cap-desc"&gt;' + esc(c.description) + '&lt;/div&gt;';
                            html += '&lt;div class="boxes"&gt;';
                            // Box 1: sub-capabilities
                            html += '&lt;div class="box box-subcap"&gt;&lt;div class="box-title"&gt;Sub-capabilities&lt;/div&gt;';
                            if (c.subCaps.length) { c.subCaps.forEach(function(s){ html += '&lt;span class="pill subcap" title="' + esc(s.description) + '"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); }
                            else html += '&lt;span style="color:#9CA3AF;font-style:italic;"&gt;None&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            // Box 2: processes (ordered tree)
                            html += '&lt;div class="box box-proc"&gt;&lt;div class="box-title"&gt;Business Processes &amp;amp; Activities&lt;/div&gt;';
                            if (c.processes.length) html += renderProcTree(c.processes);
                            else html += '&lt;span style="color:#9CA3AF;font-style:italic;"&gt;None&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            // Box 3: application functions (all across tree)
                            var funcMap = {}; collectFromProcs(c.processes, 'appFunctions', funcMap);
                            var funcs = Object.keys(funcMap).map(function(k){ return funcMap[k]; });
                            html += '&lt;div class="box box-func"&gt;&lt;div class="box-title"&gt;Application Functions&lt;/div&gt;';
                            if (funcs.length) { funcs.forEach(function(fn){ html += '&lt;span class="pill func" title="' + esc(fn.description) + '"&gt;' + esc(fn.name) + '&lt;/span&gt;'; }); }
                            else html += '&lt;span style="color:#9CA3AF;font-style:italic;"&gt;None&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            // Box 4: application services (all across tree)
                            var svcMap = {}; collectFromProcs(c.processes, 'services', svcMap);
                            var svcs = Object.keys(svcMap).map(function(k){ return svcMap[k]; });
                            html += '&lt;div class="box box-svc"&gt;&lt;div class="box-title"&gt;Application Services&lt;/div&gt;';
                            if (svcs.length) { svcs.forEach(function(s){ html += '&lt;span class="pill svc" title="' + esc(s.description) + '"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); }
                            else html += '&lt;span style="color:#9CA3AF;font-style:italic;"&gt;None&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            // Box 5: applications / composite application providers (all across tree)
                            var appMap = {}; collectFromProcs(c.processes, 'apps', appMap);
                            var apps = Object.keys(appMap).map(function(k){ return appMap[k]; });
                            html += '&lt;div class="box box-app"&gt;&lt;div class="box-title"&gt;Applications&lt;/div&gt;';
                            if (apps.length) { apps.forEach(function(a){ html += '&lt;span class="pill app clickable" onclick="openApp(\'' + a.id + '\')"&gt;' + esc(a.name) + '&lt;/span&gt;'; }); }
                            else html += '&lt;span style="color:#9CA3AF;font-style:italic;"&gt;None&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            html += '&lt;/div&gt;&lt;/div&gt;&lt;/div&gt;';
                        });
                        container.innerHTML = html;
                    }

                    function toggle(headEl, bodyId) {
                        var body = document.getElementById(bodyId);
                        if (!body) return;
                        var isOpen = body.classList.contains('open');
                        body.classList.toggle('open', !isOpen);
                        headEl.classList.toggle('open', !isOpen);
                    }

                    $(document).ready(function(){
                        console.log('Business capabilities (L1):', CAPS);
                        buildL0Filters();
                        renderList('');
                        document.getElementById('capSearch').addEventListener('input', function(){ renderList(this.value); });
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Business Capability Explorer</h1>
                    <p class="subtitle">Level 1 business capabilities. Expand one to see its sub-capabilities, ordered business processes and activities, the application functions, and the supporting applications.</p>
                    <div class="cap-search"><input type="text" id="capSearch" placeholder="Search business capabilities..."/></div>
                    <div class="l0-filters" id="l0Filters"/>
                    <div class="cap-list" id="capList"><p>Loading business capabilities...</p></div>
                </div>
                <div class="sb-overlay" id="sbOverlay" onclick="closeSidebar()"/>
                <div class="sidebar" id="sidebar">
                    <button class="sb-close" onclick="closeSidebar()">x</button>
                    <div id="sidebarContent"/>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
