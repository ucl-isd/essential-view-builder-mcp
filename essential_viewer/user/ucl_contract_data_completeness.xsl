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
    <xsl:variable name="allContracts" select="/node()/simple_instance[type='Contract']"/>
    <xsl:variable name="allSuppliers" select="/node()/simple_instance[type='Supplier']"/>
    <!-- CONTRACT_COMPONENT_RELATION links a contract (from) to an element (to) -->
    <xsl:variable name="allCCR" select="/node()/simple_instance[type='CONTRACT_COMPONENT_RELATION']"/>

    <!-- Keys -->
    <xsl:key name="instByName" match="/node()/simple_instance" use="name"/>
    <!-- CCR rows keyed by the contract they belong to -->
    <xsl:key name="ccrByContract" match="/node()/simple_instance[type='CONTRACT_COMPONENT_RELATION']" use="own_slot_value[slot_reference='contract_component_from_contract']/value"/>

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

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>Contract - Data Completeness</title>
                <style>
                    @import url('https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,100..1000;1,9..40,100..1000&amp;display=swap');
                    .view-wrapper{padding:20px;max-width:1600px;margin:80px auto 0 auto;font-family:'DM Sans',sans-serif;color:#111827;font-size:1.05rem}
                    .view-wrapper h1{color:#361A54;margin-bottom:4px}
                    .subtitle{color:#6B7280;margin-bottom:20px;font-size:1.05rem}
                    /* Summary */
                    .summary{display:flex;gap:16px;flex-wrap:wrap;margin-bottom:22px}
                    .stat{background:#fff;border:1px solid #E5E7EB;border-radius:12px;padding:16px 24px;min-width:160px}
                    .stat .big{font-size:2.4rem;font-weight:800;line-height:1;color:#361A54}
                    .stat .lbl{font-size:0.9rem;color:#6B7280;margin-top:6px}
                    .stat.total .big{color:#361A54}
                    .stat.linked .big{color:#1AAB40}
                    .stat.missing .big{color:#DC2626}
                    .stat.missing{border-color:#F3C8C4;background:#FEF4F3}
                    /* Controls */
                    .controls{display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-bottom:14px}
                    .controls input[type=text]{padding:9px 13px;border:1px solid #DDBDFF;border-radius:8px;font-family:'DM Sans',sans-serif;font-size:1rem;min-width:280px}
                    .controls label{font-weight:600;color:#361A54}
                    /* Table */
                    .tbl-wrap{overflow:auto;max-height:70vh;border:1px solid #E5E7EB;border-radius:10px}
                    table.ct{border-collapse:separate;border-spacing:0;width:100%;font-size:0.98rem}
                    table.ct th{background:#361A54;color:#fff;padding:11px 12px;text-align:left;font-weight:600;position:sticky;top:0;z-index:3;box-shadow:0 2px 0 rgba(0,0,0,0.15)}
                    table.ct td{padding:10px 12px;border-bottom:1px solid #EEE;vertical-align:top}
                    table.ct th.name-col{position:sticky;left:0;z-index:4}
                    table.ct td.name-col{position:sticky;left:0;background:#fff;z-index:1;font-weight:600;color:#361A54;min-width:260px}
                    table.ct tr:hover td{background:#FBF9FF}
                    table.ct tr:hover td.name-col{background:#FBF9FF}
                    tr.missing td{background:#FEF4F3}
                    tr.missing:hover td{background:#FDEBE9}
                    tr.missing td.name-col{background:#FEF4F3}
                    tr.missing:hover td.name-col{background:#FDEBE9}
                    .empty{color:#9CA3AF;font-style:italic}
                    .elem-pill{display:inline-block;background:#E7F8EF;color:#0B7A47;border:1px solid #B7E9CD;border-radius:14px;padding:2px 10px;margin:0 5px 4px 0;font-size:0.9rem;font-weight:600}
                    .elem-type{color:#6B7280;font-weight:400;font-size:0.82rem}
                    .missing-badge{display:inline-block;background:#DC2626;color:#fff;border-radius:12px;padding:2px 10px;font-size:0.85rem;font-weight:700}
                    .scope-type{display:block;color:#6B7280;font-size:0.82rem}
                    .no-data{text-align:center;padding:40px;color:#6B7280}
                    .legend{margin-top:10px;font-size:0.85rem;color:#6B7280}
                </style>
                <script type="text/javascript">
                    var CONTRACTS = [<xsl:for-each select="$allContracts">
                        <xsl:sort select="own_slot_value[slot_reference='name']/value"/>
                        <xsl:variable name="c" select="current()"/>
                        <!-- Supplier (direct slot) -->
                        <xsl:variable name="supplier" select="$allSuppliers[name = $c/own_slot_value[slot_reference='contract_supplier']/value]"/>
                        <!-- EA scope (direct slot) -> named instance -->
                        <xsl:variable name="scope" select="/node()/simple_instance[name = $c/own_slot_value[slot_reference='ea_scope']/value]"/>
                        <!-- Linked elements via CONTRACT_COMPONENT_RELATION -->
                        <xsl:variable name="ccrs" select="key('ccrByContract', $c/name)"/>
                        <xsl:variable name="elems" select="/node()/simple_instance[name = $ccrs/own_slot_value[slot_reference='contract_component_to_element']/value]"/>
                        {
                        "id":"<xsl:value-of select="eas:jsonText(string($c/name))"/>",
                        "name":"<xsl:value-of select="eas:jsonText(string($c/own_slot_value[slot_reference='name']/value))"/>",
                        "scope":"<xsl:value-of select="eas:jsonText(string($scope[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "scopeType":"<xsl:value-of select="eas:jsonText(string(replace(string($scope[1]/type),'_',' ')))"/>",
                        "supplier":"<xsl:value-of select="eas:jsonText(string($supplier[1]/own_slot_value[slot_reference='name']/value))"/>",
                        "elements":[<xsl:for-each select="$elems">{"name":"<xsl:value-of select="eas:jsonText(string(current()/own_slot_value[slot_reference='name']/value))"/>","type":"<xsl:value-of select="eas:jsonText(string(replace(string(current()/type),'_',' ')))"/>"}<xsl:if test="not(position()=last())">,</xsl:if></xsl:for-each>]
                        }<xsl:if test="not(position()=last())">,</xsl:if>
                    </xsl:for-each>];

                    function esc(s){ if(s===null||s===undefined) return ''; return String(s).replace(/&amp;/g,'&amp;amp;').replace(/&lt;/g,'&amp;lt;').replace(/&gt;/g,'&amp;gt;'); }
                    function hasElement(c){ return c.elements &amp;&amp; c.elements.length &gt; 0; }

                    function renderSummary(){
                        var total = CONTRACTS.length;
                        var missing = CONTRACTS.filter(function(c){ return !hasElement(c); }).length;
                        var linked = total - missing;
                        document.getElementById('statTotal').textContent = total;
                        document.getElementById('statLinked').textContent = linked;
                        document.getElementById('statMissing').textContent = missing;
                        var pct = total ? Math.round(missing / total * 100) : 0;
                        document.getElementById('statMissingPct').textContent = pct + '% of contracts';
                    }

                    function renderTable(){
                        var filterText = (document.getElementById('search').value || '').toLowerCase();
                        var onlyMissing = document.getElementById('missingOnly').checked;
                        var rows = CONTRACTS.filter(function(c){
                            if (filterText){
                                var hay = (c.name + ' ' + c.supplier + ' ' + c.scope).toLowerCase();
                                if (hay.indexOf(filterText) === -1) return false;
                            }
                            if (onlyMissing &amp;&amp; hasElement(c)) return false;
                            return true;
                        });
                        var container = document.getElementById('tableWrap');
                        if (!rows.length){ container.innerHTML = '&lt;div class="no-data"&gt;No contracts match.&lt;/div&gt;'; return; }
                        var html = '&lt;table class="ct"&gt;&lt;thead&gt;&lt;tr&gt;';
                        html += '&lt;th class="name-col"&gt;Contract&lt;/th&gt;&lt;th&gt;EA Scope&lt;/th&gt;&lt;th&gt;Contract Supplier&lt;/th&gt;&lt;th&gt;Linked Element (contract_component_to_element)&lt;/th&gt;&lt;/tr&gt;&lt;/thead&gt;&lt;tbody&gt;';
                        rows.forEach(function(c){
                            var missing = !hasElement(c);
                            html += '&lt;tr' + (missing ? ' class="missing"' : '') + '&gt;';
                            html += '&lt;td class="name-col"&gt;' + esc(c.name) + '&lt;/td&gt;';
                            // EA scope
                            if (c.scope) html += '&lt;td&gt;' + esc(c.scope) + '&lt;span class="scope-type"&gt;' + esc(c.scopeType) + '&lt;/span&gt;&lt;/td&gt;';
                            else html += '&lt;td&gt;&lt;span class="empty"&gt;Not set&lt;/span&gt;&lt;/td&gt;';
                            // Supplier
                            html += '&lt;td&gt;' + (c.supplier ? esc(c.supplier) : '&lt;span class="empty"&gt;Not set&lt;/span&gt;') + '&lt;/td&gt;';
                            // Linked elements
                            if (missing){
                                html += '&lt;td&gt;&lt;span class="missing-badge"&gt;No linked element&lt;/span&gt;&lt;/td&gt;';
                            } else {
                                html += '&lt;td&gt;';
                                c.elements.forEach(function(e){ html += '&lt;span class="elem-pill"&gt;' + esc(e.name) + ' &lt;span class="elem-type"&gt;' + esc(e.type) + '&lt;/span&gt;&lt;/span&gt;'; });
                                html += '&lt;/td&gt;';
                            }
                            html += '&lt;/tr&gt;';
                        });
                        html += '&lt;/tbody&gt;&lt;/table&gt;';
                        container.innerHTML = html;
                        document.getElementById('shownCount').textContent = rows.length;
                    }

                    $(document).ready(function(){
                        console.log('Contracts:', CONTRACTS);
                        renderSummary();
                        renderTable();
                        document.getElementById('search').addEventListener('input', renderTable);
                        document.getElementById('missingOnly').addEventListener('change', renderTable);
                    });
                </script>
            </head>
            <body>
                <xsl:call-template name="Heading"/>
                <div class="view-wrapper">
                    <h1>Contract &#8212; Data Completeness</h1>
                    <p class="subtitle">EA Scope, Contract Supplier and the linked element (via contract_component_to_element) for every Contract. Rows with no linked element are highlighted.</p>
                    <div class="summary">
                        <div class="stat total"><span class="big" id="statTotal">0</span><span class="lbl">Contracts</span></div>
                        <div class="stat linked"><span class="big" id="statLinked">0</span><span class="lbl">With a linked element</span></div>
                        <div class="stat missing"><span class="big" id="statMissing">0</span><span class="lbl">No linked element</span><span class="lbl" id="statMissingPct"></span></div>
                    </div>
                    <div class="controls">
                        <input type="text" id="search" placeholder="Search by contract, supplier or scope..."/>
                        <label><input type="checkbox" id="missingOnly"/> Missing linked element only</label>
                        <span style="color:#6B7280;">Showing <strong id="shownCount">0</strong></span>
                    </div>
                    <div class="tbl-wrap" id="tableWrap"><p>Loading...</p></div>
                    <p class="legend">Highlighted rows have no <strong>contract_component_to_element</strong> entry (no CONTRACT_COMPONENT_RELATION linking the contract to an architecture element).</p>
                </div>
                <xsl:call-template name="Footer"/>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
