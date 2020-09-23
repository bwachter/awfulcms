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
               "ssl"=>{-handler=>"mainsite",
                       -content=>"html",
                       -ssl=>"1"},
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
  $p->h1("Example page");
  $p->h2("Request parameters");

  $p->ul(li("Mode: $s->{page}->{mode}"),
         li("Module name: $s->{page}->{module}"),
         li("Module instance: $s->{page}->{module_instance}"),
         li("Module request: $s->{page}->{url}->{request}"),
         li("Module arguments: $s->{page}->{url}->{arguments}"),
         li("Base URL: $s->{page}->{baseurl}"),
         li("Target URL: $s->{page}->{target}"),
         li("Requested host: $s->{page}->{rq}->{host}"),
         li("Requested file: $s->{page}->{rq}->{file} ($s->{page}->{rq}->{fileabs})"),
         li("Requested directory: $s->{page}->{rq}->{dir}"),
         li("Remote host: $s->{page}->{rq}->{remote_host}"),
         li("Remote IP: $s->{page}->{rq}->{remote_ip}"),
         li("SSL: $s->{page}->{rq}->{ssl}")
        );

  $p->h2("URL parameters");
  $p->add("<dl>");
  foreach my $key (sort(keys(%{$s->{page}->{url}->{args}}))){
    $p->add("<dt>$key</dt><dd>$s->{page}->{url}->{args}->{$key}</dd>\n");
  }
  $p->add("</dl>");

  $p->h2("Module configuration");
  $p->add("<dl>");
  foreach my $key (sort(keys(%{$s->{mc}}))){
    $p->add("<dt>$key</dt><dd>$s->{mc}->{$key}</dd>\n");
  }
  $p->add("</dl>");

  $p->h2("Generate status page");
  $p->form({name=>"foo",
            method=>"post",
            action=>"$p->{target}"},
           input({type=>"hidden",
                  name=>"req",
                  value=>"status"}),
           input({type=>"text",
                  name=>"message",
                  value=>"status message"}),
           input({type=>"text",
                  name=>"status",
                  size=>"4",
                  value=>"404"}),
           input({type=>"submit",
                  name=>"submit",
                  value=>"Submit"})
          );

  $p->add($p->pEnv());
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
