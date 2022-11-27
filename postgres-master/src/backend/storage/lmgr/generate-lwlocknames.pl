#!/usr/bin/perl
#
# Generate lwlocknames.h and lwlocknames.c from lwlocknames.txt
# Copyright (c) 2000-2022, PostgreSQL Global Development Group

use strict;
use warnings;
use Getopt::Long;

my $output_path = '.';

my $lastlockidx = -1;
my $continue    = "\n";

GetOptions(
	'outdir:s'       => \$output_path);

open my $lwlocknames, '<', $ARGV[0] or die;

# Include PID in suffix in case parallel make runs this multiple times.
my $htmp = "$output_path/lwlocknames.h.tmp$$";
my $ctmp = "$output_path/lwlocknames.c.tmp$$";
open my $h, '>', $htmp or die "Could not open $htmp: $!";
open my $c, '>', $ctmp or die "Could not open $ctmp: $!";

my $autogen =
  "/* autogenerated from src/backend/storage/lmgr/lwlocknames.txt, do not edit */\n";
print $h $autogen;
print $h "/* there is deliberately not an #ifndef LWLOCKNAMES_H here */\n\n";
print $c $autogen, "\n";

print $c "const char *const IndividualLWLockNames[] = {";

while (<$lwlocknames>)
{
	chomp;

	# Skip comments
	next if /^#/;
	next if /^\s*$/;

	die "unable to parse lwlocknames.txt"
	  unless /^(\w+)\s+(\d+)$/;

	(my $lockname, my $lockidx) = ($1, $2);

	my $trimmedlockname = $lockname;
	$trimmedlockname =~ s/Lock$//;
	die "lock names must end with 'Lock'" if $trimmedlockname eq $lockname;

	die "lwlocknames.txt not in order"   if $lockidx < $lastlockidx;
	die "lwlocknames.txt has duplicates" if $lockidx == $lastlockidx;

	while ($lastlockidx < $lockidx - 1)
	{
		++$lastlockidx;
		printf $c "%s	\"<unassigned:%d>\"", $continue, $lastlockidx;
		$continue = ",\n";
	}
	printf $c "%s	\"%s\"", $continue, $trimmedlockname;
	$lastlockidx = $lockidx;
	$continue    = ",\n";

	print $h "#define $lockname (&MainLWLockArray[$lockidx].lock)\n";
}

printf $c "\n};\n";
print $h "\n";
printf $h "#define NUM_INDIVIDUAL_LWLOCKS		%s\n", $lastlockidx + 1;

close $h;
close $c;

rename($htmp, "$output_path/lwlocknames.h") || die "rename: $htmp to $output_path/lwlocknames.h: $!";
rename($ctmp, "$output_path/lwlocknames.c") || die "rename: $ctmp: $!";

close $lwlocknames;