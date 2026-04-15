<?xml version="1.0" encoding="UTF-8"?>

<xsl:stylesheet version="2.0" xpath-default-namespace="http://protege.stanford.edu/xml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt" xmlns:pro="http://protege.stanford.edu/xml" xmlns:eas="http://www.enterprise-architecture.org/essential" xmlns:functx="http://www.functx.com" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:ess="http://www.enterprise-architecture.org/essential/errorview">
    
    <!-- IMPORT MUST COME FIRST (single import only) -->
    <xsl:import href="../common/core_js_functions.xsl"/>

    <!-- ALL SIX INCLUDES ARE MANDATORY — omitting any one causes silent failure or XSLT errors -->
    <xsl:include href="../common/core_doctype.xsl"/>
    <xsl:include href="../common/core_common_head_content.xsl"/>
    <xsl:include href="../common/core_header.xsl"/>        <!-- Provided template: Heading (Includes ViewUserScopingUI and transitively includes viewer_security.xsl) -->
	<xsl:include href="../common/core_footer.xsl"/>        <!-- Provided template: Footer -->
	<xsl:include href="../common/core_external_doc_ref.xsl"/>
	<xsl:include href="../common/core_api_fetcher.xsl"/>   <!-- NO NOT REMOVE: Required for API loading mechanism -->
	
	
	<!-- 
		SECURITY WARNING: 
		DO NOT manually include viewer_security.xsl. It is transitively included via core_header.xsl.
	-->

    <!-- OPTIONAL includes — only add if your view needs them:
    <xsl:include href="../common/core_handlebars_functions.xsl"/>
    <xsl:include href="../common/datatables_includes.xsl"/>
    -->
	<xsl:output method="html" omit-xml-declaration="yes" indent="yes"/>


	<!-- START GENERIC PARAMETERS -->
	<xsl:param name="viewScopeTermIds"/>

	<!-- END GENERIC PARAMETERS -->

	<!-- START GENERIC LINK VARIABLES -->
	<xsl:variable name="viewScopeTerms" select="eas:get_scoping_terms_from_string($viewScopeTermIds)"/>

	<!--
		* Copyright © 2008-2017 Enterprise Architecture Solutions Limited.
	 	* This file is part of Essential Architecture Manager, 
	 	* the Essential Architecture Meta Model and The Essential Project.
		*
		* Essential Architecture Manager is free software: you can redistribute it and/or modify
		* it under the terms of the GNU General Public License as published by
		* the Free Software Foundation, either version 3 of the License, or
		* (at your option) any later version.
		*
		* Essential Architecture Manager is distributed in the hope that it will be useful,
		* but WITHOUT ANY WARRANTY; without even the implied warranty of
		* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
		* GNU General Public License for more details.
		*
		* You should have received a copy of the GNU General Public License
		* along with Essential Architecture Manager.  If not, see <http://www.gnu.org/licenses/>.
		* 
	-->
  
	<xsl:template match="knowledge_base">
	
		<html lang="en">
			<head>
				<xsl:call-template name="commonHeadContent"/>
				<meta name="viewport" content="width=device-width, initial-scale=1" />
				<meta charset="UTF-8" />
				<title>TEMPLATE</title>
				<!-- ANY LINKS TO JAVASCRIPT LIBRARIES-->
				<style>
					<!-- YOUR CSS -->
				</style>
			</head>
			<body role="document" aria-labelledby="main-heading">
				
				
				<!-- ADD THE PAGE HEADING -->
				<xsl:call-template name="Heading"/>
				
				<!--ADD THE CONTENT-->
				<div class="container-fluid">
					<div class="row">
						<div class="col-xs-12">
							<div class="page-header">
								<h1 id="main-heading">
									<span class="text-primary"><xsl:value-of select="eas:i18n('View')"/>: </span>
									<span class="text-darkgrey">NAME OF VIEW</span>
								</h1>
							</div>
						</div>
						<div class="col-xs-12" role="main">
							<!-- INSERT YOUR AI HTML HERE-->
						</div>
						<!--Setup Closing Tags-->
					</div>
				</div>

				<!-- ADD THE PAGE FOOTER -->
				<xsl:call-template name="Footer"/>
                <script type="text/javascript">
                    <xsl:call-template name="RenderViewerAPIJSFunction"/>	
                 
					<!-- DEFINE YOUR VARIABLES - If GPT doesn't provide then just replicate the apiList names-->
		 
						let appMartAPI, infoMartAPI;
                        $(document).ready(function() {
							<!-- DEFINE APIS - the list of apis to call based on their data label GPT SHOULD PROVIDE-->
                            const apiList=['appMartAPI','infoMartAPI',];

                            async function executeFetchAndRender() {
                                try {
                            let responses = await fetchAndRenderData(apiList);
							 ({  appMartAPI,infoMartAPI } = responses);
							
							console.log('Original responses A', appMartAPI) 
							console.log('Original responses B', infoMartAPI) 

							// INSERT AI javascript code here

                                }
                                catch (error) {
                                    // Handle any errors that occur during the fetch operations
                                }
                            }
                            executeFetchAndRender()
                        });   
                                                                     
                </script>
			
			</body>
            
		</html>
	</xsl:template>


</xsl:stylesheet>
