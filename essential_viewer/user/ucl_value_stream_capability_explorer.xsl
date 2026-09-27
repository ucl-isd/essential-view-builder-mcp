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
    <xsl:variable name="allBusCaps" select="/node()/simple_instance[type='Business_Capability']"/>
    <xsl:variable name="allBusProcs" select="/node()/simple_instance[type=('Business_Process','Business_Activity')]"/>
    <xsl:variable name="allFlows" select="/node()/simple_instance[type='Business_Process_Flow']"/>
    <xsl:variable name="allUsages" select="/node()/simple_instance[type=('Business_Process_Usage','Business_Activity_Usage')]"/>
    <xsl:variable name="allOccursBefore" select="/node()/simple_instance[type=':BPU-OCCURS_BEFORE-BPU']"/>
    <xsl:variable name="allAppFuncs" select="/node()/simple_instance[type='Application_Function']"/>
    <xsl:variable name="allApps" select="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider')]"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allAppProviderRoles" select="/node()/simple_instance[type='Application_Provider_Role']"/>

    <!-- Value streams & stages -->
    <xsl:variable name="allValueStreams" select="/node()/simple_instance[type='Value_Stream']"/>
    <xsl:variable name="allValueStages" select="/node()/simple_instance[type='Value_Stage']"/>

    <!-- App detail lookups -->
    <xsl:variable name="allDeliveryModels" select="/node()/simple_instance[type='Application_Delivery_Model']"/>
    <xsl:variable name="allCodebaseStatuses" select="/node()/simple_instance[type='Codebase_Status']"/>
    <xsl:variable name="allDispositions" select="/node()/simple_instance[type='Disposition_Lifecycle_Status']"/>
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <xsl:variable name="allContracts" select="/node()/simple_instance[type='Contract']"/>
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
    <xsl:key name="stagesByStream" match="/node()/simple_instance[type='Value_Stage']" use="own_slot_value[slot_reference='vsg_value_stream']/value"/>

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

    <!-- Render a business process/activity as a JSON node, ordered by occurs-before within its flow -->
    <xsl:template name="renderProcNode">
        <xsl:param name="proc"/>
        <xsl:param name="depth"/>
        <xsl:variable name="funRels" select="key('appFunToBusByName', $proc/own_slot_value[slot_reference='bp_supported_by_app_fun']/value)"/>
        <xsl:variable name="appFuncs" select="$allAppFuncs[name = $funRels/own_slot_value[slot_reference='appfun_to_bus_from_appfun']/value]"/>
        <xsl:variable name="funcServices" select="$allAppServices[name = $appFuncs/own_slot_value[slot_reference='provided_by_application_service']/value]"/>
        <xsl:variable name="funcServiceRoles" select="$allAppProviderRoles[name = $funcServices/own_slot_value[slot_reference='provided_by_application_provider_roles']/value]"/>
        <xsl:variable name="allAppsForProc" select="$allApps[name = $funcServiceRoles/own_slot_value[slot_reference='role_for_application_provider']/value]"/>
        <xsl:variable name="flow" select="$allFlows[name=$proc/own_slot_value[slot_reference='defining_business_process_flow']/value]"/>
        <xsl:variable name="usages" select="$allUsages[own_slot_value[slot_reference='used_in_process_flow']/value = $flow/name]"/>
        <xsl:variable name="rels" select="$allOccursBefore[own_slot_value[slot_reference='contained_in_process_flow']/value = $flow/name]"/>
        <xsl:variable name="targetUsageIds" select="$rels/own_slot_value[slot_reference=':TO']/value"/>
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
            <xsl:variable name="nextRel" select="$rels[own_slot_value[slot_reference=':FROM']/value = $usage/name][1]"/>
            <xsl:variable name="nextUsage" select="$usages[name = $nextRel/own_slot_value[slot_reference=':TO']/value]"/>
            <xsl:if test="$nextUsage and $childProc">,</xsl:if>
            <xsl:call-template name="renderUsageChain"><xsl:with-param name="usage" select="$nextUsage[1]"/><xsl:with-param name="rels" select="$rels"/><xsl:with-param name="usages" select="$usages"/><xsl:with-param name="depth" select="$depth"/><xsl:with-param name="guard" select="$guard + 1"/></xsl:call-template>
        </xsl:if>
    </xsl:template>

    <!-- Render a single L1 capability as a JSON object (sub-caps + full ordered process tree) -->
    <xsl:template name="renderCap">
        <xsl:param name="cap"/>
        <xsl:variable name="l0" select="$l0Caps[own_slot_value[slot_reference='contained_business_capabilities']/value = $cap/name]"/>
        <xsl:variable name="subCaps" select="$allBusCaps[name=$cap/own_slot_value[slot_reference='contained_business_capabilities']/value]"/>
        <xsl:variable name="capProcs" select="key('procsByCapability', ($cap/name, $subCaps/name))"/>
        {
        "id":"<xsl:value-of select="eas:jsonText(string($cap/name))"/>",
        "name":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='name']/value))"/>",
        "l0":"<xsl:value-of select="eas:jsonText(string($l0[1]/own_slot_value[slot_reference='name']/value))"/>",
        "description":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='description']/value))"/>",
        "subCaps":[<xsl:for-each select="$subCaps">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "processes":[<xsl:for-each select="$capProcs"><xsl:call-template name="renderProcNode"><xsl:with-param name="proc" select="current()"/><xsl:with-param name="depth" select="0"/></xsl:call-template><xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
        }
    </xsl:template>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Value Stream &#8594; Capability Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1800px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.1rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.1rem}
                    .vs-select-row{display:flex;align-items:center;gap:12px;margin-bottom:20px;flex-wrap:wrap}
                    .vs-select-row label{font-weight:700;color:#361A54}
                    .vs-select-row select{padding:10px 14px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem;min-width:320px;background:#fff}
                    .vs-desc{color:#4B5563;margin-bottom:18px;line-height:1.55;font-size:1.05rem}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    /* Stage chevrons across the top */
                    .stage-track{display:flex;gap:6px;overflow-x:auto;padding-bottom:8px;margin-bottom:8px}
                    .stage-col{flex:1 1 0;min-width:230px;display:flex;flex-direction:column}
                    .stage-head{position:relative;background:linear-gradient(135deg,#361A54,#5B2A87);color:#fff;padding:14px 20px 14px 30px;font-weight:700;font-size:1.05rem;clip-path:polygon(0 0, calc(100% - 16px) 0, 100% 50%, calc(100% - 16px) 100%, 0 100%, 16px 50%);min-height:52px;display:flex;align-items:center;gap:8px}
                    .stage-col:first-child .stage-head{clip-path:polygon(0 0, calc(100% - 16px) 0, 100% 50%, calc(100% - 16px) 100%, 0 100%);padding-left:20px}
                    .stage-index{background:rgba(255,255,255,0.25);border-radius:50%;width:24px;height:24px;display:flex;align-items:center;justify-content:center;font-size:0.85rem;flex-shrink:0}
                    .stage-body{background:#F5F0FF;border:1px solid #DDBDFF;border-top:none;border-radius:0 0 8px 8px;padding:10px;display:flex;flex-direction:column;gap:8px;flex:1}
                    .stage-cap-count{font-size:0.8rem;color:#6B7280;padding:2px 4px}
                    /* L1 capability card inside a stage */
                    .vcap{background:#fff;border:1px solid #E5E7EB;border-radius:8px;overflow:hidden}
                    .vcap-head{display:flex;align-items:center;gap:8px;padding:10px 12px;cursor:pointer;background:#EDE4FF;color:#361A54;font-weight:700}
                    .vcap-head .caret{font-size:0.85rem;transition:transform 0.2s;flex-shrink:0}
                    .vcap-head.open .caret{transform:rotate(90deg)}
                    .vcap-name{flex:1;font-size:1rem}
                    .vcap-body{display:none;padding:12px;background:#FBF9FF;border-top:1px solid #E5E7EB}
                    .vcap-body.open{display:block}
                    .vcap-desc{color:#4B5563;margin-bottom:12px;line-height:1.5;font-size:0.95rem}
                    .box{width:100%;background:#fff;border:1px solid #E5E7EB;border-radius:8px;padding:12px;margin-bottom:10px}
                    .box:last-child{margin-bottom:0}
                    .box-title{font-size:0.82rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;margin-bottom:10px;padding-bottom:5px;border-bottom:2px solid}
                    .box-subcap .box-title{color:#361A54;border-color:#361A54}
                    .box-proc .box-title{color:#7d1fe0;border-color:#7d1fe0}
                    .box-func .box-title{color:#2E75B6;border-color:#2E75B6}
                    .box-svc .box-title{color:#0E7C6B;border-color:#0E7C6B}
                    .box-app .box-title{color:#12B76A;border-color:#12B76A}
                    .pill{display:inline-block;border-radius:16px;padding:6px 12px;margin:0 5px 6px 0;font-weight:600;font-size:0.92rem;cursor:default}
                    .pill.subcap{background:#EDE4FF;color:#361A54;border:1px solid #DDBDFF}
                    .pill.func{background:#3E7DD6;color:#fff}
                    .pill.svc{background:#0E9E86;color:#fff}
                    .pill.app{background:#12B76A;color:#fff}
                    .pill.clickable{cursor:pointer}
                    .pill.clickable:hover{transform:translateY(-1px);box-shadow:0 2px 8px rgba(0,0,0,0.15)}
                    .proc-tier{display:flex;flex-wrap:wrap;gap:8px;align-items:stretch;margin-bottom:10px;padding-bottom:10px;border-bottom:1px dashed #E5E7EB}
                    .proc-tier:last-child{border-bottom:none;margin-bottom:0;padding-bottom:0}
                    .proc-tier-label{flex-basis:100%;font-size:0.75rem;text-transform:uppercase;letter-spacing:0.04em;color:#9CA3AF;font-weight:700;margin-bottom:2px}
                    .proc-card{display:flex;flex-direction:column;gap:3px;background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:8px 12px;min-width:150px;cursor:pointer;transition:transform 0.1s,box-shadow 0.1s}
                    .proc-card:hover{transform:translateY(-2px);box-shadow:0 3px 10px rgba(0,0,0,0.12)}
                    .proc-card.activity{background:#fff;border-style:dashed}
                    .proc-card .pc-head{display:flex;align-items:center;gap:6px}
                    .proc-seq{background:#7d1fe0;color:#fff;border-radius:6px;padding:2px 7px;font-size:0.8rem;font-weight:700;flex-shrink:0}
                    .proc-card.activity .proc-seq{background:#B982FF}
                    .proc-name{font-weight:600;color:#361A54;font-size:0.92rem}
                    .proc-meta{font-size:0.78rem;color:#6B7280}
                    .empty-note{color:#9CA3AF;font-style:italic;font-size:0.9rem}
                    /* Sidebar */
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
                    var STREAMS = [<xsl:for-each select="$allValueStreams">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="vs" select="current()"/>
                        <xsl:variable name="stages" select="key('stagesByStream', $vs/name)"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($vs/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($vs/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($vs/own_slot_value[slot_reference='description']/value))"/>",
                        "stages":[<xsl:for-each select="$stages">
                            <xsl:sort select="number(own_slot_value[slot_reference='vsg_index']/value)" data-type="number"/>
                            <xsl:variable name="stg" select="current()"/>
                            <xsl:variable name="stgCaps" select="$l1Caps[name = $stg/own_slot_value[slot_reference='vsg_required_business_capabilities']/value]"/>
                            {
                            "id":"<xsl:value-of select="eas:jsonText(string($stg/name))"/>",
                            "name":"<xsl:value-of select="eas:jsonText(string($stg/own_slot_value[slot_reference='name']/value))"/>",
                            "index":"<xsl:value-of select="eas:jsonText(string($stg/own_slot_value[slot_reference='vsg_index']/value))"/>",
                            "description":"<xsl:value-of select="eas:jsonText(string($stg/own_slot_value[slot_reference='description']/value))"/>",
                            "caps":[<xsl:for-each select="$stgCaps"><xsl:sort select="own_slot_value[slot_reference='name']/value"/><xsl:call-template name="renderCap"><xsl:with-param name="cap" select="current()"/></xsl:call-template><xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                            }<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }

                    var APP_BY_ID = {};
                    var PROC_BY_ID = {};
                    function indexProcs(procs){
                        procs.forEach(function(p){
                            PROC_BY_ID[p.id] = p;
                            (p.apps||[]).forEach(function(a){ APP_BY_ID[a.id] = a; });
                            if (p.children &amp;&amp; p.children.length) indexProcs(p.children);
                        });
                    }
                    STREAMS.forEach(function(vs){ vs.stages.forEach(function(st){ st.caps.forEach(function(c){ indexProcs(c.processes); }); }); });

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
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Provides Application Services&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (a.providesServices &amp;&amp; a.providesServices.length){ html += '&lt;div class="sb-pillwrap"&gt;'; a.providesServices.forEach(function(s){ html += '&lt;span class="sb-pill svc"&gt;' + esc(s) + '&lt;/span&gt;'; }); html += '&lt;/div&gt;'; }
                        else html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
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

                    function collectFromProcs(procs, key, map) {
                        procs.forEach(function(p){
                            (p[key]||[]).forEach(function(x){ map[x.id] = x; });
                            if (p.children &amp;&amp; p.children.length) collectFromProcs(p.children, key, map);
                        });
                    }

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

                    // Render an L1 capability card with the full lower-level stack
                    function renderCapCard(c){
                        var html = '&lt;div class="vcap"&gt;';
                        html += '&lt;div class="vcap-head" onclick="toggleCap(this, \'vbody-' + c.uid + '\')"&gt;&lt;span class="caret"&gt;&#9656;&lt;/span&gt;&lt;span class="vcap-name"&gt;' + esc(c.name) + '&lt;/span&gt;&lt;/div&gt;';
                        html += '&lt;div class="vcap-body" id="vbody-' + c.uid + '"&gt;';
                        if (c.description) html += '&lt;div class="vcap-desc"&gt;' + esc(c.description) + '&lt;/div&gt;';
                        // Sub-capabilities
                        html += '&lt;div class="box box-subcap"&gt;&lt;div class="box-title"&gt;Sub-capabilities&lt;/div&gt;';
                        if (c.subCaps.length) { c.subCaps.forEach(function(s){ html += '&lt;span class="pill subcap" title="' + esc(s.description) + '"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); }
                        else html += '&lt;span class="empty-note"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        // Processes
                        html += '&lt;div class="box box-proc"&gt;&lt;div class="box-title"&gt;Business Processes &amp;amp; Activities&lt;/div&gt;';
                        if (c.processes.length) html += renderProcTree(c.processes);
                        else html += '&lt;span class="empty-note"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        // Application functions
                        var funcMap = {}; collectFromProcs(c.processes, 'appFunctions', funcMap);
                        var funcs = Object.keys(funcMap).map(function(k){ return funcMap[k]; });
                        html += '&lt;div class="box box-func"&gt;&lt;div class="box-title"&gt;Application Functions&lt;/div&gt;';
                        if (funcs.length) { funcs.forEach(function(fn){ html += '&lt;span class="pill func" title="' + esc(fn.description) + '"&gt;' + esc(fn.name) + '&lt;/span&gt;'; }); }
                        else html += '&lt;span class="empty-note"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        // Application services
                        var svcMap = {}; collectFromProcs(c.processes, 'services', svcMap);
                        var svcs = Object.keys(svcMap).map(function(k){ return svcMap[k]; });
                        html += '&lt;div class="box box-svc"&gt;&lt;div class="box-title"&gt;Application Services&lt;/div&gt;';
                        if (svcs.length) { svcs.forEach(function(s){ html += '&lt;span class="pill svc" title="' + esc(s.description) + '"&gt;' + esc(s.name) + '&lt;/span&gt;'; }); }
                        else html += '&lt;span class="empty-note"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        // Applications
                        var appMap = {}; collectFromProcs(c.processes, 'apps', appMap);
                        var apps = Object.keys(appMap).map(function(k){ return appMap[k]; });
                        html += '&lt;div class="box box-app"&gt;&lt;div class="box-title"&gt;Applications&lt;/div&gt;';
                        if (apps.length) { apps.forEach(function(a){ html += '&lt;span class="pill app clickable" onclick="openApp(\'' + a.id + '\')"&gt;' + esc(a.name) + '&lt;/span&gt;'; }); }
                        else html += '&lt;span class="empty-note"&gt;None&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        return html;
                    }

                    function renderStream(vs){
                        var container = document.getElementById('stageTrack');
                        if (!vs.stages.length){ container.innerHTML = '&lt;div class="no-data"&gt;This value stream has no stages.&lt;/div&gt;'; return; }
                        var uid = 0;
                        var html = '';
                        vs.stages.forEach(function(st){
                            html += '&lt;div class="stage-col"&gt;';
                            html += '&lt;div class="stage-head"&gt;&lt;span class="stage-index"&gt;' + esc(st.index || '') + '&lt;/span&gt;&lt;span&gt;' + esc(st.name) + '&lt;/span&gt;&lt;/div&gt;';
                            html += '&lt;div class="stage-body"&gt;';
                            if (st.caps.length){
                                html += '&lt;div class="stage-cap-count"&gt;' + st.caps.length + ' capability' + (st.caps.length===1?'':'ies') + '&lt;/div&gt;';
                                st.caps.forEach(function(c){ c.uid = 'u' + (uid++); html += renderCapCard(c); });
                            } else {
                                html += '&lt;div class="empty-note"&gt;No linked capabilities&lt;/div&gt;';
                            }
                            html += '&lt;/div&gt;&lt;/div&gt;';
                        });
                        container.innerHTML = html;
                    }

                    function toggleCap(headEl, bodyId) {
                        var body = document.getElementById(bodyId);
                        if (!body) return;
                        var isOpen = body.classList.contains('open');
                        body.classList.toggle('open', !isOpen);
                        headEl.classList.toggle('open', !isOpen);
                    }

                    function selectStream(id){
                        var vs = STREAMS.find(function(s){ return s.id === id; });
                        if (!vs) return;
                        document.getElementById('vsDesc').innerHTML = vs.description ? esc(vs.description) : '';
                        renderStream(vs);
                    }

                    $(document).ready(function(){
                        console.log('Value streams:', STREAMS);
                        var sel = document.getElementById('vsSelect');
                        if (!STREAMS.length){ document.getElementById('stageTrack').innerHTML = '&lt;div class="no-data"&gt;No value streams found in the model.&lt;/div&gt;'; return; }
                        STREAMS.forEach(function(vs){
                            var opt = document.createElement('option');
                            opt.value = vs.id; opt.textContent = vs.name;
                            sel.appendChild(opt);
                        });
                        sel.addEventListener('change', function(){ selectStream(this.value); });
                        selectStream(STREAMS[0].id);
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Value Stream &#8594; Capability Explorer</h1>
                    <p class="subtitle">Pick a value stream to see its stages in sequence. Under each stage are the Level 1 business capabilities it requires; expand a capability to see its sub-capabilities, ordered processes and activities, application functions, services and supporting applications.</p>
                    <div class="vs-select-row">
                        <label for="vsSelect">Value stream:</label>
                        <select id="vsSelect"/>
                    </div>
                    <div class="vs-desc" id="vsDesc"/>
                    <div class="stage-track" id="stageTrack"><p>Loading value streams...</p></div>
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
