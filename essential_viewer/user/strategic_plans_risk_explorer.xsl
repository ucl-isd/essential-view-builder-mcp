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
    <xsl:variable name="linkClasses" select="('Enterprise_Strategic_Plan', 'Risk')"/>

    <!-- Risks and categories -->
    <xsl:variable name="allRiskCategories" select="/node()/simple_instance[type='Risk_Category']"/>
    <xsl:variable name="allRisks" select="/node()/simple_instance[type='Risk']"/>

    <!-- Plan to Element Relations where the element is a risk -->
    <xsl:key name="p2eByElement" match="/node()/simple_instance[type='PLAN_TO_ELEMENT_RELATION']" use="own_slot_value[slot_reference='plan_to_element_ea_element']/value"/>
    <xsl:key name="p2eByPlan" match="/node()/simple_instance[type='PLAN_TO_ELEMENT_RELATION']" use="own_slot_value[slot_reference='plan_to_element_plan']/value"/>

    <!-- Plans -->
    <xsl:variable name="allStrategicPlans" select="/node()/simple_instance[type='Enterprise_Strategic_Plan']"/>
    <xsl:key name="planByName" match="/node()/simple_instance[type='Enterprise_Strategic_Plan']" use="name"/>
    <xsl:variable name="allPlanningActions" select="/node()/simple_instance[type='Planning_Action']"/>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>
                <title>Strategic Plans - Risk Mitigation Explorer</title>
                <style>
                    .view-wrapper{padding:20px;max-width:1400px;margin:80px auto 0 auto;font-family:'Aptos',sans-serif}
                    .risk-card{background:#fff;border:1px solid #e0e0e0;border-radius:8px;margin-bottom:12px;overflow:hidden}
                    .risk-header{background:rgb(54,26,84);color:rgb(186,130,255);padding:15px 20px;font-size:16px;font-weight:600;display:flex;justify-content:space-between;align-items:center;cursor:pointer;user-select:none}
                    .risk-header:hover{background:rgb(70,40,100)}
                    .risk-header .plan-count{background:rgba(255,255,255,0.2);padding:4px 10px;border-radius:12px;font-size:13px}
                    .risk-header .chevron{transition:transform 0.3s;font-size:14px;margin-left:10px}
                    .risk-header .chevron.open{transform:rotate(180deg)}
                    .risk-body{max-height:0;overflow:hidden;transition:max-height 0.3s ease}
                    .risk-body.open{max-height:2000px}
                    .risk-desc{padding:10px 20px;color:#666;font-size:13px;border-bottom:1px solid #f0f0f0}
                    .plan-list{padding:10px 20px}
                    .plan-item{padding:10px 12px;margin-bottom:6px;background:rgb(153,59,255);border-radius:4px;cursor:pointer;transition:background 0.2s}
                    .plan-item:hover{background:rgb(130,40,220)}
                    .plan-item .plan-item-name{font-weight:600;color:#fff;font-size:16px}
                    .plan-item .plan-item-status{font-size:12px;color:rgba(255,255,255,0.8);margin-top:3px}
                    .summary-cards{display:flex;gap:15px;margin-bottom:20px;flex-wrap:wrap}
                    .summary-card{background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:15px 20px;min-width:140px;text-align:center}
                    .summary-card .count{font-size:28px;font-weight:700;color:rgb(54,26,84)}
                    .summary-card .label{font-size:12px;color:#666;margin-top:4px}
                    .detail-panel{position:fixed;top:0;right:-520px;width:500px;height:100vh;background:#fff;box-shadow:-4px 0 20px rgba(0,0,0,0.15);z-index:1000;transition:right 0.3s ease;overflow-y:auto;padding:30px}
                    .detail-panel.open{right:0}
                    .detail-panel .close-btn{position:absolute;top:15px;right:15px;font-size:24px;cursor:pointer;color:#666;background:none;border:none}
                    .detail-panel h3{margin-top:0;padding-right:40px;color:#333;border-bottom:2px solid rgb(186,130,255);padding-bottom:10px}
                    .detail-section{margin-bottom:20px}
                    .detail-section h4{color:#555;margin-bottom:8px;font-size:14px}
                    .detail-meta{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:15px}
                    .detail-meta .meta-item{background:#f5f5f5;padding:8px 12px;border-radius:4px}
                    .detail-meta .meta-label{font-size:11px;color:#888;text-transform:uppercase}
                    .detail-meta .meta-value{font-size:14px;font-weight:600;color:#333}
                    .element-list{list-style:none;padding:0}
                    .element-list li{padding:6px 10px;margin-bottom:4px;background:rgb(238,222,255);border-left:3px solid rgb(153,59,255);border-radius:3px;font-size:13px}
                    .overlay{position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.3);z-index:999;display:none}
                    .overlay.open{display:block}
                    .no-plans{color:#999;font-size:13px;padding:10px 0;font-style:italic}
                </style>
                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>

                    // Embedded risk-to-plan data from XSL
                    var allRiskData = [<xsl:for-each select="$allRisks">
                        <xsl:variable name="thisRisk" select="current()"/>
                        <xsl:variable name="thisRiskCat" select="$allRiskCategories[name=current()/own_slot_value[slot_reference='risk_category']/value]"/>
                        <xsl:variable name="p2eForRisk" select="key('p2eByElement', current()/name)"/>
                        {"id":"<xsl:value-of select="eas:getSafeJSString(current()/name)"/>","name":"<xsl:value-of select="eas:getSafeJSString(current()/own_slot_value[slot_reference='name']/value)"/>","description":"<xsl:value-of select="eas:getSafeJSString(normalize-space(current()/own_slot_value[slot_reference='description']/value))"/>","category":"<xsl:value-of select="eas:getSafeJSString(string($thisRiskCat[1]/own_slot_value[slot_reference='name']/value))"/>","plans":[<xsl:for-each select="$p2eForRisk"><xsl:variable name="thisPlan" select="key('planByName', current()/own_slot_value[slot_reference='plan_to_element_plan']/value)"/><xsl:if test="$thisPlan">{"id":"<xsl:value-of select="eas:getSafeJSString($thisPlan/name)"/>","name":"<xsl:value-of select="eas:getSafeJSString($thisPlan/own_slot_value[slot_reference='name']/value)"/>","description":"<xsl:value-of select="eas:getSafeJSString(normalize-space($thisPlan/own_slot_value[slot_reference='description']/value))"/>","startDate":"<xsl:value-of select="$thisPlan/own_slot_value[slot_reference='strategic_plan_valid_from_date_iso_8601']/value"/>","endDate":"<xsl:value-of select="$thisPlan/own_slot_value[slot_reference='strategic_plan_valid_to_date_iso_8601']/value"/>","otherElements":[<xsl:variable name="allP2EForPlan" select="key('p2eByPlan', $thisPlan/name)"/><xsl:variable name="otherP2Es" select="$allP2EForPlan[not(own_slot_value[slot_reference='plan_to_element_ea_element']/value = $thisRisk/name)]"/><xsl:for-each select="$otherP2Es"><xsl:variable name="thisElement" select="/node()/simple_instance[name = current()/own_slot_value[slot_reference='plan_to_element_ea_element']/value]"/><xsl:variable name="thisAction" select="$allPlanningActions[name = current()/own_slot_value[slot_reference='plan_to_element_change_action']/value]"/><xsl:if test="$thisElement">{"id":"<xsl:value-of select="eas:getSafeJSString($thisElement/name)"/>","name":"<xsl:value-of select="eas:getSafeJSString(normalize-space($thisElement/own_slot_value[slot_reference='name']/value))"/>","type":"<xsl:value-of select="$thisElement/type"/>","action":"<xsl:value-of select="eas:getSafeJSString(normalize-space($thisAction/own_slot_value[slot_reference='name']/value))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>];

                    // Filter to UCL Institutional Risk Area
                    var riskData = allRiskData.filter(function(r) { return r.category === 'UCL_Institutional_Risk_Area'; });
                    console.log('All risks:', allRiskData.length, 'Filtered institutional risks:', riskData.length);
                    console.log('Categories found:', [...new Set(allRiskData.map(function(r) { return r.category; }))]);

                    function cleanText(str) {
                        if (!str) return '';
                        return str.replace(/_/g, ' ');
                    }

                    $(document).ready(function() {
                        var apiList = ['planDataAPI'];
                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                console.log('API loaded, riskData:', riskData);
                                renderView();
                            } catch (error) {
                                console.error('Error loading APIs:', error);
                                // Still try to render since data is embedded
                                renderView();
                            }
                        }
                        executeFetchAndRender();
                    });

                    function renderView() {
                        if (riskData.length === 0) {
                            document.getElementById('mainContent').innerHTML = '&lt;p style="color:#999;"&gt;No UCL Institutional Risk Areas found.&lt;/p&gt;';
                            return;
                        }
                        // Summary
                        var totalRisks = riskData.length;
                        var totalPlans = 0;
                        riskData.forEach(function(r) { totalPlans += r.plans.length; });
                        var risksWithPlans = riskData.filter(function(r) { return r.plans.length &gt; 0; }).length;
                        document.getElementById('summaryRisks').textContent = totalRisks;
                        document.getElementById('summaryPlans').textContent = totalPlans;
                        document.getElementById('summaryRisksWithPlans').textContent = risksWithPlans;

                        // Render risk cards
                        var html = '';
                        riskData.forEach(function(risk, idx) {
                            html += '&lt;div class="risk-card"&gt;';
                            html += '&lt;div class="risk-header" onclick="toggleRisk(' + idx + ')"&gt;&lt;span&gt;' + cleanText(risk.name) + '&lt;/span&gt;&lt;span&gt;&lt;span class="plan-count"&gt;' + risk.plans.length + ' plan' + (risk.plans.length !== 1 ? 's' : '') + '&lt;/span&gt;&lt;span class="chevron" id="chevron-' + idx + '"&gt;&#x25BC;&lt;/span&gt;&lt;/span&gt;&lt;/div&gt;';
                            html += '&lt;div class="risk-body" id="risk-body-' + idx + '"&gt;';
                            if (risk.description) {
                                html += '&lt;div class="risk-desc"&gt;' + cleanText(risk.description) + '&lt;/div&gt;';
                            }
                            html += '&lt;div class="plan-list"&gt;';
                            if (risk.plans.length &gt; 0) {
                                risk.plans.forEach(function(plan) {
                                    html += '&lt;div class="plan-item" onclick="showPlanDetail(\'' + plan.id + '\')"&gt;';
                                    html += '&lt;div class="plan-item-name"&gt;' + cleanText(plan.name) + '&lt;/div&gt;';
                                    if (plan.startDate || plan.endDate) {
                                        html += '&lt;div class="plan-item-status"&gt;' + (plan.startDate || '?') + ' to ' + (plan.endDate || '?') + '&lt;/div&gt;';
                                    }
                                    html += '&lt;/div&gt;';
                                });
                            } else {
                                html += '&lt;div class="no-plans"&gt;No strategic plans currently mitigating this risk.&lt;/div&gt;';
                            }
                            html += '&lt;/div&gt;&lt;/div&gt;&lt;/div&gt;';
                        });
                        document.getElementById('mainContent').innerHTML = html;
                    }

                    function toggleRisk(idx) {
                        var body = document.getElementById('risk-body-' + idx);
                        var chevron = document.getElementById('chevron-' + idx);
                        body.classList.toggle('open');
                        chevron.classList.toggle('open');
                    }

                    function showPlanDetail(planId) {
                        var plan = null;
                        for (var i = 0; i &lt; riskData.length; i++) {
                            plan = riskData[i].plans.find(function(p) { return p.id === planId; });
                            if (plan) break;
                        }
                        if (!plan) return;

                        var html = '';
                        html += '&lt;h3&gt;' + cleanText(plan.name) + '&lt;/h3&gt;';

                        // Description
                        if (plan.description) {
                            html += '&lt;div class="detail-section"&gt;&lt;h4&gt;Description&lt;/h4&gt;&lt;p&gt;' + cleanText(plan.description) + '&lt;/p&gt;&lt;/div&gt;';
                        }

                        // Meta
                        html += '&lt;div class="detail-meta"&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;Start Date&lt;/div&gt;&lt;div class="meta-value"&gt;' + (plan.startDate || 'Not Set') + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;End Date&lt;/div&gt;&lt;div class="meta-value"&gt;' + (plan.endDate || 'Not Set') + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;/div&gt;';

                        // Other impacted elements grouped by type
                        html += '&lt;div class="detail-section"&gt;&lt;h4&gt;Impacted Elements (' + plan.otherElements.length + ')&lt;/h4&gt;';
                        if (plan.otherElements.length &gt; 0) {
                            var grouped = {};
                            plan.otherElements.forEach(function(el) {
                                var typeLabel = el.type.replace(/_/g, ' ');
                                if (!grouped[typeLabel]) grouped[typeLabel] = [];
                                grouped[typeLabel].push(el);
                            });
                            Object.keys(grouped).sort().forEach(function(typeName) {
                                html += '&lt;div style="margin-bottom:12px;"&gt;';
                                html += '&lt;div style="font-weight:600;font-size:13px;color:#555;margin-bottom:6px;border-bottom:1px solid #eee;padding-bottom:4px;"&gt;' + typeName + ' (' + grouped[typeName].length + ')&lt;/div&gt;';
                                html += '&lt;ul class="element-list"&gt;';
                                grouped[typeName].forEach(function(el) {
                                    var actionLabel = el.action ? cleanText(el.action) : '';
                                    html += '&lt;li&gt;' + cleanText(el.name) + (actionLabel ? ' &lt;span style="color:#666;font-size:11px;font-style:italic;"&gt;(' + actionLabel + ')&lt;/span&gt;' : '') + '&lt;/li&gt;';
                                });
                                html += '&lt;/ul&gt;&lt;/div&gt;';
                            });
                        } else {
                            html += '&lt;p style="color:#999;"&gt;No other impacted elements recorded.&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        document.getElementById('detailContent').innerHTML = html;
                        document.getElementById('detailPanel').classList.add('open');
                        document.getElementById('overlay').classList.add('open');
                    }

                    function closePlanDetail() {
                        document.getElementById('detailPanel').classList.remove('open');
                        document.getElementById('overlay').classList.remove('open');
                    }
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <xsl:call-template name="ViewUserScopingUI"/>
                <div class="view-wrapper">
                    <h1 style="margin-bottom:5px;">Strategic Plans - Risk Mitigation</h1>
                    <p style="color:#666;margin-bottom:20px;">UCL Institutional Risk Areas and the strategic plans mitigating them. Click a plan to see its description and other impacted elements.</p>
                    <div class="summary-cards">
                        <div class="summary-card"><div class="count" id="summaryRisks">0</div><div class="label">Risk Areas</div></div>
                        <div class="summary-card"><div class="count" id="summaryPlans" style="color:rgb(153,59,255);">0</div><div class="label">Mitigating Plans</div></div>
                        <div class="summary-card"><div class="count" id="summaryRisksWithPlans" style="color:rgb(153,59,255);">0</div><div class="label">Risks with Plans</div></div>
                    </div>
                    <div id="mainContent"><p>Loading risk data...</p></div>
                </div>
                <div class="overlay" id="overlay" onclick="closePlanDetail()"/>
                <div class="detail-panel" id="detailPanel">
                    <button class="close-btn" onclick="closePlanDetail()">x</button>
                    <div id="detailContent"/>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
