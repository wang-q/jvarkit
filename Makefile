#
# Makefile for jvarkit
#
SHELL=/bin/bash
this.makefile=$(lastword $(MAKEFILE_LIST))
this.dir=$(dir $(realpath ${this.makefile}))


#need local settings ? create a file 'local.mk' in this directory
ifneq ($(realpath local.mk),)
include $(realpath local.mk)
endif


# proxy for curl, etc...
curl.proxy=$(if ${http.proxy.host}${http.proxy.port},-x "${http.proxy.host}:${http.proxy.port}",)
xjc.proxy=$(if ${http.proxy.host}${http.proxy.port}, -httpproxy "${http.proxy.host}:${http.proxy.port}" ,)

ANT?=ant
JAVAC?=javac
JAVA?=java
JAR?=jar
XJC?=xjc

export htsjdk.version?=1.139
export htsjdk.home?=${this.dir}htsjdk-${htsjdk.version}
htsjdk.jars=$(addprefix ${htsjdk.home}/dist/,$(addsuffix .jar,commons-jexl-2.1.1 commons-logging-1.1.1 htsjdk-${htsjdk.version} snappy-java-1.0.3-rc3 commons-compress-1.4.1 apache-ant-1.8.2-bzip2 xz-1.5))
src.dir=${this.dir}src/main/java
generated.dir=${this.dir}src/main/generated-sources
tmp.dir=${this.dir}_tmp-${htsjdk.version}
tmp.mft=${tmp.dir}/META-INF/MANIFEST.MF
export dist.dir?=${this.dir}dist-${htsjdk.version}
galaxy.bundle.dir?=galaxy-bundle

mysql.version?=5.1.34
mysql.jar?=lib/mysql-connector-java-${mysql.version}-bin.jar
berkeleydb.version?=6.2.31
berkeleydb.jar?=lib/je-${berkeleydb.version}.jar
bigwig.version=20150429
bigwig.jar?=lib/BigWig.jar
bigwig.log4j.jar=$(dir ${bigwig.jar})/log4j-1.2.15.jar
bigwig.jars=${bigwig.jar} ${bigwig.log4j.jar}
common.math.version?=3.4.1
common.math.jar?=lib/commons-math3-${common.math.version}.jar


jvarkit.package=com.github.lindenb.jvarkit


## http://stackoverflow.com/questions/9551416
EMPTY :=
SPACE := $(EMPTY) $(EMPTY)



define compile-htsjdk-cmd

## 1 : target name
## 2 : qualified main class name
## 3 : other deps

$(1)  : ${htsjdk.jars} \
		${generated.dir}/java/com/github/lindenb/jvarkit/util/htsjdk/HtsjdkVersion.java \
		$(addsuffix .java,$(addprefix ${src.dir}/,$(subst .,/,$(2)))) \
		$(3) ${apache.commons.cli.jars}
	echo "### COMPILING $(1) ######"
	mkdir -p ${tmp.dir}/META-INF ${dist.dir} ${galaxy.bundle.dir}/jvarkit 
	#create galaxy
	rm -f ${galaxy.bundle.dir}/$(1).xml
	-xsltproc --path ${this.dir}src/main/resources/xml \
		--output ${galaxy.bundle.dir}/jvarkit/$(1).xml \
		--stringparam name "$(1)" \
		--stringparam class "$(2)" \
		--stringparam classpath "$$(notdir $$(realpath $$(filter %.jar,$$^))) $(1).jar" \
		--stringparam version $$(if $$(realpath .git/refs/heads/master), `cat  $$(realpath .git/refs/heads/master) `, "undefined") \
		${this.dir}src/main/resources/xsl/tools2galaxy.xsl ${this.dir}src/main/resources/xml/tools.xml || echo "XSLT failed (ignored)"
	-cp ${galaxy.bundle.dir}/jvarkit/$(1).xml ${tmp.dir}/META-INF/galaxy.xml 
	#generate java code if needed = a file with .xml exists, requires xsltproc
	mkdir -p ${generated.dir}/java/$(dir $(subst .,/,$(2))) && \
	xsltproc \
		--xinclude \
		--stringparam githash $$(if $$(realpath ${this.dir}.git/refs/heads/master), `cat  $$(realpath ${this.dir}.git/refs/heads/master) `, "undefined") \
		--path "${this.dir}src/main/resources/xml" \
		-o ${generated.dir}/java/$(dir $(subst .,/,$(2)))Abstract$(notdir $(subst .,/,$(2))).java \
		${this.dir}src/main/resources/xsl/command2java.xsl \
		"$(addsuffix .xml,$(addprefix ${src.dir}/,$(subst .,/,$(2))))"  
	#copy resource
	cp ${this.dir}src/main/resources/messages/messages.properties ${tmp.dir}
	echo '### Printing javac version : it should be 1.7. if Not, check your $$$${PATH}.'
	${JAVAC} -version
	#compile
	${JAVAC} -d ${tmp.dir} -g -classpath "$$(subst $$(SPACE),:,$$(filter %.jar,$$^))" -sourcepath ${src.dir}:${generated.dir}/java $$(filter %.java,$$^)
	#create META-INF/MANIFEST.MF
	echo "Manifest-Version: 1.0" > ${tmp.mft}
	echo "Main-Class: $(2)" >> ${tmp.mft}
	echo "Class-Path: $$(realpath $$(filter %.jar,$$^)) ${dist.dir}/$(1).jar" | fold -w 71 | awk '{printf("%s%s\n",(NR==1?"": " "),$$$$0);}' >>  ${tmp.mft}
	echo -n "Git-Hash: " >> ${tmp.mft}
	$$(if $$(realpath .git/refs/heads/master),cat $$(realpath .git/refs/heads/master), echo "undefined")  >> ${tmp.mft} 
	echo -n "Compile-Date: " >> ${tmp.mft}
	date +%Y-%m-%d:%H-%m-%S >> ${tmp.mft}
	#create jar
	${JAR} cfm ${dist.dir}/$(1).jar ${tmp.mft}  -C ${tmp.dir} .
	#create bash executable
	echo '#!/bin/bash' > ${dist.dir}/$(1)
	echo '${JAVA} -Dfile.encoding=UTF8 -Xmx500m $(if ${http.proxy.host},-Dhtt.proxyHost=${http.proxy.host})  $(if ${http.proxy.port},-Dhtt.proxyPort=${http.proxy.port}) -cp "$$(subst $$(SPACE),:,$$(realpath $$(filter %.jar,$$^))):${dist.dir}/$(1).jar" $(2) $$$$*' >> ${dist.dir}/$(1)
	chmod  ugo+rx ${dist.dir}/$(1)
	#cleanup
	rm -rf ${tmp.dir}


endef


##
## Creates a CGI script for java app
##
define compile-cgi-cmd

${dist.dir}/$(1).cgi : $(1)
	echo "#!/bin/bash" > $$@
	echo "PREFIX=$$(dirname $$0)" >> $$@
	echo "${JAVA} -Dfile.encoding=UTF8 -Xmx500m -Dprefs.file.xml=/var/www/cgi-bin/prefs.xml -jar $PREFIX/$(1).jar $$*" >> $$@

endef

#
# $1 :biostar post-id
# $2: other deps
#
define compile_biostar_cmd
$(call compile-htsjdk-cmd,biostar$(1),${jvarkit.package}.tools.biostar.Biostar$(1),$(2))
endef

# 
# All executables
#
GALAXY_TOOLS= vcffilterjs vcftail vcfhead vcftrio  vcffilterso groupbygene
APPS= ${GALAXY_TOOLS} addlinearindextobed	allelefreqcalc	almostsortedvcf	backlocate	bam2fastq	bam2raster	bam2svg \
	bam2wig	bam4deseq01	bamcmpcoverage	bamgenscan	bamindexreadnames	bamliftover	bamqueryreadnames \
	bamrenamechr	bamsnvwig	bamstats04	bamstats05 bamtreepack	bamviewgui	batchigvpictures	bedliftover \
	bedrenamechr	biostar103303	biostar106668	biostar130456	biostar59647	biostar76892	biostar77288 \
	biostar77828	biostar78285	biostar78400	biostar81455	biostar84452	biostar84786	biostar86363 \
	biostar86480	biostar90204	biostar94573	biostar95652 biostar139647	biostar145820 blast2sam	blastmapannots \
	blastn2snp	buildwpontology	bwamemdigest	bwamemnop	cmpbams	cmpbamsandbuild	coveragenormalizer \
	deseqcount	downsamplevcf	evs2bed	evs2vcf	evs2xml	extendbed	fastq2fasta \
	fastqentropy	fastqgrep	fastqjs	fastqphred64to33	fastqrecordtreepack	fastqrevcomp	fastqshuffle \
	fastqsplitinterleaved	findallcoverageatposition	findavariation	findcorruptedfiles	findmyvirus	findnewsplicesites	fixvarscanmissingheader \
	fixvcf	fixvcfformat	fixvcfmissinggenotypes	gcanddepth	genomicjaspar	genscan	 \
	howmanybamdict	illuminadir	ilmnfastqstats	impactofduplicates	jeter	kg2bed \
	liftover2svg	mapuniprot	mergesplittedblast	metrics2xml	ncbitaxonomy2xml	ngsfilessummary	noemptyvcf \
	nozerovariationvcf	pademptyfastq	paintcontext	pubmeddump	pubmedfilterjs	referencetovcf	sam2json \
	sam2psl	sam2tsv	sam4weblogo	samclipindelfraction	samextractclip	samfindclippedregions	samfixcigar \
	samgrep	samjs	samshortinvert	samstats01	sigframe	sortvcfoninfo \
	sortvcfonref2	splitbam3	splitbytile	splitread	tview	tview.cgi \
	vcf2hilbert	vcf2ps	vcf2rdf	vcf2sql	vcf2xml	vcfannobam	vcfbed \
	vcfbedjs	vcfbiomart	vcfcadd	vcfcmppred	vcfcomm	vcfcompare	vcfcomparegt \
	vcfconcat	vcfcutsamples	vcffilterdoid		vcffixindels	vcfgo \
	vcfin	vcfjaspar	vcfliftover	vcfmapuniprot	vcfmerge	vcfmulti2one \
	vcfpolyx	vcfpredictions	vcfrebase	vcfregistry.cgi	vcfregulomedb	vcfrenamechr	vcfrenamesamples \
	vcfresetvcf	vcfsetdict	vcfshuffle	vcfsimulator	vcfstats	vcfstopcodon	vcfstripannot \
	vcftabixml	vcftreepack	 vcfvcf	vcfviewgui	worldmapgenome \
	uniprotfilterjs skipxmlelements vcfensemblvep vcfgroupbypop bamtile xcontaminations \
	biostar3654 vcfjoinvcfjs bioalcidae vcfburden vcfbedsetfilter vcfreplacetag vcfindextabix \
	vcfpeekvcf vcfgetvariantbyindex vcfmulti2oneallele bedindextabix vcf2bam vcffilterxpath \
	biostar140111 pcrclipreads  extendrefwithreads pcrslicereads samjmx vcfjmx gtf2xml sortsamrefname biostar154220 \
	biostar160470 


.PHONY: all tests $(APPS) clean library top galaxy ${galaxy.bundle.dir}.tar ${dist.dir}/jvarkit-${htsjdk.version}.jar

top:
	@echo "This  is the top target. Run 'make name-of-target' to build the desired target. Run 'make all' if you're Pierre Lindenbaum" 


#
# include java libraries from Maven
#
include maven.mk

all: $(APPS)

tests: 
	(cd ${this.dir}tests && $(MAKE))

#bigwig
$(eval $(call compile-htsjdk-cmd,vcfbigwig,		${jvarkit.package}.tools.vcfbigwig.VCFBigWig,${bigwig.jars}))
$(eval $(call compile-htsjdk-cmd,vcfensemblreg,	${jvarkit.package}.tools.ensemblreg.VcfEnsemblReg,${bigwig.jars}))
$(eval $(call compile_biostar_cmd,105754,${bigwig.jar}))
# common math
$(eval $(call compile-htsjdk-cmd,cnv01,${jvarkit.package}.tools.redon.CopyNumber01,${common.math.jar}))
#berkeley
$(eval $(call compile-htsjdk-cmd,vcfphylotree,${jvarkit.package}.tools.phylo.VcfPhyloTree,${berkeleydb.jar}))
$(eval $(call compile-htsjdk-cmd,ngsfilesscanner,${jvarkit.package}.tools.ngsfiles.NgsFilesScanner,${berkeleydb.jar}))
$(eval $(call compile-htsjdk-cmd,92368,${berkeleydb.jar}))
#mysql
$(eval $(call compile-htsjdk-cmd,vcfucsc,${jvarkit.package}.tools.vcfucsc.VcfUcsc,${mysql.jar}))

$(eval $(call compile-htsjdk-cmd,addlinearindextobed,${jvarkit.package}.tools.misc.AddLinearIndexToBed))
$(eval $(call compile-htsjdk-cmd,allelefreqcalc,${jvarkit.package}.tools.misc.AlleleFrequencyCalculator))
$(eval $(call compile-htsjdk-cmd,almostsortedvcf,${jvarkit.package}.tools.sortvcfonref.AlmostSortedVcf))
$(eval $(call compile-htsjdk-cmd,backlocate,${jvarkit.package}.tools.backlocate.BackLocate))
$(eval $(call compile-htsjdk-cmd,bam2fastq,${jvarkit.package}.tools.fastq.BamToFastq))
$(eval $(call compile-htsjdk-cmd,bam2raster,${jvarkit.package}.tools.bam2graphics.Bam2Raster))
$(eval $(call compile-htsjdk-cmd,bam2svg,${jvarkit.package}.tools.bam2svg.BamToSVG))
$(eval $(call compile-htsjdk-cmd,bam2wig,${jvarkit.package}.tools.bam2wig.Bam2Wig))
$(eval $(call compile-htsjdk-cmd,bam4deseq01,${jvarkit.package}.tools.bam4deseq.Bam4DeseqIntervals))
$(eval $(call compile-htsjdk-cmd,bamcmpcoverage,${jvarkit.package}.tools.misc.BamCmpCoverage))
$(eval $(call compile-htsjdk-cmd,bamgenscan,${jvarkit.package}.tools.genscan.BamGenScan))
$(eval $(call compile-htsjdk-cmd,bamindexreadnames,${jvarkit.package}.tools.bamindexnames.BamIndexReadNames))
$(eval $(call compile-htsjdk-cmd,bamliftover,${jvarkit.package}.tools.liftover.BamLiftOver))
$(eval $(call compile-htsjdk-cmd,bamqueryreadnames,${jvarkit.package}.tools.bamindexnames.BamQueryReadNames))
$(eval $(call compile-htsjdk-cmd,bamrenamechr,${jvarkit.package}.tools.misc.ConvertBamChromosomes))
$(eval $(call compile-htsjdk-cmd,bamstats02,${jvarkit.package}.tools.bamstats01.BamStats02))
$(eval $(call compile-htsjdk-cmd,bamstats04,${jvarkit.package}.tools.bamstats04.BamStats04))
$(eval $(call compile-htsjdk-cmd,bamstats05,${jvarkit.package}.tools.bamstats04.BamStats05))
$(eval $(call compile-htsjdk-cmd,bamtreepack,${jvarkit.package}.tools.treepack.BamTreePack))
$(eval $(call compile-htsjdk-cmd,bamviewgui,${jvarkit.package}.tools.bamviewgui.BamViewGui))
$(eval $(call compile-htsjdk-cmd,batchigvpictures,${jvarkit.package}.tools.batchpicts.BatchIGVPictures,copy.opendoc.odp.resources))
$(eval $(call compile-htsjdk-cmd,bedliftover,${jvarkit.package}.tools.liftover.BedLiftOver))
$(eval $(call compile-htsjdk-cmd,bedrenamechr,${jvarkit.package}.tools.misc.ConvertBedChromosomes))
$(eval $(call compile_biostar_cmd,103303))
$(eval $(call compile_biostar_cmd,106668))
$(eval $(call compile_biostar_cmd,130456))
$(eval $(call compile_biostar_cmd,145820))
$(eval $(call compile_biostar_cmd,59647))
$(eval $(call compile_biostar_cmd,76892))
$(eval $(call compile_biostar_cmd,77288))
$(eval $(call compile_biostar_cmd,77828))
$(eval $(call compile_biostar_cmd,78285))
$(eval $(call compile_biostar_cmd,78400))
$(eval $(call compile_biostar_cmd,81455))
$(eval $(call compile_biostar_cmd,84452))
$(eval $(call compile_biostar_cmd,84786))
$(eval $(call compile_biostar_cmd,86363))
$(eval $(call compile_biostar_cmd,86480))
$(eval $(call compile_biostar_cmd,90204))
$(eval $(call compile_biostar_cmd,94573))
$(eval $(call compile_biostar_cmd,95652,api.ncbi.gb))
$(eval $(call compile_biostar_cmd,3654,api.ncbi.insdseq api.ncbi.blast))
$(eval $(call compile_biostar_cmd,154220))
$(eval $(call compile_biostar_cmd,140111,api.ncbi.dbsnp.gt ${generated.dir}/java/gov/nih/nlm/ncbi/dbsnp/gt/package-info.java))
$(eval $(call compile_biostar_cmd,160470,api.ncbi.blast))
$(eval $(call compile-htsjdk-cmd,blast2sam,${jvarkit.package}.tools.blast2sam.BlastToSam,api.ncbi.blast))
$(eval $(call compile-htsjdk-cmd,blastfastq,${jvarkit.package}.tools.bwamempcr.BlastFastQ))
$(eval $(call compile-htsjdk-cmd,blastmapannots, ${jvarkit.package}.tools.blastmapannots.BlastMapAnnotations, api.ncbi.blast api.ncbi.gb ${generated.dir}/java/org/uniprot/package-info.java))
$(eval $(call compile-htsjdk-cmd,blastn2snp,${jvarkit.package}.tools.blast.BlastNToSnp,api.ncbi.blast))
$(eval $(call compile-htsjdk-cmd,buildwpontology,${jvarkit.package}.tools.misc.BuildWikipediaOntology))
$(eval $(call compile-htsjdk-cmd,bwamemdigest,${jvarkit.package}.tools.mem.BWAMemDigest))
$(eval $(call compile-htsjdk-cmd,bwamemnop,${jvarkit.package}.tools.mem.BWAMemNOp))
$(eval $(call compile-htsjdk-cmd,cmpbams,${jvarkit.package}.tools.cmpbams.CompareBams2))
$(eval $(call compile-htsjdk-cmd,cmpbamsandbuild,${jvarkit.package}.tools.cmpbams.CompareBamAndBuild))
$(eval $(call compile-htsjdk-cmd,coveragenormalizer,${jvarkit.package}.tools.misc.CoverageNormalizer))
$(eval $(call compile-htsjdk-cmd,deseqcount,${jvarkit.package}.tools.bam4deseq.HtSeqCount))
$(eval $(call compile-htsjdk-cmd,downsamplevcf,${jvarkit.package}.tools.misc.DownSampleVcf))
$(eval $(call compile-htsjdk-cmd,evs2bed,${jvarkit.package}.tools.evs2bed.DumpExomeVariantServerData))
$(eval $(call compile-htsjdk-cmd,evs2vcf,${jvarkit.package}.tools.evs2bed.EvsToVcf,api.evs))
$(eval $(call compile-htsjdk-cmd,evs2xml,${jvarkit.package}.tools.evs2bed.EvsDumpXml,api.evs))
$(eval $(call compile-htsjdk-cmd,extendbed,${jvarkit.package}.tools.misc.ExtendBed))
$(eval $(call compile-htsjdk-cmd,fastq2fasta,${jvarkit.package}.tools.misc.FastqToFasta))
$(eval $(call compile-htsjdk-cmd,fastqentropy,${jvarkit.package}.tools.fastq.FastqEntropy))
$(eval $(call compile-htsjdk-cmd,fastqgrep,${jvarkit.package}.tools.misc.FastqGrep))
$(eval $(call compile-htsjdk-cmd,fastqjs,${jvarkit.package}.tools.fastq.FastqJavascript))
$(eval $(call compile-htsjdk-cmd,fastqphred64to33,${jvarkit.package}.tools.fastq.ConvertPhred64toFastq33))
$(eval $(call compile-htsjdk-cmd,fastqrecordtreepack,${jvarkit.package}.tools.treepack.FastqRecordTreePack))
$(eval $(call compile-htsjdk-cmd,fastqrevcomp,${jvarkit.package}.tools.misc.FastqRevComp))
$(eval $(call compile-htsjdk-cmd,fastqshuffle,${jvarkit.package}.tools.fastq.FastqShuffle))
$(eval $(call compile-htsjdk-cmd,fastqsplitinterleaved,${jvarkit.package}.tools.fastq.FastqSplitInterleaved))
$(eval $(call compile-htsjdk-cmd,findallcoverageatposition,${jvarkit.package}.tools.misc.FindAllCoverageAtPosition))
$(eval $(call compile-htsjdk-cmd,findavariation,${jvarkit.package}.tools.misc.FindAVariation))
$(eval $(call compile-htsjdk-cmd,findcorruptedfiles,${jvarkit.package}.tools.misc.FindCorruptedFiles))
$(eval $(call compile-htsjdk-cmd,findmyvirus,${jvarkit.package}.tools.mem.FindMyVirus))
$(eval $(call compile-htsjdk-cmd,findnewsplicesites,${jvarkit.package}.tools.rnaseq.FindNewSpliceSites))
$(eval $(call compile-htsjdk-cmd,fixvarscanmissingheader,${jvarkit.package}.tools.misc.FixVarScanMissingVCFHeader))
$(eval $(call compile-htsjdk-cmd,fixvcf,${jvarkit.package}.tools.misc.FixVCF))
$(eval $(call compile-htsjdk-cmd,fixvcfformat,${jvarkit.package}.tools.misc.FixVcfFormat))
$(eval $(call compile-htsjdk-cmd,fixvcfmissinggenotypes,${jvarkit.package}.tools.misc.FixVcfMissingGenotypes))
$(eval $(call compile-htsjdk-cmd,gcanddepth,${jvarkit.package}.tools.misc.GcPercentAndDepth))
$(eval $(call compile-htsjdk-cmd,genomicjaspar,${jvarkit.package}.tools.jaspar.GenomicJaspar))
$(eval $(call compile-htsjdk-cmd,genscan,${jvarkit.package}.tools.genscan.GenScan))
$(eval $(call compile-htsjdk-cmd,groupbygene,${jvarkit.package}.tools.groupbygene.GroupByGene))
$(eval $(call compile-htsjdk-cmd,howmanybamdict,${jvarkit.package}.tools.misc.HowManyBamDict))
$(eval $(call compile-htsjdk-cmd,idea20130924,${jvarkit.package}.tools.bwamempcr.Idea20130924))
$(eval $(call compile-htsjdk-cmd,illuminadir,${jvarkit.package}.tools.misc.IlluminaDirectory))
$(eval $(call compile-htsjdk-cmd,ilmnfastqstats,${jvarkit.package}.tools.misc.IlluminaStatsFastq))
$(eval $(call compile-htsjdk-cmd,impactofduplicates,${jvarkit.package}.tools.impactdup.ImpactOfDuplicates))
$(eval $(call compile-htsjdk-cmd,kg2bed,${jvarkit.package}.tools.misc.KnownGenesToBed))
$(eval $(call compile-htsjdk-cmd,liftover2svg,${jvarkit.package}.tools.liftover.LiftOverToSVG))
$(eval $(call compile-htsjdk-cmd,mapuniprot,${jvarkit.package}.tools.misc.MapUniProtFeatures,${generated.dir}/java/org/uniprot/package-info.java))
$(eval $(call compile-htsjdk-cmd,mergesplittedblast,${jvarkit.package}.tools.blast.MergeSplittedBlast,api.ncbi.blast))
$(eval $(call compile-htsjdk-cmd,metrics2xml,${jvarkit.package}.tools.metrics2xml.PicardMetricsToXML))
$(eval $(call compile-htsjdk-cmd,ncbitaxonomy2xml,${jvarkit.package}.tools.misc.NcbiTaxonomyToXml))
$(eval $(call compile-htsjdk-cmd,ngsfilessummary,${jvarkit.package}.tools.ngsfiles.NgsFilesSummary))
$(eval $(call compile-htsjdk-cmd,noemptyvcf,${jvarkit.package}.tools.misc.NoEmptyVCF))
$(eval $(call compile-htsjdk-cmd,nozerovariationvcf,${jvarkit.package}.tools.misc.NoZeroVariationVCF))
$(eval $(call compile-htsjdk-cmd,pademptyfastq,${jvarkit.package}.tools.misc.PadEmptyFastq))
$(eval $(call compile-htsjdk-cmd,paintcontext,${jvarkit.package}.tools.bam2graphics.PaintContext))
$(eval $(call compile-htsjdk-cmd,pubmeddump,${jvarkit.package}.tools.pubmed.PubmedDump))
$(eval $(call compile-htsjdk-cmd,pubmedgraph,${jvarkit.package}.tools.pubmed.PubmedGraph))
$(eval $(call compile-htsjdk-cmd,pubmedfilterjs,${jvarkit.package}.tools.pubmed.PubmedFilterJS,api.ncbi.pubmed))
$(eval $(call compile-htsjdk-cmd,referencetovcf,${jvarkit.package}.tools.misc.ReferenceToVCF))
$(eval $(call compile-htsjdk-cmd,sam2json,${jvarkit.package}.tools.misc.SamToJson))
$(eval $(call compile-htsjdk-cmd,sam2psl,${jvarkit.package}.tools.misc.SamToPsl))
$(eval $(call compile-htsjdk-cmd,sam2tsv,${jvarkit.package}.tools.sam2tsv.Sam2Tsv))
$(eval $(call compile-htsjdk-cmd,sam4weblogo,${jvarkit.package}.tools.sam4weblogo.SAM4WebLogo))
$(eval $(call compile-htsjdk-cmd,samclipindelfraction,${jvarkit.package}.tools.misc.SamClipIndelFraction))
$(eval $(call compile-htsjdk-cmd,samextractclip,${jvarkit.package}.tools.structvar.SamExtractClip))
$(eval $(call compile-htsjdk-cmd,samfindclippedregions,${jvarkit.package}.tools.structvar.SamFindClippedRegions))
$(eval $(call compile-htsjdk-cmd,samfixcigar,${jvarkit.package}.tools.samfixcigar.SamFixCigar))
$(eval $(call compile-htsjdk-cmd,samgrep,${jvarkit.package}.tools.samgrep.SamGrep))
$(eval $(call compile-htsjdk-cmd,samjs,${jvarkit.package}.tools.samjs.SamJavascript))
$(eval $(call compile-htsjdk-cmd,samshortinvert,${jvarkit.package}.tools.structvar.SamShortInvertion))
$(eval $(call compile-htsjdk-cmd,samstats01,${jvarkit.package}.tools.bamstats01.BamStats01))
$(eval $(call compile-htsjdk-cmd,scanshortinvert,${jvarkit.package}.tools.mem.ScanShortInvert))
$(eval $(call compile-htsjdk-cmd,sigframe,${jvarkit.package}.tools.sigframe.SigFrame))
$(eval $(call compile-htsjdk-cmd,sortvcfoninfo,${jvarkit.package}.tools.sortvcfonref.SortVcfOnInfo))
$(eval $(call compile-htsjdk-cmd,sortvcfonref2,${jvarkit.package}.tools.sortvcfonref.SortVcfOnRef2))
$(eval $(call compile-htsjdk-cmd,splitbam3,${jvarkit.package}.tools.splitbam.SplitBam3))
$(eval $(call compile-htsjdk-cmd,splitbytile,${jvarkit.package}.tools.splitbytitle.SplitByTile))
$(eval $(call compile-htsjdk-cmd,splitread,${jvarkit.package}.tools.splitread.SplitRead))
#$(eval $(call compile-htsjdk-cmd,tview,${jvarkit.package}.tools.tview.TViewCmd))
#$(eval $(call compile-cgi-cmd,tview.cgi))
$(eval $(call compile-htsjdk-cmd,vcf2hilbert,${jvarkit.package}.tools.misc.VcfToHilbert))
$(eval $(call compile-htsjdk-cmd,vcf2ps,${jvarkit.package}.tools.misc.VcfToPostscript))
$(eval $(call compile-htsjdk-cmd,vcf2rdf,${jvarkit.package}.tools.vcf2rdf.VcfToRdf))
$(eval $(call compile-htsjdk-cmd,vcf2sql,${jvarkit.package}.tools.vcf2sql.VcfToSql))
$(eval $(call compile-htsjdk-cmd,vcf2xml,${jvarkit.package}.tools.vcf2xml.Vcf2Xml))
$(eval $(call compile-htsjdk-cmd,vcfannobam,${jvarkit.package}.tools.vcfannobam.VCFAnnoBam))
$(eval $(call compile-htsjdk-cmd,vcfbed,${jvarkit.package}.tools.vcfbed.VCFBed))
$(eval $(call compile-htsjdk-cmd,vcfbedjs,${jvarkit.package}.tools.vcfbed.VCFBed))
$(eval $(call compile-htsjdk-cmd,vcfbiomart,${jvarkit.package}.tools.vcfbiomart.VcfBiomart))
$(eval $(call compile-htsjdk-cmd,vcfcadd,${jvarkit.package}.tools.misc.VcfCadd))
$(eval $(call compile-htsjdk-cmd,vcfcmppred,${jvarkit.package}.tools.vcfcmp.VCFComparePredictions))
$(eval $(call compile-htsjdk-cmd,vcfcomm,${jvarkit.package}.tools.vcfcmp.VCFComm))
$(eval $(call compile-htsjdk-cmd,vcfcompare,${jvarkit.package}.tools.vcfcmp.VCFCompare))
$(eval $(call compile-htsjdk-cmd,vcfcomparegt,${jvarkit.package}.tools.vcfcmp.VCFCompareGT))
$(eval $(call compile-htsjdk-cmd,vcfconcat,${jvarkit.package}.tools.vcfconcat.VcfConcat))
$(eval $(call compile-htsjdk-cmd,vcfcutsamples,${jvarkit.package}.tools.misc.VcfCutSamples))
$(eval $(call compile-htsjdk-cmd,vcfdas,${jvarkit.package}.tools.vcfdas.VcfDistributedAnnotationSystem, ${jetty.jars}))
$(eval $(call compile-htsjdk-cmd,vcffilterdoid,${jvarkit.package}.tools.vcfdo.VcfFilterDoid))
$(eval $(call compile-htsjdk-cmd,vcffilterjs,${jvarkit.package}.tools.vcffilterjs.VCFFilterJS))
$(eval $(call compile-htsjdk-cmd,vcffilterso,${jvarkit.package}.tools.misc.VcfFilterSequenceOntology))
$(eval $(call compile-htsjdk-cmd,vcffixindels,${jvarkit.package}.tools.vcffixindels.VCFFixIndels))
$(eval $(call compile-htsjdk-cmd,vcfgo,${jvarkit.package}.tools.vcfgo.VcfGeneOntology))
$(eval $(call compile-htsjdk-cmd,vcfhead,${jvarkit.package}.tools.misc.VcfHead))
$(eval $(call compile-htsjdk-cmd,vcfin,${jvarkit.package}.tools.vcfcmp.VcfIn))
$(eval $(call compile-htsjdk-cmd,vcfjaspar,${jvarkit.package}.tools.jaspar.VcfJaspar))
$(eval $(call compile-htsjdk-cmd,vcfliftover,${jvarkit.package}.tools.liftover.VcfLiftOver))
$(eval $(call compile-htsjdk-cmd,vcfmapuniprot,${jvarkit.package}.tools.misc.VcfMapUniprot,${generated.dir}/java/org/uniprot/package-info.java))
$(eval $(call compile-htsjdk-cmd,vcfmerge,${jvarkit.package}.tools.vcfmerge.VCFMerge2))
$(eval $(call compile-htsjdk-cmd,vcfmulti2one,${jvarkit.package}.tools.onesamplevcf.VcfMultiToOne))
$(eval $(call compile-htsjdk-cmd,vcfpolyx,${jvarkit.package}.tools.misc.VCFPolyX))
$(eval $(call compile-htsjdk-cmd,vcfpredictions,${jvarkit.package}.tools.vcfannot.VCFAnnotator))
$(eval $(call compile-htsjdk-cmd,vcfrebase,${jvarkit.package}.tools.vcfrebase.VcfRebase))
$(eval $(call compile-cgi-cmd,vcfregistry.cgi))
$(eval $(call compile-htsjdk-cmd,vcfregulomedb,${jvarkit.package}.tools.misc.VcfRegulomeDB))
$(eval $(call compile-htsjdk-cmd,vcfrenamechr,${jvarkit.package}.tools.misc.ConvertVcfChromosomes))
$(eval $(call compile-htsjdk-cmd,vcfrenamesamples,${jvarkit.package}.tools.misc.VcfRenameSamples))
$(eval $(call compile-htsjdk-cmd,vcfresetvcf,${jvarkit.package}.tools.misc.VcfRemoveGenotypeIfInVcf))
$(eval $(call compile-htsjdk-cmd,vcfsetdict,${jvarkit.package}.tools.misc.VcfSetSequenceDictionary))
$(eval $(call compile-htsjdk-cmd,vcfshuffle,${jvarkit.package}.tools.misc.VCFShuffle))
$(eval $(call compile-htsjdk-cmd,vcfsimulator,${jvarkit.package}.tools.misc.VcfSimulator))
$(eval $(call compile-htsjdk-cmd,vcfstats,${jvarkit.package}.tools.vcfstats.VcfStats))
$(eval $(call compile-htsjdk-cmd,vcfstopcodon,${jvarkit.package}.tools.vcfannot.VCFStopCodon))
$(eval $(call compile-htsjdk-cmd,vcfstripannot,${jvarkit.package}.tools.vcfstripannot.VCFStripAnnotations))
$(eval $(call compile-htsjdk-cmd,vcftabixml,${jvarkit.package}.tools.vcftabixml.VCFTabixml))
$(eval $(call compile-htsjdk-cmd,vcftail,${jvarkit.package}.tools.misc.VcfTail))
$(eval $(call compile-htsjdk-cmd,vcftreepack,${jvarkit.package}.tools.treepack.VcfTreePack))
$(eval $(call compile-htsjdk-cmd,vcftrio,${jvarkit.package}.tools.vcftrios.VCFTrios))
$(eval $(call compile-htsjdk-cmd,vcfvcf,${jvarkit.package}.tools.vcfvcf.VcfVcf))
$(eval $(call compile-htsjdk-cmd,vcfviewgui,${jvarkit.package}.tools.vcfviewgui.VcfViewGui))
$(eval $(call compile-htsjdk-cmd,worldmapgenome,${jvarkit.package}.tools.circular.WorldMapGenome))
$(eval $(call compile-htsjdk-cmd,uniprotfilterjs,${jvarkit.package}.tools.misc.UniprotFilterJS,${generated.dir}/java/org/uniprot/package-info.java ))
$(eval $(call compile-htsjdk-cmd,skipxmlelements,${jvarkit.package}.tools.misc.SkipXmlElements))
$(eval $(call compile-htsjdk-cmd,minicaller,${jvarkit.package}.tools.calling.MiniCaller))
$(eval $(call compile-htsjdk-cmd,vcfcomparecallersonesample,${jvarkit.package}.tools.vcfcmp.VcfCompareCallersOneSample))
$(eval $(call compile-htsjdk-cmd,samretrieveseqandqual,${jvarkit.package}.tools.misc.SamRetrieveSeqAndQual))
$(eval $(call compile-htsjdk-cmd,vcfensemblvep,${jvarkit.package}.tools.ensembl.VcfEnsemblVepRest,api.ensembl.vep))
$(eval $(call compile-htsjdk-cmd,vcfgroupbypop,${jvarkit.package}.tools.misc.VcfGroupByPopulation))
$(eval $(call compile-htsjdk-cmd,vcfcomparecallers,${jvarkit.package}.tools.vcfcmp.VcfCompareCallers))
$(eval $(call compile-htsjdk-cmd,bamtile,${jvarkit.package}.tools.misc.BamTile))
$(eval $(call compile-htsjdk-cmd,xcontaminations,${jvarkit.package}.tools.xcontamination.XContaminations))
$(eval $(call compile-htsjdk-cmd,vcfjoinvcfjs,${jvarkit.package}.tools.vcffilterjs.VCFJoinVCFJS))
$(eval $(call compile_biostar_cmd,139647))
$(eval $(call compile-htsjdk-cmd,vcfburden,${jvarkit.package}.tools.misc.VcfBurden))
$(eval $(call compile-htsjdk-cmd,bioalcidae,${jvarkit.package}.tools.bioalcidae.BioAlcidae))
$(eval $(call compile-htsjdk-cmd,vcfbedsetfilter,${jvarkit.package}.tools.vcfbed.VCFBedSetFilter))
$(eval $(call compile-htsjdk-cmd,vcfreplacetag,${jvarkit.package}.tools.vcfstripannot.VCFReplaceTag))
$(eval $(call compile-htsjdk-cmd,vcfindextabix,${jvarkit.package}.tools.misc.VcfIndexTabix))
$(eval $(call compile-htsjdk-cmd,vcfpeekvcf,${jvarkit.package}.tools.vcfvcf.VcfPeekVcf))
$(eval $(call compile-htsjdk-cmd,vcfgetvariantbyindex,${jvarkit.package}.tools.misc.VcfGetVariantByIndex))
$(eval $(call compile-htsjdk-cmd,vcfmulti2oneallele,${jvarkit.package}.tools.misc.VcfMultiToOneAllele))
$(eval $(call compile-htsjdk-cmd,bedindextabix,${jvarkit.package}.tools.misc.BedIndexTabix))
$(eval $(call compile-htsjdk-cmd,vcf2bam,${jvarkit.package}.tools.misc.VcfToBam))
$(eval $(call compile-htsjdk-cmd,vcffilterxpath,${jvarkit.package}.tools.misc.VcfFilterXPath))
$(eval $(call compile-htsjdk-cmd,pcrclipreads,${jvarkit.package}.tools.pcr.PcrClipReads))
$(eval $(call compile-htsjdk-cmd,extendrefwithreads,${jvarkit.package}.tools.extendref.ExtendReferenceWithReads))
$(eval $(call compile-htsjdk-cmd,pcrslicereads,${jvarkit.package}.tools.pcr.PcrSliceReads))
$(eval $(call compile-htsjdk-cmd,samjmx,${jvarkit.package}.tools.jmx.SamJmx))
$(eval $(call compile-htsjdk-cmd,vcfjmx,${jvarkit.package}.tools.jmx.VcfJmx))
$(eval $(call compile-htsjdk-cmd,gtf2xml,${jvarkit.package}.tools.misc.Gtf2Xml))
$(eval $(call compile-htsjdk-cmd,sortsamrefname,${jvarkit.package}.tools.misc.SortSamRefName))





all-jnlp : $(addprefix ${dist.dir}/,$(addsuffix .jar,vcfviewgui buildwpontology batchigvpictures)) ${htsjdk.jars} \
	 ./src/main/resources/jnlp/generic.jnlp .secret.keystore 
	mkdir -p ${tmp.dir}
	cp $(filter %.jar,$^) ${tmp.dir}
	$(foreach J, $(filter %.jar,$^) , jarsigner ${J} secret ; ) 
	sed -e 's/__MAIN_JAR__/vcfviewgui/g' \
		-e 's/__TITLE__/VcfViewGui/g' \
		-e 's/__MAIN_CLASS__/${jvarkit.package}.tools.vcfviewgui.VcfViewGui/g' \
		 ./src/main/resources/jnlp/generic.jnlp > ${tmp.dir}/vcfviewgui.jnlp
	sed -e 's/__MAIN_JAR__/buildwpontology/g' \
		-e 's/__TITLE__/BuildWikipediaOntology/g' \
		-e 's/__MAIN_CLASS__/${jvarkit.package}.tools.misc.BuildWikipediaOntology/g' \
		 ./src/main/resources/jnlp/generic.jnlp > ${tmp.dir}/buildwpontology.jnlp
	sed -e 's/__MAIN_JAR__/batchigvpictures/g' \
		-e 's/__TITLE__/BatchIGVPictures/g' \
		-e 's/__MAIN_CLASS__/${jvarkit.package}.tools.batchpicts.BatchIGVPictures/g' \
		 ./src/main/resources/jnlp/generic.jnlp > ${tmp.dir}/batchigvpictures.jnlp

.secret.keystore : 
	 -keytool -genkeypair -keystore $@ -alias secret \
	 		-keypass $(if ${keytool.keypass},${keytool.keypass},KEYTOOLPASS) \
	 		-storepass $(if ${keytool.storepass},${keytool.storepass},KEYTOOLSTOREPASS) \
	 		-dname CN=Pierre Lindenbaum, OU=INSERM, O=INSERM, L=Nantes, ST=Nantes, C=Fr

${generated.dir}/java/org/uniprot/package-info.java : api.uniprot
api.uniprot :
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java -p org.uniprot ${xjc.proxy} "http://www.uniprot.org/support/docs/uniprot.xsd" 


api.ncbi.pubmed : 
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.pubmed -dtd ${xjc.proxy} http://www.ncbi.nlm.nih.gov/corehtml/query/DTD/pubmed_150101.dtd


api.evs:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java -p edu.washington.gs.evs ${xjc.proxy} -wsdl "http://evs.gs.washington.edu/wsEVS/EVSDataQueryService?wsdl"

api.ncbi.blast:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.blast -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/dtd/NCBI_BlastOutput.dtd"

api.ncbi.esearch:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.esearch -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/corehtml/query/DTD/eSearch_020511.dtd"

api.ncbi.elink:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.elink -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/entrez/query/DTD/elink_020122.dtd"


api.ncbi.gb:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.gb -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/dtd/NCBI_GBSeq.dtd"

api.ncbi.taxonomy:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.taxonomy -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/entrez/query/DTD/taxon.dtd"

api.ncbi.tseq:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.tseq -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/dtd/NCBI_TSeq.dtd"

api.ncbi.insdseq:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.insdseq -dtd ${xjc.proxy} "http://www.ncbi.nlm.nih.gov/dtd/INSD_INSDSeq.dtd"

api.ncbi.dbsnp.gt:
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p gov.nih.nlm.ncbi.dbsnp.gt ${xjc.proxy} "http://ftp.ncbi.nlm.nih.gov/snp/specs/genoex_1_5.xsd"
	


## API Ensembl
api.ensembl.vep :
	mkdir -p ${generated.dir}/java
	${XJC} -d ${generated.dir}/java  -p org.ensembl.vep  ./src/main/resources/xsd/ensembl/vep.xsd

	
api.printf:
	mkdir -p ${generated.dir}/java/com/github/lindenb/jvarkit/util/printf
	javacc -OUTPUT_DIRECTORY=${generated.dir}/java/com/github/lindenb/jvarkit/util/printf \
		src/main/resources/javacc/com/github/lindenb/jvarkit/util/printf/Printf.jj

copy.opendoc.odp.resources : 
	mkdir -p ${tmp.dir}/META-INF/opendocument/odp
	cp src/main/resources/opendocument/thumbnail.png ${tmp.dir}/META-INF/opendocument/odp/
	cp $(addprefix src/main/resources/opendocument/odp/, meta.xml content.xml settings.xml styles.xml mimetype ) ${tmp.dir}/META-INF/opendocument/odp/


## jvarkit-library (used in knime)
library: ${dist.dir}/jvarkit-${htsjdk.version}.jar
${dist.dir}/jvarkit-${htsjdk.version}.jar : ${htsjdk.jars} ${bigwig.jars} \
		${generated.dir}/java/com/github/lindenb/jvarkit/util/htsjdk/HtsjdkVersion.java \
		${src.dir}/com/github/lindenb/jvarkit/util/Library.java
	mkdir -p ${tmp.dir}/META-INF $(dir $@)
	cp src/main/resources/messages/messages.properties ${tmp.dir}
	${JAVAC} -d ${tmp.dir} -g -classpath "$(subst $(SPACE),:,$(filter %.jar,$^))" -sourcepath ${src.dir}:${generated.dir}/java $(filter %.java,$^)
	${JAR} cf $@ -C ${tmp.dir} .
	rm -rf ${tmp.dir}

##
## Download mysql connector for java
## 
${mysql.jar} :
	echo "Downloading mysql connector for java version ${mysql.version} from oracle"
	mkdir -p $(dir $@)
	curl -Lk ${curl.proxy} -o jeter.tar.gz "http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${mysql.version}.tar.gz" 
	tar xvfz  jeter.tar.gz  --strip-components=1 "mysql-connector-java-${mysql.version}/mysql-connector-java-${mysql.version}-bin.jar"
	mv mysql-connector-java-${mysql.version}-bin.jar $@
	rm jeter.tar.gz

##
## BerkeleyDB
## 
${berkeleydb.jar}:
	echo "Downloading berkeleydb for java version ${berkeleydb.version} from oracle"
	mkdir -p $(dir $@)
	curl -Lk ${curl.proxy} -o $@ "http://download.oracle.com/maven/com/sleepycat/je/${berkeleydb.version}/je-${berkeleydb.version}.jar"

##
## Broad BigWig
## 
${bigwig.log4j.jar} : ${bigwig.jar}
	touch -c $@

${bigwig.jar} xx :
	echo "Downloading bigwig library for java."
	mkdir -p lib
	rm -rf bigwig.zip bigwig-${bigwig.version}
	curl -k ${curl.proxy} -o bigwig.zip -L "https://github.com/lindenb/bigwig/archive/${bigwig.version}.zip"
	unzip bigwig.zip
	rm -rf bigwig.zip 
	echo "Compiling, using apache ant"
	(cd  bigwig-${bigwig.version} && ${ANT} )
	mv bigwig-${bigwig.version}/lib/$(notdir ${bigwig.log4j.jar}) ${bigwig.log4j.jar}
	mv bigwig-${bigwig.version}/dist/BigWig.jar ${bigwig.jar}
	rm -rf bigwig-${bigwig.version}
	


##
## Common math
##
${common.math.jar} :
	echo "Downloading common math"
	mkdir -p $(dir $@)
	curl -Lk ${curl.proxy} -o jeter.tar.gz "http://www.us.apache.org/dist/commons/math/binaries/commons-math3-${common.math.version}-bin.tar.gz"	
	tar xvfz  jeter.tar.gz  --strip-components=1 "commons-math3-${common.math.version}/commons-math3-${common.math.version}.jar"
	mv commons-math3-${common.math.version}.jar $@
	rm jeter.tar.gz

##
## Apache Stuf
##
$(addprefix lib/, commons-validator/commons-validator/1.4.0/commons-validator-1.4.0.jar commons-beanutils/commons-beanutils/1.8.3/commons-beanutils-1.8.3.jar ):
	mkdir -p $(dir $@) && curl -Lk ${curl.proxy} -o $@ "http://central.maven.org/maven2/$(patsubst lib/%,%,$@)"
	


##
## make sure jars from htslib exist
##
$(filter-out ${htsjdk.home}/dist/htsjdk-${htsjdk.version}.jar  ,${htsjdk.jars}) : ${htsjdk.home}/dist/htsjdk-${htsjdk.version}.jar 
	touch -c $@

${htsjdk.home}/dist/htsjdk-${htsjdk.version}.jar : ${htsjdk.home}/build.xml
	echo "Compiling htsjdk with $${JAVA_HOME} = ${JAVA_HOME}"
	echo "Compiling htsjdk library for java. Requires  apache ANT. If it fails here, it's a not a problem with jvarkit."
	echo "And $${JAVA_HOME}/bin/javac should be >=1.7"
	(cd ${htsjdk.home} && ${ANT} )

${htsjdk.home}/build.xml : 
	mkdir -p $(dir ${htsjdk.home})
	rm -rf $(dir $@) 
	echo "Downloading HTSJDK ${htsjdk.version} with curl"
	wget -N "https://github.com/samtools/htsjdk/archive/${htsjdk.version}.zip"
	unzip $(dir ${htsjdk.home})${htsjdk.version}.zip -d $(dir ${htsjdk.home})
	find ${htsjdk.home} -exec touch '{}'  ';'
	rm -f $(dir ${htsjdk.home})${htsjdk.version}.zip

${generated.dir}/java/com/github/lindenb/jvarkit/util/htsjdk/HtsjdkVersion.java : ${htsjdk.home}/build.xml $(realpath .git/refs/heads/master)
	mkdir -p $(dir $@)
	echo "package ${jvarkit.package}.util.htsjdk;" > $@
	echo '@javax.annotation.Generated("jvarkit")' >> $@
	echo 'public class HtsjdkVersion{ private HtsjdkVersion(){}' >> $@
	echo 'public static String getVersion() {return "${htsjdk.version}";}' >> $@
	echo 'public static String getHome() {return "${htsjdk.home}";}' >> $@
	echo 'public static String getJavadocUrl(Class<?> clazz) {return "https://samtools.github.io/htsjdk/javadoc/htsjdk/"+clazz.getName().replaceAll("\\.","/")+".html";}' >> $@
	echo '}'  >> $@

## API EVS
src/main/generated-sources/java/edu/washington/gs/evs/package-info.java :
	mkdir -p ${generated.dir}/java
	${JAVA_HOME}/bin/xjc ${xjc.proxy} -d ${generated.dir}/java \
		-p edu.washington.gs.evs \
		"http://evs.gs.washington.edu/wsEVS/EVSDataQueryService?wsdl"


##
## galaxy bundle
##
galaxy : ${galaxy.bundle.dir}.tar
${galaxy.bundle.dir}.tar : ${GALAXY_TOOLS} ${htsjdk.jars} 
	rm -f $@
	cp  $(foreach T,${GALAXY_TOOLS}, ${dist.dir}/${T}.jar )  $(filter %.jar, $^ ) ${galaxy.bundle.dir}/jvarkit
	tar cvf $@ -C ${galaxy.bundle.dir} .

#
# ga4gh schema, see 
# http://plindenbaum.blogspot.fr/2015/06/playing-with-ga4gh-schemas-and-avro-my.html
#
ga4gh.schemas.version ?= 0.5.1
ga4gh.schemas.avpr =  $(addsuffix .avpr,$(addprefix ${generated.dir}/resources/avro/ga4gh/schemas-${ga4gh.schemas.version}/src/main/resources/avro/,beacon common readmethods reads referencemethods references variantmethods variants wip/metadata wip/metadatamethods wip/variationReference ))

ga4gh.schemas.sources : lib/org/ga4gh/ga4gh-${ga4gh.schemas.version}.jar
lib/org/ga4gh/ga4gh-${ga4gh.schemas.version}.jar: ${avro.libs} ${ga4gh.schemas.avpr} 
	mkdir -p ${generated.dir}/java _tmp.avro${ga4gh.schemas.version} lib/org/ga4gh
	java -jar $< compile protocol \
		${generated.dir}/resources/avro/ga4gh/schemas-${ga4gh.schemas.version}/src/main/resources/avro \
		${generated.dir}/resources/avro/ga4gh/schemas-${ga4gh.schemas.version}/src/main/resources/avro/wip \
		${generated.dir}/java
	javac -d _tmp.avro${ga4gh.schemas.version} -cp ${avro.libs} -sourcepath ${generated.dir}/java ${generated.dir}/java/org/ga4gh/*.java
	jar cvf lib/org/ga4gh/ga4gh-${ga4gh.schemas.version}.jar -C _tmp.avro${ga4gh.schemas.version} .
	rm -rf _tmp.avro${ga4gh.schemas.version}
	 
	
$(filter-out $(word 1,${ga4gh.schemas.avpr}),${ga4gh.schemas.avpr}) : $(word 1,${ga4gh.schemas.avpr})
$(word 1,${ga4gh.schemas.avpr}) : ${avro.libs}
	rm -rf ${generated.dir}/resources/avro/ga4gh/schemas-${ga4gh.schemas.version}
	mkdir -p $(dir $@) 
	curl -Lk ${curl.proxy} -o schema.zip "https://github.com/ga4gh/schemas/archive/v${ga4gh.schemas.version}.zip"
	unzip schema.zip -d ${generated.dir}/resources/avro/ga4gh
	rm schema.zip	
	$(foreach P,${ga4gh.schemas.avpr}, java -jar ${avro.libs}  idl $(patsubst %.avpr,%.avdl,${P}) ${P} ; )
	touch $@

#
# end of ga4gh schema
#
#

clean:
	rm -rf ${dist.dir}

