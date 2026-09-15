<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:eas="http://www.enterprise-architecture.org/essential">
	<xsl:include href="../common/core_doctype.xsl"></xsl:include>
	<xsl:include href="../common/core_common_head_content.xsl"></xsl:include>
	<xsl:include href="../common/core_header.xsl"></xsl:include>
	<xsl:include href="../common/core_footer.xsl"></xsl:include>
	<xsl:include href="../common/core_external_doc_ref.xsl"></xsl:include>
	<xsl:output method="html" omit-xml-declaration="yes" indent="yes"></xsl:output>

	<xsl:template match="knowledge_base">
		<xsl:call-template name="docType"></xsl:call-template>
		<html>
			<head>
				<xsl:call-template name="commonHeadContent"></xsl:call-template>
				<xsl:call-template name="RenderInstanceLinkJavascript">
					<xsl:with-param name="instanceClassName" select="'Enterprise_Strategic_Plan'"></xsl:with-param>
					<xsl:with-param name="targetMenu" select="()"></xsl:with-param>
				</xsl:call-template>
				<xsl:call-template name="RenderInstanceLinkJavascript">
					<xsl:with-param name="instanceClassName" select="'Roadmap'"></xsl:with-param>
					<xsl:with-param name="targetMenu" select="()"></xsl:with-param>
				</xsl:call-template>
				<title>UCL Strategic Plan Descriptions CLI</title>
				<style>
					.view-wrapper{padding:20px;margin-top:70px}
					.roadmap-section{margin-bottom:40px}
					.section-title{font-size:18px;font-weight:bold;color:#333;margin:30px 0 15px 0;padding-bottom:8px;border-bottom:2px solid #500778}
					table{width:100%;border-collapse:collapse;margin-bottom:20px}
					th,td{border:1px solid #ddd;padding:12px;text-align:left;vertical-align:top}
					th{background-color:#500778;color:white;font-weight:bold}
					td:first-child{width:30%;font-weight:bold;color:#333}
					td:not(:first-child){color:#555}
					tr:nth-child(even){background-color:#f9f9f9}
					tr:hover{background-color:#f1f1f1}
				</style>
			</head>
			<body>
				<xsl:call-template name="Heading"></xsl:call-template>
				<div class="view-wrapper container-fluid">
					<div class="row">
						<div class="col-xs-12">
							<div class="page-header">
								<h1><span class="text-primary">UCL: </span><span class="text-darkgrey">Strategic Plan Descriptions CLI</span></h1>
							</div>
						</div>
					</div>

					<xsl:variable name="allRoadmaps" select="/node()/simple_instance[type = 'Roadmap']"></xsl:variable>
					<xsl:variable name="allESPs" select="/node()/simple_instance[type = 'Enterprise_Strategic_Plan']"></xsl:variable>

					<xsl:for-each select="$allRoadmaps">
						<xsl:sort select="own_slot_value[slot_reference = 'name']/value"/>
						<xsl:variable name="rmName" select="own_slot_value[slot_reference = 'name']/value"/>
						<xsl:variable name="planNames" select="own_slot_value[slot_reference = 'roadmap_strategic_plans']/value"/>
						<xsl:variable name="plansInRoadmap" select="$allESPs[name = $planNames]"/>

						<xsl:if test="$plansInRoadmap">
							<div class="row roadmap-section">
								<div class="col-xs-12">
									<p class="section-title"><xsl:value-of select="$rmName"/></p>
									<table class="table table-bordered">
										<thead>
											<tr>
												<th>Plan Name</th>
												<th>Description</th>
											</tr>
										</thead>
										<tbody>
											<xsl:for-each select="$plansInRoadmap">
												<xsl:sort select="own_slot_value[slot_reference = 'name']/value"/>
												<tr>
													<td><xsl:value-of select="own_slot_value[slot_reference = 'name']/value"/></td>
													<td><xsl:value-of select="own_slot_value[slot_reference = 'description']/value"/></td>
												</tr>
											</xsl:for-each>
										</tbody>
									</table>
								</div>
							</div>
						</xsl:if>
					</xsl:for-each>
				</div>
				<xsl:call-template name="Footer"></xsl:call-template>
			</body>
		</html>
	</xsl:template>

</xsl:stylesheet>
