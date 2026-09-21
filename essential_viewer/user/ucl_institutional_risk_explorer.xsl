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

    <!-- ===== Model variables (slot names confirmed via live diagnostic) ===== -->
    <xsl:variable name="allRisks" select="/node()/simple_instance[type='Risk']"/>
    <xsl:variable name="allRiskCategories" select="/node()/simple_instance[type='Risk_Category']"/>
    <xsl:variable name="allRiskImpacts" select="/node()/simple_instance[type='Risk_Impact']"/>
    <xsl:variable name="allRiskAssessments" select="/node()/simple_instance[type='Risk_Assessment']"/>
    <xsl:variable name="allBusRoles" select="/node()/simple_instance[type='Individual_Business_Role']"/>
    <!-- Actor-to-role relationship instances (type varies: Actor_To_Role_Relationship or ACTOR_TO_ROLE_RELATION) -->
    <xsl:variable name="allActorToRole" select="/node()/simple_instance[own_slot_value[slot_reference='act_to_role_from_actor']]"/>
    <xsl:variable name="allControls" select="/node()/simple_instance[type='Control']"/>
    <xsl:variable name="allRoadmaps" select="/node()/simple_instance[type='Roadmap']"/>
    <!-- Control effectiveness = Control performance_measures -> Performance_Measure -> pm_performance_value -> Service_Quality_Value name -->
    <xsl:variable name="allPerfMeasures" select="/node()/simple_instance[supertype='Performance_Measure']"/>
    <xsl:variable name="allSQValues" select="/node()/simple_instance[supertype='Service_Quality_Value']"/>
    <!-- Actors that can play a business role (person / group) -->
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Individual_Actor','Group_Actor') or supertype='Actor']"/>
    <!-- Strategic plans / initiatives referenced by risk_related_support -->
    <xsl:variable name="allPlans" select="/node()/simple_instance[type='Enterprise_Strategic_Plan']"/>

    <!-- Keys -->
    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>

    <!-- Proper JSON string escaper for free text: backslash, double-quote, then strip newlines/tabs.
         NOTE: the built-in eas:getSafeJSString only replaces '.'/' ' with '_', so it is NOT safe for prose. -->
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
                <title>UCL Institutional Risk Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1400px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.25rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:8px}
                    .treatment-link{margin:0 0 20px 0}
                    .treatment-link a{display:inline-block;background:#993AFF;color:#fff;text-decoration:none;padding:9px 18px;border-radius:6px;font-weight:600;font-size:1.1rem}
                    .treatment-link a:hover{background:#7d1fe0;color:#fff}
                    .risk-list{display:flex;flex-direction:column;gap:12px}
                    .risk-list-item{border:1px solid #E5E7EB;border-radius:8px;background:#fff;transition:box-shadow 0.15s,border-color 0.15s}
                    .risk-list-item:hover{box-shadow:0 4px 14px rgba(153,58,255,0.15);border-color:#993AFF}
                    .rli-header{display:flex;align-items:flex-start;gap:12px;padding:16px 20px;cursor:pointer}
                    .rli-caret{color:#993AFF;font-size:1.1rem;line-height:1.4;flex-shrink:0;margin-top:2px}
                    .rli-headtext{flex:1}
                    .rli-stakeholders{display:flex;gap:10px;flex-wrap:wrap;justify-content:flex-end;flex-shrink:0;align-self:center}
                    .risk-list-item .rli-name{font-size:1.5rem;font-weight:700;color:#361A54;margin-bottom:6px}
                    .risk-tag{display:inline-block;margin-left:12px;padding:3px 12px;border-radius:14px;font-size:0.95rem;font-weight:700;color:#fff;vertical-align:middle}
                    .tag-red{background:#E5352B}
                    .tag-amber{background:#F5A623}
                    .tag-yellow{background:#F2E205;color:#4B3B00}
                    .tag-green{background:#57C84D}
                    .risk-list-item .rli-desc{color:#4B5563;font-size:1.15rem;line-height:1.45;margin-bottom:8px}
                    .risk-list-item .rli-owner{font-size:1.1rem;color:#6B7280}
                    .risk-list-item .rli-owner strong{color:#361A54}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    /* Inline expandable card body */
                    .card-body{padding:4px 24px 20px 44px;border-top:1px solid #F0EAFB}
                    .card-section{margin-bottom:26px;margin-top:20px}
                    .card-section h3{color:#361A54;font-size:1.45rem;font-weight:700;margin-bottom:12px;border-bottom:1px solid #E5E7EB;padding-bottom:6px}
                    .card-desc{line-height:1.6;color:#333;font-size:1.2rem}
                    .impact-list{margin:0;padding-left:24px;line-height:1.6;color:#333;font-size:1.2rem}
                    .impact-list li{margin-bottom:10px}
                    /* Risk assessment two-column layout */
                    .assessment-layout{display:flex;gap:28px;align-items:flex-start;flex-wrap:wrap}
                    .matrix-col{flex:0 0 auto}
                    .assessment-detail-col{flex:1;min-width:280px}
                    .impacts-block{margin-top:18px}
                    .impacts-head{color:#361A54;font-size:1.25rem;font-weight:700;margin:0 0 8px 0}
                    .stakeholders{display:flex;gap:14px;flex-wrap:wrap}
                    .stakeholder-item{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:8px;padding:12px 16px;min-width:200px}
                    .stakeholder-item .sh-role{font-size:1rem;text-transform:uppercase;color:#6B7280;font-weight:600;letter-spacing:0.04em}
                    .stakeholder-item .sh-name{font-size:1.3rem;font-weight:700;color:#361A54;margin-top:2px}
                    .roadmap-links{display:flex;gap:10px;flex-wrap:wrap}
                    .roadmap-link{display:inline-block;background:#993AFF;color:#fff;text-decoration:none;padding:9px 16px;border-radius:6px;font-weight:600;font-size:1rem}
                    .roadmap-link:hover{background:#7d1fe0;color:#fff}
                    table.causes-table{width:100%;border-collapse:collapse}
                    table.causes-table{font-size:1.15rem}
                    table.causes-table th{background:#361A54;color:#fff;text-align:left;padding:12px 14px;font-weight:600;font-size:1.15rem}
                    table.causes-table td{padding:12px 14px;border-bottom:1px solid #E5E7EB;vertical-align:top}
                    .cause-name{color:#361A54;font-weight:600;cursor:pointer;text-decoration:none}
                    .cause-name:hover{text-decoration:underline;color:#993AFF}
                    .cause-detail{background:#FAF7FF;border:1px solid #DDBDFF;border-radius:6px;padding:14px 16px;margin-top:8px}
                    .cause-detail h4{margin:0 0 6px 0;color:#361A54}
                    .cause-detail ul{margin:6px 0 0 0;padding-left:20px}
                    .cause-detail li{margin-bottom:4px}
                    .control-name{color:#361A54;font-weight:600;cursor:pointer;text-decoration:none}
                    .control-name:hover{text-decoration:underline;color:#993AFF}
                    .control-detail{background:#FAF7FF;border:1px solid #DDBDFF;border-radius:6px;padding:10px 12px;margin:6px 0 10px 0;color:#333;font-size:0.95rem;line-height:1.45}
                    .control-rag{display:inline-block;padding:2px 10px;border-radius:12px;font-size:0.85rem;font-weight:700;vertical-align:middle}
                    .assessments{display:flex;gap:16px;flex-wrap:wrap}
                    .assessment-card{flex:1;min-width:260px;border:1px solid #E5E7EB;border-radius:8px;padding:16px;background:#fff}
                    .assessment-card .ac-type{font-size:1.3rem;font-weight:700;color:#361A54}
                    .assessment-card .ac-date{font-size:1.05rem;color:#6B7280;margin-bottom:12px}
                    .rag-row{display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-top:1px solid #F0F0F0}
                    .rag-label{font-weight:600;color:#4B5563;font-size:1.15rem}
                    .rag-badge{display:inline-block;padding:5px 14px;border-radius:5px;font-weight:700;color:#fff;font-size:1.1rem}
                    .rag-green{background:#1AAB40}
                    .rag-amber{background:#F59E0B}
                    .rag-red{background:#DC2626}
                    .rag-grey{background:#9CA3AF}
                    /* Risk matrix */
                    .matrix-wrap{display:flex;align-items:flex-start;gap:12px;margin-bottom:16px}
                    .matrix-title{font-weight:700;color:#361A54;margin-bottom:8px;font-size:1.2rem}
                    .matrix-legend{font-size:0.9rem;color:#6B7280;margin-bottom:6px}
                    .y-axis-label{writing-mode:vertical-rl;transform:rotate(180deg);font-weight:700;color:#361A54;text-align:center;padding-top:20px}
                    .matrix-grid{border-collapse:collapse}
                    .matrix-grid td{width:88px;height:66px;border:1px solid #fff;text-align:center;vertical-align:middle;position:relative;font-size:0.95rem;color:#333}
                    .matrix-grid td.axis{background:none;border:none;font-weight:600;color:#361A54;width:auto;height:auto;padding:4px 8px;font-size:1.05rem}
                    .matrix-grid td.axis-y{text-align:right;white-space:nowrap}
                    .matrix-grid td.axis-x{font-size:0.95rem;line-height:1.25}
                    .m-green{background:#57C84D}
                    .m-yellow{background:#F2E205}
                    .m-amber{background:#F5A623}
                    .m-red{background:#E5352B}
                    .x-axis-title{text-align:center;font-weight:700;color:#361A54;margin-top:4px;padding-left:70px}
                    .marker{display:inline-flex;align-items:center;justify-content:center;width:30px;height:30px;border-radius:50%;background:#1F3A93;color:#fff;font-weight:700;font-size:0.95rem;margin:2px;box-shadow:0 1px 4px rgba(0,0,0,0.4)}
                </style>
                <script type="text/javascript">
                    // ===== Embedded risk data from XSL =====
                    var RISKS = [<xsl:for-each select="$allRisks">
                        <xsl:variable name="thisRisk" select="current()"/>
                        <xsl:variable name="catId" select="$thisRisk/own_slot_value[slot_reference='risk_category']/value"/>
                        <xsl:variable name="cat" select="$allRiskCategories[name=$catId]"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($thisRisk/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($thisRisk/own_slot_value[slot_reference='name']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($thisRisk/own_slot_value[slot_reference='description']/value))"/>",
                        "shortDescription":"<xsl:value-of select="eas:jsonText(string($thisRisk/own_slot_value[slot_reference='short_description']/value))"/>",
                        "category":"<xsl:value-of select="eas:jsonText(string($cat/own_slot_value[slot_reference='name']/value))"/>",
                        <xsl:variable name="thisRoles" select="$allBusRoles[name=$thisRisk/own_slot_value[slot_reference='stakeholders']/value]"/>
                        "stakeholders":[<xsl:for-each select="$thisRoles">
                            <xsl:variable name="role" select="current()"/>
                            <!-- Role -> Actor_To_Role_Relationship (via its 'stakeholders' or 'bus_role_played_by_actor' slot) -> act_to_role_from_actor -> Actor -->
                            <xsl:variable name="roleRelIds" select="$role/own_slot_value[slot_reference='stakeholders']/value | $role/own_slot_value[slot_reference='bus_role_played_by_actor']/value"/>
                            <xsl:variable name="a2r" select="$allActorToRole[name=$roleRelIds]"/>
                            <!-- Person could be the a2r's from_actor, or the role-linked ids may point straight at actors -->
                            <xsl:variable name="actors" select="$allActors[name=$a2r/own_slot_value[slot_reference='act_to_role_from_actor']/value] | $allActors[name=$roleRelIds]"/>
                            {"role":"<xsl:value-of select="eas:jsonText(string($role/own_slot_value[slot_reference='name']/value))"/>","person":"<xsl:for-each select="$actors"><xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/><xsl:if test="not(position()=last())">, </xsl:if></xsl:for-each>"}<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>],
                        <xsl:variable name="thisRoadmaps" select="$allRoadmaps[name=$thisRisk/own_slot_value[slot_reference='risk_related_support']/value]"/>
                        "roadmaps":[<xsl:for-each select="$thisRoadmaps">{"id":"<xsl:value-of select="eas:jsonText(string(current()/name))"/>","name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                        <xsl:variable name="thisCauses" select="$allRisks[name=$thisRisk/own_slot_value[slot_reference='risk_leading_to']/value]"/>
                        "causes":[<xsl:for-each select="$thisCauses">
                            <xsl:variable name="cause" select="current()"/>
                            <xsl:variable name="ctrls" select="$allControls[name=$cause/own_slot_value[slot_reference='risk_related_control']/value]"/>
                            <xsl:variable name="causeInitiatives" select="/node()/simple_instance[name=$cause/own_slot_value[slot_reference='risk_related_support']/value][type!='Roadmap']"/>
                            {
                                "id":"<xsl:value-of select="eas:jsonText(string($cause/name))"/>",
                                "name":"<xsl:value-of select="eas:jsonText(string($cause/own_slot_value[slot_reference='name']/value))"/>",
                                "description":"<xsl:value-of select="eas:jsonText(string($cause/own_slot_value[slot_reference='description']/value))"/>",
                                "controls":[<xsl:for-each select="$ctrls"><xsl:variable name="ctrlPMs" select="$allPerfMeasures[name=current()/own_slot_value[slot_reference='performance_measures']/value]"/><xsl:variable name="ctrlVal" select="$allSQValues[name=$ctrlPMs/own_slot_value[slot_reference='pm_performance_value']/value][1]"/>{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>","effectiveness":"<xsl:value-of select="eas:jsonText(string($ctrlVal/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
                                "initiatives":[<xsl:for-each select="$causeInitiatives">"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                            }<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>],
                        "assessments":[<xsl:for-each select="$allRiskAssessments[own_slot_value[slot_reference='ra_assessed_risk']/value = $thisRisk/name]">
                            <xsl:variable name="impactId" select="current()/own_slot_value[slot_reference='ra_risk_impact']/value"/>
                            <xsl:variable name="impact" select="$allRiskImpacts[name=$impactId]"/>
                            {
                            "type":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>",
                            "date":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='ra_assessment_date_ISO8601']/value))"/>",
                            "probability":<xsl:choose><xsl:when test="current()/own_slot_value[slot_reference='ra_risk_probability']/value"><xsl:value-of select="current()/own_slot_value[slot_reference='ra_risk_probability']/value"/></xsl:when><xsl:otherwise>-1</xsl:otherwise></xsl:choose>,
                            "impactValue":"<xsl:value-of select="eas:jsonText(string($impact/own_slot_value[slot_reference='enumeration_value']/value))"/>",
                            "impactScore":<xsl:choose><xsl:when test="$impact/own_slot_value[slot_reference='enumeration_score']/value"><xsl:value-of select="$impact/own_slot_value[slot_reference='enumeration_score']/value"/></xsl:when><xsl:otherwise>-1</xsl:otherwise></xsl:choose>
                            }<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    var ROADMAP_VIEW = 'user/UCL_strategic_plan_roadmaps_attibutes.xsl';
                    var INSTITUTIONAL_CATEGORY = 'UCL Strategic Risk Area';

                    function institutionalRisks() {
                        return RISKS.filter(function(r) { return r.category === INSTITUTIONAL_CATEGORY; });
                    }

                    function esc(s) {
                        if (s === null || s === undefined) return '';
                        return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;');
                    }

                    function impactRag(score) {
                        if (score &lt;= 0) return 'rag-grey';
                        if (score &lt;= 2) return 'rag-green';
                        if (score === 3) return 'rag-amber';
                        return 'rag-red';
                    }

                    function probabilityBand(p) {
                        if (p &lt; 0) return {label:'Not set', cls:'rag-grey'};
                        if (p &lt;= 25) return {label:'Rare', cls:'rag-green'};
                        if (p &lt;= 50) return {label:'Possible', cls:'rag-green'};
                        if (p &lt;= 75) return {label:'Frequent', cls:'rag-amber'};
                        return {label:'Imminent', cls:'rag-red'};
                    }

                    // Control effectiveness -> RAG label + colour, from perf-measure value name (e.g. "Control RAG - Amber")
                    function controlRag(effVal) {
                        if (!effVal || effVal.trim() === '') return null;
                        var v = effVal.toLowerCase();
                        if (v.indexOf('green') !== -1) return {label:'Green', bg:'#57C84D', fg:'#fff'};
                        if (v.indexOf('amber') !== -1 || v.indexOf('yellow') !== -1) return {label:'Amber', bg:'#F5A623', fg:'#fff'};
                        if (v.indexOf('red') !== -1) return {label:'Red', bg:'#E5352B', fg:'#fff'};
                        return {label: effVal, bg:'#9CA3AF', fg:'#fff'};
                    }

                    // Likelihood column 1-4 from probability 0-100
                    function likelihoodCol(p) {
                        if (p &lt; 0) return 0;
                        if (p &lt;= 25) return 1;
                        if (p &lt;= 50) return 2;
                        if (p &lt;= 75) return 3;
                        return 4;
                    }

                    // Cell colour for a 4x4 matrix: impact row (1-4) x likelihood col (1-4)
                    function matrixCellClass(impact, likelihood) {
                        var product = impact * likelihood;
                        if (product &lt;= 3) return 'm-green';
                        if (product &lt;= 6) return 'm-yellow';
                        if (product &lt;= 9) return 'm-amber';
                        return 'm-red';
                    }

                    // Severity band (label + tag class) from a matrix product (impact x likelihood)
                    function severityBand(product) {
                        if (product &lt;= 0) return null;
                        if (product &lt;= 3) return {label:'Low', cls:'tag-green'};
                        if (product &lt;= 6) return {label:'Moderate', cls:'tag-yellow'};
                        if (product &lt;= 9) return {label:'Severe', cls:'tag-amber'};
                        return {label:'Critical', cls:'tag-red'};
                    }

                    // Residual severity for a risk: use the Residual assessment (fallback to last assessment)
                    function residualSeverity(r) {
                        if (!r.assessments || r.assessments.length === 0) return null;
                        var a = r.assessments.find(function(x){ return /residual/i.test(x.type); });
                        if (!a) a = r.assessments[r.assessments.length - 1];
                        var col = likelihoodCol(a.probability);
                        if (a.impactScore &lt; 1 || col &lt; 1) return null;
                        return severityBand(a.impactScore * col);
                    }

                    function renderMatrix(r) {
                        var impactRows = [4, 3, 2, 1];
                        var impactLabels = {4:'4. Severe', 3:'3. Major', 2:'2. Moderate', 1:'1. Minor'};
                        var colLabels = ['1. Rare&lt;br/&gt;&amp;lt;25%', '2. Possible&lt;br/&gt;25-50%', '3. Frequent&lt;br/&gt;50-75%', '4. Imminent&lt;br/&gt;&amp;gt;75%'];

                        // Determine which cell each assessment sits in
                        var markers = {}; // key "impact-likelihood" -> array of letters
                        r.assessments.forEach(function(a){
                            var col = likelihoodCol(a.probability);
                            if (a.impactScore &lt; 1 || col &lt; 1) return;
                            var letter = /inherent/i.test(a.type) ? 'I' : (/residual/i.test(a.type) ? 'R' : a.type.charAt(0).toUpperCase());
                            var key = a.impactScore + '-' + col;
                            if (!markers[key]) markers[key] = [];
                            markers[key].push(letter);
                        });

                        var html = '&lt;div class="matrix-title"&gt;Risk Heatmap &lt;span style="font-weight:400;color:#6B7280;"&gt;(I = Inherent, R = Residual)&lt;/span&gt;&lt;/div&gt;';
                        html += '&lt;div class="matrix-wrap"&gt;';
                        html += '&lt;div class="y-axis-label"&gt;Impact&lt;/div&gt;';
                        html += '&lt;div&gt;&lt;table class="matrix-grid"&gt;&lt;tbody&gt;';
                        impactRows.forEach(function(imp){
                            html += '&lt;tr&gt;';
                            html += '&lt;td class="axis axis-y"&gt;' + impactLabels[imp] + '&lt;/td&gt;';
                            for (var col = 1; col &lt;= 4; col++) {
                                var cls = matrixCellClass(imp, col);
                                var key = imp + '-' + col;
                                var cell = '';
                                if (markers[key]) {
                                    markers[key].forEach(function(letter){
                                        cell += '&lt;span class="marker"&gt;' + letter + '&lt;/span&gt;';
                                    });
                                }
                                html += '&lt;td class="' + cls + '"&gt;' + cell + '&lt;/td&gt;';
                            }
                            html += '&lt;/tr&gt;';
                        });
                        // X axis labels row
                        html += '&lt;tr&gt;&lt;td class="axis"&gt;&lt;/td&gt;';
                        colLabels.forEach(function(lbl){
                            html += '&lt;td class="axis axis-x"&gt;' + lbl + '&lt;/td&gt;';
                        });
                        html += '&lt;/tr&gt;';
                        html += '&lt;/tbody&gt;&lt;/table&gt;';
                        html += '&lt;div class="x-axis-title"&gt;Likelihood&lt;/div&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        return html;
                    }

                    function renderList() {
                        var risks = institutionalRisks();
                        var container = document.getElementById('riskList');
                        if (risks.length === 0) {
                            container.innerHTML = '&lt;div class="no-data"&gt;No risks found in category "' + esc(INSTITUTIONAL_CATEGORY) + '".&lt;/div&gt;';
                            return;
                        }
                        risks.sort(function(a,b){ return a.name.localeCompare(b.name); });
                        var html = '';
                        risks.forEach(function(r) {
                            var desc = r.shortDescription || r.description || '';
                            html += '&lt;div class="risk-list-item"&gt;';
                            html += '&lt;div class="rli-header" onclick="toggleRisk(\'' + r.id + '\')"&gt;';
                            html += '&lt;span class="rli-caret" id="caret-' + r.id + '"&gt;&#9656;&lt;/span&gt;';
                            html += '&lt;div class="rli-headtext"&gt;';
                            var sev = residualSeverity(r);
                            var sevTag = sev ? '&lt;span class="risk-tag ' + sev.cls + '" title="Residual risk"&gt;' + sev.label + '&lt;/span&gt;' : '';
                            html += '&lt;div class="rli-name"&gt;' + esc(r.name) + sevTag + '&lt;/div&gt;';
                            html += '&lt;div class="rli-desc"&gt;' + esc(desc) + '&lt;/div&gt;';
                            html += '&lt;/div&gt;';
                            // Stakeholder cards aligned right in the header
                            html += renderStakeholderCards(r.stakeholders, 'rli-stakeholders');
                            html += '&lt;/div&gt;';
                            html += '&lt;div class="card-body" id="body-' + r.id + '" style="display:none;"&gt;' + buildCard(r) + '&lt;/div&gt;';
                            html += '&lt;/div&gt;';
                        });
                        container.innerHTML = html;
                    }

                    // Stakeholder cards (role + person)
                    function renderStakeholderCards(stakeholders, wrapClass) {
                        if (!stakeholders || stakeholders.length === 0) return '';
                        var html = '&lt;div class="' + wrapClass + '"&gt;';
                        stakeholders.forEach(function(s){
                            html += '&lt;div class="stakeholder-item"&gt;&lt;div class="sh-role"&gt;' + esc(s.role) + '&lt;/div&gt;&lt;div class="sh-name"&gt;' + esc(s.person || '&#8212;') + '&lt;/div&gt;&lt;/div&gt;';
                        });
                        html += '&lt;/div&gt;';
                        return html;
                    }

                    // Split description into bullets on "- " markers
                    function renderImpacts(text) {
                        if (!text || text.trim() === '') {
                            return '&lt;p style="color:#6B7280;"&gt;No impacts recorded.&lt;/p&gt;';
                        }
                        // Split on "- " bullet markers: at start of string or after a line break / sentence gap.
                        // Using a leading "- " (hyphen followed by space) as the delimiter.
                        var parts = text.split(/(?:^|\s)-\s+/).map(function(s){ return s.trim(); }).filter(function(s){ return s !== ''; });
                        if (parts.length &lt;= 1) {
                            // No bullet markers found - show as a single paragraph
                            return '&lt;div class="card-desc"&gt;' + esc(text) + '&lt;/div&gt;';
                        }
                        var html = '&lt;ul class="impact-list"&gt;';
                        parts.forEach(function(p){
                            html += '&lt;li&gt;' + esc(p) + '&lt;/li&gt;';
                        });
                        html += '&lt;/ul&gt;';
                        return html;
                    }

                    function buildCard(r) {
                        var html = '';

                        // Risk Assessment (moved to top) - matrix and detail side by side
                        html += '&lt;div class="card-section"&gt;&lt;h3&gt;Risk Assessment&lt;/h3&gt;';
                        html += '&lt;div class="assessment-layout"&gt;';
                        html += '&lt;div class="matrix-col"&gt;' + renderMatrix(r) + '&lt;/div&gt;';
                        html += '&lt;div class="assessment-detail-col"&gt;';
                        if (r.assessments.length &gt; 0) {
                            html += '&lt;div class="assessments"&gt;';
                            r.assessments.forEach(function(a){
                                var iCls = impactRag(a.impactScore);
                                var band = probabilityBand(a.probability);
                                html += '&lt;div class="assessment-card"&gt;';
                                html += '&lt;div class="ac-type"&gt;' + esc(a.type || 'Assessment') + '&lt;/div&gt;';
                                html += '&lt;div class="ac-date"&gt;' + esc(a.date || '') + '&lt;/div&gt;';
                                html += '&lt;div class="rag-row"&gt;&lt;span class="rag-label"&gt;Impact&lt;/span&gt;&lt;span class="rag-badge ' + iCls + '"&gt;' + esc(a.impactValue || 'Not set') + (a.impactScore &gt; 0 ? ' (' + a.impactScore + ')' : '') + '&lt;/span&gt;&lt;/div&gt;';
                                html += '&lt;div class="rag-row"&gt;&lt;span class="rag-label"&gt;Likelihood&lt;/span&gt;&lt;span class="rag-badge ' + band.cls + '"&gt;' + band.label + (a.probability &gt;= 0 ? ' (' + a.probability + ')' : '') + '&lt;/span&gt;&lt;/div&gt;';
                                html += '&lt;/div&gt;';
                            });
                            html += '&lt;/div&gt;';
                        } else {
                            html += '&lt;p style="color:#6B7280;"&gt;No risk assessments recorded.&lt;/p&gt;';
                        }
                        // Impacts on the right, below the assessment detail
                        html += '&lt;div class="impacts-block"&gt;&lt;h4 class="impacts-head"&gt;Impacts&lt;/h4&gt;';
                        html += renderImpacts(r.description || r.shortDescription || '');
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;'; // assessment-detail-col
                        html += '&lt;/div&gt;'; // assessment-layout
                        html += '&lt;/div&gt;'; // card-section

                        // Stakeholders now shown in the list header (see renderStakeholderCards)

                        // Related Roadmap(s) - removed for now (kept for future restore)
                        // if (r.roadmaps.length &gt; 0) { ... roadmap-link buttons ... }

                        // Causes
                        html += '&lt;div class="card-section"&gt;&lt;h3&gt;Causes&lt;/h3&gt;';
                        if (r.causes.length &gt; 0) {
                            html += '&lt;table class="causes-table"&gt;&lt;thead&gt;&lt;tr&gt;&lt;th&gt;Cause&lt;/th&gt;&lt;th&gt;Related Control&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                            r.causes.forEach(function(c){
                                html += '&lt;tr&gt;';
                                // Cause cell (click to expand cause detail)
                                html += '&lt;td&gt;&lt;a class="cause-name" onclick="toggleCause(\'' + c.id + '\')"&gt;' + esc(c.name) + '&lt;/a&gt;';
                                html += '&lt;div id="cause-' + c.id + '" class="cause-detail" style="display:none;"&gt;';
                                html += '&lt;h4&gt;' + esc(c.name) + '&lt;/h4&gt;';
                                if (c.description) { html += '&lt;div class="card-desc"&gt;' + esc(c.description) + '&lt;/div&gt;'; }
                                html += '&lt;strong&gt;Strategic Initiatives Addressing risks&lt;/strong&gt;';
                                if (c.initiatives.length &gt; 0) {
                                    html += '&lt;ul&gt;';
                                    c.initiatives.forEach(function(i){ html += '&lt;li&gt;' + esc(i) + '&lt;/li&gt;'; });
                                    html += '&lt;/ul&gt;';
                                } else {
                                    html += '&lt;p style="color:#6B7280;margin:4px 0 0 0;"&gt;None recorded.&lt;/p&gt;';
                                }
                                html += '&lt;/div&gt;&lt;/td&gt;';
                                // Related Control cell (click each control to expand its description)
                                html += '&lt;td&gt;';
                                if (c.controls.length &gt; 0) {
                                    c.controls.forEach(function(ctrl, ci){
                                        var cid = c.id + '-ctrl-' + ci;
                                        var rag = controlRag(ctrl.effectiveness);
                                        var ragBadge = rag ? ' &lt;span class="control-rag" style="background:' + rag.bg + ';color:' + rag.fg + ';"&gt;' + esc(rag.label) + '&lt;/span&gt;' : '';
                                        html += '&lt;div&gt;&lt;a class="control-name" onclick="toggleControl(\'' + cid + '\')"&gt;' + esc(ctrl.name) + '&lt;/a&gt;' + ragBadge;
                                        html += '&lt;div id="control-' + cid + '" class="control-detail" style="display:none;"&gt;' + esc(ctrl.description || 'No description recorded.') + '&lt;/div&gt;&lt;/div&gt;';
                                    });
                                } else {
                                    html += '&#8212;';
                                }
                                html += '&lt;/td&gt;';
                                html += '&lt;/tr&gt;';
                            });
                            html += '&lt;/tbody&gt;&lt;/table&gt;';
                        } else {
                            html += '&lt;p style="color:#6B7280;"&gt;No causes recorded.&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        return html;
                    }

                    function toggleRisk(riskId) {
                        var body = document.getElementById('body-' + riskId);
                        var caret = document.getElementById('caret-' + riskId);
                        if (!body) return;
                        var isOpen = body.style.display !== 'none';
                        body.style.display = isOpen ? 'none' : 'block';
                        if (caret) caret.innerHTML = isOpen ? '&#9656;' : '&#9662;';
                    }

                    function toggleCause(causeId) {
                        var el = document.getElementById('cause-' + causeId);
                        if (!el) return;
                        el.style.display = (el.style.display === 'none') ? 'block' : 'none';
                    }

                    function toggleControl(ctrlId) {
                        var el = document.getElementById('control-' + ctrlId);
                        if (!el) return;
                        el.style.display = (el.style.display === 'none') ? 'block' : 'none';
                    }

                    $(document).ready(function() {
                        console.log('All risks:', RISKS);
                        console.log('Institutional risks:', institutionalRisks());
                        renderList();
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Institutional Risk Explorer</h1>
                    <p class="subtitle">Institutional risks in the "UCL Strategic Risk Area" category. Click a risk to open its risk card.</p>
                    <p class="treatment-link"><a href="https://teams.microsoft.com/l/entity/com.microsoft.teamspace.tab.planner/mytasks?tenantId=1faf88fe-a998-4c5b-93c9-210a11d9a5c2&amp;webUrl=https%3A%2F%2Ftasks.teams.microsoft.com%2Fteamsui%2FpersonalApp%2Falltasklists&amp;context=%7B%22subEntityId%22%3A%22%2Fv1%2Fplan%2FH-l0-yWoQ0aqLSfZWNfBAZYAHDra%22%7D" target="_blank">Risk Treatment Plan</a></p>
                    <div class="risk-list" id="riskList"><p>Loading risks...</p></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
