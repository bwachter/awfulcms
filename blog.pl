#!/usr/bin/perl

use Term::ReadLine;
use File::Temp;
use AwfulCMS::Config;
require DBI;
use strict;

sub formatArticle{
  my $d=shift;

  if ($d->{email}=~/^\(/ && $d->{email}=~/\)$/) {
    $d->{email}=" $d->{email} ";
  } else {
    #$d->{email}="";
  }
  $d->{date}=localtime($d->{created});

  my $ret="Subject: ".$d->{caption}."\n".
    "From: ".$d->{name}." <".$d->{email}.">\n".
      "Homepage: ".$d->{homepage}."\n".
      "Date: ".$d->{date}."\n\n".
      $d->{body}."\n";
  # "ID: ".$d->{id}."\n".
  $ret;
}

my $term = new Term::ReadLine 'AwfulCMS Blog';
my $prompt = "> ";
my $OUT = $term->OUT || \*STDOUT;

my $c=AwfulCMS::Config->new("");
my $dbc=$c->getValues("database");
my $handle="blog";
my $dbh;

die("There's no configuration for DB-handle '$handle'") if (not defined $dbc->{$handle});
my $o={};
$o->{type}=$dbc->{$handle}->{type}||"mysql";
$o->{dbname}=$dbc->{$handle}->{1}->{dbname}||$dbc->{$handle}->{dbname};
$o->{user}=$dbc->{$handle}->{1}->{user}||$dbc->{$handle}->{user}||"";
$o->{password}=$dbc->{$handle}->{1}->{password}||$dbc->{$handle}->{password}||"";

$dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}", $o->{user}, 
		       $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
die "DBI->connect(): ". DBI->errstr;

while ( defined ($_ = $term->readline($prompt)) ) {
  my @cmd=split(/ /, $_);

  if ($cmd[0] eq "e"){
    next if ($cmd[1] eq "");
    my $q_a=$dbh->prepare("select * from blog where id=?");
    $q_a->execute($cmd[1])||print $OUT "Error executing query";
    my $d=$q_a->fetchrow_hashref();
    if (defined $d){
      my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
      print $tmp formatArticle($d);
      system("vi $tmp");
    } else {
      print $OUT "No such article\n";
    }
  } elsif ($cmd[0] eq "l"){
    my $q_s=$dbh->prepare("select * from blog where pid=? order by created desc limit ? offset ?") ;
    #$p->status(400, "Unable to prepare query: $!");
    $q_s->execute(0, 50, 0);
    while (my $d=$q_s->fetchrow_hashref()){
      print $d->{id}."\t".$d->{caption}."\n";
    }
  } elsif ($cmd[0] eq "p"){
    next if ($cmd[1] eq "");
    my $q_a=$dbh->prepare("select * from blog where id=?");
    $q_a->execute($cmd[1])||print $OUT "Error executing query";
    my $d=$q_a->fetchrow_hashref();
    if (defined $d){
      print $OUT formatArticle($d)
    } else {
      print $OUT "No such article\n";
    }
  } elsif ($cmd[0] eq "n"){
    my $q_i = $dbh->prepare("insert into blog(pid, rpid, caption, body, topic, lang, name, email, homepage, created) values (?,?,?,?,?,?,?,?,?,?)");
    my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
    print $tmp <<END;
Subject:
Name:
EMail:
Homepage:
--END-Header--

END
    system("vi $tmp");
    # 1 english 2 german
    #$q_i->execute(0, 0, $subject, $text, 0, 1, $name, $email, $homepage, time());
  } elsif ($cmd[0] eq "q"){
    exit(0);
  } else {
    print "Unknown command `$cmd[0]'\n" unless ($cmd[0] eq "");
  }

  $term->addhistory($_) if /\S/;
}
