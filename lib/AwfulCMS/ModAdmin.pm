package AwfulCMS::ModAdmin;

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
			   -content=>"html",
			   -role=>"admin"},
	       "roles"=>{-handler=>"mainsite",
			 -content=>"html",
			 -role=>"author"},
	       "orq"=>{-handler=>"orq",
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
  $s->{page}->add("mainsite");
}

sub orq(){
  my $s=shift;
  $s->{page}->add("orq");
}

1;
