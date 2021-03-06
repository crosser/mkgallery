#!/usr/bin/perl

my $version='$Id$';

# Recursively create image gallery index and slideshow wrappings.
# Makes use of modified "slideshow" javascript by Samuel Birch
# http://www.phatfusion.net/slideshow/

# Copyright (c) 2006-2013 Eugene G. Crosser

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
use HTTP::Date;
use CGI qw/:html *table *Tr *td *center *div *Link/;
use Image::Info qw/image_info dim/;
use Term::ReadLine;
use Getopt::Long;
use Encode;
use UUID;
use utf8;
binmode(STDOUT, ":utf8");

my $haveimagick = eval { require Image::Magick; };
{ package Image::Magick; }	# to make perl compiler happy

my $havegeoloc = eval { require Image::ExifTool::Location; };
{ package Image::ExifTool::Location; }	# to make perl compiler happy

my @sizes = (160, 640, 1600);
my $incdir = ".gallery2";

######################################################################

my $incpath;
my $debug = 0;
my $asktitle = 0;
my $noasktitle = 0;

charset("utf-8");

unless (GetOptions(
		'help'=>\&help,
		'incpath'=>\$incpath,
		'asktitle'=>\$asktitle,
		'noasktitle'=>\$noasktitle,
		'debug'=>\$debug)) {
	&help;
}

my $term = new Term::ReadLine "Edit Title";
binmode($term->IN, ':utf8');

FsObj->new(getcwd)->iterate;

sub help {

	print STDERR <<__END__;
usage: $0 [options]
 --help:        print help message and exit
 --incpath:     do not try to find .gallery2 directory upstream, use
                specified path (absolute or relavive).  Use with causion.
 --debug:       print a lot of debugging info to stdout as you run
 --asktitle:    ask to edit album titles even if there are ".title" files
 --noasktitle:  don't ask to enter album titles even where ".title"
                files are absent.  Use partial directory names as titles.
__END__

	exit 1;
}

sub new {
	my $this = shift;
	my $class;
	my $self;
	if (ref($this)) {
		$class = ref($this);
		my $parent = $this;
		my $name = shift;
		$self = {
				-parent=>$parent,
				-root=>$parent->{-root},
				-toppath=>$parent->{-toppath},
				-depth=>$parent->{-depth}+1,
				-base=>$name,
				-fullpath=>$parent->{-fullpath}.'/'.$name,
				-relpath=>$parent->{-relpath}.$name.'/',
				-inc=>'../'.$parent->{-inc},
			};
	} else {
		$class = $this;
		my $root=shift;
		$self = {
				-root=>$root,
				-fullpath=>$root,
			};
		# fill in -inc, -relpath
		initpaths($self); # we are not blessed yet, so cheat.
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

sub initpaths {
	my $self=shift;		# this is not a method but we cheat
	my $depth=20;		# arbitrary max depth
	my $fullpath=$self->{-fullpath};
	my $inc;
	my $relpath;

	if ($incpath) {
		$inc = $incpath;
		$inc .= '/' unless ($inc =~ m%/$%);
	} else {
		$inc="";
		while ( ! -d $fullpath."/".$inc."/".$incdir ) {
			$inc = "../".$inc;
			last unless ($depth-- > 0);
		}
	}
	if ($depth > 0) {
		$self->{-inc} = $inc;
		my $dp=0;
		my $pos;
		for ($pos=index($inc,'/');$pos>=0;
					$pos=index($inc,'/',$pos+1)) {
			$dp++;
		}
		$self->{-depth} = $dp;
		for ($pos=length($fullpath);$dp>0 && $pos>0;
					$pos=rindex($fullpath,'/',$pos-1)) {
			$dp--;
		}
		my $relpath = substr($fullpath,$pos);
		$relpath =~ s%^/%%;
		$relpath .= '/' if ($relpath);
		$self->{-relpath} = $relpath;
		$self->{-toppath} = substr($fullpath,0,$pos);
		#print "rel=$relpath, top=$self->{-toppath}, inc=$inc\n";
	} else {
		$self->{-inc} = 'NO-.INCLUDE-IN-PATH/';	# won't work anyway
		$self->{-relpath} = '';
		$self->{-depth} = 0;
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

	if ($havegeoloc) {
		my $exif = new Image::ExifTool;
		$exif->ExtractInfo($fullpath);
		my ($la,$lo) = $exif->GetLocation();
		if ($la && $lo) {
			$self->{-geoloc} = [$la,$lo];
		}
	}

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
	my $titleimage;
	my $T;
	my $TI;
	if (open($T,'<:encoding(utf8)', $fullpath.'/.title')) {
		$title = <$T>;
		$title =~ s/[\r\n]*$//;
		close($T);
	}
	if ($asktitle || (!$title && !$noasktitle)) {
		my $prompt = $self->{-relpath};
		$prompt = '/' unless ($prompt);
		my $OUT = $term->OUT || \*STDOUT;
		print $OUT "Enter title for $fullpath\n";
		$title = $term->readline($prompt.' >',$title);
		$term->addhistory($title) if ($title);
		if (open($T,'>:encoding(utf8)', $fullpath.'/.title')) {
			print $T $title,"\n";
			close($T);
		}
	}
	unless ($title) {
		$title=$self->{-relpath};
	}
	$self->{-title}=$title;
	if (open($TI,'<:encoding(utf8)', $fullpath.'/.titleimage')) {
		$titleimage = <$TI>;
		$titleimage =~ s/[\r\n]*$//;
		close($TI);
		#print STDERR "found title image \"",$titleimage,"\"\n";
		$self->{-titleimage}=$titleimage;
	}
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
			$self->{$size}->{'url'} = $name; # unscaled version
			$self->{$size}->{'dim'} = [$w, $h];
		} else {
			$self->{$size}->{'url'} = $nref;
			$self->{$size}->{'dim'} = [int($w*$factor+.5),
							int($h*$factor+.5)];
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
	my $inc = $self->{-inc}.$incdir.'/';
	my $title = $self->{-info}->{'Comment'};
	$title = $name unless ($title);

	print "slide: \"$title\": \"$pref\"->\"$name\"->\"$nref\"\n" if ($debug);

	# slideshow
	for my $refresh('static', 'slide') {
		my $fn = sprintf("%s/.html/%s-%s.html",$dn,$name,$refresh);
		if (isnewer($self->{-fullpath},$fn)) {
			my $imgsrc = '../'.$self->{$sizes[1]}->{'url'};
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
			unless (open($F,'>:encoding(utf8)', $fn)) {
				warn "cannot open \"$fn\": $!";
				next;
			}
			if ($refresh eq 'slide') {
				print $F start_html(
					-encoding=>"utf-8",
					-title=>$title,
					-bgcolor=>"#808080",
					-head=>meta({-http_equiv=>'Refresh',
						-content=>"3; url=$fwdref"}),
					-style=>{-src=>$inc."gallery.css"},
					),"\n",
					comment("Created by ".$version),"\n";
						
			} else {
				print $F start_html(-title=>$title,
					-encoding=>"utf-8",
					-bgcolor=>"#808080",
					-style=>{-src=>$inc."gallery.css"},
					),"\n",
					comment("Created by ".$version),"\n";
			}
			print $F start_table({-class=>'navi'}),start_Tr,"\n",
				td(a({-href=>"../index.html"},"Index")),"\n",
				td(a({-href=>$bakref},"&lt;&lt;Prev")),"\n",
				td(a({-href=>$toggleref},$toggletext)),"\n",
				td(a({-href=>$fwdref},"Next&gt;&gt;")),"\n",
				td({-class=>'title'},$title),"\n",
				end_Tr,
				end_table,"\n",
				center(table({-class=>'picframe'},
					Tr(td(img({-src=>$imgsrc,
						   -class=>'standalone',
						   -alt=>$title}))))),"\n",
				end_html,"\n";
			close($F);
		}
	}

	# info html
	my $fn = sprintf("%s/.html/%s-info.html",$dn,$name);
	if (isnewer($self->{-fullpath},$fn)) {
		my $F;
		unless (open($F,'>:encoding(utf8)', $fn)) {
			warn "cannot open \"$fn\": $!";
			return;
		}
		my $imgsrc = sprintf("../.%s/%s",$sizes[0],$name);
		print $F start_html(-title=>$title,
				-encoding=>"utf-8",
				-style=>{-src=>$inc."gallery.css"},
				-script=>[
					{-src=>$inc."mootools.js"},
					{-src=>$inc."urlparser.js"},
					{-src=>$inc."infopage.js"},
				]),"\n",
			comment("Created by ".$version),"\n",
			start_center,"\n",
			h1($title),"\n",
			table({-class=>'ipage'},
				Tr(td(img({-src=>$imgsrc,
					   -class=>'thumbnail',
					   -alt=>$title})),
					td($self->infotable))),
			a({-href=>'../index.html',-class=>'conceal'},
				'Index'),"\n",
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
	unless (open($IND,'>:encoding(utf8)', $fn)) {
		warn "cannot open $fn: $!";
		return;
	}
	$self->{-IND} = $IND;

	my $inc = $self->{-inc}.$incdir.'/';
	my $title = $self->{-title};
	my $titleimage = $self->{-titleimage};	
	print $IND start_html(-title => $title,
			-encoding=>"utf-8",
			-style=>[
				{-src=>$inc."gallery.css"},
				{-src=>$inc."custom.css"},
			],
			-script=>[
				{-src=>$inc."mootools.js"},
				{-src=>$inc."overlay.js"},
				{-src=>$inc."urlparser.js"},
				{-src=>$inc."multibox.js"},
				{-src=>$inc."showwin.js"},
				{-src=>$inc."controls.js"},
				{-src=>$inc."show.js"},
				{-src=>$inc."gallery.js"},
			]),"\n",
		comment("Created by ".$version),"\n",
		start_div({-class => 'indexContainer',
				-id => 'indexContainer'}),
		"\n";
	my $EVL;
	if (open($EVL, '<:encoding(utf8)', $self->{-toppath}.'/'.$incdir.'/header.pl')) {
		my $prm;
		while (<$EVL>) {
			$prm .= $_;
		}
		close($EVL);
		%_ = (
			-version	=> $version,
			-depth		=> $self->{-depth},
			-title		=> $title,
			-titleimage	=> $titleimage,
			-path		=> $self->{-fullpath},
			-breadcrumbs	=> "breadcrumbs unimplemented",
		);
		print $IND eval $prm,"\n";
	} else {
		print STDERR "could not open ",
			$self->{-toppath}.'/'.$incdir.'/header.pl',
			" ($!), reverting to default header";
		print $IND a({-href=>"../index.html"},"UP"),"\n";
		if ($titleimage) {
			print $IND img({-src=>$titleimage,
					-class=>'titleimage',
					-alt=>'Title Image'}),"\n";
		}
		print $IND h1({-class=>'title'},$title),
			br({-clear=>'all'}),"\n";
	}
}

sub endindex {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND end_div;
	my $EVL;
	if (open($EVL, '<:encoding(utf8)', $self->{-toppath}.'/'.$incdir.'/footer.pl')) {
		my $prm;
		while (<$EVL>) {
			$prm .= $_;
		}
		close($EVL);
		%_ = (
			-version	=> $version,
			-depth		=> $self->{-depth},
			-title		=> $self->{-title},
			-titleimage	=> $self->{-titleimage},
			-breadcrumbs	=> "breadcrumbs unimplemented",
		);
		print $IND eval $prm,"\n";
	} else {
		print STDERR "could not open ",
			$self->{-toppath}.'/'.$incdir.'/footer.pl',
			" ($!), reverting to default empty footer";
	}
	print $IND end_html,"\n";

	close($IND) if ($IND);
	undef $self->{-IND};
}

sub startsublist {
	my $self = shift;
	my $IND = $self->{-IND};

	print $IND h2({-class=>"atitle"},"Albums"),"\n",start_table,"\n";
}

sub sub_entry {
	my $self = shift;
	my $IND = $self->{-parent}->{-IND};
	my $name = $self->{-base};
	my $title = $self->{-title};

	$self->{-parent}->{-numofsubs}++;
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

	print $IND h2({-class=>"ititle"},"Images ",
		a({-href=>$slideref,-class=>'showStart',-rel=>'i'.$first},
			'&gt; slideshow')),"\n";
}

sub img_entry {
	my $self = shift;
	my $IND = $self->{-parent}->{-IND};
	my $name = $self->{-base};
	my $title = $self->{-info}->{'Comment'};
	$title = $name unless ($title);
	my $thumb = $self->{$sizes[0]}->{'url'};
	my $info = $self->{-info};
	my ($w, $h) = dim($info);

	my $i=0+$self->{-parent}->{-numofimgs};
	$self->{-parent}->{-numofimgs}++;

	print $IND a({-name=>$name}),"\n",
		start_table({-class=>'slide'}),start_Tr,start_td,"\n";
	print $IND div({-class=>'slidetitle'},
			"\n ",a({-href=>".html/$name-info.html",
				-title=>'Image Info: '.$name,
				-class=>'infoBox'},
				$title),"\n"),"\n",
		start_div({-class=>'slideimage'});
	if ($self->{-geoloc}) {
		my ($la,$lo) = @{$self->{-geoloc}};
		print $IND a({-href=>"http://maps.google.com/".
						"?q=$la,$lo&ll=$la,$lo",
				-title=>"$la,$lo",
				-class=>'geoloc'},
				div({-class=>'geoloc'},"")),"\n";
	}
	print $IND a({-href=>".html/$name-static.html",
				-title=>$title,
				-class=>'showImage',
				-rel=>'i'.$name},
				img({-src=>$thumb,
				     -class=>'thumbnail',
				     -alt=>$title})),"\n",end_div,
		start_div({-class=>'varimages',-id=>'i'.$name,-title=>$title}),"\n";
	foreach my $sz(@sizes) {
		my $src=$self->{$sz}->{'url'};
		my $w=$self->{$sz}->{'dim'}->[0];
		my $h=$self->{$sz}->{'dim'}->[1];
		print $IND "  ",a({-href=>$src,
			-class=>"conceal",
			-rel=>$w."x".$h,
			-title=>"Reduced to ".$w."x".$h},
			$w."x".$h)," \n";
	}
	print $IND "  ",a({-href=>$name,
				-rel=>$w."x".$h,
				-title=>'Original'},$w."x".$h),
		"\n",end_div,"\n",
		end_td,end_Tr,end_table,"\n";
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

