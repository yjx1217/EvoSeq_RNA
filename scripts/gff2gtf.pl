#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

my ($input, $output);

GetOptions('input|i:s' => \$input,
           'output|o:s' => \$output);

my $input_fh = read_file($input);
my $output_fh = write_file($output);

my ($gene_id, $transcript_id, $protein_id, $gene_name);
# my $exon_number;
my $info;

while (<$input_fh>) {
    chomp;
    /^\s*$/ and next;
    /^#/ and next;
    my ($chr, $source, $type, $start, $end, $score, $strand, $frame, $attribute) = split /\t/, $_;
    my @attribute = split /;/, $attribute;
    my ($id) = ($attribute[0] =~ /ID=([^;]+)/);
    if ($type eq 'gene') {
	$gene_id = $id;
	($gene_name) = ($attribute[1] =~ /Name=([^;]+)/);
	if ($gene_name eq "NA") {
	    $gene_name = $gene_id;
	}
	$info = "gene_id \"$gene_id\"; gene_name \"$gene_name\"; gene_biotype \"protein_coding\";";
    } elsif ($type eq 'mRNA') {
	$transcript_id = $id;
	$info = "gene_id \"$gene_id\"; transcript_id \"$transcript_id\"; gene_name \"$gene_name\";";
    } elsif ($type eq 'exon') {
	# ($exon_number) = ($id =~ /\.exon\.(\d+)/);
	# $info = "gene_id \"$gene_id\"; transcript_id \"$transcript_id\"; exon_number \"$exon_number\"; gene_name \"$gene_name\";";
	$info = "gene_id \"$gene_id\"; transcript_id \"$transcript_id\"; gene_name \"$gene_name\";";
    } elsif ($type eq 'CDS') {
        # ($exon_number) = ($id =~ /\.CDS\.(\d+)/);
        # $info = "gene_id \"$gene_id\"; transcript_id \"$transcript_id\"; exon_number \"$exon_number\"; gene_name \"$gene_name\";";
	$info = "gene_id \"$gene_id\"; transcript_id \"$transcript_id\"; gene_name \"$gene_name\";";
    } else {
       	$gene_id = $id;
	($gene_name) = ($attribute[1] =~ /Name=([^;]+)/);
	$info = "gene_id \"$gene_id\"; gene_name \"$gene_name\"; gene_biotype \"$type\";";
    }
    print $output_fh "$chr\t$source\t$type\t$start\t$end\t$score\t$strand\t$frame\t$info\n";
}

close $input_fh;
close $output_fh;

sub read_file {
    my $file = shift @_;
    my $fh;
    if ($file =~ /\.gz$/) {
        open($fh, "gunzip -c $file |") || die "can't open pipe to $file";
    } else {
        open($fh, $file) || die "can't open $file";
    }
    return $fh;
}

sub write_file {
    my $file = shift @_;
    my $fh;
    if ($file =~ /\.gz$/) {
	open($fh, "| gzip -c >$file") or die "can't open $file\n";
    } else {
	open($fh, ">$file") or die "can't open $file\n";
    }
    return $fh;
}  

