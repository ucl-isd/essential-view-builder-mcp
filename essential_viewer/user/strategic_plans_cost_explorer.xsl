<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    <xsl:import href="../common/core_js_functions.xsl"/>
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>
    <xsl:include href="../common/core_footer.xsl"/>
    <xsl:include href="../common/core_external_doc_ref.xsl"/>
    <xsl:include href="../common/core_api_fetcher.xsl"/>
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>
    <xsl:variable name="viewScopeTerms" select="eas:get_scoping_terms_from_string($viewScopeTermIds)"/>
    <xsl:variable name="linkClasses" select="('Enterprise_Strategic_Plan', 'Roadmap')"/>

    <!-- XSL Variables for plans -->
    <xsl:variable name="allStrategicPlans" select="/node()/simple_instance[type='Enterprise_Strategic_Plan']"/>

    <!-- Performance measures for plans -->
    <xsl:variable name="planPerfMeasureInstances" select="/node()/simple_instance[supertype='Performance_Measure'][name=$allStrategicPlans/own_slot_value[slot_reference='performance_measures']/value]"/>
    <xsl:variable name="planPerfCategories" select="/node()/simple_instance[type='Performance_Measure_Category'][name=$planPerfMeasureInstances/own_slot_value[slot_reference='pm_category']/value]"/>
    <xsl:variable name="planSQValues" select="/node()/simple_instance[supertype='Service_Quality_Value'][name=$planPerfMeasureInstances/own_slot_value[slot_reference='pm_performance_value']/value]"/>

    <!-- Cost keys: Cost linked to plan via cost_for_elements, then Cost_Components linked to Cost -->
    <xsl:key name="costsByElement" match="/node()/simple_instance[type='Cost']" use="own_slot_value[slot_reference='cost_for_elements']/value"/>
    <xsl:key name="componentsByCost" match="/node()/simple_instance[type='Adhoc_Cost_Component' or type='Annual_Cost_Component']" use="own_slot_value[slot_reference='cc_cost_component_of_cost']/value"/>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <xsl:call-template name="RenderModalReportContent">
                    <xsl:with-param name="essModalClassNames" select="$linkClasses"/>
                </xsl:call-template>
                <title>Strategic Plans Cost Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1600px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.2rem}
                    .filters-bar{display:flex;gap:15px;margin-bottom:20px;flex-wrap:wrap;align-items:center}
                    .filters-bar select{padding:8px 14px;border-radius:4px;border:1px solid #E5E7EB;min-width:180px;font-family:'DM Sans',sans-serif;font-size:1.05rem}
                    .filters-bar label{font-weight:600;margin-right:5px;color:#4B5563}
                    .roadmap-container{position:relative;overflow-x:auto;margin-bottom:30px;border:1px solid #E5E7EB;border-radius:8px;padding:20px;background:#FFFFFF}
                    .timeline-header{display:flex;border-bottom:2px solid #D1D5DB;padding-bottom:8px;margin-bottom:10px;position:sticky;top:0;background:#FFFFFF;z-index:2}
                    .timeline-label{width:440px;font-weight:700;flex-shrink:0;color:#361A54}
                    .timeline-cost-header{width:90px;font-weight:700;flex-shrink:0;text-align:right;padding-right:10px;color:#361A54}
                    .timeline-scale{flex:1;display:flex;justify-content:space-between;font-size:1rem;color:#6B7280}
                    .plan-row{display:flex;align-items:center;margin-bottom:8px;min-height:44px}
                    .plan-name{width:440px;font-size:1.2rem;font-weight:500;flex-shrink:0;padding-right:10px;line-height:1.3;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
                    .plan-cost{width:90px;font-size:1.2rem;font-weight:600;flex-shrink:0;text-align:right;padding-right:10px;color:#993AFF}
                    .plan-bar-container{flex:1;position:relative;height:28px}
                    .plan-bar{position:absolute;height:24px;border-radius:4px;cursor:pointer;display:flex;align-items:center;padding:0 8px;font-size:11px;color:#fff;font-weight:500;transition:opacity 0.2s,transform 0.1s;top:2px}
                    .plan-bar:hover{opacity:0.85;transform:scaleY(1.1)}
                    .plan-bar.status-idea{background:#B982FF}
                    .plan-bar.status-discovery{background:#F59E0B}
                    .plan-bar.status-governance{background:#993AFF}
                    .plan-bar.status-delivery{background:#1AAB40}
                    .plan-bar.status-default{background:#9CA3AF}
                    .detail-panel{position:fixed;top:0;right:-500px;width:500px;height:100vh;background:#fff;box-shadow:-4px 0 20px rgba(0,0,0,0.15);z-index:1000;transition:right 0.3s ease;overflow-y:auto;padding:30px}
                    .detail-panel.open{right:0}
                    .detail-panel .close-btn{position:absolute;top:15px;right:15px;font-size:24px;cursor:pointer;color:#6B7280;background:none;border:none}
                    .detail-panel h3{margin-top:0;padding-right:40px;color:#361A54;border-bottom:2px solid #993AFF;padding-bottom:10px;font-weight:700}
                    .detail-section{margin-bottom:20px}
                    .detail-section h4{color:#4B5563;margin-bottom:8px;font-size:1.1rem;font-weight:600}
                    .detail-meta{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:15px}
                    .detail-meta .meta-item{background:#F3F4F6;padding:10px 14px;border-radius:4px}
                    .detail-meta .meta-label{font-size:0.95rem;color:#6B7280;text-transform:uppercase;font-weight:500}
                    .detail-meta .meta-value{font-size:1.1rem;font-weight:600;color:#111827}
                    .total-cost-banner{background:#F5F0FF;border:2px solid #993AFF;border-radius:8px;padding:18px 24px;margin-bottom:20px;text-align:center}
                    .total-cost-banner .cost-amount{font-size:2.5rem;font-weight:700;color:#361A54}
                    .total-cost-banner .cost-label{font-size:0.95rem;color:#6B7280;margin-top:4px}
                    .cost-table{width:100%;border-collapse:collapse;font-size:1.05rem}
                    .cost-table th{background:#F5F0FF;padding:12px;text-align:left;border-bottom:2px solid #993AFF;color:#361A54;font-weight:600}
                    .cost-table td{padding:12px;border-bottom:1px solid #E5E7EB}
                    .cost-table tr:hover{background:#F9FAFB}
                    .perf-table{width:100%;border-collapse:collapse;font-size:1.05rem}
                    .perf-table th{background:#F3F4F6;padding:12px;text-align:left;border-bottom:1px solid #D1D5DB;font-weight:600}
                    .perf-table td{padding:12px;border-bottom:1px solid #E5E7EB}
                    .legend{display:flex;gap:15px;margin-bottom:15px;flex-wrap:wrap}
                    .legend-item{display:flex;align-items:center;gap:5px;font-size:1rem;color:#4B5563}
                    .legend-swatch{width:16px;height:16px;border-radius:3px}
                    .summary-cards{display:flex;gap:15px;margin-bottom:20px;flex-wrap:wrap}
                    .summary-card{background:#FFFFFF;border:1px solid #E5E7EB;border-radius:8px;padding:15px 20px;min-width:140px;text-align:center}
                    .summary-card .count{font-size:2.5rem;font-weight:700;color:#361A54}
                    .summary-card .label{font-size:0.95rem;color:#6B7280;margin-top:4px}
                    .overlay{position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.3);z-index:999;display:none}
                    .overlay.open{display:block}
                    .no-data{text-align:center;padding:40px;color:#6B7280;font-size:1rem}
                    .annual-costs{display:flex;gap:8px;margin-bottom:20px;flex-wrap:wrap}
                    .annual-cost-item{background:#F5F0FF;border:1px solid #DDBDFF;border-radius:6px;padding:10px 14px;text-align:center;min-width:100px;flex:1}
                    .annual-cost-item .annual-label{font-size:0.95rem;color:#6B7280;text-transform:uppercase;font-weight:600;margin-bottom:2px}
                    .annual-cost-item .annual-value{font-size:1.4rem;font-weight:700;color:#361A54}
                </style>
                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>
                    var planDataAPI;
                    var allPlans = [];
                    var allRoadmaps = [];
                    var selectedRoadmapFilter = 'all';
                    var selectedPriorityFilter = 'all';
                    var selectedCostFilter = 'all';
                    var currency = '&#xA3;';

                    // Embedded plan costs from XSL - queried directly from Cost/Cost_Component instances
                    var planCosts = [<xsl:for-each select="$allStrategicPlans"><xsl:variable name="thisPlanCosts" select="key('costsByElement', current()/name)"/><xsl:variable name="thisCostComponents" select="key('componentsByCost', $thisPlanCosts/name)"/><xsl:if test="$thisCostComponents">{"id":"<xsl:value-of select="eas:getSafeJSString(current()/name)"/>","costs":[<xsl:for-each select="$thisCostComponents">{"amount":<xsl:choose><xsl:when test="current()/own_slot_value[slot_reference='cc_cost_amount']/value"><xsl:value-of select="current()/own_slot_value[slot_reference='cc_cost_amount']/value"/></xsl:when><xsl:otherwise>0</xsl:otherwise></xsl:choose>,"name":"<xsl:value-of select="eas:getSafeJSString(string(current()/own_slot_value[slot_reference='description']/value))"/>","recurrence":"<xsl:value-of select="current()/type"/>","startDate":"<xsl:value-of select="current()/own_slot_value[slot_reference='cc_cost_start_date_iso_8601']/value"/>","endDate":"<xsl:value-of select="current()/own_slot_value[slot_reference='cc_cost_end_date_iso_8601']/value"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>];

                    // Embedded performance measures from XSL
                    var planPerfMeasures = [<xsl:for-each select="$allStrategicPlans"><xsl:variable name="thisPlanPerfMeasures" select="$planPerfMeasureInstances[name=current()/own_slot_value[slot_reference='performance_measures']/value]"/><xsl:if test="$thisPlanPerfMeasures">{"id":"<xsl:value-of select="eas:getSafeJSString(current()/name)"/>","measures":[<xsl:for-each select="$thisPlanPerfMeasures"><xsl:variable name="thisCat" select="$planPerfCategories[name=current()/own_slot_value[slot_reference='pm_category']/value]"/><xsl:variable name="thisSQV" select="$planSQValues[name=current()/own_slot_value[slot_reference='pm_performance_value']/value][1]"/>{"category":"<xsl:value-of select="eas:getSafeJSString(string($thisCat[1]/own_slot_value[slot_reference='name']/value))"/>","value":"<xsl:value-of select="eas:getSafeJSString(string($thisSQV/own_slot_value[slot_reference='name']/value))"/>","score":"<xsl:value-of select="$thisSQV/own_slot_value[slot_reference='service_quality_value_score']/value"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]}<xsl:if test="not(position()=last())">,</xsl:if></xsl:if></xsl:for-each>];

                    $(document).ready(function() {
                        var apiList = ['planDataAPI'];
                        async function executeFetchAndRender() {
                            try {
                                var responses = await fetchAndRenderData(apiList);
                                planDataAPI = responses.planDataAPI;
                                console.log('planDataAPI:', planDataAPI);
                                console.log('Embedded planCosts:', planCosts);
                                allPlans = (planDataAPI.allPlans || []).filter(function(p) { return p.planStatus !== '0. Roadmap Idea (Outside DSP 25-32)'; });
                                allRoadmaps = planDataAPI.roadmaps || [];
                                buildFilters();
                                renderView();
                            } catch (error) {
                                console.error('Error loading view data:', error);
                            }
                        }
                        executeFetchAndRender();
                    });

                    function getPlanCosts(planId) {
                        var planCostEntry = planCosts.find(function(pc) { return pc.id === planId; });
                        if (!planCostEntry || !planCostEntry.costs) return [];
                        return planCostEntry.costs;
                    }

                    function getPlanTotalCost(planId) {
                        var costs = getPlanCosts(planId);
                        var total = 0;
                        costs.forEach(function(c) { total += c.amount; });
                        return total;
                    }

                    function getPlanCostsSortedByDate(planId) {
                        var costs = getPlanCosts(planId);
                        return costs.slice().sort(function(a, b) {
                            var dateA = a.startDate || '9999-12-31';
                            var dateB = b.startDate || '9999-12-31';
                            return dateA.localeCompare(dateB);
                        });
                    }

                    function formatCurrency(amount) {
                        if (amount === 0) return currency + '0';
                        if (amount &gt;= 1000000) return currency + (amount / 1000000).toFixed(1) + 'M';
                        if (amount &gt;= 1000) return currency + (amount / 1000).toFixed(0) + 'k';
                        return currency + amount.toFixed(0);
                    }

                    function getPlanPriority(planId) {
                        var planPerf = planPerfMeasures.find(function(pp) { return pp.id === planId; });
                        if (!planPerf || !planPerf.measures) return '';
                        for (var i = 0; i &lt; planPerf.measures.length; i++) {
                            var m = planPerf.measures[i];
                            if (m.category &amp;&amp; m.category.toLowerCase().indexOf('priority') !== -1) {
                                return m.value || '';
                            }
                        }
                        return '';
                    }

                    function buildFilters() {
                        var roadmapSelect = document.getElementById('filterRoadmap');
                        roadmapSelect.innerHTML = '&lt;option value="all"&gt;All Roadmaps&lt;/option&gt;';
                        allRoadmaps.forEach(function(rm) {
                            var opt = document.createElement('option');
                            opt.value = rm.id;
                            opt.textContent = rm.name;
                            roadmapSelect.appendChild(opt);
                        });
                        var prioritySelect = document.getElementById('filterPriority');
                        prioritySelect.innerHTML = '&lt;option value="all"&gt;All Priorities&lt;/option&gt;';
                        var priorities = new Map();
                        planPerfMeasures.forEach(function(planPerf) {
                            if (planPerf.measures) {
                                planPerf.measures.forEach(function(m) {
                                    if (m.category &amp;&amp; m.category.toLowerCase().indexOf('priority') !== -1 &amp;&amp; m.value) {
                                        var order = 99;
                                        if (m.value.indexOf('Non-Negotiable') !== -1) order = 0;
                                        else if (m.value.indexOf('P1') !== -1) order = 1;
                                        else if (m.value.indexOf('P2') !== -1) order = 2;
                                        else if (m.value.indexOf('P3') !== -1) order = 3;
                                        else if (m.value.indexOf('P4') !== -1) order = 4;
                                        else if (m.value.indexOf('P5') !== -1) order = 5;
                                        else if (m.value.indexOf('P6') !== -1) order = 6;
                                        else if (m.value.indexOf('P7') !== -1) order = 7;
                                        else if (m.value.indexOf('P8') !== -1) order = 8;
                                        if (!priorities.has(m.value)) {
                                            priorities.set(m.value, order);
                                        }
                                    }
                                });
                            }
                        });
                        var sortedPriorities = Array.from(priorities.entries()).sort(function(a, b) { return a[1] - b[1]; });
                        sortedPriorities.forEach(function(entry) {
                            var opt = document.createElement('option');
                            opt.value = entry[0];
                            opt.textContent = entry[0];
                            prioritySelect.appendChild(opt);
                        });
                        roadmapSelect.addEventListener('change', function() {
                            selectedRoadmapFilter = this.value;
                            renderView();
                        });
                        prioritySelect.addEventListener('change', function() {
                            selectedPriorityFilter = this.value;
                            renderView();
                        });
                        var costSelect = document.getElementById('filterCosts');
                        costSelect.addEventListener('change', function() {
                            selectedCostFilter = this.value;
                            renderView();
                        });
                    }

                    function getPlansForRoadmap(roadmapId) {
                        var rm = allRoadmaps.find(function(r) { return r.id === roadmapId; });
                        if (!rm) return [];
                        return rm.strategicPlans || [];
                    }

                    function filterPlans() {
                        var filtered = allPlans.slice();
                        if (selectedRoadmapFilter !== 'all') {
                            var planIdsInRoadmap = getPlansForRoadmap(selectedRoadmapFilter);
                            filtered = filtered.filter(function(plan) {
                                return planIdsInRoadmap.indexOf(plan.id) !== -1;
                            });
                        }
                        if (selectedPriorityFilter !== 'all') {
                            filtered = filtered.filter(function(plan) {
                                return getPlanPriority(plan.id) === selectedPriorityFilter;
                            });
                        }
                        if (selectedCostFilter === 'with') {
                            filtered = filtered.filter(function(plan) {
                                return getPlanTotalCost(plan.id) &gt; 0;
                            });
                        } else if (selectedCostFilter === 'without') {
                            filtered = filtered.filter(function(plan) {
                                return getPlanTotalCost(plan.id) === 0;
                            });
                        }
                        return filtered;
                    }

                    function getRoadmapForPlan(planId) {
                        for (var i = 0; i &lt; allRoadmaps.length; i++) {
                            var rm = allRoadmaps[i];
                            if (rm.strategicPlans &amp;&amp; rm.strategicPlans.indexOf(planId) !== -1) {
                                return rm.name;
                            }
                        }
                        return 'Unassigned';
                    }

                    function getPlanMeasures(planId) {
                        var planPerf = planPerfMeasures.find(function(pp) { return pp.id === planId; });
                        if (!planPerf || !planPerf.measures) return [];
                        return planPerf.measures;
                    }

                    function renderView() {
                        var plans = filterPlans();
                        if (plans.length === 0) {
                            document.getElementById('roadmapArea').innerHTML = '&lt;div class="no-data"&gt;No strategic plans match the current filters.&lt;/div&gt;';
                            updateSummary(plans);
                            return;
                        }
                        var minDate = new Date(2025, 0, 1);
                        var maxDate = new Date(2032, 11, 31);
                        var totalMs = maxDate.getTime() - minDate.getTime();
                        var years = [];
                        for (var y = 2025; y &lt;= 2032; y++) { years.push(y); }

                        var html = '&lt;div class="timeline-header"&gt;';
                        html += '&lt;div class="timeline-label"&gt;Strategic Plan&lt;/div&gt;';
                        html += '&lt;div class="timeline-cost-header"&gt;Cost&lt;/div&gt;';
                        html += '&lt;div class="timeline-scale"&gt;';
                        years.forEach(function(yr) { html += '&lt;span&gt;' + yr + '&lt;/span&gt;'; });
                        html += '&lt;/div&gt;&lt;/div&gt;';

                        var groupedByRoadmap = {};
                        plans.forEach(function(plan) {
                            var rmName = getRoadmapForPlan(plan.id);
                            if (!groupedByRoadmap[rmName]) groupedByRoadmap[rmName] = [];
                            groupedByRoadmap[rmName].push(plan);
                        });
                        Object.keys(groupedByRoadmap).sort().forEach(function(rmName) {
                            html += '&lt;div style="margin-top:12px;margin-bottom:6px;font-weight:700;font-size:13px;color:#993AFF;border-bottom:1px solid #E5E7EB;padding-bottom:4px;"&gt;' + rmName + '&lt;/div&gt;';
                            groupedByRoadmap[rmName].forEach(function(plan) {
                                var startDate = plan.validStartDate ? new Date(plan.validStartDate) : minDate;
                                var endDate = plan.validEndDate ? new Date(plan.validEndDate) : new Date(2028, 11, 31);
                                var leftPct = ((startDate.getTime() - minDate.getTime()) / totalMs) * 100;
                                var widthPct = ((endDate.getTime() - startDate.getTime()) / totalMs) * 100;
                                if (leftPct &lt; 0) leftPct = 0;
                                if (widthPct &lt; 2) widthPct = 2;
                                if (leftPct + widthPct &gt; 100) widthPct = 100 - leftPct;
                                var statusClass = 'status-default';
                                if (plan.planStatus) {
                                    var s = plan.planStatus.toLowerCase();
                                    if (s === '1. roadmap idea') statusClass = 'status-idea';
                                    else if (s === '0. roadmap idea (unplanned)') statusClass = 'status-idea';
                                    else if (s === '2. discovery') statusClass = 'status-discovery';
                                    else if (s === '3. governance') statusClass = 'status-governance';
                                    else if (s === '4. delivery') statusClass = 'status-delivery';
                                }
                                var planTotal = getPlanTotalCost(plan.id);
                                var costDisplay = planTotal &gt; 0 ? formatCurrency(planTotal) : '-';

                                html += '&lt;div class="plan-row"&gt;';
                                html += '&lt;div class="plan-name" title="' + plan.name + '" onclick="showPlanDetail(\'' + plan.id + '\')" style="cursor:pointer;color:#361A54;"&gt;' + plan.name + '&lt;/div&gt;';
                                html += '&lt;div class="plan-cost"&gt;' + costDisplay + '&lt;/div&gt;';
                                html += '&lt;div class="plan-bar-container"&gt;';
                                if (plan.planStatus === '0. Roadmap Idea (Unplanned)') {
                                    html += '&lt;span style="font-size:11px;color:#999;font-style:italic;line-height:28px;"&gt;No current start date&lt;/span&gt;';
                                } else {
                                    html += '&lt;div class="plan-bar ' + statusClass + '" style="left:' + leftPct + '%;width:' + widthPct + '%;" onclick="showPlanDetail(\'' + plan.id + '\')" title="' + plan.name + ' (' + (plan.planStatus || '') + ') - ' + costDisplay + '"&gt;';
                                    html += '&lt;/div&gt;';
                                }
                                html += '&lt;/div&gt;&lt;/div&gt;';
                            });
                        });
                        document.getElementById('roadmapArea').innerHTML = html;
                        updateSummary(plans);
                    }

                    function updateSummary(plans) {
                        var totalPlans = plans.length;
                        var totalCost = 0;
                        var plansWithCosts = 0;
                        plans.forEach(function(p) {
                            var cost = getPlanTotalCost(p.id);
                            totalCost += cost;
                            if (cost &gt; 0) plansWithCosts++;
                        });
                        document.getElementById('summaryTotal').textContent = totalPlans;
                        document.getElementById('summaryTotalCost').textContent = formatCurrency(totalCost);
                        document.getElementById('summaryPlansWithCosts').textContent = plansWithCosts;

                        // Calculate annual costs by financial year (Aug-Jul)
                        var yearPeriods = [
                            {label: '25-26', start: '2025-08-01', end: '2026-07-31'},
                            {label: '26-27', start: '2026-08-01', end: '2027-07-31'},
                            {label: '27-28', start: '2027-08-01', end: '2028-07-31'},
                            {label: '28-29', start: '2028-08-01', end: '2029-07-31'},
                            {label: '29-30', start: '2029-08-01', end: '2030-07-31'},
                            {label: '30-31', start: '2030-08-01', end: '2031-07-31'},
                            {label: '31-32', start: '2031-08-01', end: '2032-07-31'}
                        ];
                        var annualHtml = '';
                        yearPeriods.forEach(function(period) {
                            var periodTotal = 0;
                            plans.forEach(function(p) {
                                var costs = getPlanCosts(p.id);
                                costs.forEach(function(c) {
                                    if (!c.startDate) return;
                                    var cStart = c.startDate;
                                    var cEnd = c.endDate || c.startDate;
                                    if (cStart &lt;= period.end &amp;&amp; cEnd &gt;= period.start) {
                                        periodTotal += c.amount;
                                    }
                                });
                            });
                            annualHtml += '&lt;div class="annual-cost-item"&gt;&lt;div class="annual-label"&gt;' + period.label + '&lt;/div&gt;&lt;div class="annual-value"&gt;' + formatCurrency(periodTotal) + '&lt;/div&gt;&lt;/div&gt;';
                        });
                        document.getElementById('annualCosts').innerHTML = annualHtml;
                    }

                    function showPlanDetail(planId) {
                        var plan = allPlans.find(function(p) { return p.id === planId; });
                        if (!plan) return;
                        var html = '';
                        html += '&lt;h3&gt;' + plan.name + '&lt;/h3&gt;';

                        // Total cost banner
                        var totalCost = getPlanTotalCost(planId);
                        html += '&lt;div class="total-cost-banner"&gt;';
                        html += '&lt;div class="cost-amount"&gt;' + (totalCost &gt; 0 ? formatCurrency(totalCost) : 'No costs recorded') + '&lt;/div&gt;';
                        html += '&lt;div class="cost-label"&gt;Total Plan Cost&lt;/div&gt;';
                        html += '&lt;/div&gt;';

                        // Meta info
                        html += '&lt;div class="detail-meta"&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;Status&lt;/div&gt;&lt;div class="meta-value"&gt;' + (plan.planStatus || 'Not Set') + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;Roadmap&lt;/div&gt;&lt;div class="meta-value"&gt;' + getRoadmapForPlan(plan.id) + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;Start Date&lt;/div&gt;&lt;div class="meta-value"&gt;' + (plan.validStartDate || 'Not Set') + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;div class="meta-item"&gt;&lt;div class="meta-label"&gt;End Date&lt;/div&gt;&lt;div class="meta-value"&gt;' + (plan.validEndDate || 'Not Set') + '&lt;/div&gt;&lt;/div&gt;';
                        html += '&lt;/div&gt;';

                        // Performance Measures section - show costs ordered by date
                        var sortedCosts = getPlanCostsSortedByDate(planId);
                        html += '&lt;div class="detail-section"&gt;&lt;h4&gt;Performance Measures - Costs (' + sortedCosts.length + ' items)&lt;/h4&gt;';
                        if (sortedCosts.length &gt; 0) {
                            html += '&lt;table class="cost-table"&gt;&lt;thead&gt;&lt;tr&gt;&lt;th&gt;Description&lt;/th&gt;&lt;th&gt;Amount&lt;/th&gt;&lt;th&gt;Start Date&lt;/th&gt;&lt;th&gt;End Date&lt;/th&gt;&lt;th&gt;Recurrence&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                            sortedCosts.forEach(function(c) {
                                var recLabel = c.recurrence === 'Annual_Cost_Component' ? 'Annual' : 'One-off';
                                html += '&lt;tr&gt;';
                                html += '&lt;td&gt;' + (c.name || '-') + '&lt;/td&gt;';
                                html += '&lt;td style="font-weight:600;color:#993AFF;"&gt;' + currency + c.amount.toLocaleString() + '&lt;/td&gt;';
                                html += '&lt;td&gt;' + (c.startDate || '-') + '&lt;/td&gt;';
                                html += '&lt;td&gt;' + (c.endDate || '-') + '&lt;/td&gt;';
                                html += '&lt;td&gt;' + recLabel + '&lt;/td&gt;';
                                html += '&lt;/tr&gt;';
                            });
                            html += '&lt;/tbody&gt;&lt;/table&gt;';
                        } else {
                            html += '&lt;p style="color:#999;"&gt;No cost components recorded for this plan.&lt;/p&gt;';
                        }
                        html += '&lt;/div&gt;';

                        // Other performance measures
                        var measures = getPlanMeasures(planId);
                        if (measures.length &gt; 0) {
                            html += '&lt;div class="detail-section"&gt;&lt;h4&gt;Other Performance Measures&lt;/h4&gt;';
                            html += '&lt;table class="perf-table"&gt;&lt;thead&gt;&lt;tr&gt;&lt;th&gt;Category&lt;/th&gt;&lt;th&gt;Value&lt;/th&gt;&lt;th&gt;Score&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                            measures.forEach(function(m) {
                                html += '&lt;tr&gt;&lt;td&gt;' + (m.category || '-') + '&lt;/td&gt;&lt;td&gt;' + (m.value || '-') + '&lt;/td&gt;&lt;td&gt;' + (m.score || '-') + '&lt;/td&gt;&lt;/tr&gt;';
                            });
                            html += '&lt;/tbody&gt;&lt;/table&gt;&lt;/div&gt;';
                        }

                        if (plan.description) {
                            html += '&lt;div class="detail-section"&gt;&lt;h4&gt;Description&lt;/h4&gt;&lt;p&gt;' + plan.description + '&lt;/p&gt;&lt;/div&gt;';
                        }

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
                    <h1 style="margin-bottom:5px;">Strategic Plans Cost Explorer</h1>
                    <p style="color:#6B7280;margin-bottom:20px;">Explore strategic plans on a timeline with their associated costs. Click a plan to see total cost and cost breakdown ordered by date.</p>
                    <div class="summary-cards">
                        <div class="summary-card"><div class="count" id="summaryTotal">0</div><div class="label">Total Plans</div></div>
                        <div class="summary-card"><div class="count" id="summaryTotalCost" style="color:#993AFF;">-</div><div class="label">Total Cost</div></div>
                        <div class="summary-card"><div class="count" id="summaryPlansWithCosts" style="color:#993AFF;">0</div><div class="label">Plans with Costs</div></div>
                    </div>
                    <div class="annual-costs" id="annualCosts"/>
                    <div class="filters-bar">
                        <div><label for="filterRoadmap">Roadmap:</label><select id="filterRoadmap"><option value="all">All Roadmaps</option></select></div>
                        <div><label for="filterPriority">Priority:</label><select id="filterPriority"><option value="all">All Priorities</option></select></div>
                        <div><label for="filterCosts">Costs:</label><select id="filterCosts"><option value="all">All Plans</option><option value="with">With Costs</option><option value="without">Without Costs</option></select></div>
                    </div>
                    <div class="legend">
                        <div class="legend-item"><div class="legend-swatch" style="background:#B982FF;"/><xsl:text> </xsl:text>1. Roadmap Idea</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:#F59E0B;"/><xsl:text> </xsl:text>2. Discovery</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:#993AFF;"/><xsl:text> </xsl:text>3. Governance</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:#1AAB40;"/><xsl:text> </xsl:text>4. Delivery</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:#9CA3AF;"/><xsl:text> </xsl:text>Not Set</div>
                    </div>
                    <div class="roadmap-container" id="mainContent">
                        <div id="roadmapArea"><p>Loading strategic plans...</p></div>
                    </div>
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
