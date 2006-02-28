#!/usr/bin/perl

# $Id$

# Recursively create image gallery index and slideshow wrappings.
# Makes use of (slightly modified) "lightbox" Javascript/CSS as published
# at http://www.huddletogether.com/projects/lightbox/

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

package FsObj;

use strict;
use Carp;
use POSIX qw/getcwd/;
use CGI qw/:html *table *center *div/;
use Image::Info qw/image_info dim/;
use Term::ReadLine;
use Getopt::Long;

use Image::Magick;

my @sizes = (160, 640);

######################################################################

my $debug = 0;
my $asktitle = 0;
my $noasktitle = 0;

GetOptions('asktitle'=>\$asktitle,
		'noasktitle'=>\$noasktitle,
		'debug'=>\$debug);

my $term = new Term::ReadLine "Edit Title";

FsObj->new(getcwd)->iterate;

sub new {
	my $this = shift;
	my $class;
	my $self;
	if (ref($this)) {
		$class = ref($this);
		my $parent = $this;
		my $name = shift;
		my $fullpath = $parent->{-fullpath}.'/'.$name;
		$self = {
				-parent=>$parent,
				-root=>$parent->{-root},
				-base=>$name,
				-fullpath=>$fullpath,
				-inc=>'../'.$parent->{-inc},
			};
	} else {
		$class = $this;
		my $root=shift;
		$self = {
				-root=>$root,
				-fullpath=>$root,
				-inc=>getinc($root),
			};
	}
	bless $self, $class;
	if ($debug) {
		print "new $class:\n";
		foreach my $k(keys %$self) {
			print "\t$k\t=\t$self->{$k}\n";
		}
	}
	return $self;
}

sub getinc {
	my $fullpath=shift;	# this is not a method
	my $depth=20;		# arbitrary max depth

	my $inc=".include";
	while ( ! -d $fullpath."/".$inc ) {
		$inc = "../".$inc;
		last unless ($depth-- > 0);
	}
	if ($depth > 0) {
		return $inc.'/';		# prefix with trailing slash
	} else {
		return 'NO-.INCLUDE-IN-PATH/';	# won't work anyway
	}
}

sub iterate {
	my $self = shift;
	my $fullpath .= $self->{-fullpath};
	print "iterate in dir $fullpath\n" if ($debug);

	my @rdirlist;
	my @rimglist;
	my $D;
	unless (opendir($D,$fullpath)) {
		warn "cannot opendir $fullpath: $!";
		return;
	}
	while (my $de = readdir($D)) {
		next if ($de =~ /^\./);
		my $child = $self->new($de);
		if ($child->isdir) {
			push(@rdirlist,$child);
		} elsif ($child->isimg) {
			push(@rimglist,$child);
		}
	}
	closedir($D);
	my @dirlist = sort {$a->{-base} cmp $b->{-base}} @rdirlist;
	undef @rdirlist; # inplace sorting would be handy here
	my @imglist = sort {$a->{-base} cmp $b->{-base}} @rimglist;
	undef @rimglist; # optimize away unsorted versions

# 1. first of all, fill title for this directory and create hidden subdirs

	$self->initdir;

# 2. iterate through subdirectories to get their titles filled
#    before we start writing out subalbum list

	foreach my $dir(@dirlist) {
		print "Dir: $dir->{-fullpath}\n" if ($debug);
		$dir->iterate;
	}

# 3. start building index.html for the directory
# 4. iterate through subdirectories to build subalbums list
# 5. iterate through images to build cross-links

	foreach my $img(@imglist) {
		print "Img: $img->{-fullpath}\n" if ($debug);
	}

# 6. iterate through images to build thumb list and aux html files
# 7. comlplete building index.html for the directory

}

sub isdir {
	my $self = shift;
	return ( -d $self->{-fullpath} );
}

sub isimg {
	my $self = shift;
	my $fullpath = $self->{-fullpath};
	return 0 unless ( -f $fullpath );
	my $info = image_info($fullpath);
	if (my $error = $info->{error}) {
		if (($error !~ "Unrecognized file format") &&
		    ($error !~ "Can't read head")) {
			warn "File \"$fullpath\": $error\n";
		}
		return 0;
	}
	$self->{-isimg} = 1;
	$self->{-info} = $info;
	return 1;
}

sub initdir {
	my $self = shift;
	my $fullpath = $self->{-fullpath};
	for my $subdir(@sizes, 'html') {
		my $tdir=sprintf "%s/.%s",$self->{-fullpath},$subdir;
		mkdir($tdir,0755) unless ( -d $tdir );
	}
	$self->edittitle;
}

sub edittitle {
	my $self = shift;
	my $fullpath = $self->{-fullpath};
	my $title;
	my $T;
	if (open($T,'<'.$fullpath.'/.title')) {
		$title = <$T>;
		$title =~ s/[\r\n]*$//;
		close($T);
	}
	if ($asktitle || (!$title && !$noasktitle)) {
		my $prompt = $self->{-base};
		$prompt = '/' unless ($prompt);
		my $OUT = $term->OUT || \*STDOUT;
		print $OUT "Enter title for $fullpath\n";
		$title = $term->readline($prompt.' >',$title);
		$term->addhistory($title) if ($title);
		if (open($T,'>'.$fullpath.'/.title')) {
			print $T $title,"\n";
			close($T);
		}
	}
	unless ($title) {
		$title=substr($fullpath,length($self->{-root}))
	}
	$self->{-title}=$title;
	print "title in $fullpath is $title\n" if ($debug);
}

######################################################################
=cut
######################################################################

&processdir(getcwd);

sub processdir {
	my ($start,$dir)=@_;
	my $dn=$start;
	$dn .= "/".$dir if ($dir);
	unless ( -d $dn ) {
		warn "not a directory: $dn";
		return;
	}
	my $D;
	unless (opendir($D,$dn)) {
		warn "cannot opendir $dn: $!";
		return;
	}

# recurse into subdirectories BEFORE opening index file

	&iteratedir($D,$start,$dir,sub {
		my ($start,$dir,$base)=@_;
		my $ndir = $dir;
		$ndir .= "/" if ($ndir);
		$ndir .= $base;
		return unless ( -d $start."/".$ndir );
		&processdir($start,$ndir);
	});

# fill in title

	my $title=&gettitle($dn,$dir);

# get include prefix

	my $inc=&getinclude($dn);

# generate directory index unless suppressed

	if ( -e $dn."/.noindex" ) {
		open(STDOUT,">/dev/null");
	} else {
		open(STDOUT,">".$dn."/index.html");
	}

# write HTML header

	print start_html(-title => $title,
			-style=>{-src=>[$inc."gallery.css",
					$inc."lightbox.css"]},
			-script=>[{-code=>"var incPrefix='$inc';"},
				{-src=>$inc."gallery.js"},
				{-src=>$inc."lightbox.js"}]),"\n";
	print a({-href=>"../index.html"},"UP");
	print start_center,"\n";
	print h1($title),"\n";

# create list of sub-albums

	my $hassubdirs=0;
	&iteratedir($D,$start,$dir,sub {
		my ($start,$dir,$base)=@_;
		my $en=sprintf("%s/%s/%s",$start,$dir,$base);
		return unless ( -d $en );
		unless ($hassubdirs) {
			print hr,h2("Albums"),start_table,"\n";
			$hassubdirs=1;
		}
		&subalbum($base,&gettitle($en,$dir."/".$base));
	});
	print end_table,hr,"\n" if ($hassubdirs);

# create picture gallery

	my @piclist=();
	my @infolist=();

	my $haspics=0;
	&iteratedir($D,$start,$dir,sub {
		my ($start,$dir,$base)=@_;
		my $en=sprintf("%s/%s/%s",$start,$dir,$base);
		return unless ( -f $en );
		my $info = image_info($en);
		if (my $error = $info->{error}) {
			if (($error !~ "Unrecognized file format") &&
			    ($error !~ "Can't read head")) {
				print STDERR "File \"$en\": $error\n";
			}
			return;
		}
		if (&processfile($start,$dir,$base,$en,$info)) {
			$haspics=1;
			push(@piclist,$base);
			push(@infolist,$info);
		}
	});

# write HTML footer

	print br({-clear=>"all"}),"\n";
	print a({-href=>".html/".$piclist[0]."-slide.html"},"Slideshow");
	print hr,"\n" if ($haspics);
	print end_center,"\n";
	print end_html,"\n";

	close(STDOUT);
	closedir($D);

# generate html files for slideshow from @piclist

	for (my $i=0;$i<=$#piclist;$i++) {
		my $base=$piclist[$i];
		my $pbase;
		my $nbase;
		$pbase=$piclist[$i-1] if ($i>0);
		$nbase=$piclist[$i+1] if ($i<$#piclist);
		for my $refresh('static','slide') {
			&mkauxfile($start,$dir,$pbase,$base,$nbase,
					$refresh,$infolist[$i]);
		}
	}

}

#############################################################
# helper functions
#############################################################

sub iteratedir {
	my ($D,$start,$dir,$prog)=@_;
	my @list=();
	while (my $de=readdir($D)) {
		next if ($de =~ /^\./);
		push(@list,$de);
	}
	foreach my $de(sort @list) {
		&$prog($start,$dir,$de);
	}
	rewinddir($D);
}

sub getinclude {
	my ($dn)=@_;

	my $depth=20;
	my $str="";
	#print STDERR "start include ",$dn."/".$str.".include","\n";
	while ( ! -d $dn."/".$str.".include" ) {
		#print STDERR "not include ",$dn."/".$str.".include","\n";
		$str.="../";
		last unless ($depth--);
	}
	#print STDERR "end include ",$dn."/".$str.".include","\n";
	if ( -d $dn."/".$str.".include" ) {
		#print STDERR "return include ".$str.".include/".$fn,"\n";
		return $str.".include/";
	} else {
		return ""; # won't work anyway but return something
	}
}

sub gettitle {
	my ($dir,$dflt)=@_;

	my $F;
	my $str;
	if (open($F,"<".$dir."/.title")) {
		$str=<$F>;
		chop $str;
		close($F);
	} else {
		print STDERR "enter title for $dir\n";
		$str=<>;
		if ($str =~ /^\s*$/) {
			$str=$dflt;
		}
		if (open($F,">".$dir."/.title")) {
			print $F $str,"\n";
			close($F);
		} else {
			print STDERR "cant open .title in $dir for writing: $!";
		}
	}
	return $str;
}

sub subalbum {
	my ($base,$title)=@_;

	print Tr({-bgcolor=>"#c0c0c0"},
		td(a({-href=>$base."/index.html"},$base)),
		td(a({-href=>$base."/index.html"},$title))),"\n";
}

sub processfile {
	my ($start,$dir,$base,$fn,$info)=@_;

	my ($w,$h) = dim($info);
	my $title=$info->{'Comment'};
	$title=$base unless ($title);
	my $thumb=&scale($start,$dir,$base,$fn,160,$info);
	my $medium=&scale($start,$dir,$base,$fn,640,$info);
	print &infobox($info,$base,$fn),"\n";
	print table({-class=>'slide'},Tr(td(
		a({-href=>".html/$base-info.html",
			-onClick=>"return showIbox('$base');"},$title),
		br,
		a({-href=>$medium,-rel=>"lightbox",-title=>$title},
			img({-src=>$thumb})),
		br,
		a({-href=>$base},"($w x $h)"),
		br))),"\n";
	return 1;
}

sub infobox {
	my ($info,$base,$fn)=@_;

	my @infokeys=(
		'DateTime',
		'ExposureTime',
		'FNumber',
		'Flash',
		'ISOSpeedRatings',
		'MeteringMode',
		'ExposureProgram',
		'FocalLength',
		'FileSource',
		'Make',
		'Model',
		'Software',
	);

	my $msg=start_div({-class=>'ibox',-id=>$base,-OnClick=>"HideIbox('$base');"});
	$msg.=span({-style=>'float: left;'},"Info for $base").
		span({-style=>'float: right;'},
			a({-href=>"#",-OnClick=>"HideIbox('$base');"},"Close"));
	$msg.=br({-clear=>'all'});
	$msg.=start_table;
	foreach my $k(@infokeys) {
		$msg.=Tr(td($k.":"),td($info->{$k}));
	}
	$msg.=end_table;
	$msg.=end_div;
	return $msg;
}

sub mkauxfile {
	my ($start,$dir,$pbase,$base,$nbase,$refresh,$info) =@_;
	my $en=sprintf("%s/%s/.html/%s-%s.html",$start,$dir,$base,$refresh);
	my $pref;
	my $nref;
	if ($pbase) {
		$pref=sprintf("%s-%s.html",$pbase,$refresh);
	} else {
		$pref="../index.html";
	}
	if ($nbase) {
		$nref=sprintf("%s-%s.html",$nbase,$refresh);
	} else {
		$nref="../index.html";
	}
	my $toggle;
	my $toggleref;
	if ($refresh eq 'slide') {
		$toggle='Stop!';
		$toggleref=sprintf("%s-static.html",$base);
	} else {
		$toggle='Play-&gt;';
		$toggleref=sprintf("%s-slide.html",$base);
	}

	my $tdir=sprintf "%s/%s/.html",$start,$dir;
	mkdir($tdir,0755) unless ( -d $tdir );

	unless (open(STDOUT,">".$en)) {
		warn "cannot open $en: $!";
		return;
	}
	my $title=$info->{'Comment'};
	$title=$base unless ($title);
	if ($refresh eq 'slide') {
		print start_html(-title=>$title,
				-bgcolor=>"#808080",
			-head=>meta({-http_equiv=>'Refresh',
				-content=>"3; url=$nref"})),"\n";
	} else {
		print start_html(-title=>$title,
				-bgcolor=>"#808080"),"\n";
	}
	print start_center,"\n";
	print h1($title);
	print a({-href=>"../index.html"},"Index")," | ";
	print a({-href=>$pref},"&lt;&lt;Prev")," | ";
	print a({-href=>$toggleref},$toggle)," | ";
	print a({-href=>$nref},"Next&gt;&gt;");
	print p;
	print img({-src=>"../.640/".$base}),"\n";
	print end_center,"\n";
	print end_html,"\n";
	close(STDOUT);
}

sub scale {
	my ($start,$dir,$base,$fn,$tsize,$info)=@_;
	my ($w,$h) = dim($info);
	my $max=($w>$h)?$w:$h;
	my $factor=$tsize/$max;

	return $base if ($factor >= 1);

	my $tdir=sprintf "%s/%s/.%s",$start,$dir,$tsize;
	mkdir($tdir,0755) unless ( -d $tdir );
	my $tbase=sprintf ".%s/%s",$tsize,$base;
	my $tfn=sprintf "%s/%s",$tdir,$base;
	my @sstat=stat($fn);
	my @tstat=stat($tfn);
	return $tbase if (@tstat && ($sstat[9] < $tstat[9])); # [9] -> mtime

	print STDERR "scale by $factor from $fn to $tfn\n";
	&doscaling($fn,$tfn,$factor,$w,$h);
	return $tbase;
}

sub doscaling {
	my ($src,$dest,$factor,$w,$h)=@_;

	my $im=new Image::Magick;
	my $err;
	#print STDERR "doscale $src -> $dest by $factor\n";
	$err=$im->Read($src);
	unless ($err) {
		$im->Scale(width=>$w*$factor,height=>$h*$factor);
		$err=$im->Write($dest);
		warn "ImageMagic: write \"$dest\": $err" if ($err);
	} else {
		warn "ImageMagic: read \"$src\": $err";
		system("djpeg \"$src\" | pnmscale \"$factor\" | cjpeg >\"$dest\"");
	}
	undef $im;
}
