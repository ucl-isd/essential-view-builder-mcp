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

    <!-- ===== Model variables (confirmed against existing core_api_al_* views) ===== -->
    <xsl:variable name="allAppCaps" select="/node()/simple_instance[type='Application_Capability']"/>
    <xsl:variable name="allAppServices" select="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]"/>
    <xsl:variable name="allAppProviderRoles" select="/node()/simple_instance[type='Application_Provider_Role']"/>
    <xsl:variable name="allAppProviders" select="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider')]"/>
    <xsl:variable name="allManagedServices" select="/node()/simple_instance[type='Managed_Service']"/>
    <!-- Detail lookups -->
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <xsl:variable name="allDeliveryModels" select="/node()/simple_instance[type='Application_Delivery_Model']"/>
    <xsl:variable name="allDispositions" select="/node()/simple_instance[type='Application_Disposition' or contains(type,'isposition')]"/>
    <xsl:variable name="allCriticalities" select="/node()/simple_instance[type='Managed_Service_Criticality']"/>
    <!-- Managed service stakeholder chain: stakeholders -> ACTOR_TO_ROLE_RELATION -> actor + role -->
    <xsl:variable name="allActorToRole" select="/node()/simple_instance[own_slot_value[slot_reference='act_to_role_from_actor']]"/>
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Individual_Actor','Group_Actor') or supertype='Actor']"/>
    <xsl:variable name="allRoles" select="/node()/simple_instance[supertype='Business_Role' or type='Individual_Business_Role']"/>
    <!-- Static architecture connections: app -> usage(s) -> APU-TO-APU edges -> other app -->
    <xsl:variable name="allStaticUsages" select="/node()/simple_instance[type='Static_Application_Provider_Usage']"/>
    <xsl:variable name="allApuEdges" select="/node()/simple_instance[type=':APU-TO-APU-STATIC-RELATION']"/>
    <xsl:variable name="allInfoRepRels" select="/node()/simple_instance[type=('APP_PRO_TO_INFOREP_RELATION','APP_PRO_TO_INFOREP_EXCHANGE_RELATION')]"/>
    <xsl:variable name="allInfoReps" select="/node()/simple_instance[type='Information_Representation']"/>

    <!-- Keys for performance -->
    <xsl:key name="servicesByCapability" match="/node()/simple_instance[type=('Application_Service','Composite_Application_Service')]" use="own_slot_value[slot_reference='realises_application_capabilities']/value"/>
    <xsl:key name="roleByName" match="/node()/simple_instance[type='Application_Provider_Role']" use="name"/>
    <xsl:key name="providerByName" match="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider')]" use="name"/>
    <xsl:key name="managedServicesByElement" match="/node()/simple_instance[type='Managed_Service']" use="own_slot_value[slot_reference='ms_managed_app_elements']/value"/>
    <!-- Static usages that represent an app (keyed by the app they are a usage of) -->
    <xsl:key name="usagesByApp" match="/node()/simple_instance[type='Static_Application_Provider_Usage']" use="own_slot_value[slot_reference='static_usage_of_app_provider']/value"/>
    <xsl:key name="usageByName" match="/node()/simple_instance[type='Static_Application_Provider_Usage']" use="name"/>
    <!-- APU edges keyed by their :FROM and :TO usage -->
    <xsl:key name="apuByFrom" match="/node()/simple_instance[type=':APU-TO-APU-STATIC-RELATION']" use="own_slot_value[slot_reference=':FROM']/value"/>
    <xsl:key name="apuByTo" match="/node()/simple_instance[type=':APU-TO-APU-STATIC-RELATION']" use="own_slot_value[slot_reference=':TO']/value"/>
    <xsl:key name="appProvByName" match="/node()/simple_instance[type=('Application_Provider','Composite_Application_Provider','Application_Provider_Interface')]" use="name"/>

    <!-- JSON-safe text escaper (backslash, quote, strip newlines) -->
    <xsl:function name="eas:jsonText">
        <xsl:param name="theString"/>
        <xsl:variable name="s1" select="replace(string($theString), '\\', '\\\\')"/>
        <xsl:variable name="s2" select="replace($s1, '&quot;', '\\&quot;')"/>
        <xsl:variable name="s3" select="replace($s2, '&#10;', ' ')"/>
        <xsl:variable name="s4" select="replace($s3, '&#13;', ' ')"/>
        <xsl:variable name="s5" select="replace($s4, '&#9;', ' ')"/>
        <xsl:value-of select="$s5"/>
    </xsl:function>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Application Capability Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1400px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.2rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.1rem}
                    .cap-search{margin-bottom:20px}
                    .cap-search input{width:100%;max-width:420px;padding:10px 14px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem}
                    .no-data{text-align:center;padding:40px;color:#6B7280}

                    /* Capability (level 0) */
                    .cap-list{display:flex;flex-direction:column;gap:14px}
                    .cap-card{border:1px solid #E5E7EB;border-radius:12px;background:#fff;overflow:hidden;box-shadow:0 1px 3px rgba(54,26,84,0.06);transition:box-shadow 0.15s}
                    .cap-card:hover{box-shadow:0 6px 18px rgba(153,58,255,0.12)}
                    .cap-head{display:flex;align-items:center;gap:14px;padding:18px 22px;cursor:pointer;background:linear-gradient(90deg,#361A54,#5B2A87);color:#fff}
                    .cap-head .caret{font-size:1rem;transition:transform 0.2s;flex-shrink:0}
                    .cap-head.open .caret{transform:rotate(90deg)}
                    .cap-head .cap-name{font-size:1.6rem;font-weight:700;flex:1}
                    .cap-head .cap-count{background:rgba(255,255,255,0.22);border-radius:20px;padding:5px 16px;font-size:1.05rem;font-weight:600}
                    .cap-body{display:none;padding:18px 22px;background:#FBF9FF}
                    .cap-body.open{display:block}
                    .cap-desc{color:#4B5563;margin-bottom:16px;line-height:1.55;font-size:1.15rem}

                    /* Service (level 1) */
                    .svc-card{border:1px solid #DDBDFF;border-radius:10px;background:#EDE4FF;margin-bottom:12px;overflow:hidden}
                    .svc-head{display:flex;align-items:center;gap:12px;padding:14px 18px;cursor:pointer}
                    .svc-head .caret{color:#7d1fe0;font-size:0.9rem;transition:transform 0.2s;flex-shrink:0}
                    .svc-head.open .caret{transform:rotate(90deg)}
                    .svc-head .svc-name{font-size:1.35rem;font-weight:700;color:#361A54;flex:1}
                    .svc-head .svc-tag{font-size:0.9rem;color:#7d1fe0;background:#fff;border:1px solid #DDBDFF;border-radius:20px;padding:3px 12px;font-weight:600}
                    .svc-body{display:none;padding:14px 18px 4px 18px;background:#F7F2FF}
                    .svc-body.open{display:block}
                    .svc-desc{color:#4B5563;margin-bottom:14px;line-height:1.55;font-size:1.1rem}

                    /* Nested boxes (apps / business services) */
                    .nest-cols{display:flex;gap:16px;flex-wrap:wrap;padding-bottom:12px}
                    .nest-box{flex:1;min-width:300px;background:#fff;border:1px solid #E5E7EB;border-radius:10px;padding:14px 16px}
                    .nest-title{font-size:1rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;margin-bottom:10px;padding-bottom:6px;border-bottom:2px solid}
                    .nest-title.ms{color:#1AAB40;border-color:#1AAB40}
                    .nest-title.cap-prov{color:#2E75B6;border-color:#2E75B6}
                    .pill-wrap{display:flex;flex-wrap:wrap;gap:8px}
                    .chip{display:inline-block;border-radius:20px;padding:9px 18px;cursor:pointer;font-weight:600;font-size:1.1rem;transition:transform 0.1s,box-shadow 0.1s}
                    .chip:hover{transform:translateY(-2px);box-shadow:0 3px 10px rgba(0,0,0,0.15)}
                    .chip.ms{background:#12B76A;color:#fff}
                    .chip.cap-prov{background:#3E7DD6;color:#fff}
                    /* App pills shaded by TIME status (dark Invest -> light Eliminate) */
                    .chip.app-pill{border:1px solid rgba(0,0,0,0.08)}
                    .time-invest{background:#361A54;color:#fff}
                    .time-tolerate{background:#7B4FA8;color:#fff}
                    .time-migrate{background:#C6A8E6;color:#361A54}
                    .time-eliminate{background:#EDE4FF;color:#361A54}
                    .time-none{background:#9CA3AF;color:#fff}
                    /* TIME legend */
                    .time-legend{display:flex;gap:16px;flex-wrap:wrap;align-items:center;margin-bottom:18px;font-size:1rem;color:#4B5563}
                    .time-legend .tl-item{display:flex;align-items:center;gap:6px}
                    .time-legend .tl-sw{width:16px;height:16px;border-radius:4px;display:inline-block;border:1px solid rgba(0,0,0,0.1)}
                    .chip-detail{display:none;background:#fff;border:1px solid #E5E7EB;border-radius:8px;padding:12px 14px;margin:-4px 0 10px 0;font-size:0.95rem;color:#333;line-height:1.5}
                    .chip-detail.open{display:block}
                    .chip-detail .cd-label{font-size:0.78rem;text-transform:uppercase;color:#6B7280;font-weight:700;letter-spacing:0.04em}
                    .chip-detail .cd-value{margin-bottom:8px}
                    .empty-note{color:#9CA3AF;font-style:italic;font-size:0.92rem}

                    /* Slide-in sidebar */
                    .sb-overlay{position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.35);z-index:999;display:none}
                    .sb-overlay.open{display:block}
                    .sidebar{position:fixed;top:0;right:-480px;width:460px;max-width:92vw;height:100vh;background:#fff;box-shadow:-4px 0 24px rgba(0,0,0,0.18);z-index:1000;transition:right 0.3s ease;overflow-y:auto;padding:28px}
                    .sidebar.open{right:0}
                    .sb-close{position:absolute;top:14px;right:16px;font-size:24px;cursor:pointer;color:#6B7280;background:none;border:none}
                    .sb-kicker{display:inline-block;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;color:#fff;padding:4px 12px;border-radius:20px;margin-bottom:10px}
                    .sb-kicker.ms{background:#12B76A}
                    .sb-kicker.cap-prov{background:#3E7DD6}
                    .sb-title{color:#361A54;margin:0 0 14px 0;padding-right:30px;font-size:1.5rem;font-weight:700}
                    .sb-summary-btn{display:inline-block;background:#993AFF;color:#fff;text-decoration:none;padding:9px 18px;border-radius:6px;font-weight:600;font-size:1.05rem;margin-bottom:20px}
                    .sb-summary-btn:hover{background:#7d1fe0;color:#fff}
                    .sb-row{margin-bottom:16px}
                    .sb-label{font-size:0.9rem;text-transform:uppercase;letter-spacing:0.04em;color:#6B7280;font-weight:700;margin-bottom:3px}
                    .sb-value{font-size:1.2rem;color:#222;line-height:1.55}
                    .sb-empty{color:#9CA3AF;font-style:italic}
                    .sb-stake{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:10px 12px;margin-bottom:8px;font-weight:600;color:#361A54}
                    .sb-stake-sub{font-weight:400;color:#6B7280;font-size:0.92rem;margin-top:2px}
                    .flow-list{display:flex;flex-direction:column;gap:8px}
                    .flow-item{display:flex;align-items:baseline;gap:8px;flex-wrap:wrap;background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:9px 12px}
                    .flow-item.flow-out{border-left:4px solid #3E7DD6}
                    .flow-item.flow-in{border-left:4px solid #12B76A}
                    .flow-arrow{font-weight:700;color:#361A54}
                    .flow-app{font-weight:700;color:#361A54;font-size:1.05rem}
                    .flow-label{font-size:0.85rem;color:#6B7280;background:#fff;border:1px solid #E5E7EB;border-radius:12px;padding:1px 10px}
                    .flow-info{flex-basis:100%;font-size:0.9rem;color:#4B5563;margin-top:2px}
                </style>
                <script type="text/javascript">
                    // ===== Embedded data from XSL =====
                    var CAPS = [<xsl:for-each select="$allAppCaps">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="cap" select="current()"/>
                        <xsl:variable name="services" select="key('servicesByCapability', $cap/name)"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($cap/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($cap/own_slot_value[slot_reference='description']/value))"/>",
                        "services":[<xsl:for-each select="$services">
                            <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                            <xsl:variable name="svc" select="current()"/>
                            <!-- Composite application providers: service -> provider roles -> role_for_application_provider -> provider -->
                            <xsl:variable name="svcRoles" select="$allAppProviderRoles[name=$svc/own_slot_value[slot_reference='provided_by_application_provider_roles']/value]"/>
                            <xsl:variable name="svcProviders" select="$allAppProviders[name=$svcRoles/own_slot_value[slot_reference='role_for_application_provider']/value]"/>
                            <!-- Managed services: Managed_Service where ms_managed_app_elements contains this service name -->
                            <xsl:variable name="svcManaged" select="key('managedServicesByElement', $svc/name)"/>
                            {
                            "id":"<xsl:value-of select="eas:jsonText(string($svc/name))"/>",
                            "name":"<xsl:value-of select="eas:jsonText(string($svc/own_slot_value[slot_reference='name']/value))"/>",
                            "type":"<xsl:value-of select="eas:jsonText(string($svc/type))"/>",
                            "description":"<xsl:value-of select="eas:jsonText(string($svc/own_slot_value[slot_reference='description']/value))"/>",
                            "providers":[<xsl:for-each select="$svcProviders">
                                <xsl:variable name="prov" select="current()"/>
                                <xsl:variable name="supplier" select="$allSuppliers[name=$prov/own_slot_value[slot_reference='ap_supplier']/value]"/>
                                <xsl:variable name="delivery" select="$allDeliveryModels[name=$prov/own_slot_value[slot_reference='ap_delivery_model']/value]"/>
                                <xsl:variable name="disposition" select="$allDispositions[name=$prov/own_slot_value[slot_reference='ap_disposition_lifecycle_status']/value]"/>
<xsl:variable name="modules" select="$allAppProviders[name=$prov/own_slot_value[slot_reference='contained_application_providers']/value]"/>
                                <!-- Static architecture connections -->
                                <xsl:variable name="provUsages" select="key('usagesByApp', $prov/name)"/>
                                <xsl:variable name="outEdges" select="key('apuByFrom', $provUsages/name)"/>
                                <xsl:variable name="inEdges" select="key('apuByTo', $provUsages/name)"/>
                                {"id":"<xsl:value-of select="eas:jsonText(string($prov/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($prov/own_slot_value[slot_reference='name']/value))"/>","type":"<xsl:value-of select="eas:jsonText(string($prov/type))"/>","description":"<xsl:value-of select="eas:jsonText(string($prov/own_slot_value[slot_reference='description']/value))"/>","supplier":"<xsl:value-of select="eas:jsonText(string($supplier/own_slot_value[slot_reference='name']/value))"/>","delivery":"<xsl:value-of select="eas:jsonText(string($delivery/own_slot_value[slot_reference='name']/value))"/>","time":"<xsl:value-of select="eas:jsonText(string($disposition/own_slot_value[slot_reference='name']/value))"/>","modules":[<xsl:for-each select="$modules">{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],"sendsTo":[<xsl:for-each select="$outEdges"><xsl:variable name="toUsage" select="key('usageByName', current()/own_slot_value[slot_reference=':TO']/value)"/><xsl:variable name="toApp" select="key('appProvByName', $toUsage/own_slot_value[slot_reference='static_usage_of_app_provider']/value)"/><xsl:variable name="eInfoRel" select="$allInfoRepRels[name=current()/own_slot_value[slot_reference='apu_to_apu_relation_inforeps']/value]"/><xsl:variable name="eInfo" select="$allInfoReps[name=$eInfoRel/own_slot_value[slot_reference='app_pro_to_inforep_to_inforep']/value]"/><xsl:if test="$toApp">{"name":"<xsl:value-of select="eas:jsonText(string($toApp/own_slot_value[slot_reference='name']/value))"/>","label":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference=':relation_label']/value))"/>","info":[<xsl:for-each select="$eInfo">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>],"receivesFrom":[<xsl:for-each select="$inEdges"><xsl:variable name="frUsage" select="key('usageByName', current()/own_slot_value[slot_reference=':FROM']/value)"/><xsl:variable name="frApp" select="key('appProvByName', $frUsage/own_slot_value[slot_reference='static_usage_of_app_provider']/value)"/><xsl:variable name="eInfoRel2" select="$allInfoRepRels[name=current()/own_slot_value[slot_reference='apu_to_apu_relation_inforeps']/value]"/><xsl:variable name="eInfo2" select="$allInfoReps[name=$eInfoRel2/own_slot_value[slot_reference='app_pro_to_inforep_to_inforep']/value]"/><xsl:if test="$frApp">{"name":"<xsl:value-of select="eas:jsonText(string($frApp/own_slot_value[slot_reference='name']/value))"/>","label":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference=':relation_label']/value))"/>","info":[<xsl:for-each select="$eInfo2">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if>
                            </xsl:for-each>],
                            "managedServices":[<xsl:for-each select="$svcManaged">
                                <xsl:variable name="ms" select="current()"/>
                                <xsl:variable name="crit" select="$allCriticalities[name=$ms/own_slot_value[slot_reference='ms_criticality']/value]"/>
                                <xsl:variable name="msRels" select="$allActorToRole[name=$ms/own_slot_value[slot_reference='stakeholders']/value]"/>
                                {"id":"<xsl:value-of select="eas:jsonText(string($ms/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($ms/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string($ms/own_slot_value[slot_reference='description']/value))"/>","criticality":"<xsl:value-of select="eas:jsonText(string($crit/own_slot_value[slot_reference='name']/value))"/>","stakeholders":[<xsl:for-each select="$msRels"><xsl:variable name="actor" select="$allActors[name=current()/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/><xsl:variable name="role" select="$allRoles[name=current()/own_slot_value[slot_reference='act_to_role_to_role']/value]"/>{"relation":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='relation_name']/value))"/>","actor":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='name']/value))"/>","role":"<xsl:value-of select="eas:jsonText(string($role/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if>
                            </xsl:for-each>]
                            }<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s) {
                        if (s === null || s === undefined) return '';
                        return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;');
                    }
                    function niceType(t) {
                        return (t || '').replace(/_/g, ' ');
                    }
                    // Map TIME disposition to a shade class: Invest dark -> Eliminate light, no status grey
                    function timeClass(time) {
                        if (!time || time.trim() === '') return 'time-none';
                        var t = time.toLowerCase();
                        if (t.indexOf('invest') !== -1) return 'time-invest';
                        if (t.indexOf('tolerate') !== -1) return 'time-tolerate';
                        if (t.indexOf('migrate') !== -1) return 'time-migrate';
                        if (t.indexOf('eliminate') !== -1) return 'time-eliminate';
                        return 'time-none';
                    }

                    // Lookup maps for sidebar detail
                    var MS_BY_ID = {};
                    var PROV_BY_ID = {};
                    CAPS.forEach(function(c){
                        c.services.forEach(function(s){
                            s.managedServices.forEach(function(m){ MS_BY_ID[m.id] = m; });
                            s.providers.forEach(function(p){ PROV_BY_ID[p.id] = p; });
                        });
                    });

                    // A service is shown only if it has at least one provider or managed service
                    function serviceHasContent(s) {
                        return (s.providers &amp;&amp; s.providers.length &gt; 0) || (s.managedServices &amp;&amp; s.managedServices.length &gt; 0);
                    }
                    function visibleServices(c) {
                        return c.services.filter(serviceHasContent);
                    }

                    function renderList(filter) {
                        var container = document.getElementById('capList');
                        var caps = CAPS.filter(function(c){ return visibleServices(c).length &gt; 0; });
                        if (filter &amp;&amp; filter.trim() !== '') {
                            var f = filter.toLowerCase();
                            caps = caps.filter(function(c){ return c.name.toLowerCase().indexOf(f) !== -1; });
                        }
                        if (caps.length === 0) {
                            container.innerHTML = '&lt;div class="no-data"&gt;No application capabilities match.&lt;/div&gt;';
                            return;
                        }
                        var html = '';
                        caps.forEach(function(c){
                            var svcs = visibleServices(c);
                            html += '&lt;div class="cap-card"&gt;';
                            html += '&lt;div class="cap-head" onclick="toggle(this, \'body-' + c.id + '\')"&gt;';
                            html += '&lt;span class="caret"&gt;&#9656;&lt;/span&gt;';
                            html += '&lt;span class="cap-name"&gt;' + esc(c.name) + '&lt;/span&gt;';
                            html += '&lt;span class="cap-count"&gt;' + svcs.length + ' service' + (svcs.length === 1 ? '' : 's') + '&lt;/span&gt;';
                            html += '&lt;/div&gt;';
                            html += '&lt;div class="cap-body" id="body-' + c.id + '"&gt;';
                            if (c.description) { html += '&lt;div class="cap-desc"&gt;' + esc(c.description) + '&lt;/div&gt;'; }
                            svcs.forEach(function(s){ html += renderService(s); });
                            html += '&lt;/div&gt;&lt;/div&gt;';
                        });
                        container.innerHTML = html;
                    }

                    function renderService(s) {
                        var html = '&lt;div class="svc-card"&gt;';
                        // Services auto-expanded by default (open class on head + body)
                        html += '&lt;div class="svc-head open" onclick="toggle(this, \'sbody-' + s.id + '\')"&gt;';
                        html += '&lt;span class="caret"&gt;&#9656;&lt;/span&gt;';
                        html += '&lt;span class="svc-name"&gt;' + esc(s.name) + '&lt;/span&gt;';
                        html += '&lt;span class="svc-tag"&gt;' + esc(niceType(s.type)) + '&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        html += '&lt;div class="svc-body open" id="sbody-' + s.id + '"&gt;';
                        if (s.description) { html += '&lt;div class="svc-desc"&gt;' + esc(s.description) + '&lt;/div&gt;'; }
                        html += '&lt;div class="nest-cols"&gt;';
                        // Apps box (composite application providers)
                        html += '&lt;div class="nest-box"&gt;&lt;div class="nest-title cap-prov"&gt;Apps&lt;/div&gt;';
                        if (s.providers.length === 0) {
                            html += '&lt;div class="empty-note"&gt;None&lt;/div&gt;';
                        } else {
                            html += '&lt;div class="pill-wrap"&gt;';
                            s.providers.forEach(function(p){
                                var tc = timeClass(p.time);
                                var tt = p.time ? (' &#8226; ' + esc(p.time)) : '';
                                html += '&lt;span class="chip app-pill ' + tc + '" onclick="openProv(\'' + p.id + '\')" title="' + esc(p.name) + tt + '"&gt;' + esc(p.name) + '&lt;/span&gt;';
                            });
                            html += '&lt;/div&gt;';
                        }
                        html += '&lt;/div&gt;';
                        // Business Services box (managed services)
                        html += '&lt;div class="nest-box"&gt;&lt;div class="nest-title ms"&gt;Business Services&lt;/div&gt;';
                        if (s.managedServices.length === 0) {
                            html += '&lt;div class="empty-note"&gt;None&lt;/div&gt;';
                        } else {
                            html += '&lt;div class="pill-wrap"&gt;';
                            s.managedServices.forEach(function(m){
                                html += '&lt;span class="chip ms" onclick="openMS(\'' + m.id + '\')"&gt;' + esc(m.name) + '&lt;/span&gt;';
                            });
                            html += '&lt;/div&gt;';
                        }
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;'; // nest-cols
                        html += '&lt;/div&gt;&lt;/div&gt;'; // svc-body, svc-card
                        return html;
                    }

                    function toggle(headEl, bodyId) {
                        var body = document.getElementById(bodyId);
                        if (!body) return;
                        var isOpen = body.classList.contains('open');
                        body.classList.toggle('open', !isOpen);
                        headEl.classList.toggle('open', !isOpen);
                    }

                    function detailRow(label, value) {
                        return '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;' + esc(label) + '&lt;/div&gt;&lt;div class="sb-value"&gt;' + (value ? esc(value) : '&lt;span class="sb-empty"&gt;Not set&lt;/span&gt;') + '&lt;/div&gt;&lt;/div&gt;';
                    }

                    function openMS(id) {
                        var m = MS_BY_ID[id];
                        if (!m) return;
                        var html = '&lt;div class="sb-kicker ms"&gt;Managed Service&lt;/div&gt;';
                        html += '&lt;h2 class="sb-title"&gt;' + esc(m.name) + '&lt;/h2&gt;';
                        html += detailRow('Description', m.description);
                        html += detailRow('Criticality', m.criticality);
                        // Stakeholders
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Stakeholders&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (m.stakeholders &amp;&amp; m.stakeholders.length &gt; 0) {
                            m.stakeholders.forEach(function(st){
                                var line = st.relation || [st.actor, st.role].filter(Boolean).join(' as ');
                                html += '&lt;div class="sb-stake"&gt;' + esc(line || 'Unnamed');
                                if (st.actor || st.role) { html += '&lt;div class="sb-stake-sub"&gt;' + esc([st.actor, st.role].filter(Boolean).join(' &#8226; ')) + '&lt;/div&gt;'; }
                                html += '&lt;/div&gt;';
                            });
                        } else { html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;'; }
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        openSidebar(html);
                    }

                    function connectionsBlock(label, conns, cls) {
                        var html = '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;' + esc(label) + '&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (conns &amp;&amp; conns.length &gt; 0) {
                            html += '&lt;div class="flow-list"&gt;';
                            conns.forEach(function(c){
                                html += '&lt;div class="flow-item ' + cls + '"&gt;';
                                html += '&lt;span class="flow-arrow"&gt;' + (cls === 'flow-out' ? '&#8594;' : '&#8592;') + '&lt;/span&gt;';
                                html += '&lt;span class="flow-app"&gt;' + esc(c.name) + '&lt;/span&gt;';
                                if (c.label) { html += '&lt;span class="flow-label"&gt;' + esc(c.label) + '&lt;/span&gt;'; }
                                if (c.info &amp;&amp; c.info.length &gt; 0) { html += '&lt;div class="flow-info"&gt;' + c.info.map(esc).join(', ') + '&lt;/div&gt;'; }
                                html += '&lt;/div&gt;';
                            });
                            html += '&lt;/div&gt;';
                        } else { html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;'; }
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        return html;
                    }

                    function openProv(id) {
                        var p = PROV_BY_ID[id];
                        if (!p) return;
                        var html = '&lt;div class="sb-kicker cap-prov"&gt;' + esc(niceType(p.type)) + '&lt;/div&gt;';
                        html += '&lt;h2 class="sb-title"&gt;' + esc(p.name) + '&lt;/h2&gt;';
                        var summaryUrl = 'report?XML=reportXML.xml&amp;PMA=' + encodeURIComponent(p.id) + '&amp;XSL=application/core_al_application_provider_summary.xsl&amp;cl=en-gb';
                        html += '&lt;a class="sb-summary-btn" href="' + summaryUrl + '" target="_blank"&gt;View full application summary &#8594;&lt;/a&gt;';
                        html += detailRow('Description', p.description);
                        html += detailRow('Supplier', p.supplier);
                        html += detailRow('Delivery Model', p.delivery);
                        html += detailRow('TIME Status', p.time);
                        // Modules (contained application providers)
                        html += '&lt;div class="sb-row"&gt;&lt;div class="sb-label"&gt;Modules&lt;/div&gt;&lt;div class="sb-value"&gt;';
                        if (p.modules &amp;&amp; p.modules.length &gt; 0) {
                            html += '&lt;div class="pill-wrap"&gt;';
                            p.modules.forEach(function(mod){
                                var title = mod.description ? esc(mod.description) : '';
                                html += '&lt;span class="chip cap-prov" title="' + title + '" style="cursor:default;"&gt;' + esc(mod.name) + '&lt;/span&gt;';
                            });
                            html += '&lt;/div&gt;';
                        } else { html += '&lt;span class="sb-empty"&gt;None&lt;/span&gt;'; }
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        // Data flows (static architecture connections)
                        html += connectionsBlock('Sends to', p.sendsTo, 'flow-out');
                        html += connectionsBlock('Receives from', p.receivesFrom, 'flow-in');
                        openSidebar(html);
                    }

                    function openSidebar(html) {
                        document.getElementById('sidebarContent').innerHTML = html;
                        document.getElementById('sidebar').classList.add('open');
                        document.getElementById('sbOverlay').classList.add('open');
                    }
                    function closeSidebar() {
                        document.getElementById('sidebar').classList.remove('open');
                        document.getElementById('sbOverlay').classList.remove('open');
                    }

                    $(document).ready(function() {
                        console.log('Application capabilities:', CAPS);
                        renderList('');
                        document.getElementById('capSearch').addEventListener('input', function(){ renderList(this.value); });
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Application Capability Explorer</h1>
                    <p class="subtitle">Browse application capabilities. Expand a capability to see the application services that realise it, and expand each service to see the managed services and the applications that provide it.</p>
                    <div class="cap-search"><input type="text" id="capSearch" placeholder="Search application capabilities..."/></div>
                    <div class="time-legend">
                        <strong>App TIME status:</strong>
                        <span class="tl-item"><span class="tl-sw time-invest"/> Invest</span>
                        <span class="tl-item"><span class="tl-sw time-tolerate"/> Tolerate</span>
                        <span class="tl-item"><span class="tl-sw time-migrate"/> Migrate</span>
                        <span class="tl-item"><span class="tl-sw time-eliminate"/> Eliminate</span>
                        <span class="tl-item"><span class="tl-sw time-none"/> No status</span>
                    </div>
                    <div class="cap-list" id="capList"><p>Loading application capabilities...</p></div>
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
