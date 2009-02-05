package AwfulCMS::Mod404;

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
			   -content=>"html"}
	       };

  $s->{mc}=$r->{mc};
  $s->{mc}->{errortext}="Page not found" unless (defined $r->{mc}->{errortext});

  bless $s;
  $s;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  $p->status(404, $s->{mc}->{errortext});
}

1;
