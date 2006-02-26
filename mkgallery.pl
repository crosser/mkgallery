#!/usr/bin/perl

use strict;
use Carp;
use POSIX qw/getcwd/;
use CGI qw/:html *table *center *div/;
use Image::Info qw/image_info dim/;
use Image::Magick;

my $ask=1;
my $startdir=getcwd;

######################################################################

&processdir($startdir);

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
	print a({-href=>"../"},"UP");
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

	my $haspics=0;
	&iteratedir($D,$start,$dir,sub {
		my ($start,$dir,$base)=@_;
		my $en=sprintf("%s/%s/%s",$start,$dir,$base);
		return unless ( -f $en );
		$haspics=1 if (&processfile($start,$dir,$base,$en));
	});

# write HTML footer

	print br({-clear=>"all"}),"\n";
	print hr,"\n" if ($haspics);
	print end_center,"\n";
	print end_html,"\n";

	close(STDOUT);
	closedir($D);
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
		td(a({-href=>$base."/"},$base)),
		td(a({-href=>$base."/"},$title))),"\n";
}

sub processfile {
	my ($start,$dir,$base,$fn)=@_;

	my $info = image_info($fn);
	if (my $error = $info->{error}) {
		if (($error !~ "Unrecognized file format") &&
		    ($error !~ "Can't read head")) {
			print STDERR "File \"$fn\": $error\n";
		}
		return 0;
	}
	my ($w,$h) = dim($info);
	my $title=$info->{'Comment'};
	$title=$base unless ($title);
	my $thumb=&scale($start,$dir,$base,$fn,160,$info);
	my $medium=&scale($start,$dir,$base,$fn,640,$info);
	print &infobox($info,$base,$fn),"\n";
	print table({-class=>'slide'},Tr(td(
		a({-href=>".info/$base.html",
			-onClick=>"return showIbox('$base');"},$title),
		br,
		a({-href=>$medium,-rel=>"lightbox",-title=>$title},
			img({-src=>$thumb})),
		br,
		a({-href=>$base},"($w x $h)"),
		br))),"\n";
	#for my $k(keys %$info) {
	#	print "\t$k:\t$info->{$k}<br>\n";
	#}
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
