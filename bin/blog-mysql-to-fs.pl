#!/usr/bin/perl
# blog-mysql-to-fs.pl
# (c) 2021 Bernd Wachter bwachter@lart.info

=head1 blog-mysql-to-fs.pl

Foo.

=cut

use strict;

use AwfulCMS::Config;
use strict;
use Getopt::Long;
use File::Path qw(mkpath);

require DBI;

my %opt;
my $backend;

Getopt::Long::Configure('bundling');
GetOptions(
           "l|list" => \$opt{l},
           "h|handle:s" => \$opt{h},
           );

my $c=AwfulCMS::Config->new("");
my $dbc=$c->getValues("database");

if ($opt{l}){
  print "Available database modules: \n";

  foreach my $key (sort(keys(%$dbc))){
    print "$key\n";
  }
  exit;
}

my $dbh;
my $q;

sub cb_dbh{
  $dbh;
}

sub cb_error{
  my $e=shift;

  print STDERR "$e\n";
}

sub cb_write_article{
  my $d=shift;

  utf8::encode($d->{subject});
  utf8::encode($d->{author});
  utf8::encode($d->{body});

  $d->{quoted_subject}=$d->{subject};
  $d->{quoted_subject}=~s/"/\\"/g;

  print "Processing article $d->{id}, $d->{subject}\n";
  mkpath($d->{subject});
  if (defined $d->{markup}){
    print "Markup: $d->{markup}\n";
  } else {
    print "Article doesn't have markup specification, using defaults.\n";
    $d->{markup}="basic";
  }

  my @tags=$backend->getTagsForArticle($d->{id});
  my $tag_string=join("\n  - ", @tags);

  my $filename;
  if (lc $d->{markup} eq "markdown"){
    $filename="$d->{subject}/index.md";
  } elsif (lc $d->{markup} eq "basic"){
    $filename="$d->{subject}/index.basic";
  }

  if ($filename ne ""){
    open(FH, ">$filename")||die "Unable to open $filename: $!";
    print FH "---\n";
    print FH "title: \"$d->{quoted_subject}\"\n";
    print FH "author: $d->{name}\n";
    print FH "date: ".localtime($d->{created})."\n";
    print FH "modified: ".localtime($d->{changed})."\n" if ($d->{modified});
    print FH "id: $d->{id}\n" if ($d->{id});
    print FH "lang: $d->{lang}\n" if ($d->{lang});
    print FH "email: $d->{email}\n" if ($d->{email});
    print FH "homepage: $d->{homepage}\n" if ($d->{homepage});
    print FH "keywords:\n  - $tag_string\n" if @tags>0;
    print FH "draft: $d->{draft}\n" if ($d->{draft}==1);
    print FH "tease: $d->{tease}\n" if ($d->{tease}==1);
    print FH "---\n";
    print FH $d->{body};
    close(FH);
  } else {
    print STDERR "Skipping $d->{subject} due to lack of filename\n";
  }
}

if ($opt{h}){
  my $dbhandle;
  if (defined $dbc->{$opt{h}}){
    print "Using $opt{h} as handle\n";
    $dbhandle=$opt{h};
  } else {
    die("$opt{h} is not a valid handle.");
  }

  my $o={};
  $o->{type}=$dbc->{$dbhandle}->{type}||"mysql";
  $o->{host}=$dbc->{$dbhandle}->{host};
  $o->{dbname}=$dbc->{$dbhandle}->{1}->{dbname}||$dbc->{$dbhandle}->{dbname};
  $o->{user}=$dbc->{$dbhandle}->{1}->{user}||$dbc->{$dbhandle}->{user}||"";
  $o->{password}=$dbc->{$dbhandle}->{1}->{password}||$dbc->{$dbhandle}->{password}||"";

  $dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}:host=$o->{host}", $o->{user},
                    $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
                      die "DBI->connect(): ". DBI->errstr;
}

require AwfulCMS::ModBlog::BackendMySQL;
$backend=new AwfulCMS::ModBlog::BackendMySQL;
$backend->{cb_dbh}=sub{cb_dbh()};
$backend->{cb_err}=sub{my $e=shift;cb_error($e)};

my $cnt=$backend->getArticleCount(0);
print "Blog has $cnt articles\n";

# cb_format gets called for each article -> write articles to disk there
# this only gets toplevel articles, so we need additional passes to grab the comments
$backend->getArticleList
  ({
    pid=>0,
    limit=>$cnt,
    draft=>0,
    offset=>0,
    cb_format=>sub{my $d=shift;cb_write_article($d);},
   });
