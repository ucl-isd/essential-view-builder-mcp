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
    <xsl:variable name="allGroupActors" select="/node()/simple_instance[type='Group_Actor']"/>
    <xsl:variable name="allPM" select="/node()/simple_instance[supertype='Performance_Measure']"/>
    <xsl:variable name="allPMcat" select="/node()/simple_instance[type='Performance_Measure_Category']"/>
    <xsl:variable name="allSQV" select="/node()/simple_instance[supertype='Service_Quality_Value']"/>
    <xsl:variable name="allElementStyles" select="/node()/simple_instance[type='Element_Style']"/>
    <xsl:variable name="allExtLinks" select="/node()/simple_instance[type='External_Reference_Link']"/>
    <xsl:variable name="govRoot" select="$allGroupActors[own_slot_value[slot_reference='name']/value='UCL Governance'][1]"/>

    <!-- Keys -->
    <xsl:key name="actorByName" match="/node()/simple_instance[type='Group_Actor']" use="name"/>

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

    <!-- Extract the first #RRGGBB (or #RGB) hex colour value from an instance's slots -->
    <xsl:function name="eas:hexColour">
        <xsl:param name="inst"/>
        <xsl:variable name="hexVals" select="$inst/own_slot_value/value[matches(., '^#[0-9A-Fa-f]{3,8}$')]"/>
        <xsl:value-of select="string($hexVals[1])"/>
    </xsl:function>

    <!-- Recursively emit a Group_Actor as a JSON node: name, code, description,
         Group Status performance value (+ colour), related links, and sub-actors. -->
    <xsl:template name="renderActor">
        <xsl:param name="actor"/>
        <xsl:param name="depth"/>
        <xsl:param name="ancestors"/>
        <xsl:variable name="subActors" select="$allGroupActors[name = $actor/own_slot_value[slot_reference='contained_sub_actors']/value]"/>
        <!-- Performance measures on this actor, filtered to the 'Group Status' category -->
        <xsl:variable name="pms" select="$allPM[name = $actor/own_slot_value[slot_reference='performance_measures']/value]"/>
        <xsl:variable name="statusPMs" select="$pms[own_slot_value[slot_reference='pm_category']/value = $allPMcat[own_slot_value[slot_reference='name']/value='Group Status']/name]"/>
        <!-- Most recent group-status PM (sort by its date-ish name/assessment date is hard; take last) -->
        <xsl:variable name="statusPM" select="$statusPMs[last()]"/>
        <xsl:variable name="statusVal" select="$allSQV[name = $statusPM/own_slot_value[slot_reference='pm_performance_value']/value]"/>
        <!-- Element_Style whose first slot references the value id -> holds the hex colour -->
        <xsl:variable name="statusStyle" select="$allElementStyles[own_slot_value/value = $statusVal/name]"/>
        <xsl:variable name="statusColour" select="eas:hexColour($statusStyle[1])"/>
        <!-- Related links: External_Reference_Link instances that reference this actor -->
        <xsl:variable name="links" select="$allExtLinks[own_slot_value/value = $actor/name]"/>
        {
        "id":"<xsl:value-of select="eas:jsonText(string($actor/name))"/>",
        "name":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='name']/value))"/>",
        "code":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='ea_reference']/value))"/>",
        "description":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='description']/value))"/>",
        "status":"<xsl:value-of select="eas:jsonText(string($statusVal[1]/own_slot_value[slot_reference='short_name']/value))"/>",
        "statusLong":"<xsl:value-of select="eas:jsonText(string($statusVal[1]/own_slot_value[slot_reference='name']/value))"/>",
        "statusColour":"<xsl:value-of select="eas:jsonText(string($statusColour))"/>",
        "links":[<xsl:for-each select="$links">
            <xsl:variable name="url" select="current()/own_slot_value/value[matches(., '^https?://')][1]"/>
            {"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","url":"<xsl:value-of select="eas:jsonText(string($url))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
        "children":[<xsl:if test="$depth &lt; 12"><xsl:for-each select="$subActors">
            <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
            <xsl:if test="not(current()/name = $ancestors)">
                <xsl:call-template name="renderActor">
                    <xsl:with-param name="actor" select="current()"/>
                    <xsl:with-param name="depth" select="$depth + 1"/>
                    <xsl:with-param name="ancestors" select="($ancestors, $actor/name)"/>
                </xsl:call-template>
                <xsl:if test="not(position()=last())">,</xsl:if>
            </xsl:if>
        </xsl:for-each></xsl:if>]
        }
    </xsl:template>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>UCL Governance Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px 28px;max-width:none;width:100%;margin:80px 0 0 0;box-sizing:border-box;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.05rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.05rem}
                    .search-row{margin-bottom:12px}
                    .search-row input{width:100%;max-width:460px;padding:11px 16px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem}
                    .search-row input:focus{outline:none;border-color:#993AFF;box-shadow:0 0 0 3px rgba(153,58,255,0.15)}
                    .tree-actions{display:flex;gap:10px;margin-bottom:16px}
                    .tree-actions a{color:#7d1fe0;cursor:pointer;text-decoration:underline;font-weight:600;font-size:0.95rem}
                    /* ===== Top-down org chart ===== */
                    .tree-scroll{overflow-x:auto;padding:20px 10px 40px 10px}
                    .tree, .tree ul{list-style:none;margin:0;padding:0}
                    /* Size the tree to its content and centre with auto margins so the scroll container
                       can reach all of it (no unreachable left overflow from justify-content:center). */
                    .tree{width:max-content;margin:0 auto}
                    .tree ul{display:flex;flex-direction:row;justify-content:center;padding-top:30px;position:relative}
                    .tree li{position:relative;padding:30px 14px 0 14px;display:flex;flex-direction:column;align-items:center}
                    .tree li::before, .tree li::after{content:'';position:absolute;top:0;right:50%;width:50%;height:30px;border-top:2px solid #C9B8E6}
                    .tree li::after{right:auto;left:50%;border-left:2px solid #C9B8E6}
                    .tree li:first-child::before{border:0}
                    .tree li:last-child::after{border-top:0}
                    .tree li:only-child::before{display:none}
                    .tree li:only-child::after{left:50%;border-top:0;border-left:2px solid #C9B8E6}
                    .tree > li{padding-top:0}
                    .tree > li::before, .tree > li::after{display:none}
                    .tree li.has-children.open > ul::before{content:'';position:absolute;top:0;left:50%;height:30px;border-left:2px solid #C9B8E6}
                    .node-row{display:flex;flex-direction:column;align-items:center;position:relative;z-index:1}
                    .node-box{display:flex;flex-direction:column;gap:8px;background:#fff;border:1px solid #CBB8EC;border-radius:12px;padding:14px 18px;box-shadow:0 1px 4px rgba(54,26,84,0.12);min-width:230px;max-width:320px;transition:border-color 0.15s,box-shadow 0.15s;position:relative}
                    .node-box.has-children{cursor:pointer}
                    .node-box.has-children:hover{border-color:#7d1fe0;box-shadow:0 4px 12px rgba(153,58,255,0.25)}
                    .node-head{display:flex;align-items:flex-start;gap:10px}
                    .node-caret{color:#5B2A87;font-size:0.8rem;flex-shrink:0;margin-top:4px;transition:transform 0.15s}
                    .node-caret.open{transform:rotate(90deg)}
                    .node-caret.leaf{display:none}
                    .node-main{display:flex;flex-direction:column;gap:3px;flex:1}
                    .node-name{font-weight:700;color:#2A1540;font-size:1.05rem;line-height:1.25}
                    .node-code{font-size:0.8rem;color:#5B4B74;font-weight:600;letter-spacing:0.03em}
                    .node-code .no-code{color:#8E7FB0;font-style:italic;font-weight:400}
                    .status-pill{align-self:flex-start;display:inline-block;border-radius:12px;padding:3px 12px;font-size:0.82rem;font-weight:700;color:#fff;background:#9CA3AF}
                    .node-desc{font-size:0.88rem;color:#4B5563;line-height:1.45;text-align:left;border-top:1px solid #F0EAFB;padding-top:8px}
                    .node-links{display:flex;flex-direction:column;gap:4px;border-top:1px solid #F0EAFB;padding-top:8px}
                    .node-links a{color:#7d1fe0;text-decoration:none;font-size:0.85rem;font-weight:600;display:inline-flex;align-items:center;gap:6px}
                    .node-links a:hover{text-decoration:underline}
                    .node-count{position:absolute;top:-8px;right:-8px;background:#7d1fe0;color:#fff;font-size:0.72rem;font-weight:700;border-radius:50%;min-width:20px;height:20px;display:flex;align-items:center;justify-content:center;padding:0 4px;z-index:2}
                    .root-badge{background:linear-gradient(135deg,#361A54,#5B2A87);color:#fff;border-color:#361A54}
                    .root-badge .node-name{color:#fff}
                    .root-badge .node-code{color:rgba(255,255,255,0.85)}
                    .root-badge .node-desc{color:rgba(255,255,255,0.9);border-top-color:rgba(255,255,255,0.25)}
                    .root-badge .node-links{border-top-color:rgba(255,255,255,0.25)}
                    .root-badge .node-links a{color:#E9D8FF}
                    .node-box.match{border-color:#7d1fe0;border-width:2px;box-shadow:0 0 0 3px rgba(125,31,224,0.25)}
                    .hidden{display:none}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                </style>
                <script type="text/javascript">
                    var ROOT = <xsl:choose><xsl:when test="$govRoot"><xsl:call-template name="renderActor"><xsl:with-param name="actor" select="$govRoot"/><xsl:with-param name="depth" select="0"/><xsl:with-param name="ancestors" select="()"/></xsl:call-template></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>;

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }
                    function escAttr(s){ return esc(s).replace(/"/g,'&amp;quot;'); }

                    var searchTerm = '';
                    function selfMatches(node){
                        if (searchTerm === '') return false;
                        return (node.name &amp;&amp; node.name.toLowerCase().indexOf(searchTerm) !== -1)
                            || (node.code &amp;&amp; node.code.toLowerCase().indexOf(searchTerm) !== -1);
                    }
                    function subtreeHasMatch(node){
                        if (selfMatches(node)) return true;
                        return (node.children||[]).some(subtreeHasMatch);
                    }

                    function buildNode(node, isRoot, belowMatch){
                        var active = searchTerm !== '';
                        var kids = node.children || [];
                        var isMatch = active &amp;&amp; selfMatches(node);
                        if (active &amp;&amp; !belowMatch &amp;&amp; !isMatch &amp;&amp; !subtreeHasMatch(node)) return '';

                        var renderKids = kids;
                        var nowBelow = belowMatch || isMatch;
                        if (active &amp;&amp; !nowBelow){
                            renderKids = kids.filter(function(ch){ return selfMatches(ch) || subtreeHasMatch(ch); });
                        }
                        var hasKids = renderKids.length &gt; 0;
                        var expanded;
                        if (!active){ expanded = isRoot; }
                        else if (nowBelow){ expanded = false; }
                        else { expanded = true; }

                        var liCls = 'actor-li' + (hasKids ? ' has-children' : '') + (expanded ? ' open' : '');
                        var boxCls = 'node-box' + (hasKids ? ' has-children' : '') + (isRoot ? ' root-badge' : '') + (isMatch ? ' match' : '');
                        var caretCls = 'node-caret' + (hasKids ? (expanded ? ' open' : '') : ' leaf');

                        var html = '&lt;li class="' + liCls + '" id="li-' + node.id + '"&gt;';
                        html += '&lt;div class="node-row"&gt;';
                        html += '&lt;div class="' + boxCls + '" id="box-' + node.id + '"' + (hasKids ? ' onclick="toggleNode(\'' + node.id + '\')"' : '') + '&gt;';
                        html += '&lt;div class="node-head"&gt;';
                        html += '&lt;span class="' + caretCls + '" id="caret-' + node.id + '"&gt;&#9656;&lt;/span&gt;';
                        html += '&lt;div class="node-main"&gt;';
                        html += '&lt;span class="node-name"&gt;' + esc(node.name) + '&lt;/span&gt;';
                        html += '&lt;span class="node-code"&gt;' + (node.code ? ('Dept Code: ' + esc(node.code)) : '&lt;span class="no-code"&gt;No department code&lt;/span&gt;') + '&lt;/span&gt;';
                        if (node.statusLong || node.status){
                            var col = node.statusColour || '#9CA3AF';
                            // Prefer the short_name; otherwise take the text after the last ' - ' in the full name
                            var pillText = node.status;
                            if (!pillText &amp;&amp; node.statusLong){
                                var parts = node.statusLong.split(' - ');
                                pillText = parts.length &gt; 1 ? parts[parts.length - 1].trim() : node.statusLong;
                            }
                            html += '&lt;span class="status-pill" style="background:' + esc(col) + ';" title="' + escAttr(node.statusLong || '') + '"&gt;' + esc(pillText) + '&lt;/span&gt;';
                        }
                        html += '&lt;/div&gt;';
                        if (hasKids) html += '&lt;span class="node-count"&gt;' + renderKids.length + '&lt;/span&gt;';
                        html += '&lt;/div&gt;'; // node-head
                        if (node.description) html += '&lt;div class="node-desc"&gt;' + esc(node.description) + '&lt;/div&gt;';
                        if (node.links &amp;&amp; node.links.length){
                            html += '&lt;div class="node-links"&gt;';
                            node.links.forEach(function(l){
                                if (!l.url) return;
                                html += '&lt;a href="' + escAttr(l.url) + '" target="_blank" onclick="event.stopPropagation();"&gt;&#128279; ' + esc(l.name || l.url) + '&lt;/a&gt;';
                            });
                            html += '&lt;/div&gt;';
                        }
                        html += '&lt;/div&gt;'; // node-box
                        html += '&lt;/div&gt;'; // node-row
                        if (hasKids){
                            html += '&lt;ul id="kids-' + node.id + '"' + (expanded ? '' : ' class="hidden"') + '&gt;';
                            renderKids.forEach(function(ch){ html += buildNode(ch, false, nowBelow); });
                            html += '&lt;/ul&gt;';
                        }
                        html += '&lt;/li&gt;';
                        return html;
                    }

                    function render(){
                        var container = document.getElementById('tree');
                        if (!ROOT){ container.innerHTML = '&lt;div class="no-data"&gt;No "UCL Governance" Group Actor found.&lt;/div&gt;'; return; }
                        var inner = buildNode(ROOT, true, false);
                        if (inner === ''){ container.innerHTML = '&lt;div class="no-data"&gt;No actors match the search.&lt;/div&gt;'; return; }
                        container.innerHTML = '&lt;ul class="tree"&gt;' + inner + '&lt;/ul&gt;';
                    }

                    function toggleNode(id){
                        var kids = document.getElementById('kids-' + id);
                        var caret = document.getElementById('caret-' + id);
                        var li = document.getElementById('li-' + id);
                        if (!kids) return;
                        var isHidden = kids.classList.contains('hidden');
                        kids.classList.toggle('hidden', !isHidden);
                        if (caret) caret.classList.toggle('open', isHidden);
                        if (li) li.classList.toggle('open', isHidden);
                    }

                    function onSearch(val){ searchTerm = (val || '').trim().toLowerCase(); render(); }

                    function expandAll(show){
                        document.querySelectorAll('#tree li.has-children').forEach(function(li){
                            var id = li.id.replace('li-','');
                            var kids = document.getElementById('kids-' + id);
                            var caret = document.getElementById('caret-' + id);
                            if (kids) kids.classList.toggle('hidden', !show);
                            if (caret) caret.classList.toggle('open', show);
                            li.classList.toggle('open', show);
                        });
                    }

                    $(document).ready(function(){
                        console.log('UCL Governance root:', ROOT);
                        render();
                        var sb = document.getElementById('searchBox');
                        if (sb) sb.addEventListener('input', function(){ onSearch(this.value); });
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Governance Explorer</h1>
                    <p class="subtitle">The UCL Governance hierarchy. Click a group to expand its sub-groups. Each card shows the description, the Group Status (as a colour pill) and any related links.</p>
                    <div class="search-row">
                        <input type="text" id="searchBox" placeholder="Search groups by name or code..."/>
                    </div>
                    <div class="tree-actions">
                        <a onclick="expandAll(true)">Expand all</a>
                        <a onclick="expandAll(false)">Collapse all</a>
                    </div>
                    <div class="tree-scroll"><div id="tree"><p>Loading governance hierarchy...</p></div></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
