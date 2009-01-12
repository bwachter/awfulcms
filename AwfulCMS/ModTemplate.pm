package AwfulCMS::ModTemplate;

use strict;

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"mainsite",
			   -content=>"html"},
	       "file"=>{-handler=>"mainsite",
			 -content=>"html"}
	       };
  bless $s;
  $s;
}

sub info(){
  "foobar
bar
baz";
}

sub mainsite(){
  my $s=shift;
  my @lines;
  open(F, "$s->{page}->{rq_file}")||die "Unable to open template '$s->{page}->{rq_file}'";
  @lines=<F>;
  close(F);
  foreach(@lines){
    $s->{page}->add($_);
  }
}

1;
