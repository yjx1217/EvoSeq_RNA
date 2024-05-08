#!/usr/bin/perl
use warnings;
use strict;
use Getopt::Long;

my ($master_sample_table, $output, $batch_id, $quant_dir);

GetOptions('master_sample_table|i:s' => \$master_sample_table,
	   'output|o:s' => \$output,
	   'batch_id|b:s' => \$batch_id,
	   'quant_dir|q:s' => \$quant_dir);

my $master_sample_table_fh = read_file($master_sample_table);
my %samples = parse_master_sample_table($master_sample_table_fh);
my %samples_by_genes = ();
my $output_fh = write_file($output);

print $output_fh "";
foreach my $sample_id (sort keys %samples) {
    my $quant_file = "$quant_dir/$batch_id/$sample_id.genes_quant/quant.sf";
    my $quant_fh = read_file($quant_file);
    parse_quant_file($quant_fh, $sample_id, \%samples_by_genes);
    print $output_fh "\t$sample_id";
}
print $output_fh "\n";

foreach my $gene_id (sort keys %samples_by_genes) {
    print $output_fh "$gene_id";
    foreach my $sample_id (sort keys %{$samples_by_genes{$gene_id}}) {
	print $output_fh "\t$samples_by_genes{$gene_id}{$sample_id}";
    }
    print $output_fh "\n";
}


sub read_file {
    my $file = shift @_;
    my $fh;
    if ($file =~ /\.gz$/) {
        open($fh, "gunzip -c $file |") or die "can't open pipe to $file";
    }
    else {
        open($fh, $file) or die "can't open $file";
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

sub parse_master_sample_table {
    my $fh = shift @_;
    my %samples = ();
    while (<$fh>) {
	chomp;
	/^\s*$/ and next;
	/^#/ and next;
	/^sample_id\tR1_read/ and next;
	my ($sample_id, $PE_read_files, $biolgical_sample, $treatment_condition, $sampling_timepoint, $biological_replicate_id, $technical_replicate_id, $note) = split /\s+/, $_;
	$samples{$sample_id} = 1;
    }
    return %samples;
}

sub parse_quant_file {
    my ($fh, $sample_id, $samples_by_genes_hashref) = @_;
    while (<$fh>) {
	chomp;
	/^\s*$/ and next;
        /^#/ and next;
	/^gene_id\tcounts/ and next;
	my ($gene_id, $counts) = split /\t/, $_;
	$$samples_by_genes_hashref{$gene_id}{$sample_id} = $counts;
    }
}

