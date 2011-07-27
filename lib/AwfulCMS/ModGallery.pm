package AwfulCMS::ModGallery;

=head1 AwfulCMS::ModGallery

This module provides a fancy directory listing.
Features like showing file type information and generating thumbnails
of images are configurable.

=head2 Configuration parameters

=over

=item * iconset=<string>

A (preferably absolute) path to the directory where the icons reside.
The path needs to be absolute to the document root.

=item * fileinfo=<int>

Toggles display (and retrieving) of file type information. Default value is 0 (disabled).

=item * preview=<int>

Toggles display (and generation) of thumbnails for jpeg, png and gif files. Only works if `fileinfo' is set to `1'. Default value is 0 (disabled).

=item * fileicon=<string>

The icon name for files, relative to the `iconset' directory. Default is file.png.

=item * diricon=<string>

The icon name for directories, relative to the `iconset' directory. Default is directory.png.

=item * icon-<mime-type>=<string>

Set an icon different from the default fileicon for <mimetype>. The specified filename needs to be relative to the directory specified in `iconset'. Example: `icon-application/pdf=pdf.png'

=item * preview-maxx

The maximum x-Resolution of thumbnail images in pixels. Default is 150.

=item * preview-maxy

The maximum y-Resolution of thumbnail images in pixels. Default is 150.

=back

=cut

use strict;
use AwfulCMS::LibFS qw(lsx ls);
use AwfulCMS::LibGraphic qw(thumbnail);
use AwfulCMS::Page qw(:tags);
use AwfulCMS::LibUtil qw(toUTF8);

my $hasexif=1;
eval "require Image::ExifTool";
$hasexif=0 if ($@);
%Image::ExifTool::UserDefined::Options=(
                                        Charset => 'Latin',
                                        CoordFormat => '%.8f',
                                        Duplicates => 0,
                                        DateFormat => '%Y:%m:%d %H:%M:%S'
                                       );

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
                           -setup=>"commonsetup",
                           -content=>"html"},
               "displayPicture"=>{-handler=>"display",
                                  -setup=>"commonsetup",
                                  -content=>"html"}
              };
  $s->{mc}=$r->{mc};

  bless $s;
  $s;
}

sub commonsetup(){
  my $s=shift;
  $s->{mc}->{iconset}="/icons/themes/konqueror" unless (defined $s->{mc}->{iconset});
  $s->{mc}->{diricon}="directory.png" unless (defined $s->{mc}->{diricon});
  $s->{mc}->{fileicon}="file.png" unless (defined $s->{mc}->{fileicon});
}

sub extractExif{
  my $s=shift;
  my $filename=shift;

  my $info=Image::ExifTool::ImageInfo($filename);
  if ($$info{Title} eq ""){
    $$info{Title}=$filename;
    $$info{Title}=~s,.*/,,;
  }

  $$info{City}=toUTF8($$info{City});

  if ($$info{City} ne "" && $$info{Country} ne ""){
    $$info{_location}="$$info{City}, $$info{Country}";
  } elsif ($$info{City} ne ""){
    $$info{_location}="$$info{City}";
  }

  $$info{_date_location}=$$info{_location};

  if ($$info{GPSLatitude} ne "" && $$info{GPSLongitude} ne ""){
    my ($lat)=$$info{GPSLatitude}=~m/(.*) .*/;
    my ($lon)=$$info{GPSLongitude}=~m/(.*) .*/;
    $$info{_date_location_href}="<a href=\"http://maps.google.com/maps?q=$lat+$lon\">$$info{_date_location}</a>";
  }

  if ($s->{mc}->{'dump-exif'}==1){
    $info->{'html-dump'}="<br/><hr>";
    foreach (sort keys %$info){
      next if ($_ eq 'html-dump');
      $info->{'html-dump'}.="$_ = $$info{$_}<br>";
    }
  }

  $info;
}

sub display(){
  my $s=shift;
  my $p=$s->{page};
  my ($filepath, $path, $file)=$p->{url}->paramFile("picture");
  my $info={};
  my $files={};

  my $icon;
  my ($maxx,$maxy)=(300,300);
  $maxx=$maxy=$s->{mc}->{'display-size'} if defined $s->{mc}->{'display-size'};

  my @modelist=(640, 1024);
  if (defined $s->{mc}->{'resize-modes'}){
    $s->{mc}->{'resize-modes'}=~s/ //g;
    @modelist=split(',', $s->{mc}->{'resize-modes'});
  }
  push(@modelist, $maxx);

  my %tmp=();
  my @resizemodes=();
  foreach(@modelist){
    #unless ($tmp{$_}){
    #  $tmp{$_}=1;
      push(@resizemodes, $_)
    #}
  }

  my %thumblist;

  foreach(@resizemodes){
    my $ret=thumbnail({'type'=>File::Type->mime_type($filepath),
                      'filename'=>$file,
                      'directory'=>$path,
                      'prepend'=>"$_.",
                      'ignorelarger'=>"1",
                      'maxx'=>$_,
                      'maxy'=>$_});

    %thumblist->{$_}="/$ret" unless $ret eq "";
    $icon="/$ret" unless $ret eq "";
  }

  lsx($path, $files,  1);
  my ($prevPic, $hit, $nextPic);
  foreach (sort keys %$files){
    if ($_ eq $file) {
      $hit=1;
      next;
    }
    if ($hit){
      $nextPic=$_;
      last;
    }
    $prevPic=$_;
  }

  $p->p(":: $prevPic | $nextPic ::");
  if ($hasexif){
    $info=$s->extractExif($filepath);
    $p->title($$info{Title});
    $p->h1($$info{Title});
  }

  $p->p(a({href=>"/$path"}, "Overview"));

  foreach (sort {$a<=>$b} keys %thumblist){
    $p->add("| $_ ");
  }

  $p->a({href=>"/$filepath"}, img({src=>$icon, alt=>""}));

  $p->add($$info{'html-dump'});
}

sub defaultpage(){
  my $s=shift;
  my $dir=".";
  my $files={};
  my @dirs;
  my $icon="file.png";
  my ($maxx,$maxy)=(300,300);
  $maxx=$maxy=$s->{mc}->{'preview-size'} if defined $s->{mc}->{'preview-size'};

  if ($s->{page}->{rq}->{dir} eq "." && $s->{page}->{rq}->{file} eq ""){
    #$s->{page}->status(403, "You're not allowed to view this");
    #return;
  }

  # prevent listing the parent directory if the given filename
  # does not exist as a directory, but is configured for ModGallery
  $s->{page}->{rq}->{dir}.="/".$s->{page}->{rq}->{file}
    if ($s->{page}->{rq}->{dir} ne "" && $s->{page}->{rq}->{file} ne "");
  unless (-d $s->{page}->{rq}->{dir}){
    $s->{page}->status(404, "Directory does not exist");
    return;
  }

  lsx($s->{page}->{rq}->{dir}, $files, \@dirs, 1);

  $s->{page}->add("<div class=\"gallery-group\">");
  my $icon="$s->{mc}->{iconset}/$s->{mc}->{diricon}";
  foreach(sort @dirs){
    $s->{page}->div({class=>"gallery-item",
                     style=>"width:150px"},
                    div({class=>"gallery-info" },
                        a({href=>$_},
                          img({src=>$icon,
                               border=>0,
                               alt=>"Directory"}),
                          "<br/>$_"
                         )
                       )
                   );
  }
  $s->{page}->add("</div><div class=\"gallery-group\">");

  foreach my $key (sort (keys(%$files))){
    my $url;
    my $icon="$s->{mc}->{iconset}/$s->{mc}->{fileicon}";
    my $value=$files->{$key};
    if ($s->{mc}->{fileinfo}==1){
      $icon = "$s->{mc}->{iconset}/".$s->{mc}->{"icon-".$value->{type}} if (defined $s->{mc}->{"icon-".$value->{type}});
    }

    %$value=(%$value, 'filename'=>$key,
             'directory'=>$s->{page}->{rq}->{dir},
             'prepend'=>"$maxx.",
             'ignorelarger'=>"1",
             'maxx'=>$maxx,
             'maxy'=>$maxy);
    my $ret=thumbnail($value);
    # alle zu einem hash dazuwerfen, wenn voll. danach dann aussuchen was wir haben
    $icon="/$ret" unless $ret eq "";

    # FIXME, hook in preview stuff for other content as well
    # maybe add an option to relocate all viewing stuff under a /viewer/ namespace?
    if ($$value{type}=~/image\//){
      $url=$s->{page}->{url}->buildurl({'req'=>'displayPicture',
                                          'picture'=>$s->{page}->{rq}->{dir}."/$key"});
    } else {
      $url=$key;
    }

    $s->{page}->add("<div class=\"gallery-item\" style=\"width:$s->{mc}->{'preview-size'}px height:$s->{mc}->{'preview-size'}px\">" .
                    "<div class=\"gallery-info\">" .
                    "<a href=\"$url\">"
                   );

    if ($hasexif){
      my $info=$s->extractExif($s->{page}->{rq}->{dir}."/$key");

      $s->{page}->add("<img src=\"$icon\" border=\"2\" alt=\"File\" /><br />$$info{Title}</a>" .
                      "<br />$$info{_date_location_href}\n");
    } else {
      $s->{page}->add("<img src=\"$icon\" border=\"2\" alt=\"File\" /><br />$key<br />$value->{type}\n");
    }
    $s->{page}->add("</a></div></div>\n");
  }
  $s->{page}->add("</div>");
}

1;
