package AwfulCMS::ModExample;

=head1 AwfulCMS::ModExample

This is a small example module to demonstrate how to build an AwfulCMS module. 
Currently it just displays the requested host/file/directory

=head2 Configuration parameters

This module does not have any configurable options.

=cut

use strict;
use AwfulCMS::Page qw(:tags);

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
  $s->{page}->add("Example page");

  $s->{page}->add("<ul><li>Requested host: $s->{page}->{rq_host}</li>".
		  "<li>Requested file: $s->{page}->{rq_file} ($s->{page}->{rq_fileabs})</li>".
		  "<li>Requested directory: $s->{page}->{rq_dir}</li>".
		  "</ul>");
}

sub orq(){
  my $s=shift;
  $s->{page}->add("orq");
}

1;
