<?xml version='1.0'  encoding="UTF-8" ?>
<xsl:stylesheet
	version='1.0'
	xmlns:c="http://github.com/lindenb/jvarkit/"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	>
<xsl:output method="text"/>

<xsl:template match="c:app" mode="header">/*
The MIT License (MIT)

Copyright (c) 2015 Pierre Lindenbaum

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


<xsl:apply-templates select="c:history"/>

*/
</xsl:template>

<xsl:template match="c:app" mode="package">
<xsl:value-of select="@package"/>
</xsl:template>

<xsl:template match="c:app" mode="class-name">
<xsl:value-of select="@app"/>
</xsl:template>

<xsl:template match="c:app" mode="abstract-class-name">
<xsl:text>Abstract</xsl:text>
<xsl:apply-templates select="." mode="class-name"/>
</xsl:template>

<xsl:template match="c:app" mode="factory-class-name">
<xsl:apply-templates select="." mode="class-name"/>
<xsl:text>Factory</xsl:text>
</xsl:template>

<xsl:template match="c:app" mode="abstract-command-name">
<xsl:text>Abstract</xsl:text>
<xsl:apply-templates select="." mode="class-name"/>
<xsl:text>Command</xsl:text>
</xsl:template>

<xsl:template match="c:app" mode="jfx">
public static class <xsl:apply-templates select="." mode="class-name"/>Application extends javafx.application.Application
	{
    public void start(javafx.stage.Stage stage)
    	{
    	stage.setTitle("<xsl:apply-templates select="." mode="class-name"/>");
    	javafx.scene.layout.VBox parent = new javafx.scene.layout.VBox();
    	<xsl:apply-templates select=".//c:option" mode="jfx-ctrl"/>
    	javafx.scene.Scene scene = new javafx.scene.Scene(parent);
    	stage.setScene(scene);
        stage.show();
    	}
    public static void main(String args[])
    	{
    	javafx.application.Application.launch(<xsl:apply-templates select="." mode="class-name"/>Application.class,args);
    	}
    }
</xsl:template>


<xsl:template match="c:app" mode="html">
<xsl:if test="c:documentation">
	@Override
	protected void writeHtmlDoc(final javax.xml.stream.XMLStreamWriter w)
		throws javax.xml.stream.XMLStreamException
	{
	w.writeStartElement("div");
	
	w.writeStartElement("h3");
	w.writeCharacters("Description");
	w.writeEndElement();
	w.writeStartElement("div");
	w.writeEndElement();
	
	
	w.writeEndElement();
	}
</xsl:if>
</xsl:template>

<xsl:template match="c:option-group" mode="cli">
final OptionGroup <xsl:value-of select="generate-id()"/> = new OptionGroup();
<xsl:apply-templates select="c:option" mode="cli"/>
options.addOptionGroup(<xsl:value-of select="generate-id()"/>);
</xsl:template>

<xsl:template match="c:option" mode="label">
<xsl:choose>
	<xsl:when test="c:label"><xsl:value-of select="c:label"/></xsl:when>
	<xsl:when test="@label"><xsl:value-of select="@label"/></xsl:when>
	<xsl:otherwise><xsl:value-of select="@name"/></xsl:otherwise>
</xsl:choose>
</xsl:template>

<xsl:template match="c:option" mode="description">
<xsl:choose>
	<xsl:when test="c:description"><xsl:value-of select="c:description"/></xsl:when>
	<xsl:when test="@description"><xsl:value-of select="@description"/></xsl:when>
	<xsl:otherwise><xsl:apply-templates select="." mode="label"/></xsl:otherwise>
</xsl:choose>
</xsl:template>


<xsl:template match="c:option" mode="cli">
options.addOption(org.apache.commons.cli.Option
	<xsl:choose>
		<xsl:when test="@opt">
			.builder("<xsl:value-of select="@opt"/>")
		</xsl:when>
		<xsl:otherwise>
			.builder("<xsl:value-of select="@name"/>")
		</xsl:otherwise>
	</xsl:choose>
	<xsl:if test="@required">
	.required(<xsl:value-of select="@required"/>)
	</xsl:if>
	<xsl:if test="@optional-arg">
	.optionalArg(<xsl:value-of select="@optional-arg"/>)
	</xsl:if>
	<xsl:if test="@longOpt">
	.longOpt("<xsl:value-of select="@longOpt"/>")
	</xsl:if>
	<xsl:if test="@longopt">
	.longOpt("<xsl:value-of select="@longopt"/>")
	</xsl:if>
	<xsl:if test="@value-separator">
	.valueSeparator('<xsl:value-of select="@value-separator"/>')
	</xsl:if>
	<xsl:if test="@description">
	.desc("<xsl:value-of select="@description"/>"
		<xsl:if test="@default">
		+ ". default: <xsl:value-of select="@default"/>"
		</xsl:if>
		)
	</xsl:if>
	<xsl:if test="c:description">
	.desc("<xsl:value-of select="c:description"/>"
		<xsl:if test="@default">
		+ ". default: <xsl:value-of select="@default"/>"
		</xsl:if>	
		)
	</xsl:if>
		<xsl:choose>
		<xsl:when test="@arg-name">
			.argName("<xsl:value-of select="@arg-name"/>")
		</xsl:when>
		<xsl:otherwise>
			.argName("<xsl:value-of select="@name"/>")
		</xsl:otherwise>
	</xsl:choose>
	<xsl:choose>
		<xsl:when test="@type='bool' or @type='boolean' or @type='Boolean' or @type='java.lang.Boolean'">
		.hasArg(false)
		</xsl:when>
		<xsl:when test="@type='int' or @type='long' or @type='short' or @type='double' or @type='float'  or @type='number'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.NUMBER_VALUE)
		</xsl:when>
		<xsl:when test="@type='url' or @type='string' or @type='String'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.STRING_VALUE)
		</xsl:when>
		<xsl:when test="@type='object'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.OBJECT_VALUE)
		</xsl:when>
		<xsl:when test="@type='date'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.DATE_VALUE)
		</xsl:when>
		<xsl:when test="@type='file' or @type='output-file'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.FILE_VALUE)
		</xsl:when>
		<xsl:when test="@type='existing-file' or @type='input-file'">
		.hasArg(true)
		.type(org.apache.commons.cli.PatternOptionBuilder.EXISTING_FILE_VALUE)
		</xsl:when>
		<xsl:otherwise>
			<xsl:message terminate="yes">option:cli unknown type <xsl:value-of select="@type"/></xsl:message>
		</xsl:otherwise>
		
	</xsl:choose>
	.build() );	
</xsl:template>


<xsl:template match="c:option[@type='long']" mode="validator">
LongValidator <xsl:apply-templates select="@name"/> 
</xsl:template>


<xsl:template match="c:option" mode="name">
<xsl:value-of select="@name"/>
</xsl:template>


<xsl:template match="c:option">
<xsl:variable name="cloneable">
	<xsl:apply-templates select="." mode="cloneable"/>
</xsl:variable>
<xsl:variable name="nilleable">
	<xsl:apply-templates select="." mode="nilleable"/>
</xsl:variable>

/** option <xsl:apply-templates select="." mode="name"/> */
protected <xsl:apply-templates select="." mode="java-type"/><xsl:text> </xsl:text> <xsl:apply-templates select="." mode="name"/> = <xsl:choose>
		<xsl:when test="@default and (not(@type) or @type='string' or @type='String' or @type='java.lang.String')">"<xsl:value-of select="@default"/>"</xsl:when>
		<xsl:when test="@default"><xsl:value-of select="@default"/></xsl:when>
		<xsl:when test="$nilleable = 'true'">null</xsl:when>
		<xsl:otherwise>0</xsl:otherwise>
	</xsl:choose>;

/** getter for <xsl:value-of select="@name"/> */
public <xsl:apply-templates select="." mode="java-type"/>
		<xsl:text> </xsl:text>
		<xsl:apply-templates select="." mode="getter"/>()
	{
	return this.<xsl:apply-templates select="." mode="name"/>;
	}

/** setter for <xsl:value-of select="@name"/> */
public  void  <xsl:apply-templates select="." mode="setter"/>( final <xsl:apply-templates select="." mode="java-type"/><xsl:text> </xsl:text><xsl:apply-templates select="." mode="name"/>)
	{
	this.<xsl:apply-templates select="." mode="name"/> = <xsl:choose>
		<xsl:when test="$cloneable = 'true'">(<xsl:apply-templates select="." mode="java-type"/>)(<xsl:apply-templates select="." mode="name"/>==null?null:<xsl:apply-templates select="." mode="name"/>.clone())</xsl:when>
		<xsl:otherwise><xsl:apply-templates select="." mode="name"/></xsl:otherwise>
		</xsl:choose>;
	}

</xsl:template>

<xsl:template match="c:option" mode="copy">
this.<xsl:apply-templates select="." mode="setter"/>(factory.<xsl:apply-templates select="." mode="getter"/>());
</xsl:template>

<xsl:template match="c:option" mode="cloneable">
<xsl:variable name="nilleable">
	<xsl:apply-templates select="." mode="nilleable"/>
</xsl:variable>
<xsl:choose>
	<xsl:when test="@type='java.net.URL'">false</xsl:when>
	<xsl:when test="@type='string' or @type='String' or @type='java.lang.String'">false</xsl:when>
	<xsl:when test="@type='output-file'">false</xsl:when>
	<xsl:when test="@type='input-file'">false</xsl:when>
	<xsl:when test="starts-with(@type,'java.lang')">false</xsl:when>
	<xsl:when test="@type='bool' or @type='boolean'">false</xsl:when>
	<xsl:when test="$nilleable = 'true'">true</xsl:when>
		<xsl:message terminate='yes'>cloneable: unknown type <xsl:value-of select="@type"/>.</xsl:message>
</xsl:choose>
</xsl:template>

<xsl:template match="c:option" mode="nilleable">
<xsl:choose>
	<xsl:when test="@type='java.net.URL'">true</xsl:when>
	<xsl:when test="@type='output-file'">true</xsl:when>
	<xsl:when test="@type='input-file'">true</xsl:when>
	<xsl:when test="@type='java.net.URL'">true</xsl:when>
	<xsl:when test="@type='bool' or @type='boolean'">false</xsl:when>
	<xsl:when test="@type='string' or @type='String' or @type='java.lang.String'">true</xsl:when>
    <xsl:when test="starts-with(@type,'java.lang')">true</xsl:when>
	<xsl:when test="@type='int' or @type='double'">false</xsl:when>
	<xsl:message terminate='yes'>nilleable: unknown type <xsl:value-of select="@type"/>.</xsl:message>
</xsl:choose>
</xsl:template>



<xsl:template match="c:option" mode="setter">
<xsl:variable name="s">
<xsl:call-template name="titleize">
	<xsl:with-param name="s" select="@name"/>
</xsl:call-template>
</xsl:variable>
<xsl:value-of select="concat('set',$s)"/>
</xsl:template>

<xsl:template match="c:option" mode="getter">
<xsl:variable name="s">
<xsl:call-template name="titleize">
	<xsl:with-param name="s" select="@name"/>
</xsl:call-template>
</xsl:variable>
<xsl:choose>
		<xsl:when test="@type='bool' or @type='boolean'  or @type='Boolean'  or @type='java.lang.Boolean'"><xsl:value-of select="concat('is',$s)"/></xsl:when>
		<xsl:otherwise><xsl:value-of select="concat('get',$s)"/></xsl:otherwise>
</xsl:choose>

</xsl:template>

<xsl:template match="c:option" mode="java-type">
<xsl:choose>
	<xsl:when test="@type='output-file'">java.io.File</xsl:when>
	<xsl:when test="@type='input-file'">java.io.File</xsl:when>
	<xsl:when test="@type='int'">int</xsl:when>
	<xsl:when test="@type='bool' or @type='boolean'">boolean</xsl:when>
	<xsl:when test="@type='string' or @type='String' or @type='java.lang.String'">java.lang.String</xsl:when>
	<xsl:message terminate='yes'>unknown type <xsl:value-of select="@type"/>.</xsl:message>
</xsl:choose>
</xsl:template>

<xsl:template match="c:option" mode="jfx-ctrl">
/* begin : javafx control for <xsl:value-of select="@name"/> */
final javafx.scene.control.Tooltip <xsl:value-of select="concat('tooltip',generate-id())"/> = new javafx.scene.control.Tooltip("<xsl:apply-templates select="." mode="description"/>");
final javafx.scene.layout.HBox  <xsl:value-of select="concat('hbox',generate-id())"/> = new javafx.scene.layout.HBox();
parent.getChildren().add( <xsl:value-of select="concat('hbox',generate-id())"/>);
final javafx.scene.control.Label <xsl:value-of select="concat('lbl',generate-id())"/> = new javafx.scene.control.Label("<xsl:apply-templates select="." mode="label"/>");
<xsl:value-of select="concat('hbox',generate-id())"/>.getChildren().add(<xsl:value-of select="concat('lbl',generate-id())"/>);
<xsl:choose>
	<xsl:when test="@type='input-file'">
	final javafx.scene.control.Button <xsl:value-of select="generate-id()"/> = new javafx.scene.control.Button();
	<xsl:value-of select="concat('hbox',generate-id())"/>.getChildren().add(<xsl:value-of select="generate-id()"/>);
	<xsl:value-of select="concat('lbl',generate-id())"/>.setLabelFor(<xsl:value-of select="generate-id()"/>);
	<xsl:value-of select="generate-id()"/>.setTooltip(<xsl:value-of select="concat('tooltip',generate-id())"/>);
	<xsl:value-of select="generate-id()"/>.setOnAction(new javafx.event.EventHandler&lt;javafx.event.ActionEvent&gt;() {
	    @Override public void handle(final javafx.event.ActionEvent evt)
	    	{
	        javafx.stage.FileChooser <xsl:value-of select="concat('fc',generate-id())"/> = new javafx.stage.FileChooser();
			<xsl:value-of select="concat('fc',generate-id())"/>.setTitle("<xsl:apply-templates select="." mode="label"/>");
			java.io.File selectedFile = <xsl:value-of select="concat('fc',generate-id())"/>.showOpenDialog(<xsl:value-of select="generate-id()"/>.getScene().getWindow());
			if( selectedFile == null ) return;
			<xsl:value-of select="generate-id()"/>.getProperties().put("file",selectedFile);
			<xsl:value-of select="generate-id()"/>.setText(selectedFile.getName());
	    	}
		});
	
	</xsl:when>
	<xsl:when test="@type='bool' or @type='boolean' or @type='java.lang.Boolean' or @type='Boolean'">
		final javafx.scene.control.CheckBox <xsl:value-of select="generate-id()"/> = new javafx.scene.control.CheckBox("<xsl:apply-templates select="." mode="label"/>");
		<xsl:value-of select="generate-id()"/>.setTooltip(<xsl:value-of select="concat('tooltip',generate-id())"/>);
		<xsl:value-of select="concat('hbox',generate-id())"/>.getChildren().remove(<xsl:value-of select="concat('lbl',generate-id())"/>);
		<xsl:value-of select="concat('hbox',generate-id())"/>.getChildren().add(<xsl:value-of select="generate-id()"/>);
	</xsl:when>
	
	<xsl:when test="@type='string' or @type='String' or @type='java.lang.String'">
		final javafx.scene.control.TextField <xsl:value-of select="generate-id()"/> = new javafx.scene.control.TextField();
		<xsl:value-of select="generate-id()"/>.setTooltip(<xsl:value-of select="concat('tooltip',generate-id())"/>);
		<xsl:value-of select="concat('hbox',generate-id())"/>.getChildren().add(<xsl:value-of select="generate-id()"/>);
		<xsl:if test="@default">
		<xsl:value-of select="generate-id()"/>.setText("<xsl:value-of select="@default"/>");
		</xsl:if>
	</xsl:when>
	<xsl:message terminate='yes'>jfx-ctrl:unknown type <xsl:value-of select="@type"/>.</xsl:message>
</xsl:choose>
/* end : javafx control for <xsl:value-of select="@name"/> */
</xsl:template>


<xsl:template match="c:option" mode="visit">if(opt.getOpt().equals("<xsl:value-of select="@opt"/>"))
	{
	/* <xsl:value-of select="@name"/> : <xsl:value-of select="@type"/> */
	<xsl:choose>
		<xsl:when test="@type='bool' or @type='boolean' or @type='Boolean' or @type='java.lang.Boolean' ">
		boolean <xsl:value-of select="generate-id()"/>;
		if( opt.getValue().toLowerCase().equals("t") || opt.getValue().toLowerCase().equals("true") || opt.getValue().toLowerCase().equals("yes") || opt.getValue().toLowerCase().equals("1"))
			{
			<xsl:value-of select="generate-id()"/> = true;
			}
		else if( opt.getValue().toLowerCase().equals("f") || opt.getValue().toLowerCase().equals("false") || opt.getValue().toLowerCase().equals("no") || opt.getValue().toLowerCase().equals("0"))
			{
			<xsl:value-of select="generate-id()"/> = false;
			}
		else
			{
			LOG.error("<xsl:value-of select="@name"/> : Cannot cast "+opt.getValue()+" to a boolean value");
			return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;
			}
		</xsl:when>
	
	
		<xsl:when test="not(@type) or @type='string' or @type='String' or @type='java.lang.String'">
		java.lang.String <xsl:value-of select="generate-id()"/> = opt.getValue();
		</xsl:when>
	
		<xsl:when test="@type='int'">
		int <xsl:value-of select="generate-id()"/> = 0;
		try { <xsl:value-of select="generate-id()"/> = Integer.parseInt(opt.getValue());}
		catch(Exception err) { LOG.error("Cannot cast "+opt.getValue()+" to integer",err); return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;}
		
		</xsl:when>
		<xsl:when test="@type='output-file'">
		java.io.File <xsl:value-of select="generate-id()"/> =  null;
		try { <xsl:value-of select="generate-id()"/> = new java.io.File(opt.getValue());}
		catch(Exception err) { LOG.error("Cannot cast "+opt.getValue()+" to File",err); return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;}
		</xsl:when>
		<xsl:when test="@type='input-file'">
		java.io.File <xsl:value-of select="generate-id()"/> =  null;
		try { <xsl:value-of select="generate-id()"/> = new java.io.File(opt.getValue());}
		catch(Exception err) { LOG.error("Cannot cast "+opt.getValue()+" to File",err); return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;}
		if(!<xsl:value-of select="generate-id()"/>.exists())
			{
			LOG.error("option -"+opt.getOpt()+": file "+<xsl:value-of select="generate-id()"/>+" doesn't exists");
			return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;
			}
		if(!<xsl:value-of select="generate-id()"/>.isFile())
			{
			LOG.error("option -"+opt.getOpt()+": file "+<xsl:value-of select="generate-id()"/>+" is not a file.");
			return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;
			}
		if(!<xsl:value-of select="generate-id()"/>.canRead())
			{
			LOG.error("option -"+opt.getOpt()+": file "+<xsl:value-of select="generate-id()"/>+" is not readeable.");
			return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.EXIT_FAILURE;
			}
		</xsl:when>
		<xsl:message terminate='yes'>visit: unknown type <xsl:value-of select="@type"/>.</xsl:message>
	</xsl:choose>
	this.<xsl:apply-templates select="." mode="setter"/>(<xsl:value-of select="generate-id()"/>);
	return com.github.lindenb.jvarkit.util.command.CommandFactory.Status.OK;
	}
</xsl:template>


<xsl:template name="titleize">
<xsl:param name="s"/>
<xsl:value-of select="concat(translate(substring($s,1,1),'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ'),substring($s,2))"/>
</xsl:template>



<xsl:template match="c:history">
* xsl TODO
</xsl:template>




</xsl:stylesheet>


