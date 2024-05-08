#! /usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

##############################################################
#  script: tidy_table.pl
#  author: Jia-Xing Yue (GitHub ID: yjx1217)
#  last edited: 2019.08.16
#  description: tidy up space separated table
#  example: perl tidy_table.pl -i input.txt(.gz) -o output.txt(.gz)
##############################################################

my ($input, $output);
GetOptions('input|i:s' => \$input, # input genome fasta file
	   'output|o:s' => \$output);

my $input_fh = read_file($input);
my $output_fh = write_file($output);

while (<$input_fh>) {
    chomp;
    /^\s*$/ and next;
    /^#/ and next;
    my @line = split /\s+/, $_;
    my $line = join "\t", @line;
    print $output_fh "$line\n";
}


sub read_file {
    my $file = shift @_;
    my $fh;
    if ($file =~ /\.gz$/) {
        open($fh, "gunzip -c $file |") or die "can't open pipe to $file";
    } else {
        open($fh, $file) or die "can't open $file";
    }
    return $fh;
}

sub write_file {
    my $file = shift @_;
    my $fh;
    if ($file =~ /.gz$/) {
        open($fh, "| gzip -c >$file") or die "can't open $file\n";
    } else {
        open($fh, ">$file") or die "can't open $file\n";
    }
    return $fh;
}  

