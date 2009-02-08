#!/usr/bin/perl

=head1 blog.pl

A command line client for ModBlog

=head2 Configuration parameters

There are no configuration parameters outside this module. 

=head2 Module functions

=over

=cut

#TODO: LibCLI as CLI<>Module-wrapper; move as much code as possible to ModBlog

use Term::ReadLine;
use File::Temp;
use AwfulCMS::Config;
use AwfulCMS::LibFS qw(openreadclose);
require DBI;
use strict;

# config part
my $handle="blog";

my @keys=('pid', 'rpid', 'subject', 'body', 'lang', 'name', 'email', 'homepage', 'draft');
my @fixedkeys=('id');

# global values
my $c=AwfulCMS::Config->new("");
my $mc=$c->getValues("ModBlogCLI");
my $dbh;
my $OUT;

sub formatArticle{
  my $d=shift;

  if ($d->{email}=~/^\(/ && $d->{email}=~/\)$/) {
    $d->{email}=" $d->{email} ";
  } else {
    #$d->{email}="";
  }
  $d->{date}=localtime($d->{created});

  my $ret="From: ".$d->{name}." <".$d->{email}.">\n";
  $ret.="Date: ".$d->{date}."\n";
  foreach(@keys){
    next if ($_ eq "email" || $_ eq "name" || $_ eq "body");
    $ret.=ucfirst($_).": ".$d->{$_}."\n";
  }

  $ret.="\n".$d->{body}."\n";
  $ret;
}

sub parseArticle{
  my $input=shift;
  my $output=shift;
  my $body=0;
  return if (!ref($input) eq "ARRAY");
  return if (!ref($output) eq "HASH");

  foreach (@$input){
    if ($body==1){
      $output->{body}.=$_;
      next;
    }
    if (/^from:/i){
      my ($email)=/<(.*)>/;
      my ($name)=/ (.*)</;
      $name=~s/ *$//;
      $output->{email}=$email if ($email ne "");
      $output->{name}=$email if ($name ne "");
      next;
    } else {
      my ($key)=/^(.*?):/;
      my ($value)=/: *(.*)$/;
      $output->{lc($key)}=$value if ($key ne "" && $value ne "");
    }
    $body=1 if (/^$/);
  }
  $output->{body}=~s/^\s+//;
  $output->{body}=~s/\s+$//;
}

sub connectDB{
  my $dbc=$c->getValues("database");

  die("There's no configuration for DB-handle '$handle'") if (not defined $dbc->{$handle});
  my $o={};
  $o->{type}=$dbc->{$handle}->{type}||"mysql";
  $o->{dbname}=$dbc->{$handle}->{1}->{dbname}||$dbc->{$handle}->{dbname};
  $o->{user}=$dbc->{$handle}->{1}->{user}||$dbc->{$handle}->{user}||"";
  $o->{password}=$dbc->{$handle}->{1}->{password}||$dbc->{$handle}->{password}||"";

  $dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}", $o->{user}, 
		    $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
		      die "DBI->connect(): ". DBI->errstr;
}

sub writeArticleDB{
  my $args=shift;
  my $q_u = $dbh->prepare("update blog set pid=?, rpid=?, subject=?, body=?, lang=?, name=?, email=?, homepage=?, draft=? where id=?");
  my $q_i = $dbh->prepare("insert into blog(pid, rpid, subject, body, lang, name, email, homepage, draft, created) values (?,?,?,?,?,?,?,?,?,?)");

  foreach (@keys){
    return "Key $_ not found" unless (defined $args->{$_});
  }

  if ($args->{id}){
    $q_u->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body}, 
		  $args->{lang}, $args->{name}, $args->{email},
		  $args->{homepage}, $args->{draft}, $args->{id})||return "Unable to insert new record: $!\n";
  } else {
    $q_i->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body}, 
		  $args->{lang}, $args->{name}, $args->{email},
		  $args->{homepage}, $args->{draft}, time())||return "Unable to insert new record: $!\n";
  }
}

sub deleteArticle{
  my $ID=shift;
  my $q_d=$dbh->prepare("delete from blog where id=?");
  $q_d->execute($ID)||print $OUT "Error executing query";
}

sub editArticle{
  my $ID=shift;
  my @result;
  my %newarticle;

  my $q_a=$dbh->prepare("select * from blog where id=?");
  $q_a->execute($ID)||print $OUT "Error executing query";
  my $d=$q_a->fetchrow_hashref();
  if (defined $d){
    my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
    print $tmp formatArticle($d);
    system("vi $tmp");
    openreadclose($tmp, \@result);
    parseArticle(\@result, \%newarticle);
    if (%newarticle->{body} eq ""){
      print "Skipping article due to empty body\n";
      return;
    }
#    print writeArticleDB(\(%$d, %newarticle))."\n";
    my %newhash=(%$d, %newarticle);
    print writeArticleDB(\%newhash)."\n";
  } else {
    print $OUT "No such article\n";
  }
}

sub listArticles{
  my $opt=shift;
  my $q_s=$dbh->prepare("select * from blog where pid=? and draft=? order by created desc limit ? offset ?") ;
  #$p->status(400, "Unable to prepare query: $!");
  if ($opt eq "d"){
    $q_s->execute(0, 1, 50, 0);
  } else {
    $q_s->execute(0, 0, 50, 0);
  }

  while (my $d=$q_s->fetchrow_hashref()){
    print $d->{id}."\t".$d->{subject}."\n";
  }
}

sub getArticle{
}

sub printArticle{
  my $ID=shift;
  my $q_a=$dbh->prepare("select * from blog where id=?");
  $q_a->execute($ID)||print $OUT "Error executing query";
  my $d=$q_a->fetchrow_hashref();
  if (defined $d){
    print $OUT formatArticle($d)
  } else {
    print $OUT "No such article\n";
  }
}

sub newArticle{
  my %newarticle;
  my @result;
  my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
  print $tmp <<END;
Subject: test
Name: $mc->{name}
EMail: $mc->{email}
Homepage: $mc->{homepage}
Pid: 0
Rpid: 0
Lang: $mc->{lang}
Draft: $mc->{draft}


END
  system("vi $tmp");
  openreadclose($tmp, \@result);
  parseArticle(\@result, \%newarticle);
  if (%newarticle->{body} eq ""){
    print "Skipping article due to empty body\n";
    return;
  }
  print writeArticleDB(\%newarticle)."\n";
  # 1 english 2 german
  #$q_i->execute(0, 0, $subject, $text, 0, 1, $name, $email, $homepage, time());
}

sub main{
  my $term = new Term::ReadLine 'AwfulCMS Blog';
  my $prompt = "> ";
  $OUT = $term->OUT || \*STDOUT;
  my %article;

  connectDB();
  while ( defined ($_ = $term->readline($prompt)) ) {
    my @cmd=split(/ /, $_);

    if ($cmd[0] eq "d"){
      next if ($cmd[1] eq "");
      deleteArticle($cmd[1]);
    } elsif ($cmd[0] eq "e"){
      next if ($cmd[1] eq "");
      editArticle($cmd[1]);
    } elsif ($cmd[0] eq "l"){
      listArticles($cmd[1]);
    } elsif ($cmd[0] eq "p"){
      next if ($cmd[1] eq "");
      printArticle($cmd[1]);
    } elsif ($cmd[0] eq "n"){
      newArticle();
    } elsif ($cmd[0] eq "q"){
      exit(0);
    } else {
      print "Unknown command `$cmd[0]'\n" unless ($cmd[0] eq "");
    }
    $term->addhistory($_) if /\S/;
  }
}

main();
