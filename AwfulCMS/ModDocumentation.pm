package AwfulCMS::ModDocumentation;

use AwfulCMS::LibFS qw(ls);
use strict;

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
			   -content=>"html"},
	       "pod"=>{-handler=>"podview",
			-content=>"html"}
	       };

  $s->{mc}=$r->{mc};
  $s->{target}="/$s->{page}->{rq_dir}/$s->{page}->{rq_file}";
  bless $s;
  $s;
}

sub contentlisting(){
  my $s=shift;
  my $p=$s->{page};

  my @dirs=("/AwfulCMS", "/");
  $p->status(500, "modulepath not set, unable to find modules") unless (defined $s->{mc}->{modulepath});

  $p->add("<ul>");
  foreach my $dir (@dirs){
    my @files;
    ls($s->{mc}->{modulepath}."$dir", \@files)||
      $p->status(500, "Unable to open directory $dir");
    $p->add("<li>$dir<ul>");
    foreach(@files){
      next unless ($_=~/\.pm$/||$_=~/\.cgi$/||$_=~/\.pl$/);
      $p->add("<li><a href=\"$s->{target}?req=pod&file=$dir/$_\">$_</a></li>");
    }
    $p->add("</ul></li>");
  }
  $p->add("</ul>");
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  $s->contentlisting();
}

sub podview(){
  my $s=shift;
  my $p=$s->{page};
  my $file=$p->{cgi}->param("file");

  eval "require Pod::Simple::HTML";
  $p->status(500, $@) if ($@);

  $file=~s/^[^a-zA-Z0-9]*//;
  $p->add($file);

  $s->contentlisting() if ($file eq "");

  my $output;
  my $parser = Pod::Simple::HTML->new();
  $parser->output_string(\$output);
  $parser->parse_from_file($s->{target}."/$file");
}

1;
