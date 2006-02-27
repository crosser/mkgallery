#!/usr/bin/perl

use strict;
use Carp;
use CGI qw/:html *table *Tr *center/;

my @years=();
my @subdirs=();

opendir(D,'.') || die "cannot open current directory: $!";
while (my $de=readdir(D)) {
	next if ($de =~/^\./);
	next unless (-d $de);
	if ($de =~ /^\d\d\d\d$/) {
		push(@years,$de);
	} else {
		push(@subdirs,$de);
	}
}
closedir(D);

my @mn=(
	'',
	'Jan',
	'Feb',
	'Mar',
	'Apr',
	'May',
	'Jun',
	'Jul',
	'Aug',
	'Sep',
	'Oct',
	'Nov',
	'Dec',
);

print start_html(-title=>'Gallery'),"\n";
print start_center,"\n";
print h1("Gallery Index"),"\n";
print start_table({-cellspacing=>3}),"\n";
foreach my $yr(sort @years) {
	print start_Tr,"\n";
	print td({-bgcolor=>"#ffc0ff"},$yr);
	for (my $mo=1;$mo<=12;$mo++) {
		my $dir=sprintf "%04d/%02d",$yr,$mo;
		if (-d $dir) {
			print td({-bgcolor=>"#ffffc0"},a({-href=>$dir.'/'},$mn[$mo]));
		} else {
			print td({-bgcolor=>"#c0c0c0"},$mn[$mo]);
		}
	}
	print end_Tr,"\n";
}
print end_table,p,"\n";

print start_table({-cellspacing=>3}),"\n";
foreach my $sub(sort @subdirs) {
	print Tr(td({-bgcolor=>"#ffffc0"},a({-href=>$sub.'/'},$sub)));
}
print end_table,"\n";

print end_center,"\n";
print end_html,"\n";
