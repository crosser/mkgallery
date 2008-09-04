#!/usr/bin/perl
# $Id$
#
# customizable class to generate html around the gallery index

package Chrome;

use strict;

# Boilerplate. Do not change this (unless you know better).

sub new {
	my $this=shift;
	my $self;
	my $parm=shift;
	if (ref($this)) {
		die "$this::new should not be called as instance method";
	} else {
		$self={
			-title		=> $parm->{-title},
			-depth		=> $parm->{-depth},
			-breadcrumbs	=> $parm->{-breadcrumbs},
		};
	}
	bless $self,$this;
	return $self;
}

# Public methods. Replace this with what suits you.

sub header {
	my $self=shift;
	return $self{-depth}?
		"<div class=\"uplink\"><a href=\"../index.html\">UP</a></div>":
		"".
		"<h1 class=\"title\">$self{-title}</h1>";
}

sub axheader {
	my $self=shift;
	return "<h2 class=\"alisthdr\">Albums</h2>";
}

sub ixheader {
	my $self=shift;
	return "<h2 class=\"ilisthdr\">Images</h2>";
}

sub footer {
	my $self=shift;
	return "<hr class=\"footer\" />";
}
