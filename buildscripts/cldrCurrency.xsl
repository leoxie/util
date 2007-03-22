<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:saxon="http://saxon.sf.net/" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" extension-element-prefixes="saxon" version="2.0">
<xsl:output method="text" indent="yes"/>
<!-- list the data elements whose spaces should be preserved
       it seems listing only the parent node doesn't work -->
<xsl:preserve-space elements="displayName symbol"/>
<xsl:strip-space elements="*"/>

<!--  currencyList is an external string property like "AUD|BEF|CAD|CHF|CNY|DEM|...|USD",
        if it is provided, only those currencies in this list will be extracted,
        otherwise all the currencies will be extracted by default-->
<xsl:param name="currencyList"></xsl:param>
<xsl:variable name="first" select="true()" saxon:assignable="yes"/>

<xsl:template match="/">
     <xsl:apply-templates/>
</xsl:template>

<!-- process ldml, numbers and currencies -->
<xsl:template name="top" match="/ldml">
    <xsl:choose>
        <xsl:when test="count(./alias)>0">
            <!-- Handle Alias -->
            <xsl:for-each select="./alias">
                <xsl:call-template name="alias_template">
                    <xsl:with-param name="templateToCall">top</xsl:with-param>
                    <xsl:with-param name="source" select="@source"></xsl:with-param>
                    <xsl:with-param name="xpath" select="@path"></xsl:with-param>
                </xsl:call-template>     
                </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
            <xsl:choose>
                <xsl:when test="name()='currencies'">
                    <xsl:result-document href="currency.js" encoding="UTF-8">// generated from cldr/ldml/main/*.xml, xpath: ldml/numbers/currencies
({<xsl:choose><xsl:when test="string-length(string($currencyList))>0">                            
                                 <xsl:for-each select="currency">
                                     <xsl:if test="contains($currencyList,@type)">
                                         <xsl:call-template name="currency"></xsl:call-template>
                                     </xsl:if>
                                 </xsl:for-each>
                         </xsl:when>
                         <xsl:otherwise>
                             <xsl:for-each select="currency">
                                 <xsl:call-template name="currency"></xsl:call-template>                        
                             </xsl:for-each>
                         </xsl:otherwise>
                     </xsl:choose>
})
                 </xsl:result-document>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:if test="name()='ldml'">
                        <!-- ldml -->
                        <xsl:for-each select="numbers">    
                            <xsl:call-template name="top"></xsl:call-template>
                        </xsl:for-each>
                    </xsl:if>
                    <xsl:if test="name()='numbers'">
                        <!-- numbers -->
                        <xsl:for-each select="currencies">
                            <xsl:call-template name="top"></xsl:call-template>
                        </xsl:for-each>
                    </xsl:if>                 
                </xsl:otherwise>
            </xsl:choose>
         </xsl:otherwise>
    </xsl:choose>        
</xsl:template>

    <!-- currency-->
    <xsl:template name="currency" match="currency">
    <xsl:param name="width" select="@type"></xsl:param>
    <xsl:choose>
        <xsl:when test="count(./alias)>0">
            <!-- Handle Alias -->
            <xsl:for-each select="./alias">
                <xsl:call-template name="alias_template">
                    <xsl:with-param name="templateToCall">currency</xsl:with-param>
                    <xsl:with-param name="source" select="@source"></xsl:with-param>
                    <xsl:with-param name="xpath" select="@path"></xsl:with-param>
                </xsl:call-template>
            </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
        <xsl:if test="count(./* [(not(@draft) or @draft!='provisional' and @draft!='unconfirmed')]) > 0">
            <xsl:call-template name="insert_comma"/>
            <xsl:text>
        </xsl:text>
            <xsl:value-of select="@type"></xsl:value-of>
            <xsl:text>:{</xsl:text>
             <xsl:for-each select="*[not(@draft)] | *[@draft!='provisional' and @draft!='unconfirmed']">
                    <xsl:value-of select="name()"></xsl:value-of>
                    <xsl:text>:"</xsl:text> 
                    <xsl:value-of select="replace(.,'&quot;', '\\&quot;')"></xsl:value-of>                
                    <xsl:text>"</xsl:text>
                    <xsl:if test="count((following-sibling::node())[not(@draft)] 
                               | *[@draft!='provisional' and @draft!='unconfirmed']) > 0 ">
                    <xsl:text>, </xsl:text>
                    </xsl:if>
             </xsl:for-each>
            <xsl:text>}</xsl:text>
            </xsl:if>
         </xsl:otherwise>   
        </xsl:choose>
    </xsl:template>
    
    <!-- recursive process for alias -->
    <xsl:template name="alias_template">
        <xsl:param name="templateToCall"></xsl:param>
        <xsl:param name="source"></xsl:param>
        <xsl:param name="xpath"></xsl:param>
        <xsl:variable name="cur_width" select="../@type"></xsl:variable>
        
        <xsl:choose>            
            <xsl:when test="compare($source,'locale')=0">
                <!-- source="locale" -->
                <xsl:for-each select="saxon:evaluate(concat('../',$xpath))">   
                    <xsl:call-template name="invoke_template_by_name">
                        <xsl:with-param name="templateName" select="$templateToCall"></xsl:with-param>
                    </xsl:call-template>
                </xsl:for-each>
            </xsl:when>
            <xsl:otherwise>
                <!-- source is an external xml file -->
                <xsl:if test="string-length($xpath)>0">
                    <xsl:for-each select="doc(concat($source,'.xml'))"> 
                        <xsl:for-each select="saxon:evaluate($xpath)">
                            <xsl:call-template name="invoke_template_by_name">
                                <xsl:with-param name="templateName" select="$templateToCall"></xsl:with-param>
                            </xsl:call-template>
                        </xsl:for-each>
                    </xsl:for-each>
                </xsl:if>            
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>   
    
    <!-- too bad that can only use standard xsl:call-template(name can not be variable) 
         error occurs if use <saxson:call-templates($templateToCall)  /> -->
    <xsl:template name="invoke_template_by_name">
        <xsl:param name="templateName"></xsl:param>
        <xsl:if test="$templateName='top'">
            <xsl:call-template name="top"></xsl:call-template>
        </xsl:if>
        <xsl:if test="$templateName='currency'">
            <xsl:call-template name="currency"></xsl:call-template>
        </xsl:if>
    </xsl:template>   

    <xsl:template name="insert_comma">
        <xsl:choose>
            <xsl:when test="$first">
                <saxon:assign name="first" select="false()"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>,</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
</xsl:stylesheet>