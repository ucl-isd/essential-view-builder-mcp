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
    <xsl:variable name="allA2R" select="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']"/>
    <xsl:variable name="allRoles" select="/node()/simple_instance[type=('Group_Business_Role','Individual_Business_Role')]"/>
    <xsl:variable name="uclRoot" select="$allGroupActors[own_slot_value[slot_reference='name']/value='UCL'][1]"/>

    <!-- Keys -->
    <xsl:key name="actorByName" match="/node()/simple_instance[type='Group_Actor']" use="name"/>
    <xsl:key name="a2rByName" match="/node()/simple_instance[type='ACTOR_TO_ROLE_RELATION']" use="name"/>
    <xsl:key name="roleByName" match="/node()/simple_instance[type=('Group_Business_Role','Individual_Business_Role')]" use="name"/>

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

    <!-- Recursively emit a Group_Actor as a JSON node with its sub-actors and role names.
         Guarded against cycles / runaway depth. -->
    <xsl:template name="renderActor">
        <xsl:param name="actor"/>
        <xsl:param name="depth"/>
        <xsl:param name="ancestors"/>
        <xsl:variable name="subActors" select="$allGroupActors[name = $actor/own_slot_value[slot_reference='contained_sub_actors']/value]"/>
        <!-- roles played by this actor: actor_plays_role -> relation -> role name -->
        <xsl:variable name="playRels" select="key('a2rByName', $actor/own_slot_value[slot_reference='actor_plays_role']/value)"/>
        <xsl:variable name="roleNames" select="distinct-values($allRoles[name = $playRels/own_slot_value/value]/own_slot_value[slot_reference='name']/value)"/>
        {
        "id":"<xsl:value-of select="eas:jsonText(string($actor/name))"/>",
        "name":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='name']/value))"/>",
        "code":"<xsl:value-of select="eas:jsonText(string($actor/own_slot_value[slot_reference='ea_reference']/value))"/>",
        "roles":[<xsl:for-each select="$roleNames">"<xsl:value-of select="eas:jsonText(string(.))"/>"<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>],
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
                <title>UCL Hierarchy Explorer</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px 28px;max-width:none;width:100%;margin:80px 0 0 0;box-sizing:border-box;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.05rem}
                    .search-row{margin-bottom:12px}
                    .search-row input{width:100%;max-width:460px;padding:11px 16px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1.05rem}
                    .search-row input:focus{outline:none;border-color:#993AFF;box-shadow:0 0 0 3px rgba(153,58,255,0.15)}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:16px;font-size:1.05rem}
                    .filters{display:flex;flex-wrap:wrap;gap:10px;margin-bottom:12px;align-items:center}
                    .filter-btn{background:#F5F0FF;border:1px solid #DDBDFF;color:#361A54;border-radius:20px;padding:9px 18px;cursor:pointer;font-family:'DM Sans',sans-serif;font-weight:600;font-size:1rem;transition:background 0.15s,color 0.15s}
                    .filter-btn:hover{background:#DDBDFF}
                    .filter-btn.active{background:#361A54;color:#fff;border-color:#361A54}
                    .filter-note{color:#6B7280;font-size:0.9rem;margin-left:4px}
                    .tree-actions{display:flex;gap:10px;margin-bottom:16px}
                    .tree-actions a{color:#7d1fe0;cursor:pointer;text-decoration:underline;font-weight:600;font-size:0.95rem}
                    /* ===== Top-down org chart (classic CSS connector pattern) ===== */
                    .tree-scroll{overflow-x:auto;padding:20px 10px 40px 10px}
                    .tree, .tree ul{list-style:none;margin:0;padding:0}
                    /* children laid out in a horizontal row below their parent */
                    .tree ul{display:flex;flex-direction:row;justify-content:center;padding-top:30px;position:relative}
                    .tree li{position:relative;padding:30px 14px 0 14px;display:flex;flex-direction:column;align-items:center}
                    /* each child draws two half-width arms at its top; the ::after also drops the vertical line up to the arm */
                    .tree li::before, .tree li::after{content:'';position:absolute;top:0;right:50%;width:50%;height:30px;border-top:2px solid #C9B8E6}
                    .tree li::after{right:auto;left:50%;border-left:2px solid #C9B8E6}
                    /* first child: no left arm; last child: no right arm (keeps the bar flush) */
                    .tree li:first-child::before{border:0}
                    .tree li:last-child::after{border-top:0}
                    /* single child: no horizontal arms, just a straight drop line */
                    .tree li:only-child::before{display:none}
                    .tree li:only-child::after{left:50%;border-top:0;border-left:2px solid #C9B8E6}
                    /* top-level root: no connectors above it */
                    .tree > li{padding-top:0}
                    .tree > li::before, .tree > li::after{display:none}
                    /* parent-to-children drop line: the children ul draws a short vertical stub up to the parent */
                    .tree li.has-children.open > ul::before{content:'';position:absolute;top:0;left:50%;height:30px;border-left:2px solid #C9B8E6}
                    .node-row{display:flex;flex-direction:column;align-items:center;position:relative;z-index:1}
                    .node-box{display:flex;align-items:center;gap:10px;background:#C9C3F0;border:1px solid #B4ABE6;border-radius:12px;padding:12px 18px;box-shadow:0 1px 4px rgba(54,26,84,0.12);min-width:150px;max-width:220px;transition:border-color 0.15s,box-shadow 0.15s,opacity 0.15s;text-align:center;position:relative}
                    .node-box .node-main{align-items:center}
                    .node-box.has-children{cursor:pointer}
                    .node-box.has-children:hover{border-color:#7d1fe0;box-shadow:0 4px 12px rgba(153,58,255,0.25)}
                    .node-caret{color:#5B2A87;font-size:0.8rem;flex-shrink:0;transition:transform 0.15s}
                    .node-caret.open{transform:rotate(90deg)}
                    .node-caret.leaf{display:none}
                    .node-main{display:flex;flex-direction:column;gap:3px}
                    .node-name{font-weight:700;color:#2A1540;font-size:1.02rem;line-height:1.25}
                    .node-code{font-size:0.8rem;color:#5B4B74;font-weight:600;letter-spacing:0.03em}
                    .node-code .no-code{color:#8E7FB0;font-style:italic;font-weight:400}
                    .node-roletag{display:inline-block;border-radius:12px;padding:2px 9px;font-size:0.72rem;font-weight:700;color:#fff;margin-top:4px}
                    .rt-academic{background:#2E75B6}
                    .rt-vp{background:#B26A00}
                    .rt-ps{background:#0E7C6B}
                    .node-count{position:absolute;top:-8px;right:-8px;background:#7d1fe0;color:#fff;font-size:0.72rem;font-weight:700;border-radius:50%;min-width:20px;height:20px;display:flex;align-items:center;justify-content:center;padding:0 4px;z-index:2}
                    .root-badge{background:linear-gradient(135deg,#361A54,#5B2A87);color:#fff;border-color:#361A54}
                    .root-badge .node-name{color:#fff}
                    .root-badge .node-code{color:rgba(255,255,255,0.85)}
                    /* filter dimming + match highlight (applied without re-rendering) */
                    .node-box.dim{opacity:0.35}
                    .node-box.match{border-color:#7d1fe0;border-width:2px;box-shadow:0 0 0 3px rgba(125,31,224,0.25)}
                    .hidden{display:none}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                </style>
                <script type="text/javascript">
                    var ROOT = <xsl:choose><xsl:when test="$uclRoot"><xsl:call-template name="renderActor"><xsl:with-param name="actor" select="$uclRoot"/><xsl:with-param name="depth" select="0"/><xsl:with-param name="ancestors" select="()"/></xsl:call-template></xsl:when><xsl:otherwise>null</xsl:otherwise></xsl:choose>;

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }

                    // Filter definitions: label -> exact role name
                    var FILTERS = [
                        {key:'UCL Academic School', label:'Academic Departments', cls:'rt-academic'},
                        {key:'VP Office', label:'VP Offices', cls:'rt-vp'},
                        {key:'Professional Services Division', label:'PS Divisions', cls:'rt-ps'}
                    ];
                    var activeFilters = []; // array of active role names (multi-select)
                    var searchTerm = '';    // lower-cased name search

                    function roleTagClass(role){
                        var f = FILTERS.find(function(x){ return x.key === role; });
                        return f ? f.cls : '';
                    }
                    function roleShort(role){
                        if (role === 'UCL Academic School') return 'Academic';
                        if (role === 'VP Office') return 'VP Office';
                        if (role === 'Professional Services Division') return 'PS Division';
                        return role;
                    }

                    function filtersActive(){ return activeFilters.length &gt; 0 || searchTerm !== ''; }

                    // Does this node itself satisfy the active criteria (role filter AND/OR search)?
                    function selfMatches(node){
                        var roleOk = activeFilters.length === 0 || (node.roles &amp;&amp; activeFilters.some(function(r){ return node.roles.indexOf(r) !== -1; }));
                        var searchOk = searchTerm === '' || (node.name &amp;&amp; node.name.toLowerCase().indexOf(searchTerm) !== -1) || (node.code &amp;&amp; node.code.toLowerCase().indexOf(searchTerm) !== -1);
                        // when both are set, require both; when only one set, require that one
                        if (activeFilters.length &gt; 0 &amp;&amp; searchTerm !== '') return roleOk &amp;&amp; searchOk;
                        if (activeFilters.length &gt; 0) return roleOk;
                        if (searchTerm !== '') return searchOk;
                        return false;
                    }

                    // Does the subtree rooted here contain a match (self or any descendant)?
                    function subtreeHasMatch(node){
                        if (selfMatches(node)) return true;
                        return (node.children||[]).some(subtreeHasMatch);
                    }

                    // Build the tree HTML. Behaviour:
                    //  - No filter/search: full tree, root expanded, rest collapsed-but-expandable.
                    //  - Filter/search active: render only matches, their ancestors (path), and the full
                    //    subtree beneath a match. Non-matching sibling branches are omitted entirely.
                    //    Ancestors auto-expand to reveal matches; a match's own children stay collapsed
                    //    (but expandable) so users can keep browsing underneath.
                    // Params: belowMatch = we are inside the subtree of an already-matched ancestor.
                    function buildNode(node, isRoot, belowMatch){
                        var active = filtersActive();
                        var kids = node.children || [];
                        var hasKids = kids.length &gt; 0;
                        var isMatch = active &amp;&amp; selfMatches(node);

                        // Decide whether to render this node at all when filtering
                        if (active &amp;&amp; !belowMatch){
                            // keep only if it is a match or an ancestor leading to one
                            if (!isMatch &amp;&amp; !subtreeHasMatch(node)) return '';
                        }

                        // Which children to render
                        var renderKids = kids;
                        var nowBelowMatch = belowMatch || isMatch;
                        if (active &amp;&amp; !nowBelowMatch){
                            // ancestor node: only keep children that lead to a match
                            renderKids = kids.filter(function(ch){ return selfMatches(ch) || subtreeHasMatch(ch); });
                        }
                        var hasRenderKids = renderKids.length &gt; 0;

                        // Expansion: root always open. When filtering, ancestors (path nodes that are not
                        // themselves a match) auto-open to reveal matches. Matches and below stay as the
                        // user left them -> default collapsed so they can choose to drill in.
                        var expanded;
                        if (!active){ expanded = isRoot; }
                        else if (nowBelowMatch){ expanded = false; } // match + its subtree: collapsed, user-expandable
                        else { expanded = true; }                    // ancestor path: open to show the match

                        var liCls = 'actor-li' + (hasRenderKids ? ' has-children' : '') + (expanded ? ' open' : '');
                        var boxCls = 'node-box' + (hasRenderKids ? ' has-children' : '') + (isRoot ? ' root-badge' : '') + (isMatch ? ' match' : '');
                        var caretCls = 'node-caret' + (hasRenderKids ? (expanded ? ' open' : '') : ' leaf');

                        var html = '&lt;li class="' + liCls + '" id="li-' + node.id + '"&gt;';
                        html += '&lt;div class="node-row"&gt;';
                        html += '&lt;div class="' + boxCls + '" id="box-' + node.id + '"' + (hasRenderKids ? ' onclick="toggleNode(\'' + node.id + '\')"' : '') + '&gt;';
                        html += '&lt;span class="' + caretCls + '" id="caret-' + node.id + '"&gt;&#9656;&lt;/span&gt;';
                        html += '&lt;div class="node-main"&gt;';
                        var roleTags = '';
                        (node.roles||[]).forEach(function(r){
                            var c = roleTagClass(r);
                            if (c) roleTags += '&lt;span class="node-roletag ' + c + '"&gt;' + esc(roleShort(r)) + '&lt;/span&gt;';
                        });
                        html += '&lt;span class="node-name"&gt;' + esc(node.name) + '&lt;/span&gt;';
                        html += '&lt;span class="node-code"&gt;' + (node.code ? ('Dept Code: ' + esc(node.code)) : '&lt;span class="no-code"&gt;No department code&lt;/span&gt;') + '&lt;/span&gt;';
                        if (roleTags) html += roleTags;
                        html += '&lt;/div&gt;';
                        if (hasRenderKids) html += '&lt;span class="node-count"&gt;' + renderKids.length + '&lt;/span&gt;';
                        html += '&lt;/div&gt;';
                        html += '&lt;/div&gt;';
                        if (hasRenderKids){
                            html += '&lt;ul id="kids-' + node.id + '"' + (expanded ? '' : ' class="hidden"') + '&gt;';
                            renderKids.forEach(function(ch){ html += buildNode(ch, false, nowBelowMatch); });
                            html += '&lt;/ul&gt;';
                        }
                        html += '&lt;/li&gt;';
                        return html;
                    }

                    function render(){
                        var container = document.getElementById('tree');
                        if (!ROOT){ container.innerHTML = '&lt;div class="no-data"&gt;No UCL root Group Actor found.&lt;/div&gt;'; return; }
                        var inner = buildNode(ROOT, true, false);
                        if (inner === ''){ container.innerHTML = '&lt;div class="no-data"&gt;No actors match the current filters/search.&lt;/div&gt;'; return; }
                        container.innerHTML = '&lt;ul class="tree"&gt;' + inner + '&lt;/ul&gt;';
                    }

                    // Toggle expand/collapse of one node
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

                    function setFilter(role, btn){
                        var i = activeFilters.indexOf(role);
                        if (i !== -1){ activeFilters.splice(i, 1); if (btn) btn.classList.remove('active'); }
                        else { activeFilters.push(role); if (btn) btn.classList.add('active'); }
                        render();
                    }

                    function onSearch(val){
                        searchTerm = (val || '').trim().toLowerCase();
                        render();
                    }

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
                        console.log('UCL hierarchy root:', ROOT);
                        // Build filter buttons
                        var fc = document.getElementById('filters');
                        var html = '';
                        FILTERS.forEach(function(f){
                            html += '&lt;button class="filter-btn" onclick="setFilter(\'' + f.key.replace(/'/g,&quot;\\'&quot;) + '\', this)"&gt;Show ' + esc(f.label) + '&lt;/button&gt;';
                        });
                        html += '&lt;span class="filter-note"&gt;Select one or more; click again to clear&lt;/span&gt;';
                        fc.innerHTML = html;
                        render();
                        var sb = document.getElementById('searchBox');
                        if (sb) sb.addEventListener('input', function(){ onSearch(this.value); });
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>UCL Hierarchy Explorer</h1>
                    <p class="subtitle">Browse the UCL organisational hierarchy from the top. Click an actor to expand its sub-departments. Each actor shows its name and department code (from ea_reference). Apply one or more role filters or search by name &#8212; only matching departments and the path to them are shown, and you can keep expanding underneath.</p>
                    <div class="search-row">
                        <input type="text" id="searchBox" placeholder="Search departments by name or code..."/>
                    </div>
                    <div class="filters" id="filters"></div>
                    <div class="tree-actions">
                        <a onclick="expandAll(true)">Expand all</a>
                        <a onclick="expandAll(false)">Collapse all</a>
                    </div>
                    <div class="tree-scroll"><div id="tree"><p>Loading hierarchy...</p></div></div>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
