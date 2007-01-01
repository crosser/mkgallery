#!/usr/bin/perl

# $Id: mkgallery.pl 38 2006-12-17 09:39:01Z crosser $

# Build initial (empty) RSS file for mkgallery.pl

# Copyright (c) 2007 Eugene G. Crosser

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
use Term::ReadLine;
use XML::RSS;
use Getopt::Long;
use Encode;
use encoding 'utf-8';
binmode(STDOUT, ":utf8");

######################################################################

my $debug = 0;
my $rssfile = "";

unless (GetOptions(
		'help'=>\&help,
		'rssfile=s'=>\$rssfile,
		'debug'=>\$debug)) {
	&help;
}

sub help {

	print STDERR <<__END__;
usage: $0 [options]
 --help:        print help message and exit
 --incpath:     do not try to find .include diretory upstream, use
                specified path (absolute or relavive).  Use with causion.
 --debug:       print a lot of debugging info to stdout as you run
 --asktitle:    ask to edit album titles even if there are ".title" files
 --noasktitle:  don't ask to enter album titles even where ".title"
                files are absent.  Use partial directory names as titles.
 --rssfile=...:	build RSS feed for newly added "albums", give name of rss file
__END__

	exit 1;
}

unless ($rssfile) {
	print STDERR "you must specify --rssfile\n";
	exit 1;
}

my $term = new Term::ReadLine "Edit RSS Attribute";

my $rssobj = new XML::RSS (version=>'2.0');
die "could not build new RSS object" unless ($rssobj);

my $OUT = $term->OUT || \*STDOUT;
print $OUT "Enter attributes for this gallery RSS feed\n";
my $title = $term->readline('Feed title >','');
$term->addhistory($title) if ($title);
my $link = $term->readline('Gallery root URL >','');
$term->addhistory($link) if ($link);
my $desc = $term->readline('Gallery description >','');
$term->addhistory($desc) if ($desc);

$rssobj->channel(
		title=>$title,
		link=>$link,
		description=>$desc,
		#language=>$language,
		#rating=>$rating,
		#copyright=>$copyright,
		#pubDate=>$pubDate,
		#lastBuildDate=>$lastBuild,
		#docs=>$docs,
		#managingEditor=>$editor,
		#webMaster=>$webMaster
		);
$rssobj->save($rssfile);
