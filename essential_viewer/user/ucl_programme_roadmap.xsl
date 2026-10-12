<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>

    <!-- ===== Model variables ===== -->
    <xsl:variable name="allProgrammes" select="/node()/simple_instance[type='Programme']"/>
    <xsl:variable name="allProjects" select="/node()/simple_instance[type='Project']"/>
    <xsl:variable name="allPMs" select="/node()/simple_instance[type='Business_Performance_Measure']"/>
    <xsl:variable name="allPMCats" select="/node()/simple_instance[type='Performance_Measure_Category']"/>
    <xsl:variable name="allSQV" select="/node()/simple_instance[supertype='Service_Quality_Value' or type='Business_Service_Quality_Value']"/>
    <xsl:variable name="allA2R" select="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']"/>
    <xsl:variable name="allActors" select="/node()/simple_instance[type=('Group_Actor','Individual_Actor')]"/>
    <xsl:variable name="allRoadmaps" select="/node()/simple_instance[type='Roadmap']"/>

    <!-- Category instances by name -->
    <xsl:variable name="catClassification" select="$allPMCats[own_slot_value[slot_reference='name']/value='Change Classification']"/>
    <xsl:variable name="catRAG" select="$allPMCats[own_slot_value[slot_reference='name']/value='RAG']"/>

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

    <!-- Resolve the performance-value for a given element + category.
         The readable label lives in service_quality_value_value (e.g. 'DSP Change', 'Enhance').
         Falls back to the name with any 'Category - ' prefix stripped. -->
    <xsl:function name="eas:pmValue">
        <xsl:param name="elem"/>
        <xsl:param name="catName"/>
        <xsl:variable name="cat" select="$allPMCats[own_slot_value[slot_reference='name']/value=$catName]"/>
        <xsl:variable name="pms" select="$allPMs[own_slot_value[slot_reference='pm_measured_element']/value = $elem/name][own_slot_value[slot_reference='pm_category']/value = $cat/name]"/>
        <xsl:variable name="val" select="$allSQV[name = $pms[1]/own_slot_value[slot_reference='pm_performance_value']/value]"/>
        <xsl:variable name="label" select="string($val[1]/own_slot_value[slot_reference='service_quality_value_value']/value)"/>
        <xsl:choose>
            <xsl:when test="normalize-space($label) != ''"><xsl:value-of select="$label"/></xsl:when>
            <xsl:otherwise>
                <xsl:variable name="nm" select="string($val[1]/own_slot_value[slot_reference='name']/value)"/>
                <xsl:value-of select="replace($nm, '^.* - ', '')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Resolve the portfolio (actor name) for a programme via its 'Programme Manager' stakeholder relation -->
    <xsl:function name="eas:portfolio">
        <xsl:param name="prog"/>
        <xsl:variable name="rels" select="$allA2R[name = $prog/own_slot_value[slot_reference='stakeholders']/value]"/>
        <xsl:variable name="pmRel" select="$rels[ends-with(own_slot_value[slot_reference='relation_name']/value, 'as Programme Manager')]"/>
        <xsl:variable name="actor" select="$allActors[name = $pmRel[1]/own_slot_value[slot_reference='act_to_role_from_actor']/value]"/>
        <xsl:value-of select="string($actor[1]/own_slot_value[slot_reference='name']/value)"/>
    </xsl:function>

    <xsl:template match="/">
        <html>
            <head>
                <meta charset="UTF-8"/>
                <title>UCL Delivery Roadmaps</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    :root{--p800:#361A54;--p700:#4A1B94;--p600:#6023C0;--p400:#993AFF;--p200:#DDBDFF;--p50:#F5F0FF;--g50:#F9FAFB;--g100:#F3F4F6;--g200:#E5E7EB;--g500:#6B7280;--g600:#4B5563;--g900:#111827;--success:#1AAB40;--warning:#F59E0B;--error:#DC2626;--discovery:#2AA198;--elaboration:#7B2DF8;--delivery:#361A54;}
                    *{margin:0;padding:0;box-sizing:border-box;}
                    body{font-family:'DM Sans',sans-serif;background:#F9FAFB;color:var(--g900);padding:24px;}
                    .roadmap-container{max-width:1500px;margin:0 auto;}
                    .roadmap-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px;}
                    .roadmap-header h1{font-size:1.5rem;font-weight:700;color:var(--p800);}
                    .roadmap-header .meta{font-size:0.8rem;color:var(--g500);}
                    /* term grid header */
                    .term-header{display:grid;grid-template-columns:308px repeat(8,1fr);border-bottom:2px solid var(--g200);}
                    .term-header .label-col{padding:8px;font-size:0.75rem;color:var(--g500);}
                    .term-cell{text-align:center;padding:10px 4px;font-size:0.78rem;font-weight:600;color:#fff;background:var(--p800);border-left:1px solid var(--p700);}
                    /* classification group */
                    .classification-group{margin-bottom:8px;position:relative;padding-left:28px;}
                    .classification-label{writing-mode:vertical-rl;text-orientation:mixed;transform:rotate(180deg);font-size:0.7rem;font-weight:700;padding:8px 4px;text-align:center;border-radius:4px 0 0 4px;position:absolute;left:0;top:0;bottom:0;width:28px;display:flex;align-items:center;justify-content:center;}
                    .class-dsp{background:var(--p600);color:#fff;}
                    .class-non-dsp{background:var(--p400);color:#fff;}
                    .class-enhance{background:var(--p200);color:var(--p800);}
                    .class-maintain{background:var(--g200);color:#1F2937;}
                    .class-other{background:var(--g200);color:#1F2937;}
                    /* epic (programme) row */
                    .epic-row{display:grid;grid-template-columns:280px 1fr;min-height:44px;border-bottom:1px solid var(--g200);position:relative;}
                    .epic-row:hover{background:var(--g50);}
                    .epic-label{padding:8px 12px 8px 8px;display:flex;align-items:center;gap:8px;font-size:0.78rem;font-weight:600;color:var(--g900);}
                    .epic-label .rag{width:12px;height:12px;border-radius:50%;flex-shrink:0;border:2px solid rgba(255,255,255,0.3);}
                    .rag-red{background:var(--error);}
                    .rag-amber{background:var(--warning);}
                    .rag-green{background:var(--success);}
                    .timeline-area{position:relative;padding:10px 0;}
                    .phase-bar{position:absolute;height:22px;border-radius:4px;top:50%;transform:translateY(-50%);cursor:pointer;transition:opacity 0.2s;}
                    .phase-bar:hover{opacity:0.85;}
                    .phase-discovery{background:var(--discovery);}
                    .phase-elaboration{background:var(--elaboration);}
                    .phase-delivery{background:var(--delivery);border:1px solid var(--p400);}
                    .outcome-wrapper{position:absolute;top:0;bottom:0;}
                    .outcome-marker{position:absolute;top:50%;transform:translate(-50%,-50%) rotate(45deg);width:10px;height:10px;background:#fff;border:2px solid var(--p800);cursor:pointer;z-index:10;transition:transform 0.15s;}
                    .outcome-marker:hover{transform:translate(-50%,-50%) rotate(45deg) scale(1.4);}
                    .outcome-tooltip{display:none;position:absolute;bottom:calc(50% + 18px);transform:translateX(-50%);background:#fff;color:var(--g900);padding:8px 12px;border-radius:6px;font-size:0.75rem;white-space:nowrap;box-shadow:0 4px 12px rgba(0,0,0,0.3);z-index:100;pointer-events:none;}
                    .outcome-tooltip .tt-title{font-weight:700;margin-bottom:2px;}
                    .outcome-tooltip .tt-date{color:var(--g500);font-size:0.7rem;}
                    .outcome-tooltip .tt-desc{color:var(--g600);font-size:0.7rem;margin-top:4px;max-width:250px;white-space:normal;}
                    .outcome-wrapper:hover .outcome-tooltip{display:block;}
                    .grid-lines{position:absolute;top:0;left:0;right:0;bottom:0;display:grid;grid-template-columns:repeat(8,1fr);pointer-events:none;}
                    .grid-line{border-left:1px solid var(--g200);}
                    .pre-start{position:absolute;left:0;top:50%;transform:translateY(-50%);z-index:15;}
                    .pre-start-badge{display:inline-block;background:var(--p400);color:#fff;font-size:0.65rem;font-weight:700;padding:0 14px 0 8px;height:28px;line-height:28px;white-space:nowrap;clip-path:polygon(0 0,calc(100% - 10px) 0,100% 50%,calc(100% - 10px) 100%,0 100%);border-radius:4px 0 0 4px;}
                    .legend{display:flex;gap:24px;align-items:center;margin-top:20px;padding:12px 16px;background:var(--g100);border-radius:8px;border:1px solid var(--g200);font-size:0.78rem;color:var(--g600);flex-wrap:wrap;}
                    .legend-item{display:flex;align-items:center;gap:6px;}
                    .legend-swatch{width:20px;height:10px;border-radius:3px;}
                    .legend-diamond{width:10px;height:10px;background:#fff;border:2px solid var(--p800);transform:rotate(45deg);}
                    .no-data{padding:24px;color:var(--g500);font-size:0.85rem;}
                    /* portfolio tab nav */
                    .portfolio-nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:20px;border-bottom:2px solid var(--g200);}
                    .portfolio-nav a{padding:8px 16px;font-size:0.82rem;font-weight:600;color:var(--g600);text-decoration:none;border-bottom:3px solid transparent;cursor:pointer;transition:color 0.15s,border-color 0.15s;}
                    .portfolio-nav a:hover{color:var(--p600);}
                    .portfolio-nav a.active{color:var(--p800);border-bottom-color:var(--p600);}
                    /* detail panel + overlay */
                    .dp-overlay{display:none;position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.3);z-index:150;}
                    .dp-overlay.active{display:block;}
                    .detail-panel{position:fixed;top:0;right:-400px;width:380px;max-width:92vw;height:100vh;background:#fff;color:var(--g900);box-shadow:-4px 0 20px rgba(0,0,0,0.25);padding:24px;overflow-y:auto;z-index:200;transition:right 0.25s ease;}
                    .detail-panel.active{right:0;}
                    .detail-panel h3{font-size:1.15rem;color:var(--p800);margin-bottom:10px;padding-right:28px;}
                    .dp-kicker{display:inline-block;font-size:0.7rem;text-transform:uppercase;letter-spacing:0.05em;font-weight:700;color:#fff;background:var(--p600);padding:3px 10px;border-radius:12px;margin-bottom:8px;}
                    .dp-kicker.proj{background:var(--delivery);}
                    .dp-meta{font-size:0.82rem;color:var(--g600);margin-bottom:16px;}
                    .dp-meta dt{font-weight:700;color:var(--g900);margin-top:8px;}
                    .dp-meta dd{margin:2px 0 0 0;line-height:1.45;}
                    .dp-sub{font-size:0.85rem;color:var(--p800);margin:16px 0 6px 0;}
                    .dp-list{list-style:none;display:flex;flex-direction:column;gap:6px;}
                    .dp-list li{background:var(--p50);border:1px solid var(--p200);border-radius:6px;padding:8px 12px;font-size:0.8rem;color:var(--g900);cursor:pointer;}
                    .dp-list li:hover{background:var(--p200);}
                    .dp-empty{font-size:0.8rem;color:var(--g500);font-style:italic;}
                    .dp-close{position:absolute;top:12px;right:12px;background:none;border:none;font-size:1.5rem;cursor:pointer;color:var(--g500);}
                    .dp-close:hover{color:var(--g900);}
                    .rag-dot{display:inline-block;width:12px;height:12px;border-radius:50%;vertical-align:middle;margin-right:6px;}
                </style>
            </head>
            <body>
                <div class="roadmap-container">
                    <div class="roadmap-header">
                        <h1>UCL Delivery Roadmaps</h1>
                        <div class="meta">Stage 1 preview &#8226; Programmes: <xsl:value-of select="count($allProgrammes)"/> &#8226; Projects: <xsl:value-of select="count($allProjects)"/></div>
                    </div>
                    <nav class="portfolio-nav" id="portfolioNav"></nav>
                    <div id="portfolioSections"><p>Loading...</p></div>
                    <div class="legend">
                        <span style="font-weight:600;color:var(--g900);">Phase:</span>
                        <div class="legend-item"><div class="legend-swatch" style="background:var(--discovery);"></div> Discovery</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:var(--elaboration);"></div> Elaboration</div>
                        <div class="legend-item"><div class="legend-swatch" style="background:var(--delivery);border:1px solid var(--p400);"></div> Delivery</div>
                        <span style="margin-left:16px;font-weight:600;color:var(--g900);">Project due:</span>
                        <div class="legend-item"><div class="legend-diamond"></div> Project</div>
                    </div>
                </div>
                <div class="dp-overlay" id="dpOverlay" onclick="closeDetail()"></div>
                <div class="detail-panel" id="detailPanel"></div>

                <script type="text/javascript">
                    var PROGRAMMES = [<xsl:for-each select="$allProgrammes">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="prog" select="current()"/>
                        <xsl:variable name="projects" select="$allProjects[name = $prog/own_slot_value[slot_reference='projects_for_programme']/value]"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($prog/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($prog/own_slot_value[slot_reference='name']/value))"/>",
                        "ref":"<xsl:value-of select="eas:jsonText(string($prog/own_slot_value[slot_reference='ea_reference']/value))"/>",
                        "description":"<xsl:value-of select="eas:jsonText(string($prog/own_slot_value[slot_reference='description']/value))"/>",
                        "portfolio":"<xsl:value-of select="eas:jsonText(eas:portfolio($prog))"/>",
                        "classification":"<xsl:value-of select="eas:jsonText(eas:pmValue($prog,'Change Classification'))"/>",
                        "rag":"<xsl:value-of select="eas:jsonText(eas:pmValue($prog,'RAG'))"/>",
                        "discoveryStart":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Discovery Planned Start']/value"/>",
                        "discoveryEnd":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Discovery Due Date']/value"/>",
                        "elaborationStart":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Elaboration Planned Start']/value"/>",
                        "elaborationEnd":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Elaboration Planned Due']/value"/>",
                        "deliveryStart":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Delivery Planned Start']/value"/>",
                        "deliveryEnd":"<xsl:value-of select="$prog/own_slot_value[slot_reference='Delivery Due Date']/value"/>",
                        "projects":[<xsl:for-each select="$projects">
                            <xsl:variable name="pj" select="current()"/>
                            {"id":"<xsl:value-of select="eas:jsonText(string($pj/name))"/>","name":"<xsl:value-of select="eas:jsonText(string($pj/own_slot_value[slot_reference='name']/value))"/>","ref":"<xsl:value-of select="eas:jsonText(string($pj/own_slot_value[slot_reference='ea_reference']/value))"/>","description":"<xsl:value-of select="eas:jsonText(string($pj/own_slot_value[slot_reference='description']/value))"/>","start":"<xsl:value-of select="$pj/own_slot_value[slot_reference='ca_proposed_start_date_iso_8601']/value"/>","due":"<xsl:value-of select="$pj/own_slot_value[slot_reference='ca_forecast_end_date_iso_8601']/value"/>","classification":"<xsl:value-of select="eas:jsonText(eas:pmValue($pj,'Change Classification'))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    // ---- date math (chart window 1 Aug 2026 - 31 Jul 2028) ----
                    var CHART_START = Date.UTC(2026,7,1);
                    var CHART_END = Date.UTC(2028,6,31);
                    var CHART_DAYS = (CHART_END - CHART_START) / 86400000;
                    function parseD(s){ if(!s) return null; var m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s); if(!m) return null; return Date.UTC(+m[1], +m[2]-1, +m[3]); }
                    function pct(s){ var d = parseD(s); if(d===null) return null; var days=(d-CHART_START)/86400000; var p=days/CHART_DAYS*100; return Math.max(0,Math.min(100,p)); }
                    function beforeChart(s){ var d=parseD(s); return d!==null &amp;&amp; d &lt; CHART_START; }
                    function fmtD(s){ var d=parseD(s); if(d===null) return 'TBC'; var mo=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']; var dt=new Date(d); return dt.getUTCDate()+' '+mo[dt.getUTCMonth()]+' '+dt.getUTCFullYear(); }
                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }

                    function ragClass(v){ if(!v) return ''; var s=v.toLowerCase(); if(s.indexOf('red')!==-1) return 'rag-red'; if(s.indexOf('amber')!==-1||s.indexOf('yellow')!==-1) return 'rag-amber'; if(s.indexOf('green')!==-1) return 'rag-green'; return ''; }

                    // Phase bars for a programme
                    function phaseBars(p){
                        var html='';
                        var phases=[['discovery',p.discoveryStart,p.discoveryEnd,'Discovery'],['elaboration',p.elaborationStart,p.elaborationEnd,'Elaboration'],['delivery',p.deliveryStart,p.deliveryEnd,'Delivery']];
                        var hasPre=false;
                        phases.forEach(function(ph){
                            var start=ph[1], end=ph[2];
                            if(!start) return;
                            var before=beforeChart(start); if(before) hasPre=true;
                            var left=before?0:pct(start);
                            var width, extra='';
                            if(end){ width=pct(end)-left; } else { width=8; extra=' opacity:0.6;'; }
                            if(width&lt;0) width=0;
                            var title=ph[3]+': '+fmtD(start)+' \u2013 '+(end?fmtD(end):'TBC')+(before?' (started before chart)':'');
                            html+='&lt;div class="phase-bar phase-'+ph[0]+'" style="left:'+left.toFixed(1)+'%; width:'+width.toFixed(1)+'%;'+extra+'" title="'+esc(title)+'"&gt;&lt;/div&gt;';
                        });
                        if(hasPre) html='&lt;div class="pre-start"&gt;&lt;span class="pre-start-badge"&gt;pre 26/27&lt;/span&gt;&lt;/div&gt;'+html;
                        return html;
                    }
                    // Project diamonds
                    function projectDiamonds(p){
                        var html='';
                        (p.projects||[]).forEach(function(pj){
                            var pos=pct(pj.due); if(pos===null) return;
                            html+='&lt;div class="outcome-wrapper" style="left:'+pos.toFixed(1)+'%;" onclick="event.stopPropagation(); openProject(\''+pj.id+'\')"&gt;'
                                + '&lt;div class="outcome-marker"&gt;&lt;/div&gt;'
                                + '&lt;div class="outcome-tooltip"&gt;&lt;div class="tt-title"&gt;'+esc(pj.name)+'&lt;/div&gt;&lt;div class="tt-date"&gt;'+fmtD(pj.due)+'&lt;/div&gt;'+(pj.description?'&lt;div class="tt-desc"&gt;'+esc(pj.description)+'&lt;/div&gt;':'')+'&lt;/div&gt;'
                                + '&lt;/div&gt;';
                        });
                        return html;
                    }
                    function gridLines(){ var h=''; for(var i=0;i&lt;8;i++) h+='&lt;div class="grid-line"&gt;&lt;/div&gt;'; return '&lt;div class="grid-lines"&gt;'+h+'&lt;/div&gt;'; }

                    function programmeRow(p){
                        var rag=ragClass(p.rag);
                        var ragSpan = rag ? '&lt;span class="rag '+rag+'"&gt;&lt;/span&gt;' : '';
                        return '&lt;div class="epic-row" onclick="openProgramme(\''+p.id+'\')" style="cursor:pointer;"&gt;'
                            + '&lt;div class="epic-label"&gt;'+ragSpan+esc(p.name)+'&lt;/div&gt;'
                            + '&lt;div class="timeline-area"&gt;'+gridLines()+phaseBars(p)+projectDiamonds(p)+'&lt;/div&gt;'
                            + '&lt;/div&gt;';
                    }

                    // Classification bands
                    var CLASS_ORDER=[['DSP Change','class-dsp'],['Non-DSP Change','class-non-dsp'],['Enhance','class-enhance'],['Maintain','class-maintain']];
                    function classificationGroups(list){
                        var html=''; var used={};
                        CLASS_ORDER.forEach(function(c){
                            var grp=list.filter(function(p){ return (p.classification||'')===c[0]; });
                            grp.forEach(function(p){ used[p.id]=true; });
                            if(!grp.length) return;
                            html+='&lt;div class="classification-group"&gt;&lt;div class="classification-label '+c[1]+'"&gt;'+c[0]+'&lt;/div&gt;'+grp.map(programmeRow).join('')+'&lt;/div&gt;';
                        });
                        var other=list.filter(function(p){ return !used[p.id]; });
                        if(other.length) html+='&lt;div class="classification-group"&gt;&lt;div class="classification-label class-other"&gt;Other&lt;/div&gt;'+other.map(programmeRow).join('')+'&lt;/div&gt;';
                        return html;
                    }

                    function termHeader(){
                        return '&lt;div class="term-header"&gt;&lt;div class="label-col"&gt;&lt;/div&gt;'
                            +'&lt;div class="term-cell"&gt;T1 26/27&lt;/div&gt;&lt;div class="term-cell"&gt;T2 26/27&lt;/div&gt;&lt;div class="term-cell"&gt;T3 26/27&lt;/div&gt;&lt;div class="term-cell"&gt;T4 26/27&lt;/div&gt;'
                            +'&lt;div class="term-cell"&gt;T1 27/28&lt;/div&gt;&lt;div class="term-cell"&gt;T2 27/28&lt;/div&gt;&lt;div class="term-cell"&gt;T3 27/28&lt;/div&gt;&lt;div class="term-cell"&gt;T4 27/28&lt;/div&gt;&lt;/div&gt;';
                    }

                    // ---- Index programmes + projects by id for the detail panels ----
                    var PROG_BY_ID={}, PROJ_BY_ID={};
                    PROGRAMMES.forEach(function(p){
                        PROG_BY_ID[p.id]=p;
                        (p.projects||[]).forEach(function(pj){ pj.parentName=p.name; PROJ_BY_ID[pj.id]=pj; });
                    });

                    function detailRow(label, val){
                        if(!val) return '';
                        return '&lt;dt&gt;'+esc(label)+'&lt;/dt&gt;&lt;dd&gt;'+esc(val)+'&lt;/dd&gt;';
                    }
                    function phaseRow(label, s, e){
                        if(!s &amp;&amp; !e) return '';
                        return '&lt;dt&gt;'+esc(label)+'&lt;/dt&gt;&lt;dd&gt;'+fmtD(s)+' \u2013 '+fmtD(e)+'&lt;/dd&gt;';
                    }
                    function ragDot(v){ var c=ragClass(v); return c?'&lt;span class="rag-dot '+c+'"&gt;&lt;/span&gt;':''; }

                    function openProgramme(id){
                        var p=PROG_BY_ID[id]; if(!p) return;
                        var html='&lt;button class="dp-close" onclick="closeDetail()"&gt;&#215;&lt;/button&gt;';
                        html+='&lt;div class="dp-kicker"&gt;Delivery Initiative&lt;/div&gt;';
                        html+='&lt;h3&gt;'+esc(p.name)+'&lt;/h3&gt;';
                        html+='&lt;dl class="dp-meta"&gt;';
                        html+=detailRow('Reference', p.ref);
                        html+=detailRow('Portfolio', p.portfolio);
                        html+=detailRow('Change Classification', p.classification);
                        if(p.rag) html+='&lt;dt&gt;RAG&lt;/dt&gt;&lt;dd&gt;'+ragDot(p.rag)+esc(p.rag)+'&lt;/dd&gt;';
                        if(p.roadmap) html+=detailRow('DSP Roadmap', p.roadmap);
                        html+=detailRow('Description', p.description);
                        html+=phaseRow('Discovery', p.discoveryStart, p.discoveryEnd);
                        html+=phaseRow('Elaboration', p.elaborationStart, p.elaborationEnd);
                        html+=phaseRow('Delivery', p.deliveryStart, p.deliveryEnd);
                        html+='&lt;/dl&gt;';
                        html+='&lt;h4 class="dp-sub"&gt;Projects&lt;/h4&gt;';
                        if(p.projects &amp;&amp; p.projects.length){
                            html+='&lt;ul class="dp-list"&gt;';
                            p.projects.forEach(function(pj){
                                var due=pj.due?(' &#8212; Due: '+fmtD(pj.due)):'';
                                html+='&lt;li onclick="openProject(\''+pj.id+'\')"&gt;&lt;strong&gt;'+esc(pj.name)+'&lt;/strong&gt;'+due+'&lt;/li&gt;';
                            });
                            html+='&lt;/ul&gt;';
                        } else { html+='&lt;p class="dp-empty"&gt;No projects linked.&lt;/p&gt;'; }
                        showDetail(html);
                    }

                    function openProject(id){
                        var pj=PROJ_BY_ID[id]; if(!pj) return;
                        var html='&lt;button class="dp-close" onclick="closeDetail()"&gt;&#215;&lt;/button&gt;';
                        html+='&lt;div class="dp-kicker proj"&gt;Project&lt;/div&gt;';
                        html+='&lt;h3&gt;'+esc(pj.name)+'&lt;/h3&gt;';
                        html+='&lt;dl class="dp-meta"&gt;';
                        html+=detailRow('Reference', pj.ref);
                        html+=detailRow('Change Classification', pj.classification);
                        html+=detailRow('Start Date', pj.start?fmtD(pj.start):'');
                        html+=detailRow('Due Date', pj.due?fmtD(pj.due):'');
                        html+=detailRow('Parent Programme', pj.parentName);
                        html+=detailRow('Description', pj.description);
                        html+='&lt;/dl&gt;';
                        showDetail(html);
                    }

                    function showDetail(html){
                        var dp=document.getElementById('detailPanel');
                        dp.innerHTML=html; dp.classList.add('active');
                        document.getElementById('dpOverlay').classList.add('active');
                    }
                    function closeDetail(){
                        document.getElementById('detailPanel').classList.remove('active');
                        document.getElementById('dpOverlay').classList.remove('active');
                    }

                    // ---- Tabs: render all portfolios ----
                    function renderPortfolioSection(name){
                        var list=PROGRAMMES.filter(function(p){ return (p.portfolio||'(no portfolio)')===name; });
                        var html=termHeader();
                        html+='&lt;div class="di-rows"&gt;'+classificationGroups(list)+'&lt;/div&gt;';
                        return html;
                    }

                    function showTab(name){
                        var secs=document.querySelectorAll('#portfolioSections .portfolio-section');
                        for(var i=0;i&lt;secs.length;i++) secs[i].style.display='none';
                        var navs=document.querySelectorAll('#portfolioNav a');
                        for(var j=0;j&lt;navs.length;j++) navs[j].classList.remove('active');
                        var sec=document.getElementById('pf-section-'+name);
                        if(sec) sec.style.display='block';
                        var nav=document.getElementById('pf-nav-'+name);
                        if(nav) nav.classList.add('active');
                    }

                    document.addEventListener('DOMContentLoaded', function(){
                        console.log('Programmes:', PROGRAMMES);
                        var portfolios=[];
                        PROGRAMMES.forEach(function(p){ var k=p.portfolio||'(no portfolio)'; if(portfolios.indexOf(k)===-1) portfolios.push(k); });
                        portfolios.sort();

                        var navHtml='', secHtml='';
                        portfolios.forEach(function(name, idx){
                            var sid=name.replace(/[^A-Za-z0-9]/g,'-');
                            navHtml+='&lt;a id="pf-nav-'+sid+'" class="pf-link'+(idx===0?' active':'')+'" onclick="showTab(\''+sid+'\')"&gt;'+esc(name)+'&lt;/a&gt;';
                            secHtml+='&lt;div class="portfolio-section" id="pf-section-'+sid+'" style="display:'+(idx===0?'block':'none')+';"&gt;'+renderPortfolioSection(name)+'&lt;/div&gt;';
                        });
                        document.getElementById('portfolioNav').innerHTML=navHtml;
                        document.getElementById('portfolioSections').innerHTML=secHtml;
                    });
                    // close detail on Escape
                    document.addEventListener('keydown', function(e){ if(e.key==='Escape') closeDetail(); });
                </script>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
