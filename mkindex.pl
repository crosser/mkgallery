#!/usr/bin/perl

# $Id$

# Create per-month index assuming that directory structure is ./YYYY/MM/...
# non-four-numeric subtis are put on a separate list.
# Output to stdout (redirect >index.html if you wish)

# Copyright (c) 2006 Eugene G. Crosser

#  This software is provided 'as-is', without any express or implied
#  warranty.  In no event will the authors be held liable for any damages
#  arising from the use of this software.
#
#  Permission is granted to anyone to use this software for any purpose,
#  including commercial applications, and to alter it and redistribute it
#  freely, subject to the following restrictions:
#
#  1. The origin of this software must not be misrepresented; you must not
#     claim that you wrote the original software. If you use this software
#     in a product, an acknowledgment in the product documentation would be
#     appreciated but is not required.
#  2. Altered source versions must be plainly marked as such, and must not be
#     misrepresented as being the original software.
#  3. This notice may not be removed or altered from any source distribution.

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
