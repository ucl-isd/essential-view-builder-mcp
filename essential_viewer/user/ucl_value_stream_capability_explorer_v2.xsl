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
    <xsl:variable name="allPhysProcs" select="/node()/simple_instance[type='Physical_Process']"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allApps" select="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider')]"/>
    <xsl:variable name="allProvRoles" select="/node()/simple_instance[type='Application_Provider_Role']"/>
    <xsl:variable name="allApTaPhys" select="/node()/simple_instance[type='APP_PRO_TO_PHYS_BUS_RELATION']"/>
    <!-- Actors performing physical processes (via process_performed_by_actor_role, direct or through an ACTOR_TO_ROLE_RELATION) -->
    <xsl:variable name="allGroupActors" select="/node()/simple_instance[type='Group_Actor']"/>
    <xsl:variable name="allActorToRole" select="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']"/>
    <!-- App owner organisation + purpose lookups for the detail sidebar -->
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Group_Actor','Individual_Actor')]"/>
    <xsl:variable name="allBusRoles" select="/node()/simple_instance[type=('Group_Business_Role','Individual_Business_Role')]"/>
    <xsl:variable name="ownerRole" select="$allBusRoles[own_slot_value[slot_reference='name']/value='Application Organisation Owner']"/>
    <xsl:variable name="allPurposes" select="/node()/simple_instance[type='Application_Provider_Purpose']"/>
    <!-- Stakeholder relations keyed by the element (app) they are a stakeholder of -->
    <xsl:key name="stakeRelByElement" match="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']" use="own_slot_value[slot_reference='stakeholder_of_elements']/value"/>

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
    <xsl:key name="procsByCapability" match="/node()/simple_instance[type=('Business_Process','Business_Activity')]" use="own_slot_value[slot_reference='realises_business_capability']/value"/>
    <xsl:key name="stagesByStream" match="/node()/simple_instance[type='Value_Stage']" use="own_slot_value[slot_reference='vsg_value_stream']/value"/>
    <!-- Physical processes that implement a business process -->
    <xsl:key name="physByBusProc" match="/node()/simple_instance[type='Physical_Process']" use="own_slot_value[slot_reference='implements_business_process']/value"/>
    <!-- APP_PRO_TO_PHYS_BUS_RELATION keyed by the physical process it supports -->
    <xsl:key name="apPhysRelByPhys" match="/node()/simple_instance[type='APP_PRO_TO_PHYS_BUS_RELATION']" use="own_slot_value[slot_reference='apppro_to_physbus_to_busproc']/value"/>

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

    <!-- Render a business process as a JSON node with its physical processes, services and apps.
         Chain: BusProc -> Physical_Process (implements_business_process)
                Physical_Process <- APP_PRO_TO_PHYS_BUS_RELATION (apppro_to_physbus_to_busproc)
                relation -> apppro_to_physbus_from_appprorole -> Application_Provider_Role
                role -> provided_by_application_provider_roles (reverse) -> Application_Service
                role -> role_for_application_provider -> Composite_Application_Provider
                (plus direct app support via app_pro_supports_phys_proc) -->
    <xsl:template name="renderProcNode">
        <xsl:param name="proc"/>
        <!-- Physical processes implementing this business process -->
        <xsl:variable name="physProcs" select="key('physByBusProc', $proc/name)"/>
        {
        "id":"<xsl:value-of select="eas:jsonText(string($proc/name))"/>",
        "name":"<xsl:value-of select="eas:jsonText(string($proc/own_slot_value[slot_reference='name']/value))"/>",
        "type":"<xsl:value-of select="eas:jsonText(string($proc/type))"/>",
        "description":"<xsl:value-of select="eas:jsonText(string($proc/own_slot_value[slot_reference='description']/value))"/>",
        "physProcs":[<xsl:for-each select="$physProcs">
            <xsl:variable name="pp" select="current()"/>
            <!-- relations supporting this physical process -->
            <xsl:variable name="rels" select="key('apPhysRelByPhys', $pp/name)"/>
            <!-- provider roles referenced by those relations -->
            <xsl:variable name="roles" select="$allProvRoles[name = $rels/own_slot_value[slot_reference='apppro_to_physbus_from_appprorole']/value]"/>
            <!-- providers: via roles, plus any direct app support -->
            <xsl:variable name="roleApps" select="$allApps[name = $roles/own_slot_value[slot_reference='role_for_application_provider']/value]"/>
            <xsl:variable name="directApps" select="$allApps[name = $rels/own_slot_value[slot_reference='apppro_to_physbus_from_apppro']/value]"/>
            <xsl:variable name="ppApps" select="$roleApps | $directApps"/>
            <!-- Actor performing this physical process: process_performed_by_actor_role -> Group_Actor directly,
                 or -> ACTOR_TO_ROLE_RELATION -> act_to_role_from_actor -> Group_Actor -->
            <xsl:variable name="performRefIds" select="$pp/own_slot_value[slot_reference='process_performed_by_actor_role']/value"/>
            <xsl:variable name="directActors" select="$allGroupActors[name = $performRefIds]"/>
            <xsl:variable name="actorRels" select="$allActorToRole[name = $performRefIds]"/>
            <xsl:variable name="indirectActors" select="$allGroupActors[name = $actorRels/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
            <xsl:variable name="ppActors" select="$directActors | $indirectActors"/>
            {"id":"<xsl:value-of select="eas:jsonText(string($pp/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($pp/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string($pp/own_slot_value[slot_reference='description']/value))"/>",
            "actor":"<xsl:for-each select="$ppActors"><xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/><xsl:if test="not(position()=last())">, </xsl:if></xsl:for-each>",
            "appIds":[<xsl:for-each select="$ppApps">"<xsl:value-of select="eas:jsonText(string(current()/name))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
            }<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "apps":[<xsl:variable name="allRels2" select="key('apPhysRelByPhys', $physProcs/name)"/>
            <xsl:variable name="allRoles2" select="$allProvRoles[name = $allRels2/own_slot_value[slot_reference='apppro_to_physbus_from_appprorole']/value]"/>
            <xsl:variable name="roleApps2" select="$allApps[name = $allRoles2/own_slot_value[slot_reference='role_for_application_provider']/value]"/>
            <xsl:variable name="directApps2" select="$allApps[name = $allRels2/own_slot_value[slot_reference='apppro_to_physbus_from_apppro']/value]"/>
            <xsl:variable name="capApps" select="$roleApps2 | $directApps2"/>
            <xsl:for-each select="$capApps">
            <xsl:variable name="app" select="current()"/>
            <xsl:variable name="dm" select="$allDeliveryModels[name=$app/own_slot_value[slot_reference='ap_delivery_model']/value]"/>
            <xsl:variable name="cb" select="$allCodebaseStatuses[name=$app/own_slot_value[slot_reference='ap_codebase_status']/value]"/>
            <xsl:variable name="disp" select="$allDispositions[name=$app/own_slot_value[slot_reference='ap_disposition_lifecycle_status']/value]"/>
            <xsl:variable name="sup" select="$allSuppliers[name=$app/own_slot_value[slot_reference='ap_supplier']/value]"/>
            <!-- Services: app -> provides_application_services -> Application_Provider_Role -> (reverse) provided_by_application_provider_roles -> Application_Service -->
            <xsl:variable name="appProvRoles" select="$allProvRoles[name=$app/own_slot_value[slot_reference='provides_application_services']/value]"/>
            <xsl:variable name="provServices" select="$allAppServices[own_slot_value[slot_reference='provided_by_application_provider_roles']/value = $appProvRoles/name]"/>
            <!-- Purpose -->
            <xsl:variable name="purpose" select="$allPurposes[name=$app/own_slot_value[slot_reference='application_provider_purpose']/value]"/>
            <!-- Owner organisation: stakeholder relation on this app classified as 'Application Organisation Owner' -->
            <xsl:variable name="stakeRels" select="key('stakeRelByElement', $app/name)"/>
            <xsl:variable name="ownerRels" select="$stakeRels[own_slot_value[slot_reference='act_to_role_to_role']/value = $ownerRole/name]"/>
            <xsl:variable name="ownerActors" select="$allActors[name = $ownerRels/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
            <xsl:variable name="ccrs" select="key('ccrByElement', $app/name)"/>
            <xsl:variable name="appContracts" select="$allContracts[name=$ccrs/own_slot_value[slot_reference='contract_component_from_contract']/value]"/>
            {"id":"<xsl:value-of select="eas:jsonText(string($app/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($app/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string($app/own_slot_value[slot_reference='description']/value))"/>","deliveryModel":"<xsl:value-of select="eas:jsonText(string($dm/own_slot_value[slot_reference='name']/value))"/>","codebase":"<xsl:value-of select="eas:jsonText(string($cb/own_slot_value[slot_reference='name']/value))"/>","disposition":"<xsl:value-of select="eas:jsonText(string($disp/own_slot_value[slot_reference='name']/value))"/>","supplier":"<xsl:value-of select="eas:jsonText(string($sup/own_slot_value[slot_reference='name']/value))"/>","purpose":"<xsl:value-of select="eas:jsonText(string($purpose[1]/own_slot_value[slot_reference='name']/value))"/>","owner":"<xsl:for-each select="$ownerActors"><xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/><xsl:if test="not(position()=last())">, </xsl:if></xsl:for-each>","providesServices":[<xsl:for-each select="$provServices">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],"contracts":[<xsl:for-each select="$appContracts">{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","endDate":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='contract_end_date_ISO8601']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
        }
    </xsl:template>

    <!-- Render a single L1 capability as a JSON object -->
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
        "processes":[<xsl:for-each select="$capProcs"><xsl:call-template name="renderProcNode"><xsl:with-param name="proc" select="current()"/></xsl:call-template><xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
        }
    </xsl:template>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Value Stream &#8594; Capability Flow</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1900px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.1rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.1rem}
                    .controls{display:flex;flex-direction:column;gap:12px;margin-bottom:18px}
                    .vs-select-row{display:flex;align-items:center;gap:12px;flex-wrap:wrap}
                    .vs-select-row label{font-weight:700;color:#361A54}
                    .vs-select-row select{padding:10px 14px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem;min-width:320px;background:#fff}
                    .stage-filter{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:10px;padding:12px 16px}
                    .stage-filter .sf-title{font-weight:700;color:#361A54;margin-bottom:8px;display:flex;align-items:center;gap:12px}
                    .sf-actions{font-size:0.85rem;font-weight:600}
                    .sf-actions a{color:#7d1fe0;cursor:pointer;text-decoration:underline;margin-left:10px}
                    .sf-checks{display:flex;flex-wrap:wrap;gap:8px}
                    .sf-chk{display:flex;align-items:center;gap:6px;background:#fff;border:1px solid #DDBDFF;border-radius:20px;padding:6px 14px;cursor:pointer;font-weight:600;color:#361A54;font-size:0.95rem;user-select:none}
                    .sf-chk input{cursor:pointer}
                    .sf-chk .sf-idx{background:#361A54;color:#fff;border-radius:50%;width:20px;height:20px;display:inline-flex;align-items:center;justify-content:center;font-size:0.75rem}
                    .vs-desc{color:#4B5563;margin-bottom:18px;line-height:1.55;font-size:1.05rem}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    /* Stage columns */
                    .stage-track{display:flex;gap:8px;overflow-x:auto;padding-bottom:8px;align-items:flex-start}
                    .stage-col{flex:1 1 0;min-width:340px;display:flex;flex-direction:column}
                    .stage-head{position:relative;background:linear-gradient(135deg,#361A54,#5B2A87);color:#fff;padding:14px 20px 14px 30px;font-weight:700;font-size:1.05rem;clip-path:polygon(0 0, calc(100% - 16px) 0, 100% 50%, calc(100% - 16px) 100%, 0 100%, 16px 50%);min-height:52px;display:flex;align-items:center;gap:8px}
                    .stage-col:first-child .stage-head{clip-path:polygon(0 0, calc(100% - 16px) 0, 100% 50%, calc(100% - 16px) 100%, 0 100%);padding-left:20px}
                    .stage-index{background:rgba(255,255,255,0.25);border-radius:50%;width:24px;height:24px;display:flex;align-items:center;justify-content:center;font-size:0.85rem;flex-shrink:0}
                    .stage-body{background:#F5F0FF;border:1px solid #DDBDFF;border-top:none;border-radius:0 0 8px 8px;padding:10px;display:flex;flex-direction:column;gap:8px;flex:1}
                    .stage-cap-count{font-size:0.8rem;color:#6B7280;padding:2px 4px}
                    /* L1 capability card */
                    .vcap{background:#fff;border:1px solid #E5E7EB;border-radius:8px;overflow:hidden}
                    .vcap-head{display:flex;align-items:center;gap:8px;padding:10px 12px;cursor:pointer;background:#EDE4FF;color:#361A54;font-weight:700}
                    .vcap-head .caret{font-size:0.85rem;transition:transform 0.2s;flex-shrink:0}
                    .vcap-head.open .caret{transform:rotate(90deg)}
                    .vcap-name{flex:1;font-size:1rem}
                    .vcap-body{display:none;padding:12px;background:#FBF9FF;border-top:1px solid #E5E7EB}
                    .vcap-body.open{display:block}
                    .vcap-desc{color:#4B5563;margin-bottom:12px;line-height:1.5;font-size:0.95rem}
                    /* Connected node diagram - vertical tiers (top: Capability, bottom: Application) */
                    .diagram-scroll{overflow-x:auto}
                    .diagram{position:relative}
                    .diagram svg.links{position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:1}
                    .diag-rows{position:relative;display:flex;flex-direction:column;gap:52px;z-index:2}
                    .diag-row{display:flex;flex-direction:column;gap:6px}
                    .diag-row-title{font-size:0.72rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;padding-bottom:4px;border-bottom:2px solid;margin-bottom:4px;align-self:flex-start}
                    .row-cap .diag-row-title{color:#361A54;border-color:#361A54}
                    .row-pp .diag-row-title{color:#B26A00;border-color:#B26A00}
                    .row-app .diag-row-title{color:#12B76A;border-color:#12B76A}
                    .diag-row-nodes{display:flex;flex-wrap:wrap;gap:16px;align-items:flex-start}
                    .row-cap .diag-row-nodes{justify-content:center}
                    .node{border-radius:8px;padding:9px 12px;font-weight:600;font-size:0.9rem;border:1px solid;position:relative;line-height:1.3;max-width:240px}
                    .node.n-cap{background:#EDE4FF;color:#361A54;border-color:#DDBDFF;font-size:1rem;padding:12px 18px;cursor:pointer}
                    .node.n-cap:hover{box-shadow:0 2px 8px rgba(0,0,0,0.15)}
                    .node.n-pp{background:#FFF4E5;color:#8A5200;border-color:#F3D6A6;text-align:left}
                    .node.n-pp .pp-line{display:block}
                    .node.n-pp .pp-lbl{font-weight:700;text-transform:uppercase;font-size:0.72rem;letter-spacing:0.03em;color:#B26A00}
                    .node.n-pp .pp-empty{color:#C4A98A;font-style:italic;font-weight:400}
                    .node.n-pp{cursor:pointer}
                    /* click-to-focus highlighting */
                    .node.faded{opacity:0.25}
                    .node.focused{box-shadow:0 0 0 2px #7d1fe0;border-color:#7d1fe0;opacity:1}
                    svg.links path.link-path{transition:opacity 0.15s}
                    svg.links path.link-path.faded{opacity:0.12}
                    svg.links path.link-path.focused{stroke:#7d1fe0;stroke-width:2.4;opacity:1}
                    .node.n-app{background:#E7F8EF;color:#0B7A47;border-color:#B7E9CD;cursor:pointer}
                    .node.n-app:hover{box-shadow:0 2px 8px rgba(0,0,0,0.15)}
                    .node.dim{opacity:0.25}
                    .node .n-meta{display:block;font-size:0.72rem;color:#6B7280;font-weight:500;margin-top:3px}
                    .diag-empty{color:#9CA3AF;font-style:italic;font-size:0.85rem;padding:6px}
                    .legend{display:flex;flex-wrap:wrap;gap:14px;margin:6px 0 14px 0;font-size:0.8rem;color:#4B5563}
                    .legend span{display:inline-flex;align-items:center;gap:5px}
                    .legend i{width:14px;height:14px;border-radius:3px;display:inline-block;border:1px solid rgba(0,0,0,0.1)}
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
                    .sb-pillwrap{display:flex;flex-wrap:wrap;gap:6px}
                    .sb-pill{display:inline-block;border-radius:16px;padding:4px 12px;font-size:0.95rem;font-weight:600}
                    .sb-pill.svc{background:#0E9E86;color:#fff}
                    .sb-child-list{display:flex;flex-direction:column;gap:8px}
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
                        var url = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(a.id) + '&amp;cl=en-gb&amp;XSL=application/core_al_app_provider_info_deps_model.xsl';
                        html += '&lt;a class="sb-summary-btn" href="' + url + '" target="_blank"&gt;View Application Dependency Model &#8594;&lt;/a&gt;';
                        html += detailRow('Description', a.description);
                        html += detailRow('Owner Organisation', a.owner);
                        html += detailRow('Purpose', a.purpose);
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
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Physical processes&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (p.physProcs &amp;&amp; p.physProcs.length){
                            html += '&lt;div class="sb-child-list"&gt;';
                            p.physProcs.forEach(function(pp){ html += '&lt;div class="sb-contract"&gt;&lt;span class="ct-name"&gt;' + esc(pp.name) + '&lt;/span&gt;&lt;span class="ct-end"&gt;' + pp.appIds.length + ' app' + (pp.appIds.length===1?'':'s') + '&lt;/span&gt;&lt;/div&gt;'; });
                            html += '&lt;/div&gt;';
                        } else { html += '&lt;span class="sb-empty"&gt;None linked&lt;/span&gt;'; }
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

                    var _nodeSeq = 0;
                    function nid(){ return 'nd' + (_nodeSeq++); }

                    // Build ONE combined diagram for a whole stage.
                    // 3 vertical tiers, top -&gt; bottom: Capability | Physical Process | Application
                    // All the stage's capabilities appear as top-tier nodes. Physical processes and apps
                    // are de-duplicated across the capabilities. Links drawn: cap-&gt;pp and pp-&gt;app.
                    function renderStageDiagram(stage){
                        var capNodes = [], ppNodes = [], appNodes = [];
                        var ppById = {}, appById = {};
                        var links = []; // {from, to}
                        (stage.caps||[]).forEach(function(c){
                            var capDom = nid();
                            var capHasLink = false;
                            c.processes.forEach(function(bp){
                                (bp.physProcs||[]).forEach(function(pp){
                                    if (!(pp.appIds &amp;&amp; pp.appIds.length)) return; // skip phys procs with no application
                                    var ppDom = ppById[pp.id];
                                    if (!ppDom){ ppDom = nid(); ppById[pp.id] = ppDom; ppNodes.push({domId: ppDom, node: pp}); }
                                    // capability -&gt; physical process link (avoid duplicates)
                                    links.push({from: capDom, to: ppDom});
                                    capHasLink = true;
                                    (pp.appIds||[]).forEach(function(aid){
                                        if (!appById[aid]){ appById[aid] = nid(); var app = (bp.apps||[]).find(function(a){return a.id===aid;}) || APP_BY_ID[aid]; appNodes.push({domId: appById[aid], node: app || {id:aid, name:aid}}); }
                                        links.push({from: ppDom, to: appById[aid]});
                                    });
                                });
                            });
                            // show the capability node even if it has no app-linked processes (as a leaf)
                            capNodes.push({domId: capDom, node: c, hasLink: capHasLink});
                        });

                        if (!capNodes.length) return {html: '&lt;div class="diag-empty"&gt;No linked capabilities&lt;/div&gt;', links: [], empty: true};

                        function rowHtml(cls, title, nodesHtml){
                            return '&lt;div class="diag-row ' + cls + '"&gt;&lt;div class="diag-row-title"&gt;' + title + '&lt;/div&gt;&lt;div class="diag-row-nodes"&gt;' + (nodesHtml || '&lt;div class="diag-empty"&gt;None&lt;/div&gt;') + '&lt;/div&gt;&lt;/div&gt;';
                        }
                        var capRow = capNodes.map(function(c){
                            return '&lt;div class="node n-cap" id="' + c.domId + '" onclick="focusCap(\'' + c.domId + '\')" title="' + esc(c.node.description || '') + '"&gt;' + esc(c.node.name) + '&lt;/div&gt;';
                        }).join('');
                        var ppRow = ppNodes.map(function(p){
                            var actor = p.node.actor ? esc(p.node.actor) : '&lt;span class="pp-empty"&gt;Not set&lt;/span&gt;';
                            var procName = p.node.name || '';
                            var idx = procName.indexOf(' performing ');
                            if (idx !== -1) procName = procName.substring(idx + ' performing '.length);
                            return '&lt;div class="node n-pp" id="' + p.domId + '" onclick="focusPhys(\'' + p.domId + '\')"&gt;&lt;span class="pp-line"&gt;&lt;span class="pp-lbl"&gt;Actor:&lt;/span&gt; ' + actor + '&lt;/span&gt;&lt;span class="pp-line"&gt;&lt;span class="pp-lbl"&gt;Process:&lt;/span&gt; ' + esc(procName) + '&lt;/span&gt;&lt;/div&gt;';
                        }).join('');
                        var appRow = appNodes.map(function(a){ return '&lt;div class="node n-app" id="' + a.domId + '" onclick="event.stopPropagation(); focusApp(\'' + a.domId + '\'); openApp(\'' + a.node.id + '\')"&gt;' + esc(a.node.name) + '&lt;/div&gt;'; }).join('');

                        var html = '&lt;div class="diagram-scroll"&gt;&lt;div class="diagram"&gt;&lt;svg class="links"&gt;&lt;/svg&gt;&lt;div class="diag-rows"&gt;';
                        html += rowHtml('row-cap', 'Capability', capRow);
                        html += rowHtml('row-pp', 'Physical Process', ppRow);
                        html += rowHtml('row-app', 'Application', appRow);
                        html += '&lt;/div&gt;&lt;/div&gt;&lt;/div&gt;';
                        return {html: html, links: links};
                    }

                    // Draw SVG lines between node DOM elements after layout
                    function drawLinks(diagramEl, links){
                        var svg = diagramEl.querySelector('svg.links');
                        var inner = diagramEl.querySelector('.diag-rows');
                        if (!svg || !inner) return;
                        var w = inner.scrollWidth, h = inner.scrollHeight;
                        diagramEl.style.width = w + 'px';
                        diagramEl.style.height = h + 'px';
                        svg.setAttribute('width', w); svg.setAttribute('height', h);
                        svg.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
                        var base = diagramEl.getBoundingClientRect();
                        var ns = 'http://www.w3.org/2000/svg';
                        svg.innerHTML = '';
                        links.forEach(function(lk){
                            var a = document.getElementById(lk.from), b = document.getElementById(lk.to);
                            if (!a || !b) return;
                            var ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
                            // vertical flow: from bottom-centre of source node to top-centre of target node
                            var x1 = ra.left + ra.width/2 - base.left, y1 = ra.bottom - base.top;
                            var x2 = rb.left + rb.width/2 - base.left, y2 = rb.top - base.top;
                            var my = (y1 + y2) / 2;
                            var path = document.createElementNS(ns, 'path');
                            path.setAttribute('d', 'M ' + x1 + ' ' + y1 + ' C ' + x1 + ' ' + my + ', ' + x2 + ' ' + my + ', ' + x2 + ' ' + y2);
                            path.setAttribute('fill', 'none');
                            path.setAttribute('stroke', '#B49AD1');
                            path.setAttribute('stroke-width', '1.6');
                            path.setAttribute('class', 'link-path');
                            path.setAttribute('data-from', lk.from);
                            path.setAttribute('data-to', lk.to);
                            svg.appendChild(path);
                        });
                    }

                    // Click a physical process to focus it: highlight that process, its lines and its apps;
                    // grey out everything else in the same diagram. Click it again to clear.
                    function focusPhys(ppDomId){
                        var ppEl = document.getElementById(ppDomId);
                        if (!ppEl) return;
                        var diagram = ppEl.closest('.diagram');
                        if (!diagram) return;
                        var alreadyFocused = ppEl.classList.contains('focused');
                        clearFocus(diagram);
                        if (alreadyFocused) return; // toggle off

                        diagram.classList.add('has-focus');
                        // find the apps connected to this pp via the svg paths
                        var connectedApps = {};
                        var paths = diagram.querySelectorAll('svg.links path.link-path');
                        paths.forEach(function(p){
                            if (p.getAttribute('data-from') === ppDomId){
                                p.classList.add('focused');
                                connectedApps[p.getAttribute('data-to')] = true;
                            } else {
                                p.classList.add('faded');
                            }
                        });
                        // also light the cap -&gt; this pp links and their capabilities
                        var connectedCaps = {};
                        paths.forEach(function(p){
                            if (p.getAttribute('data-to') === ppDomId){
                                p.classList.remove('faded'); p.classList.add('focused');
                                connectedCaps[p.getAttribute('data-from')] = true;
                            }
                        });
                        // mark cap, pp and app nodes
                        diagram.querySelectorAll('.node.n-cap').forEach(function(n){
                            n.classList.add(connectedCaps[n.id] ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-pp').forEach(function(n){
                            n.classList.add(n.id === ppDomId ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-app').forEach(function(n){
                            n.classList.add(connectedApps[n.id] ? 'focused' : 'faded');
                        });
                    }

                    // Click an application to focus it: highlight that app, its lines and the physical
                    // processes feeding it; grey out everything else. Click again to clear.
                    function focusApp(appDomId){
                        var appEl = document.getElementById(appDomId);
                        if (!appEl) return;
                        var diagram = appEl.closest('.diagram');
                        if (!diagram) return;
                        var alreadyFocused = appEl.classList.contains('focused');
                        clearFocus(diagram);
                        if (alreadyFocused) return; // toggle off

                        diagram.classList.add('has-focus');
                        var paths = diagram.querySelectorAll('svg.links path.link-path');
                        // 1) pp -&gt; this app links
                        var connectedPhys = {};
                        paths.forEach(function(p){
                            if (p.getAttribute('data-to') === appDomId){
                                p.classList.add('focused');
                                connectedPhys[p.getAttribute('data-from')] = true;
                            }
                        });
                        // 2) cap -&gt; those physical processes links (so the whole chain is lit)
                        var connectedCaps = {};
                        paths.forEach(function(p){
                            if (connectedPhys[p.getAttribute('data-to')]){
                                p.classList.add('focused');
                                connectedCaps[p.getAttribute('data-from')] = true;
                            }
                        });
                        // fade any path not focused
                        paths.forEach(function(p){ if (!p.classList.contains('focused')) p.classList.add('faded'); });
                        // mark nodes across all three tiers
                        diagram.querySelectorAll('.node.n-app').forEach(function(n){
                            n.classList.add(n.id === appDomId ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-pp').forEach(function(n){
                            n.classList.add(connectedPhys[n.id] ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-cap').forEach(function(n){
                            n.classList.add(connectedCaps[n.id] ? 'focused' : 'faded');
                        });
                    }

                    // Click a capability to focus it: highlight it, its physical processes, their apps,
                    // and all connecting lines; grey out everything else. Click again to clear.
                    function focusCap(capDomId){
                        var capEl = document.getElementById(capDomId);
                        if (!capEl) return;
                        var diagram = capEl.closest('.diagram');
                        if (!diagram) return;
                        var alreadyFocused = capEl.classList.contains('focused');
                        clearFocus(diagram);
                        if (alreadyFocused) return; // toggle off

                        diagram.classList.add('has-focus');
                        var paths = diagram.querySelectorAll('svg.links path.link-path');
                        // 1) cap -&gt; pp links from this capability
                        var connectedPhys = {};
                        paths.forEach(function(p){
                            if (p.getAttribute('data-from') === capDomId){
                                p.classList.add('focused');
                                connectedPhys[p.getAttribute('data-to')] = true;
                            }
                        });
                        // 2) pp -&gt; app links from those physical processes
                        var connectedApps = {};
                        paths.forEach(function(p){
                            if (connectedPhys[p.getAttribute('data-from')]){
                                p.classList.add('focused');
                                connectedApps[p.getAttribute('data-to')] = true;
                            }
                        });
                        // fade any path not already focused
                        paths.forEach(function(p){ if (!p.classList.contains('focused')) p.classList.add('faded'); });
                        // mark nodes
                        diagram.querySelectorAll('.node.n-cap').forEach(function(n){
                            n.classList.add(n.id === capDomId ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-pp').forEach(function(n){
                            n.classList.add(connectedPhys[n.id] ? 'focused' : 'faded');
                        });
                        diagram.querySelectorAll('.node.n-app').forEach(function(n){
                            n.classList.add(connectedApps[n.id] ? 'focused' : 'faded');
                        });
                    }

                    function clearFocus(diagram){
                        diagram.classList.remove('has-focus');
                        diagram.querySelectorAll('.focused, .faded').forEach(function(el){
                            el.classList.remove('focused','faded');
                        });
                    }

                    var PENDING = []; // stage diagrams awaiting line-draw after layout

                    function renderStream(vs){
                        var container = document.getElementById('stageTrack');
                        PENDING = [];
                        var stages = vs.stages.filter(function(st){ return ACTIVE_STAGES[st.id] !== false; });
                        if (!stages.length){ container.innerHTML = '&lt;div class="no-data"&gt;No stages selected. Tick one or more stages above.&lt;/div&gt;'; return; }
                        var html = '';
                        stages.forEach(function(st, i){
                            var diag = renderStageDiagram(st);
                            var diagId = 'stagediag-' + i;
                            html += '&lt;div class="stage-col"&gt;';
                            html += '&lt;div class="stage-head"&gt;&lt;span class="stage-index"&gt;' + esc(st.index || '') + '&lt;/span&gt;&lt;span&gt;' + esc(st.name) + '&lt;/span&gt;&lt;/div&gt;';
                            html += '&lt;div class="stage-body" id="' + diagId + '"&gt;';
                            html += '&lt;div class="stage-cap-count"&gt;' + st.caps.length + ' capability' + (st.caps.length===1?'':'ies') + '&lt;/div&gt;';
                            html += diag.html;
                            html += '&lt;/div&gt;&lt;/div&gt;';
                            PENDING.push({diagId: diagId, links: diag.links});
                        });
                        container.innerHTML = html;
                        // draw all stage diagram lines once laid out
                        setTimeout(function(){
                            PENDING.forEach(function(p){
                                var body = document.getElementById(p.diagId);
                                if (!body) return;
                                var dg = body.querySelector('.diagram');
                                if (dg) drawLinks(dg, p.links);
                            });
                        }, 30);
                    }

                    var ACTIVE_STAGES = {}; // stageId -> bool
                    var CURRENT_VS = null;

                    function buildStageFilter(vs){
                        CURRENT_VS = vs;
                        ACTIVE_STAGES = {};
                        var wrap = document.getElementById('stageChecks');
                        var html = '';
                        vs.stages.forEach(function(st){
                            ACTIVE_STAGES[st.id] = true;
                            html += '&lt;label class="sf-chk"&gt;&lt;input type="checkbox" checked="checked" data-stage="' + st.id + '" onchange="onStageToggle(this)"/&gt;&lt;span class="sf-idx"&gt;' + esc(st.index||'') + '&lt;/span&gt;' + esc(st.name) + '&lt;/label&gt;';
                        });
                        wrap.innerHTML = html || '&lt;span class="diag-empty"&gt;This value stream has no stages.&lt;/span&gt;';
                    }

                    function onStageToggle(cb){
                        ACTIVE_STAGES[cb.getAttribute('data-stage')] = cb.checked;
                        if (CURRENT_VS) renderStream(CURRENT_VS);
                    }
                    function setAllStages(val){
                        var boxes = document.querySelectorAll('#stageChecks input[type=checkbox]');
                        for (var i=0;i&lt;boxes.length;i++){ boxes[i].checked = val; ACTIVE_STAGES[boxes[i].getAttribute('data-stage')] = val; }
                        if (CURRENT_VS) renderStream(CURRENT_VS);
                    }

                    function selectStream(id){
                        var vs = STREAMS.find(function(s){ return s.id === id; });
                        if (!vs) return;
                        document.getElementById('vsDesc').innerHTML = vs.description ? esc(vs.description) : '';
                        buildStageFilter(vs);
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
                    <h1>UCL Value Stream &#8594; Capability Flow</h1>
                    <p class="subtitle">Pick a value stream and the stages you want to see. Under each stage are its Level 1 capabilities; expand one to see the linked chain drawn as a vertical diagram: Capability at the top, the Physical Processes that realise it in the middle, and the supporting Applications at the bottom. Physical processes that don't reach an application are hidden.</p>
                    <div class="controls">
                        <div class="vs-select-row">
                            <label for="vsSelect">Value stream:</label>
                            <select id="vsSelect"/>
                        </div>
                        <div class="stage-filter">
                            <div class="sf-title">Stages
                                <span class="sf-actions"><a onclick="setAllStages(true)">Select all</a><a onclick="setAllStages(false)">Clear</a></span>
                            </div>
                            <div class="sf-checks" id="stageChecks"/>
                        </div>
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
