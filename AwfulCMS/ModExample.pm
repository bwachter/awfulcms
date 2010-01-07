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
               "status"=>{-handler=>"status",
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
          "<li>Mode: $s->{page}->{mode}</li>".
          "<li>Module name: $s->{page}->{module}</li>".
          "<li>Module instance: $s->{page}->{module_instance}</li>".
          "<li>Module request: $s->{page}->{url}->{request}</li>".
          "<li>Module arguments: $s->{page}->{url}->{arguments}</li>".
          "<li>Base URL: $s->{page}->{baseurl}</li>".
          "<li>Target URL: $s->{page}->{target}</li>".
          "<li>Requested host: $s->{page}->{rq}->{host}</li>".
          "<li>Requested file: $s->{page}->{rq}->{file} ($s->{page}->{rq}->{fileabs})</li>".
          "<li>Requested directory: $s->{page}->{rq}->{dir}</li>".
          "<li>Remote host: $s->{page}->{rq}->{remote_host}</li>".
          "<li>Remote IP: $s->{page}->{rq}->{remote_ip}</li>".
          "</ul>");

  $p->add("<h2>URL parameters</h2>");
  $p->add("<dl>");
  foreach my $key (sort(keys(%{$s->{page}->{url}->{args}}))){
    $p->add("<dt>$key</dt><dd>$s->{page}->{url}->{args}->{$key}</dd>\n");
  }
  $p->add("</dl>");

  $p->add("<h2>Module configuration</h2>");
  $p->add("<dl>");
  foreach my $key (sort(keys(%{$s->{mc}}))){
    $p->add("<dt>$key</dt><dd>$s->{mc}->{$key}</dd>\n");
  }
  $p->add("</dl>");

  $p->add("<h2>Generate status page</h2>");
  $p->add("<form name=\"foo\" method=\"post\" action=\"$p->{target}\">".
          "<input type=\"hidden\" name=\"req\" value=\"status\" />".
          "<input type=\"text\" name=\"message\" value=\"status message\" />".
          "<input type=\"text\" name=\"status\" size=\"4\" value=\"404\" />".
          "<input type=\"submit\" name=\"submit\" value=\"Submit\" />");
}

sub status(){
  my $s=shift;
  my $p=$s->{page};
  my $status=400;
  my $message="Sample message";

  $status=$p->{url}->param('status') if ($p->{url}->param('status'));
  $message=$p->{url}->param('message') if ($p->{url}->param('message'));
  $p->status($status, $message);
}

1;
