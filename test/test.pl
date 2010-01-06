#!/usr/bin/perl
# an old testcase, currently here for historical purposes

use lib "/home/bwachter/aard";
use strict;
use AwfulCMS::Page;

my $request="default";
my $module;
my $call;
my $s={};
my $m; #AwfulCMS::ModExample->new($s);

# set up a page for later use and find out about module and request foo
my $p=AwfulCMS::Page->new("test");

if (defined($p->{rq_vars}->{req})){
  $request=$p->{rq_vars}->{req};
}

if (defined($p->{rq_vars}->{mod})){
  # module validation, whatever
} else {

}

$p->{rq_file}="test.html";

$module="AwfulCMS::ModTemplate";
eval "require $module";
$p->s404($@) if ($@);

$m=$module->new($s, $p);
$p->s404("Unable to load module") if (ref($m) ne $module);


unless (defined $s->{rqmap}->{$request}->{-handler}){
  if (defined $s->{rqmap}->{default}->{-handler}){
    $request="default";
  } else {
    $p->s404("No default method defined in module");
  }
}

if (defined $s->{rqmap}->{$request}->{-dbrw}){
  # open rw database connection
} elsif (defined $s->{rqmap}->{$request}->{-dbro}){
  # open ro database connection
}

$call=$s->{rqmap}->{$request}->{-handler};
$m->$call();

$p->out();
