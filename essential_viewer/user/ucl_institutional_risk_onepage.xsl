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
    <xsl:variable name="allActorToRole" select="/node()/simple_instance[own_slot_value[slot_reference='act_to_role_from_actor']]"/>
    <xsl:variable name="allControls" select="/node()/simple_instance[type='Control']"/>
    <xsl:variable name="allRoadmaps" select="/node()/simple_instance[type='Roadmap']"/>
    <!-- Control effectiveness = Control performance_measures -> Performance_Measure -> pm_performance_value -> Service_Quality_Value name -->
    <xsl:variable name="allPerfMeasures" select="/node()/simple_instance[supertype='Performance_Measure']"/>
    <xsl:variable name="allSQValues" select="/node()/simple_instance[supertype='Service_Quality_Value']"/>
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Individual_Actor','Group_Actor') or supertype='Actor']"/>
    <xsl:variable name="allPlans" select="/node()/simple_instance[type='Enterprise_Strategic_Plan']"/>

    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>

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
                <title>UCL Institutional Risk - Risk on a Page</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1600px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.15rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px}
                    .risk-nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:20px}
                    .risk-nav button{background:#F5F0FF;border:1px solid #DDBDFF;color:#361A54;border-radius:6px;padding:9px 16px;cursor:pointer;font-family:'DM Sans',sans-serif;font-weight:600;font-size:1.05rem}
                    .risk-nav button:hover{background:#993AFF;color:#fff}
                    .no-data{text-align:center;padding:40px;color:#6B7280}

                    /* ===== Risk on a page card ===== */
                    .rop-card{border:1px solid #C9CDD6;margin-bottom:40px;background:#fff}
                    .rop-header{background:#0A1A3C;color:#fff;display:flex;justify-content:space-between;align-items:flex-start;padding:14px 18px;position:relative}
                    .rop-header .rop-ref{font-size:1.9rem;font-weight:700}
                    .rop-header .rop-soa{font-size:1.25rem;font-weight:600;margin-top:2px}
                    .rop-header .rop-owner{font-size:1.25rem;font-weight:700;text-align:right;padding-right:170px}
                    .rop-updated{position:absolute;top:10px;right:14px;background:#FFEB00;color:#111;font-weight:700;font-size:1rem;padding:4px 10px;border-radius:3px}

                    .rop-midrow{display:flex;align-items:stretch;gap:0;padding:10px;flex-wrap:nowrap}
                    .rop-panel{border:1px solid #C9CDD6}
                    .rop-panel-head{background:#2E75B6;color:#fff;font-weight:700;padding:8px 12px;font-size:1.15rem}
                    /* Causes */
                    .rop-causes{flex:0 0 26%;display:flex;flex-direction:column}
                    .rop-causes .rop-panel-head{background:#548235}
                    .rop-causes-body{background:#E2EFDA;flex:1;padding:10px 12px;font-size:1.1rem;color:#333}
                    .rop-causes-body ul{margin:0;padding-left:20px}
                    .rop-causes-body li{margin-bottom:8px}
                    /* Chevrons */
                    .rop-chevrons{flex:0 0 60px;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:8px}
                    .rop-chevron{width:0;height:0;border-top:22px solid transparent;border-bottom:22px solid transparent;border-left:28px solid #A9D08E}
                    /* Risk centre block */
                    .rop-risk{flex:0 0 220px;display:flex;flex-direction:column;justify-content:center;align-items:center;margin:0 28px}
                    .rop-risk-inner{width:100%;border:2px solid #9DC3E6}
                    .rop-risk-title{background:#2E75B6;color:#fff;font-weight:700;text-align:center;padding:10px;font-size:1.35rem}
                    .rop-risk-desc{background:#DEEAF6;color:#1F3864;text-align:center;padding:18px 12px;font-size:1.1rem;min-height:80px}
                    .rop-risk-residual{color:#fff;font-weight:700;text-align:center;padding:10px;font-size:1.05rem}
                    /* Impacts */
                    .rop-impacts{flex:1 1 auto;display:flex;flex-direction:column;margin-left:8px}
                    .rop-impacts table{width:100%;border-collapse:collapse;font-size:1.1rem}
                    .rop-impacts th{background:#2E75B6;color:#fff;text-align:left;padding:8px 10px;border:1px solid #fff}
                    .rop-impacts td{border:1px solid #C9CDD6;padding:8px 10px;vertical-align:top;background:#fff}
                    .rop-impacts th.num{text-align:center;font-weight:700;width:56px;font-size:0.95rem;padding:8px 4px}
                    .rop-impacts td.num{text-align:center;font-weight:700;width:56px;font-size:1.2rem}
                    .rop-impacts ul{margin:0;padding-left:18px}
                    /* Heatmap */
                    .rop-heatmap{flex:0 0 auto;margin-left:12px}

                    /* Key controls */
                    .rop-section-head{background:#2E75B6;color:#fff;font-weight:700;padding:6px 10px;font-size:0.95rem;margin:0}
                    table.rop-controls{width:100%;border-collapse:collapse;font-size:1.1rem}
                    table.rop-controls th{background:#2E75B6;color:#fff;text-align:left;padding:8px 12px;border:1px solid #fff;font-size:1.15rem}
                    table.rop-controls th.ce-col{width:70px;text-align:center}
                    table.rop-controls td{border:1px solid #C9CDD6;padding:10px 12px;background:#DEEAF6}
                    table.rop-controls td.ce{text-align:center;font-weight:700;font-size:1.2rem}
                    .ce-na{background:#FFC000 !important}
                    /* Actions */
                    table.rop-actions{width:100%;border-collapse:collapse;font-size:0.9rem}
                    table.rop-actions th{background:#2E75B6;color:#fff;text-align:left;padding:6px 10px;border:1px solid #fff}
                    table.rop-actions td{border:1px solid #C9CDD6;padding:10px;background:#DEEAF6;height:26px}
                    table.rop-actions td.num{text-align:center;font-weight:700;width:36px}
                    table.rop-actions td.status{width:70px}
                    .rop-legend{display:flex;gap:18px;justify-content:flex-end;align-items:center;padding:8px 10px;font-size:0.85rem}
                    .rop-legend .sw{display:inline-block;width:14px;height:14px;border-radius:3px;margin-right:5px;vertical-align:middle}

                    /* matrix */
                    .matrix-title{font-weight:700;color:#361A54;margin-bottom:6px;font-size:1.15rem}
                    .matrix-wrap{display:flex;align-items:flex-start;gap:8px}
                    .y-axis-label{writing-mode:vertical-rl;transform:rotate(180deg);font-weight:700;color:#361A54;text-align:center;font-size:0.95rem;padding-top:20px}
                    .matrix-grid{border-collapse:collapse}
                    .matrix-grid td{width:72px;height:44px;border:1px solid #fff;text-align:center;vertical-align:middle;position:relative;font-size:0.85rem}
                    .matrix-grid td.axis{background:none;border:none;font-weight:600;color:#361A54;width:auto;height:auto;padding:3px 6px;font-size:0.9rem;white-space:nowrap}
                    .matrix-grid td.axis-y{text-align:right}
                    .m-green{background:#57C84D}
                    .m-yellow{background:#F2E205}
                    .m-amber{background:#F5A623}
                    .m-red{background:#E5352B}
                    .x-axis-title{text-align:center;font-weight:700;color:#361A54;margin-top:4px;font-size:0.95rem;padding-left:44px}
                    .marker{display:inline-flex;align-items:center;justify-content:center;width:28px;height:28px;border-radius:50%;background:#1F3A93;color:#fff;font-weight:700;font-size:0.9rem;margin:1px;box-shadow:0 1px 3px rgba(0,0,0,0.4)}
                    .appetite-line{position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none}
                </style>
                <script type="text/javascript">
                    // ===== Embedded risk data from XSL (same model as the explorer view) =====
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
                        "updated":"<xsl:value-of select="eas:jsonText(string($thisRisk/own_slot_value[slot_reference='system_last_modified_datetime_iso8601']/value))"/>",
                        <xsl:variable name="thisRoles" select="$allBusRoles[name=$thisRisk/own_slot_value[slot_reference='stakeholders']/value]"/>
                        "stakeholders":[<xsl:for-each select="$thisRoles">
                            <xsl:variable name="role" select="current()"/>
                            <xsl:variable name="roleRelIds" select="$role/own_slot_value[slot_reference='stakeholders']/value | $role/own_slot_value[slot_reference='bus_role_played_by_actor']/value"/>
                            <xsl:variable name="a2r" select="$allActorToRole[name=$roleRelIds]"/>
                            <xsl:variable name="actors" select="$allActors[name=$a2r/own_slot_value[slot_reference='act_to_role_from_actor']/value] | $allActors[name=$roleRelIds]"/>
                            {"role":"<xsl:value-of select="eas:jsonText(string($role/own_slot_value[slot_reference='name']/value))"/>","person":"<xsl:for-each select="$actors"><xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/><xsl:if test="not(position()=last())">, </xsl:if></xsl:for-each>"}<xsl:if test="not(position()=last())">,</xsl:if>
                        </xsl:for-each>],
                        <xsl:variable name="thisCauses" select="$allRisks[name=$thisRisk/own_slot_value[slot_reference='risk_leading_to']/value]"/>
                        "causes":[<xsl:for-each select="$thisCauses">
                            <xsl:variable name="cause" select="current()"/>
                            <xsl:variable name="ctrls" select="$allControls[name=$cause/own_slot_value[slot_reference='risk_related_control']/value]"/>
                            {
                                "id":"<xsl:value-of select="eas:jsonText(string($cause/name))"/>",
                                "name":"<xsl:value-of select="eas:jsonText(string($cause/own_slot_value[slot_reference='name']/value))"/>",
                                "ref":"<xsl:value-of select="eas:jsonText(string($cause/own_slot_value[slot_reference='name']/value))"/>",
                                "controls":[<xsl:for-each select="$ctrls"><xsl:variable name="ctrlPMs" select="$allPerfMeasures[name=current()/own_slot_value[slot_reference='performance_measures']/value]"/><xsl:variable name="ctrlVal" select="$allSQValues[name=$ctrlPMs/own_slot_value[slot_reference='pm_performance_value']/value][1]"/>{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='description']/value))"/>","effectiveness":"<xsl:value-of select="eas:jsonText(string($ctrlVal/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
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

                    var INSTITUTIONAL_CATEGORY = 'UCL Strategic Risk Area';

                    function institutionalRisks() {
                        return RISKS.filter(function(r) { return r.category === INSTITUTIONAL_CATEGORY; });
                    }

                    function esc(s) {
                        if (s === null || s === undefined) return '';
                        return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;');
                    }

                    function likelihoodCol(p) {
                        if (p &lt; 0) return 0;
                        if (p &lt;= 25) return 1;
                        if (p &lt;= 50) return 2;
                        if (p &lt;= 75) return 3;
                        return 4;
                    }

                    function matrixCellClass(impact, likelihood) {
                        var product = impact * likelihood;
                        if (product &lt;= 3) return 'm-green';
                        if (product &lt;= 6) return 'm-yellow';
                        if (product &lt;= 9) return 'm-amber';
                        return 'm-red';
                    }

                    function severityBand(product) {
                        if (product &lt;= 0) return null;
                        if (product &lt;= 3) return {label:'Low', bg:'#57C84D'};
                        if (product &lt;= 6) return {label:'Moderate', bg:'#F2E205', fg:'#4B3B00'};
                        if (product &lt;= 9) return {label:'Severe', bg:'#F5A623'};
                        return {label:'Critical', bg:'#E5352B'};
                    }

                    // Control effectiveness -> CE label + colour, from the perf-measure value name (e.g. "Control RAG - Amber")
                    function controlEffectiveness(effVal) {
                        if (!effVal || effVal.trim() === '') return {label:'N/A', bg:'#FFC000', fg:'#111'};
                        var v = effVal.toLowerCase();
                        if (v.indexOf('green') !== -1) return {label:'G', bg:'#57C84D', fg:'#fff'};
                        if (v.indexOf('amber') !== -1 || v.indexOf('yellow') !== -1) return {label:'A', bg:'#F5A623', fg:'#fff'};
                        if (v.indexOf('red') !== -1) return {label:'R', bg:'#E5352B', fg:'#fff'};
                        // Unknown value - show its text
                        return {label: esc(effVal), bg:'#FFC000', fg:'#111'};
                    }

                    function residualAssessment(r) {
                        if (!r.assessments || r.assessments.length === 0) return null;
                        var a = r.assessments.find(function(x){ return /residual/i.test(x.type); });
                        if (!a) a = r.assessments[r.assessments.length - 1];
                        return a;
                    }

                    function residualSeverity(r) {
                        var a = residualAssessment(r);
                        if (!a) return null;
                        var col = likelihoodCol(a.probability);
                        if (a.impactScore &lt; 1 || col &lt; 1) return null;
                        return severityBand(a.impactScore * col);
                    }

                    // Split risk name into a short reference (before " - " or " :") and the rest
                    function splitRef(name) {
                        var m = name.match(/^\s*([A-Za-z]{1,4}\d+[\.\d]*)\s*[-:]\s*(.*)$/);
                        if (m) return {ref: m[1], rest: m[2]};
                        return {ref: '', rest: name};
                    }

                    function renderMatrix(r) {
                        var impactRows = [4, 3, 2, 1];
                        var impactLabels = {4:'4. Severe', 3:'3. Major', 2:'2. Moderate', 1:'1. Minor'};
                        var colLabels = ['1. Rare&lt;br/&gt;&amp;lt;25%', '2. Possible&lt;br/&gt;25-50%', '3. Frequent&lt;br/&gt;50-75%', '4. Imminent&lt;br/&gt;&amp;gt;75%'];
                        var markers = {};
                        r.assessments.forEach(function(a){
                            var col = likelihoodCol(a.probability);
                            if (a.impactScore &lt; 1 || col &lt; 1) return;
                            var letter = /inherent/i.test(a.type) ? 'I' : (/residual/i.test(a.type) ? 'R' : (a.type ? a.type.charAt(0).toUpperCase() : '?'));
                            var key = a.impactScore + '-' + col;
                            if (!markers[key]) markers[key] = [];
                            markers[key].push(letter);
                        });
                        var html = '&lt;div class="matrix-title"&gt;Risk Heatmap &lt;span style="font-weight:400;color:#6B7280;font-size:0.8rem;"&gt;(I = Inherent, R = Residual)&lt;/span&gt;&lt;/div&gt;';
                        html += '&lt;div class="matrix-wrap"&gt;';
                        html += '&lt;div class="y-axis-label"&gt;Impact&lt;/div&gt;';
                        html += '&lt;div&gt;&lt;table class="matrix-grid"&gt;&lt;tbody&gt;';
                        impactRows.forEach(function(imp){
                            html += '&lt;tr&gt;&lt;td class="axis axis-y"&gt;' + impactLabels[imp] + '&lt;/td&gt;';
                            for (var col = 1; col &lt;= 4; col++) {
                                var cls = matrixCellClass(imp, col);
                                var key = imp + '-' + col;
                                var cell = '';
                                if (markers[key]) { markers[key].forEach(function(letter){ cell += '&lt;span class="marker"&gt;' + letter + '&lt;/span&gt;'; }); }
                                html += '&lt;td class="' + cls + '"&gt;' + cell + '&lt;/td&gt;';
                            }
                            html += '&lt;/tr&gt;';
                        });
                        html += '&lt;tr&gt;&lt;td class="axis"&gt;&lt;/td&gt;';
                        colLabels.forEach(function(lbl){ html += '&lt;td class="axis axis-x"&gt;' + lbl + '&lt;/td&gt;'; });
                        html += '&lt;/tr&gt;&lt;/tbody&gt;&lt;/table&gt;';
                        html += '&lt;div class="x-axis-title"&gt;Likelihood&lt;/div&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';
                        return html;
                    }

                    function renderImpactRows(r) {
                        // Description bullets + residual impact/likelihood values
                        var text = r.description || r.shortDescription || '';
                        var parts = text.split(/(?:^|\s)-\s+/).map(function(s){ return s.trim(); }).filter(function(s){ return s !== ''; });
                        var descCell = '';
                        if (parts.length &gt; 1) {
                            descCell = '&lt;ul&gt;';
                            parts.forEach(function(p){ descCell += '&lt;li&gt;' + esc(p) + '&lt;/li&gt;'; });
                            descCell += '&lt;/ul&gt;';
                        } else {
                            descCell = esc(text || 'No description recorded.');
                        }
                        var a = residualAssessment(r);
                        var impactScore = a &amp;&amp; a.impactScore &gt; 0 ? a.impactScore : '';
                        var likeCol = a ? likelihoodCol(a.probability) : 0;
                        var likeText = likeCol &gt; 0 ? likeCol : '';
                        return '&lt;tr&gt;&lt;td&gt;' + descCell + '&lt;/td&gt;&lt;td class="num"&gt;' + impactScore + '&lt;/td&gt;&lt;td class="num"&gt;' + likeText + '&lt;/td&gt;&lt;/tr&gt;';
                    }

                    function renderCard(r) {
                        var parts = splitRef(r.name);
                        var sev = residualSeverity(r);
                        var owner = r.stakeholders.find(function(s){ return /owner/i.test(s.role); });
                        var ownerText = owner ? (owner.person || '') : '';
                        var updated = r.updated ? r.updated.split('T')[0] : '';

                        var html = '&lt;div class="rop-card"&gt;';

                        // Header
                        html += '&lt;div class="rop-header"&gt;';
                        html += '&lt;div&gt;&lt;div class="rop-ref"&gt;' + esc(parts.ref || r.name) + '&lt;/div&gt;&lt;div class="rop-soa"&gt;Strategic Outcome Area(s): ' + esc(parts.rest) + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;div class="rop-owner"&gt;Risk Owner: ' + esc(ownerText) + '&lt;/div&gt;';
                        if (updated) { html += '&lt;div class="rop-updated"&gt;Updated ' + esc(updated) + '&lt;/div&gt;'; }
                        html += '&lt;/div&gt;';

                        // Middle row
                        html += '&lt;div class="rop-midrow"&gt;';

                        // Causes
                        html += '&lt;div class="rop-panel rop-causes"&gt;&lt;div class="rop-panel-head"&gt;Causes (risks leading to risks)&lt;/div&gt;&lt;div class="rop-causes-body"&gt;';
                        if (r.causes.length &gt; 0) {
                            html += '&lt;ul&gt;';
                            r.causes.forEach(function(c){ html += '&lt;li&gt;' + esc(c.name) + '&lt;/li&gt;'; });
                            html += '&lt;/ul&gt;';
                        } else { html += '&lt;span style="color:#6B7280;"&gt;None recorded&lt;/span&gt;'; }
                        html += '&lt;/div&gt;&lt;/div&gt;';

                        // Risk centre block
                        html += '&lt;div class="rop-risk"&gt;&lt;div class="rop-risk-inner"&gt;';
                        html += '&lt;div class="rop-risk-title"&gt;RISK&lt;/div&gt;';
                        html += '&lt;div class="rop-risk-desc"&gt;' + esc(r.shortDescription || '') + '&lt;/div&gt;';
                        var resBg = sev ? sev.bg : '#9CA3AF';
                        var resFg = (sev &amp;&amp; sev.fg) ? sev.fg : '#fff';
                        var resLabel = sev ? ('RESIDUAL RISK: ' + sev.label.toUpperCase()) : 'RESIDUAL RISK LEVEL';
                        html += '&lt;div class="rop-risk-residual" style="background:' + resBg + ';color:' + resFg + ';"&gt;' + resLabel + '&lt;/div&gt;';
                        html += '&lt;/div&gt;&lt;/div&gt;';

                        // Impacts
                        html += '&lt;div class="rop-panel rop-impacts"&gt;&lt;div class="rop-panel-head"&gt;IMPACTS&lt;/div&gt;';
                        html += '&lt;table&gt;&lt;thead&gt;&lt;tr&gt;&lt;th&gt;Description&lt;/th&gt;&lt;th class="num"&gt;Impact&lt;/th&gt;&lt;th class="num"&gt;Likelihood&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                        html += renderImpactRows(r);
                        html += '&lt;/tbody&gt;&lt;/table&gt;&lt;/div&gt;';

                        // Heatmap
                        html += '&lt;div class="rop-heatmap"&gt;' + renderMatrix(r) + '&lt;/div&gt;';

                        html += '&lt;/div&gt;'; // midrow

                        // Key Controls
                        html += '&lt;div style="padding:0 10px 12px 10px;"&gt;';
                        html += '&lt;table class="rop-controls"&gt;&lt;thead&gt;';
                        html += '&lt;tr&gt;&lt;th&gt;Key Controls (related controls for risks leading to this risk)&lt;/th&gt;&lt;th class="ce-col"&gt;CE&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                        var anyControl = false;
                        r.causes.forEach(function(c){
                            c.controls.forEach(function(ctrl){
                                anyControl = true;
                                var ce = controlEffectiveness(ctrl.effectiveness);
                                html += '&lt;tr&gt;&lt;td&gt;' + esc(ctrl.name) + ' &lt;span style="color:#1F3864;font-weight:400;"&gt;(linked risk reference ' + esc(c.ref) + ')&lt;/span&gt;&lt;/td&gt;&lt;td class="ce" style="background:' + ce.bg + ';color:' + ce.fg + ';"&gt;' + ce.label + '&lt;/td&gt;&lt;/tr&gt;';
                            });
                        });
                        if (!anyControl) {
                            html += '&lt;tr&gt;&lt;td style="background:#fff;color:#6B7280;"&gt;No controls recorded&lt;/td&gt;&lt;td class="ce ce-na"&gt;N/A&lt;/td&gt;&lt;/tr&gt;';
                        }
                        html += '&lt;/tbody&gt;&lt;/table&gt;&lt;/div&gt;';

                        html += '&lt;/div&gt;'; // card
                        return html;
                    }

                    function renderAll() {
                        var risks = institutionalRisks();
                        var container = document.getElementById('cards');
                        var nav = document.getElementById('riskNav');
                        if (risks.length === 0) {
                            container.innerHTML = '&lt;div class="no-data"&gt;No risks found in category "' + esc(INSTITUTIONAL_CATEGORY) + '".&lt;/div&gt;';
                            return;
                        }
                        risks.sort(function(a,b){ return a.name.localeCompare(b.name); });
                        var navHtml = '';
                        var cardsHtml = '';
                        risks.forEach(function(r){
                            var parts = splitRef(r.name);
                            navHtml += '&lt;button onclick="document.getElementById(\'card-' + r.id + '\').scrollIntoView({behavior:\'smooth\'})"&gt;' + esc(parts.ref || r.name) + '&lt;/button&gt;';
                            cardsHtml += '&lt;div id="card-' + r.id + '"&gt;' + renderCard(r) + '&lt;/div&gt;';
                        });
                        nav.innerHTML = navHtml;
                        container.innerHTML = cardsHtml;
                    }

                    $(document).ready(function() {
                        console.log('All risks:', RISKS);
                        console.log('Institutional risks:', institutionalRisks());
                        renderAll();
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Institutional Risk - Risk on a Page</h1>
                    <p class="subtitle">Risk-on-a-page cards for risks in the "UCL Strategic Risk Area" category.</p>
                    <div class="risk-nav" id="riskNav"/>
                    <div id="cards"><p>Loading risks...</p></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
