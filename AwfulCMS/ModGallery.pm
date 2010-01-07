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

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
                           -content=>"html"}
              };
  $s->{mc}=$r->{mc};
  $s->{mc}->{iconset}="/icons/themes/simple" unless (defined $s->{mc}->{iconset});
  $s->{mc}->{diricon}="directory.png" unless (defined $s->{mc}->{diricon});
  $s->{mc}->{fileicon}="file.png" unless (defined $s->{mc}->{fileicon});

#  if ($s->{mc}->{typeinfo}=1){
#    eval "require File::Type";
#  }

  bless $s;
  $s;
}

sub defaultpage(){
  my $s=shift;
  my $dir=".";
  my $files={};
  my @dirs;
  my $icon="file.png";
  my ($maxx,$maxy)=(300,300);
  $maxx=$maxy=$s->{mc}->{'preview-size'} if defined $s->{mc}->{'preview-size'};
  my @resizemodes=(640, 1024);
  if (defined $s->{mc}->{'resize-modes'}){
    $s->{mc}->{'resize-modes'}=~s/ //g;
    @resizemodes=split(',', $s->{mc}->{'resize-modes'});
  }
  my @sizecheck;
  for (@resizemodes) { $sizecheck[$_]=1; };
  push(@resizemodes, $maxx) unless $sizecheck[$_];

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
    $s->{page}->add("<div class=\"gallery-item\"><div class=\"gallery-info\"><a href=\"$_\"><img src=\"$icon\" border=\"0\" alt=\"Directory\" /><br />$_</a></div></div>");
  }

  foreach my $key (sort (keys(%$files))){
    my $icon="$s->{mc}->{iconset}/$s->{mc}->{fileicon}";
    my $value=$files->{$key};
    if ($s->{mc}->{fileinfo}==1){
      $icon = "$s->{mc}->{iconset}/".$s->{mc}->{"icon-".$value->{type}} if (defined $s->{mc}->{"icon-".$value->{type}});
    }

    foreach(@resizemodes){
      %$value=(%$value, 'filename'=>$key,
               'directory'=>$s->{page}->{rq}->{dir},
               'prepend'=>"$_.",
               'ignorelarger'=>"1",
               'maxx'=>$_,
               'maxy'=>$_);
      my $ret=thumbnail($value);
      # alle zu einem hash dazuwerfen, wenn voll. danach dann aussuchen was wir haben
      $icon="/$ret" unless $ret eq "";
    }

    $s->{page}->add("<div class=\"gallery-item\"><div class=\"gallery-info\"><a href=\"$key\"><img src=\"$icon\" border=\"2\" alt=\"File\" /><br />$key<br />$value->{type}</a></div></div>\n");
  }
  $s->{page}->add("</div>");
}

1;
