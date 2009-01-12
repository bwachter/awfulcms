package AwfulCMS::ModDirIndex;

use strict;
use GD;
use AwfulCMS::LibFS qw(lsx);
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
  bless $s;
  $s;
}

sub defaultpage(){
  my $s=shift;
  my $dir=".";
  my $files={};
  my @dirs;
  my $icon="file.png";

  #$s->{page}->add("'".$s->{page}->{rq_dir}."' -- '".$s->{page}->{rq_file}."' -- '".$s->{page}->{rq_host});
  lsx($s->{page}->{rq_dir}, $files, \@dirs);

  $s->{page}->add("<div class=\"dirview-group\">");
  my $icon="$s->{mc}->{iconset}/$s->{mc}->{diricon}";
  foreach(sort @dirs){
    $s->{page}->add("<div class=\"dirview-item\"><div class=\"dirview-info\"><a href=\"$_\"><img src=\"$icon\" border=\"0\" alt=\"Directory\" /><br />$_</a></div></div>");
  }

  my $icon="$s->{mc}->{iconset}/$s->{mc}->{fileicon}";
  foreach my $key (sort (keys(%$files))){
    my $value=$files->{$key};
    $s->{page}->add("<div class=\"dirview-item\"><div class=\"dirview-info\"><a href=\"$key\"><img src=\"$icon\" border=\"2\" alt=\"File\" /><br />$key<br />$value->{type}</a></div></div>\n");
  }
  $s->{page}->add("</div>");
}

1;
