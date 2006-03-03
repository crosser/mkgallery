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
use POSIX qw/getcwd strftime/;
use CGI qw/:html *table *Tr *center *div/;
use Image::Info qw/image_info dim/;
use Term::ReadLine;
use Getopt::Long;

my $haveimagick = eval { require Image::Magick; };
{ package Image::Magick; }	# to make perl compiler happy

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

	my $youngest=0;
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
		my @stat = stat($child->{-fullpath});
		$youngest = $stat[9] if ($youngest < $stat[9]);
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
	$self->{-firstimg} = $imglist[0];

	print "Dir: $self->{-fullpath}\n" if ($debug);

# 1. first of all, fill title for this directory and create hidden subdirs

	$self->initdir;

# 2. recurse into subdirectories to get their titles filled
#    before we start writing out subalbum list

	foreach my $dir(@dirlist) {
		$dir->iterate;
	}

# 3. iterate through images to build cross-links,

	my $previmg = undef;
	foreach my $img(@imglist) {
		# list-linking must be done before generating
		# aux html because aux pages rely on prev/next refs
		if ($previmg) {
			$previmg->{-nextimg} = $img;
			$img->{-previmg} = $previmg;
		}
		$previmg=$img;
	}

# 4. create scaled versions and aux html pages

	foreach my $img(@imglist) {
		# scaled versions must be generated before aux html
		# and main image index because they both rely on
		# refs to scaled images and they may be just original
		# images, this is not known before we try scaling.
		$img->makescaled;
		# finally, make aux html pages
		$img->makeaux;
	}

# no need to go beyond this point if the directory timestamp did not
# change since we built index.html file last time.

	my @istat = stat($self->{-fullpath}.'/index.html');
	return unless ($youngest > $istat[9]);

# 5. start building index.html for the directory

	$self->startindex;

# 6. iterate through subdirectories to build subalbums list

	if (@dirlist) {
		$self->startsublist;
		foreach my $dir(@dirlist) {
			$dir->sub_entry;
		}
		$self->endsublist;
	}

# 7. iterate through images to build thumb list

	if (@imglist) {
		$self->startimglist;
		foreach my $img(@imglist) {
			print "Img: $img->{-fullpath}\n" if ($debug);
			$img->img_entry;
		}
		$self->endimglist;
	}

# 8. comlplete building index.html for the directory

	$self->endindex;
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

	tryapp12($info) unless ($info->{'ExifVersion'});

	$self->{-isimg} = 1;
	$self->{-info} = $info;
	return 1;
}

sub tryapp12 {
	my $info = shift;	# this is not a method
	my $app12;
	# dirty hack to take care of Image::Info parser strangeness
	foreach my $k(keys %$info) {
		$app12=substr($k,6).$info->{$k} if ($k =~ /^App12-/);
	}
	return unless ($app12);	# bad luck
	my $seenfirstline=0;
	foreach my $ln(split /[\r\n]+/,$app12) {
		$ln =~ s/[[:^print:]\000]/ /g;
		unless ($seenfirstline) {
			$seenfirstline=1;
			$info->{'Make'}=$ln;
			next;
		}
		my ($k,$v)=split /=/,$ln,2;
		if ($k eq 'TimeDate') {
			$info->{'DateTime'} =
				strftime("%Y:%m:%d %H:%M:%S", localtime($v))
							unless ($v < 0);
		} elsif ($k eq 'Shutter') {
			$info->{'ExposureTime'} = '1/'.int(1000000/$v+.5);
		} elsif ($k eq 'Flash') {
			$info->{'Flash'} = $v?'Flash fired':'Flash did not fire';
		} elsif ($k eq 'Type') {
			$info->{'Model'} = $v;
		} elsif ($k eq 'Version') {
			$info->{'Software'} = $v;
		} elsif ($k eq 'Fnumber') {
			$info->{'FNumber'} = $v;
		}
	}
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
		$title=substr($fullpath,length($self->{-root}));
	}
	$self->{-title}=$title;
	print "title in $fullpath is $title\n" if ($debug);
}

sub makescaled {
	my $self = shift;
	my $fn = $self->{-fullpath};
	my $name = $self->{-base};
	my $dn = $self->{-parent}->{-fullpath};
	my ($w, $h) = dim($self->{-info});
	my $max = ($w > $h)?$w:$h;

	foreach my $size(@sizes) {
		my $nref = '.'.$size.'/'.$name;
		my $nfn = $dn.'/'.$nref;
		my $factor=$size/$max;
		if ($factor >= 1) {
			$self->{$size} = $name;	# unscaled version will do
		} else {
			$self->{$size} = $nref;
			if (isnewer($fn,$nfn)) {
				doscaling($fn,$nfn,$factor,$w,$h);
			}
		}
	}
}

sub isnewer {
	my ($fn1,$fn2) = @_;			# this is not a method
	my @stat1=stat($fn1);
	my @stat2=stat($fn2);
	return (!@stat2 || ($stat1[9] > $stat2[9]));
	# true if $fn2 is absent or is older than $fn1
}

sub doscaling {
	my ($src,$dest,$factor,$w,$h) = @_;	# this is not a method

	my $err=1;
	if ($haveimagick) {
		my $im = new Image::Magick;
		print "doscaling $src -> $dest by $factor\n" if ($debug);
		if ($err = $im->Read($src)) {
			warn "ImageMagick: read \"$src\": $err";
		} else {
			$im->Scale(width=>$w*$factor,height=>$h*$factor);
			$err=$im->Write($dest);
			warn "ImageMagick: write \"$dest\": $err" if ($err);
		}
		undef $im;
	}
	if ($err) {	# fallback to command-line tools
		system("djpeg \"$src\" | pnmscale \"$factor\" | cjpeg >\"$dest\"");
	}
}

sub makeaux {
	my $self = shift;
	my $name = $self->{-base};
	my $dn = $self->{-parent}->{-fullpath};
	my $pref = $self->{-previmg}->{-base};
	my $nref = $self->{-nextimg}->{-base};
	my $inc = $self->{-inc};
	my $title = $self->{-info}->{'Comment'};
	$title = $name unless ($title);

	print "slide: \"$pref\"->\"$name\"->\"$nref\"\n" if ($debug);

	# slideshow
	for my $refresh('static', 'slide') {
		my $fn = sprintf("%s/.html/%s-%s.html",$dn,$name,$refresh);
		if (isnewer($self->{-fullpath},$fn)) {
			my $imgsrc = '../'.$self->{$sizes[1]};
			my $fwdref;
			my $bakref;
			if ($nref) {
				$fwdref = sprintf("%s-%s.html",$nref,$refresh);
			} else {
				$fwdref = '../index.html';
			}
			if ($pref) {
				$bakref = sprintf("%s-%s.html",$pref,$refresh);
			} else {
				$bakref = '../index.html';
			}
			my $toggleref;
			my $toggletext;
			if ($refresh eq 'slide') {
				$toggleref=sprintf("%s-static.html",$name);
				$toggletext = 'Stop!';
			} else {
				$toggleref=sprintf("%s-slide.html",$name);
				$toggletext = 'Play-&gt;';
			}
			my $F;
			unless (open($F,'>'.$fn)) {
				warn "cannot open \"$fn\": $!";
				next;
			}
			if ($refresh eq 'slide') {
				print $F start_html(
					-title=>$title,
					-bgcolor=>"#808080",
					-head=>meta({-http_equiv=>'Refresh',
						-content=>"3; url=$fwdref"}),
					-style=>{-src=>$inc."gallery.css"},
					),"\n";
						
			} else {
				print $F start_html(-title=>$title,
					-bgcolor=>"#808080",
					-style=>{-src=>$inc."gallery.css"},
					),"\n";
			}
			print $F start_center,"\n",
				h1($title),"\n",
				start_table({-class=>'navi'}),start_Tr,"\n",
				td(a({-href=>"../index.html"},"Index")),"\n",
				td(a({-href=>$bakref},"&lt;&lt;Prev")),"\n",
				td(a({-href=>$toggleref},$toggletext)),"\n",
				td(a({-href=>$fwdref},"Next&gt;&gt;")),"\n",
				end_Tr,
				end_table,"\n",
				table({-class=>'picframe'},
					Tr(td(img({-src=>$imgsrc})))),"\n",
				end_center,"\n",
				end_html,"\n";
			close($F);
		}
	}

	# info html
	my $fn = sprintf("%s/.html/%s-info.html",$dn,$name);
	if (isnewer($self->{-fullpath},$fn)) {
		my $F;
		unless (open($F,'>'.$fn)) {
			warn "cannot open \"$fn\": $!";
			return;
		}
		my $imgsrc = sprintf("../.%s/%s",$sizes[0],$name);
		print $F start_html(-title=>$title,
				-style=>{-src=>$inc."gallery.css"},),"\n",
			start_center,"\n",
			h1($title),"\n",
			table({-class=>'ipage'},
				Tr(td(img({-src=>$imgsrc})),
					td($self->infotable))),
			a({-href=>'../index.html'},'Index'),"\n",
			end_center,"\n",
			end_html,"\n";
		close($F);
	}
}

sub startindex {
	my $self = shift;
	my $fn = $self->{-fullpath}.'/index.html';
	my $block = $self->{-fullpath}.'/.noindex';
	$fn = '/dev/null' if ( -f $block );
	my $IND;
	unless (open($IND,'>'.$fn)) {
		warn "cannot open $fn: $!";
		return;
	}
	$self->{-IND} = $IND;

	my $inc = $self->{-inc};
	my $title = $self->{-title};
	print $IND start_html(-title => $title,
			-style=>{-src=>[$inc."gallery.css",
					$inc."lightbox.css"]},
			-script=>[{-code=>"var incPrefix='$inc';"},
				{-src=>$inc."gallery.js"},
				{-src=>$inc."lightbox.js"}]),
		a({-href=>"../index.html"},"UP"),"\n",
		start_center,"\n",
		h1($title),"\n",
		"\n";
}

sub endindex {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND end_center,end_html,"\n";

	close($IND) if ($IND);
	undef $self->{-IND};
}

sub startsublist {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND h2("Albums"),"\n",start_table,"\n";
}

sub sub_entry {
	my $self = shift;
	my $IND = $self->{-parent}->{-IND};
	my $name = $self->{-base};
	my $title = $self->{-title};

	print $IND Tr(td(a({-href=>$name.'/index.html'},$name)),
			td(a({-href=>$name.'/index.html'},$title))),"\n";
}

sub endsublist {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND end_table,"\n",br({-clear=>'all'}),hr,"\n\n";
}

sub startimglist {
	my $self = shift;
	my $IND = $self->{-IND};
	my $first = $self->{-firstimg}->{-base};
	my $slideref = sprintf(".html/%s-slide.html",$first);

	print $IND h2("Images"),"\n",
		a({-href=>$slideref},'Slideshow'),
		"\n";
}

sub img_entry {
	my $self = shift;
	my $IND = $self->{-parent}->{-IND};
	my $name = $self->{-base};
	my $title = $self->{-info}->{'Comment'};
	$title = $name unless ($title);
	my $thumb = $self->{$sizes[0]};
	my $medium = $self->{$sizes[1]};
	my $info = $self->{-info};
	my ($w, $h) = dim($info);

	print $IND start_div({-class=>'ibox',-id=>$name,
				-OnClick=>"HideIbox('$name');"}),"\n",
		start_div({-class=>'iboxtitle'}),
		span({-style=>'float: left;'},b("Info for $name")),
		span({-style=>'float: right;'},
			a({-href=>"#",-OnClick=>"HideIbox('$name');"},"Close")),
		br({-clear=>'all'}),"\n",
		end_div,"\n",
		$self->infotable,
		end_div,"\n";

	print $IND table({-class=>'slide'},Tr(td(
		a({-href=>".html/$name-info.html",-title=>'Image Info',
			-onClick=>"return showIbox('$name');"},$title),
		br,
		a({-href=>$medium,-rel=>"lightbox",-title=>$title},
			img({-src=>$thumb})),
		br,
		a({-href=>$name,-title=>'Original Image'},"($w x $h)"),
		br))),"\n";
}

sub endimglist {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND br({-clear=>'all'}),hr,"\n\n";
}

sub infotable {
	my $self = shift;
	my $info = $self->{-info};
	my $msg='';

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
	$msg.=start_table({-class=>'infotable'})."\n";
	foreach my $k(@infokeys) {
		$msg.=Tr(td($k.":"),td($info->{$k}))."\n" if ($info->{$k});
	}
	$msg.=end_table."\n";
}

