package AwfulCMS::ModDirIndex;

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
			   -content=>"html",
			   -dbhandle=>"blog"}
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
  my ($maxx,$maxy) = (150,150);

  if ($s->{mc}->{preview}==1){
    $maxx=$s->{mc}->{'preview-maxx'} if defined $s->{mc}->{'preview-maxx'};
    $maxy=$s->{mc}->{'preview-maxy'} if defined $s->{mc}->{'preview-maxy'};
  }

  lsx($s->{page}->{rq_dir}, $files, \@dirs, $s->{mc}->{fileinfo});

  $s->{page}->add("<div class=\"dirview-group\">");
  my $icon="$s->{mc}->{iconset}/$s->{mc}->{diricon}";
  foreach(sort @dirs){
    $s->{page}->add("<div class=\"dirview-item\"><div class=\"dirview-info\"><a href=\"$_\"><img src=\"$icon\" border=\"0\" alt=\"Directory\" /><br />$_</a></div></div>");
  }

  foreach my $key (sort (keys(%$files))){
    my $icon="$s->{mc}->{iconset}/$s->{mc}->{fileicon}";
    my $value=$files->{$key};
    if ($s->{mc}->{fileinfo}==1){
      $icon = "$s->{mc}->{iconset}/".$s->{mc}->{"icon-".$value->{type}} if (defined $s->{mc}->{"icon-".$value->{type}});
    }
    if ($s->{mc}->{preview}==1){
      %$value=(%$value, 'filename'=>$key,
	       'directory'=>$s->{page}->{rq_dir},
	       'maxx'=>$maxx,
	       'maxy'=>$maxy);
      my $ret=thumbnail($value);
      $icon="/$ret" unless $ret eq "";
    }

    $s->{page}->add("<div class=\"dirview-item\"><div class=\"dirview-info\"><a href=\"$key\"><img src=\"$icon\" border=\"2\" alt=\"File\" /><br />$key<br />$value->{type}</a></div></div>\n");
  }
  $s->{page}->add("</div>");
}

1;
