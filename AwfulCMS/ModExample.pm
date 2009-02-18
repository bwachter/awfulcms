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
  $s->{mc}=$r->{mc};
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
  my $p=$s->{page};
  $p->add("<h1>Example page</h1>");
  $p->add("<h2>Request parameters</h2>");

  $p->add("<ul>".
	  "<li>Module name: $s->{page}->{module}</li>".
	  "<li>Module instance: $s->{page}->{module_instance}</li>".
	  "<li>Target URL: $s->{page}->{target}</li>".
	  "<li>Requested host: $s->{page}->{rq_host}</li>".
	  "<li>Requested file: $s->{page}->{rq_file} ($s->{page}->{rq_fileabs})</li>".
	  "<li>Requested directory: $s->{page}->{rq_dir}</li>".
	  "</ul>");

  $p->add("<h2>Module configuration</h2>");
  $p->add("<dl>");
  #foreach my $key (sort($s->{mc})){
  foreach my $key (sort(keys(%{$s->{mc}}))){
    $p->add("<dt>$key</dt><dd>$s->{mc}->{$key}</dd>\n");
  }  
  $p->add("</dl>");
}

sub orq(){
  my $s=shift;
  $s->{page}->add("orq");
}

1;
