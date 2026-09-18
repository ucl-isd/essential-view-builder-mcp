<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>
    <xsl:include href="../common/core_footer.xsl"/>
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:param name="param1"/>
    <xsl:param name="viewScopeTermIds"/>

    <xsl:variable name="allRisks" select="/node()/simple_instance[type='Risk']"/>
    <!-- Any class whose type contains 'ssessment' to catch Risk_Assessment however it is named -->
    <xsl:variable name="assessmentInstances" select="/node()/simple_instance[contains(type,'ssessment')]"/>

    <!-- Specific IDs from SR06 to resolve -->
    <xsl:variable name="probeIds" select="('store_184_Class140001','store_184_Class140002','store_184_Class140003','store_184_Class140004','store_184_Class140010')"/>
    <!-- Also dump all Actor_To_Role_Relationship and actor-ish instances so we can see the real chain -->
    <xsl:variable name="a2rInstances" select="/node()/simple_instance[type='Actor_To_Role_Relationship']"/>
    <xsl:variable name="probeInstances" select="/node()/simple_instance[name=$probeIds]"/>

    <xsl:template match="knowledge_base">
        <xsl:call-template name="docType"/>
        <html>
            <head>
                <xsl:call-template name="commonHeadContent"/>
                <title>Risk Slot Diagnostic</title>
                <style>
                    body{font-family:monospace;padding:20px;font-size:13px}
                    h2{background:#361A54;color:#fff;padding:8px;margin-top:30px}
                    h3{color:#993AFF;border-bottom:1px solid #ccc;margin-top:20px}
                    table{border-collapse:collapse;width:100%;margin-bottom:15px}
                    td,th{border:1px solid #ddd;padding:4px 8px;text-align:left;vertical-align:top}
                    th{background:#F5F0FF}
                    .slotref{font-weight:bold;color:#361A54;white-space:nowrap}
                    .val{color:#333}
                    .count{color:#6B7280}
                </style>
            </head>
            <body>
                <h1>Risk Slot Diagnostic</h1>
                <p>Total Risk instances: <xsl:value-of select="count($allRisks)"/></p>
                <p>Total *Assessment instances: <xsl:value-of select="count($assessmentInstances)"/></p>

                <h2>RISK INSTANCES (first 4)</h2>
                <xsl:for-each select="$allRisks[position() &lt;= 4]">
                    <h3>Risk: <xsl:value-of select="own_slot_value[slot_reference='name']/value"/> (instance name: <xsl:value-of select="name"/>)</h3>
                    <table>
                        <tr><th>slot_reference</th><th>value(s)</th></tr>
                        <xsl:for-each select="own_slot_value">
                            <tr>
                                <td class="slotref"><xsl:value-of select="slot_reference"/></td>
                                <td class="val">
                                    <xsl:for-each select="value">
                                        <xsl:value-of select="."/>
                                        <xsl:if test="not(position()=last())"> | </xsl:if>
                                    </xsl:for-each>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </table>
                </xsl:for-each>

                <h2>*ASSESSMENT INSTANCES (first 4)</h2>
                <xsl:for-each select="$assessmentInstances[position() &lt;= 4]">
                    <h3>Type: <xsl:value-of select="type"/> | name: <xsl:value-of select="name"/></h3>
                    <table>
                        <tr><th>slot_reference</th><th>value(s)</th></tr>
                        <xsl:for-each select="own_slot_value">
                            <tr>
                                <td class="slotref"><xsl:value-of select="slot_reference"/></td>
                                <td class="val">
                                    <xsl:for-each select="value">
                                        <xsl:value-of select="."/>
                                        <xsl:if test="not(position()=last())"> | </xsl:if>
                                    </xsl:for-each>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </table>
                </xsl:for-each>

                <h2>PROBE: resolving specific IDs from SR06 (impact enum, stakeholders, related_support, leading_to)</h2>
                <xsl:for-each select="$probeInstances">
                    <h3>ID: <xsl:value-of select="name"/> | Type: <xsl:value-of select="type"/></h3>
                    <table>
                        <tr><th>slot_reference</th><th>value(s)</th></tr>
                        <xsl:for-each select="own_slot_value">
                            <tr>
                                <td class="slotref"><xsl:value-of select="slot_reference"/></td>
                                <td class="val">
                                    <xsl:for-each select="value">
                                        <xsl:value-of select="."/>
                                        <xsl:if test="not(position()=last())"> | </xsl:if>
                                    </xsl:for-each>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </table>
                </xsl:for-each>

                <h2>ALL Actor_To_Role_Relationship instances (first 6)</h2>
                <xsl:for-each select="$a2rInstances[position() &lt;= 6]">
                    <h3>name: <xsl:value-of select="name"/></h3>
                    <table>
                        <tr><th>slot_reference</th><th>value(s)</th></tr>
                        <xsl:for-each select="own_slot_value">
                            <tr>
                                <td class="slotref"><xsl:value-of select="slot_reference"/></td>
                                <td class="val"><xsl:for-each select="value"><xsl:value-of select="."/><xsl:if test="not(position()=last())"> | </xsl:if></xsl:for-each></td>
                            </tr>
                        </xsl:for-each>
                    </table>
                </xsl:for-each>

                <h2>DISTINCT TYPES containing 'isk' or 'ssessment' or 'ontrol'</h2>
                <table>
                    <tr><th>type</th><th>count</th></tr>
                    <xsl:for-each-group select="/node()/simple_instance[contains(type,'isk') or contains(type,'ssessment') or contains(type,'ontrol')]" group-by="type">
                        <xsl:sort select="current-grouping-key()"/>
                        <tr><td class="slotref"><xsl:value-of select="current-grouping-key()"/></td><td class="count"><xsl:value-of select="count(current-group())"/></td></tr>
                    </xsl:for-each-group>
                </table>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
