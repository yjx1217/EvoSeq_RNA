#!/bin/bash
set -e -o pipefail

#######################################
# load environment variables for EvoSeq
source ./../../env.sh

#######################################
# set project-specific variables
species="human" # The species name prefix for the reference genome. Default = "human".
ref_genome_version="GRCh38" # The assembly version of the reference genome. Default = "GRCh38".
ref_genome_download_URL="ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_${species}/release_38/${ref_genome_version}.primary_assembly.genome.fa.gz" # The downloading URL for the refernece genome (in .fa or .fa.gz format). Default = "ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_${species}/release_38/${ref_genome_version}.primary_assembly.genome.fa.gz"
ref_annotation_download_URL="ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_${species}/release_38/gencode.v38.primary_assembly.annotation.gtf.gz" # The downloading URL for the reference gene annotation (in gtf or gtf.gz format). Default = "ftp://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_${species}/release_38/gencode.v38.primary_assembly.annotation.gtf.gz"
threads=4 # The number of threads to use. Default = 4.
############################################################


############################################################
# normally, no need to change the following parameters
salmon_k=31 # The k-mer size to be used for Salmon. Default = 31.
ERCC_fa="./../../data/ERCC92.fa" 
ERCC_gtf="./../../data/ERCC92.gtf"
############################################################


if [[ ! -e ref.genome.raw.fa ]]
then
    if [[ $ref_genome_download_URL =~ \.gz$ ]]
    then
	wget -c --no-check-certificate $ref_genome_download_URL -O  ref.genome.raw.fa.gz
	gunzip -c ref.genome.raw.fa.gz > ref.genome.raw.fa
    else
	wget -c --no-check-certificate $ref_genome_download_URL -O  ref.genome.raw.fa
    fi
fi

if [[ ! -e ref.genome.raw.gtf ]]
then
    if [[ $ref_annotation_download_URL =~ \.gz$ ]]
    then
	wget -c --no-check-certificate $ref_annotation_download_URL -O ref.genome.raw.gtf.gz
	gunzip -c ref.genome.raw.gtf.gz > ref.genome.raw.gtf
    else
	wget -c --no-check-certificate $ref_annotation_download_URL -O ref.genome.raw.gtf
    fi
fi


if [[ ! -d tmp ]]
then
    mkdir tmp
fi

perl $EVOSEQ_HOME/scripts/tidy_fasta.pl -i ref.genome.raw.fa -o ref.genome.fa
perl $EVOSEQ_HOME/scripts/tidy_id_in_ensembl_gtf.pl -i ref.genome.raw.gtf -o ref.genome.gtf
# combine reference genome with ERCC
cat $ERCC_fa >> ref.genome.fa
cat $ERCC_gtf >> ref.genome.gtf

perl $EVOSEQ_HOME/scripts/transcript2gene_map_by_ensembl_gtf.pl -i ref.genome.gtf -o ref.transcript2gene_map.txt -ignore_version_number yes


if [[ "$debug" == "no" ]]
then
    rm ref.genome.raw.fa
    rm ref.genome.raw.gtf
fi


# get cDNA sequence
$gffread_dir/gffread ref.genome.gtf -g ref.genome.fa -w ref.transcriptome.fa

# index genome
$samtools_dir/samtools faidx ref.genome.fa
$java_dir/java -Djava.io.tmpdir=./tmp -Dpicard.useLegacyParser=false -jar $picard_dir/picard.jar CreateSequenceDictionary -R ref.genome.fa -O ref.genome.dict

# index cDNA with Salmon-SMEM
mkdir SalmonIndex

# extracting exonic features from the gtf"
awk -v OFS='\t' '{if ($3=="exon") {print $1,$4,$5}}' ref.genome.gtf > ref.exons.bed

# masking the exonic regions from the genome
$bedtools_dir/bedtools maskfasta -fi ref.genome.fa -bed ref.exons.bed -fo ref.genome.exon_masked.fa

# aligning the transcriptome to the masked genome
$samtools_dir/samtools faidx ref.genome.exon_masked.fa
$mashmap_dir/mashmap -r ref.genome.exon_masked.fa -q ref.transcriptome.fa -t $threads --pi 80 -s 500 

# extracting the bed files from the reported alignment
awk -v OFS='\t' '{print $6,$8,$9}' mashmap.out | sort -k1,1 -k2,2n - > ref.genome_found.sorted.bed

# merging the reported intervals
$bedtools_dir/bedtools merge -i ref.genome_found.sorted.bed > ref.genome_found_merged.bed

# extracting relevant sequence from the genome
$bedtools_dir/bedtools getfasta -fi ref.genome.exon_masked.fa -bed ref.genome_found_merged.bed -fo ref.genome_found.fa

# concatenating the sequence at per chromsome level to extract decoy sequences
awk '{a=$0; getline;split(a, b, ":");  r[b[1]] = r[b[1]]""$0} END { for (k in r) { print k"\n"r[k] } }' ref.genome_found.fa > ref.decoy.fa

# concatenating decoys to transcriptome
cat ref.transcriptome.fa ref.decoy.fa > ref.gentrome.fa

# extracting the names of the decoys
grep ">" ref.decoy.fa | awk '{print substr($1,2); }' > ref.decoys.txt


# clean up intermediate files
if [[ $debug == "no" ]]
then
    rm exons.bed 
    rm ref.genome.exon_masked.fa
    rm mashmap.out
    rm ref.genome_found.sorted.bed
    rm ref.genome_found_merged.bed
    rm ref.genome_found.fa
    rm ref.decoys.fa
    rm ref.genome.exon_masked.fa.fai
fi

$salmon_dir/salmon index -t ref.gentrome.fa -i SalmonIndex --decoys ref.decoys.txt -p $threads -k $salmon_k  

rm -r tmp



############################
# checking bash exit status
if [[ $? -eq 0 ]]
then
    echo ""
    echo "#########################################################################"
    echo ""
    echo "EvoSeq message: This bash script has been successfully processed! :)"
    echo ""
    echo "#########################################################################"
    echo ""
    exit 0
fi
############################
