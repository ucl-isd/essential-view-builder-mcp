<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:xs="http://www.w3.org/2001/XMLSchema">
    <xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>
    <xsl:template match="/">
        <html><body style="font-family:monospace;font-size:12px;padding:20px;line-height:1.5;">
            <h2>Change Classification value store_916_Class219 - all slots</h2>
            <xsl:for-each select="//simple_instance[name='store_916_Class219']/own_slot_value">
                <div><b><xsl:value-of select="slot_reference"/></b> = <xsl:value-of select="string-join(value,' ; ')"/></div>
            </xsl:for-each>

            <h2>First 12 Change Classification performance measures: element -&gt; value name</h2>
            <xsl:for-each select="//simple_instance[type='Business_Performance_Measure'][own_slot_value[slot_reference='pm_category']/value='store_916_Class213'][position() &lt;= 12]">
                <xsl:variable name="valId" select="own_slot_value[slot_reference='pm_performance_value']/value"/>
                <xsl:variable name="v" select="//simple_instance[name=$valId]"/>
                <div style="border-bottom:1px solid #eee;padding:3px 0;">
                    elem=<xsl:value-of select="own_slot_value[slot_reference='pm_measured_element']/value"/>
                    | valId=<xsl:value-of select="$valId"/>
                    | name=&quot;<b><xsl:value-of select="$v/own_slot_value[slot_reference='name']/value"/></b>&quot;
                    | enumeration_value=&quot;<xsl:value-of select="$v/own_slot_value[slot_reference='enumeration_value']/value"/>&quot;
                    | short_name=&quot;<xsl:value-of select="$v/own_slot_value[slot_reference='short_name']/value"/>&quot;
                </div>
            </xsl:for-each>
        </body></html>
    </xsl:template>
</xsl:stylesheet>
