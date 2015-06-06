#!/usr/bin/perl
# new headers: obsoletes
# add `description' to tags (separate table, join)
# descrition-header; only visible in the blog
# faq autogeneration

=head1 blog.pl

A command line client for ModBlog

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

=over

=cut

#TODO: LibCLI as CLI<>Module-wrapper; move as much code as possible to ModBlog

use Term::ReadLine;
use Term::ReadKey;
use File::Temp;
use AwfulCMS::Config;
use AwfulCMS::LibFS qw(openreadclose);
use AwfulCMS::Page;
use AwfulCMS::SynBasic;
use AwfulCMS::ModBlog::BackendMySQL;
use Text::ASCIITable;
use POSIX 'strftime';
require DBI;
use strict;

my %features = {
                trackback_client => 1,
                trackback_ping => 1,
                rpc_xml_client => 1,
               };

eval "require Net::Trackback::Client";
if ($@){
  print "Net::Trackback::Client not found, pingbacks and trackbacks won't work.\n";
  $features{trackback_client}=0;
}

eval "require Net::Trackback::Ping";
if ($@){
  print "Net::Trackback::Ping not found, trackbacks won't work.\n";
  $features{trackback_ping}=0;
}

eval "require RPC::XML::Client";
if ($@){
  print "RPC::XML::Client not found, pingbacks won't work.\n";
  $features{rpc_xml_client}=0;
}

# config part
my $handle="ModBlog";

my @keys=('pid', 'rpid', 'subject', 'body', 'lang', 'name', 'email', 'homepage', 'draft', 'tease', 'markup');
my @fixedkeys=('id');

# global values
my $instance=$ARGV[0];
my $c=AwfulCMS::Config->new("");
my $mc=$c->getValues("ModBlogCLI");
my $mcm=$c->getValues("$handle");
$mcm={%{$mcm}, %{$c->getValues("$handle/$instance")}} if ($c->getValues("$handle/$instance"));

my $backend;
my $OUT;

$mcm->{'title-prefix'}="Blog" unless (defined $mcm->{'title-prefix'});
$mcm->{baselink}="" unless (defined $mcm->{baselink});
$mcm->{description}="Some blog without description" unless (defined $mcm->{description});

sub cb_die{
  my $e=shift;

  print $OUT "Critical error: $e\n";
}

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
  $ret.="Tags: ".join(", ", @{$d->{tags}})."\n" if (defined $d->{tags});

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
      $output->{name}=$name if ($name ne "");
      next;
    } elsif (/^tags:/i){
      my ($value)=/: *(.*)$/;
      $value=~s/^\s+//;
      $value=~s/\s+$//;
      $value=~s/\s*,\s*/,/g;
      my @tags=split(',', $value);
      $output->{tags}=\@tags;
    } elsif (/^markup:\s*$/){
      # old articles have empty markup, set those to the 'Basic' default on next edit
      $output->{markup}="Basic";
    } else {
      my ($key)=/^(.*?):/;
      my ($value)=/: *(.*)$/;
      $output->{lc($key)}=$value if ($key ne "" && $value ne "");
    }
    $body=1 if (/^$/);
  }
  $output->{body}=~s/^\s+//;
  $output->{body}=~s/\s+$//;
  $output->{olddraft}=$output->{draft} if (defined $output->{draft});
}

sub connectDB{
  my $dbhandle=$handle;
  my $dbc=$c->getValues("database");

  $dbhandle="$handle/$instance" if (defined $dbc->{"$handle/$instance"});
  die("There's no configuration for DB-handle '$handle'") if (not defined $dbc->{$dbhandle});
  my $o={};
  $o->{type}=$dbc->{$dbhandle}->{type}||"mysql";
  $o->{dbname}=$dbc->{$dbhandle}->{1}->{dbname}||$dbc->{$dbhandle}->{dbname};
  $o->{user}=$dbc->{$dbhandle}->{1}->{user}||$dbc->{$dbhandle}->{user}||"";
  $o->{password}=$dbc->{$dbhandle}->{1}->{password}||$dbc->{$dbhandle}->{password}||"";

  my $dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}", $o->{user},
                    $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
                      die "DBI->connect(): ". DBI->errstr;
  $backend=new AwfulCMS::ModBlog::BackendMySQL({dbh => $dbh});
}

sub pingURLs{
  my $args=shift;

  return if ($args->{draft}!=0);
  eval "require HTML::FormatText::WithLinks::AndTables";
  print $OUT "Require HTML::FormatText::WithLinks::AndTables failed ($@)" if ($@);

  my $body=AwfulCMS::SynBasic->format($args->{body},
                                      {blogurl=>$mcm->{'content-prefix'}});

  my $text=HTML::FormatText::WithLinks::AndTables->convert($body);
  my $excerpt=substr($text, 0, 240);
  $excerpt.=" [...]" if (length $text > 240);
  my $url="$mcm->{'baselink'}/article,$args->{id}/";

  my @urls=$args->{body}=~m{\[\[(http://[^ |\]]*)}gx;
  foreach(@urls){
    if (/\.exe$/ || /\.gz$/ || /\.zip$/ || /\.bz2$/){
      print $OUT "Skipping '$_'.\n";
      next;
    } else {
      print $OUT "Checking '$_'... ";
    }

    if ($features{trackback_client}==1){
      my $client = Net::Trackback::Client->new;
      my $data = $client->discover($_);
      if ($data){ # we found a trackback url
        if ($features{trackback_client}==1){
          for my $resource (@$data) {
            #print $OUT "(".$resource->ping.")";
            print $OUT "sending trackback... ";
            my $p = {
                     ping_url=>$resource->ping,
                     blog_name=>$mcm->{'title-prefix'},
                     excerpt=>$excerpt,
                     url=>"$url",
                     title=>$args->{title}
                    };
            my $ping = Net::Trackback::Ping->new($p);
            my $msg = $client->send_ping($ping);
            if ($msg->is_success){
              print $OUT "done\n";
            } else {
              print $OUT "failed (".$msg->message().")\n";
            }
          }
        } else {
          print $OUT "Net::Trackback::Ping missing, unable to send trackback\n";
        }
      } else {
        if ($features{rpc_xml_client}==1){
          my $ua=LWP::UserAgent->new();
          my $response=$ua->head($_);
          my $ping;
          if ($response->is_success && ($ping=$response->header("X-Pingback"))){
            print $OUT "sending pingback... ";
            #print $OUT "Pingback to: $ping\n";
            my $client = RPC::XML::Client->new($ping);
            my $response = $client->send_request('pingback.ping', $url, $_);
            #fixme, properly parse return codes
            if (not ref $response) {
              print $OUT "Failed to ping back '$ping': $response\n";
            } else {
              print $OUT "Got a response from '$ping': \n" . $response->as_string . "\n";
            }
          } else {
            print $OUT "trackback/pingback url not found\n";
          }
        } else {
          print $OUT "RPC::XML::Client missing, unable to send pingback\n";
        }
      }
    }
  }
}

sub editArticle{
  my $ID=shift;
  my @result;
  my %newarticle;

  my $d=$backend->getArticle($ID);
  if (defined $d){
    my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
    @{$d->{tags}}=$backend->getTagsForArticle($d->{id}, \&cb_die);
    print $tmp formatArticle($d);
    system("vi $tmp");
    openreadclose($tmp, \@result);
    parseArticle(\@result, \%newarticle);
    if ($newarticle{body} eq ""){
      print "Skipping article due to empty body\n";
      return;
    }
    my %newhash=(%$d, %newarticle);
    print $backend->updateOrEditArticle(\%newhash)."\n";
    $backend->setTags($d->{id}, $d->{tags}, $newhash{tags});
    pingURLs(\%newhash);
    unlink $tmp;
  } else {
    print $OUT "No such article\n";
  }
}

sub listArticles{
  my $opt=shift;
  my $page=shift;

  my $draft=0;

  if ($opt eq "d"){
    $draft=1 if ($opt eq "d");
    $page=1 unless ($page =~ /[0-9+]/);
  } elsif ($opt =~ /[0-9]+/){
    $page=$opt;
  } else {
    $page=1;
  }

  my $numarticles=20;

  my ($cnt)=$backend->getArticleCount(0);
  my $pages=int($cnt/$numarticles);
  $pages++ unless ($cnt=~/0$/);

  $page=1 if ($page<=0);
  my $offset=($page-1)*$numarticles;

  my $t=Text::ASCIITable->new({ headingText => "$cnt articles on page $page/$pages" });
  $t->setCols('ID', 'Subject', 'Created', 'Changed', 'Tease');

  # created / changed / tease / 4-digit ID and additional padding
  # TODO: this will fail for longer IDs, but we need to set the col width
  #       before getting the data
  my $content_size = 22 + 22 + 8 + 5 + 5;
  my ($wchar, $hchar, $wpixels, $hpixels) = GetTerminalSize();

  $t->setColWidth('Subject', $wchar - $content_size);

  $backend->getArticleList({
                            pid=>0,
                            limit=>$numarticles,
                            draft=>$draft,
                            offset=>$offset,
                            cb_format=>sub{
                              my $d=shift;
                              my $dt=strftime '%Y-%m-%d %H:%M:%S', localtime($d->{created});
                              $t->addRow($d->{id}, $d->{subject},
                                         $dt, $d->{changed},
                                         $d->{tease});},
                           });

  print $OUT $t;
}

sub printArticle{
  my $ID=shift;
  my $d=$backend->getArticle($ID);
  if (defined $d){
    @{$d->{tags}}=$backend->getTagsForArticle($d->{id}, \&cb_die);
    print $OUT formatArticle($d)
  } else {
    print $OUT "No such article\n";
  }
}

sub newArticle{
  my %newarticle;
  my @result;
  my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
  my $markup=$mc->{markup}||"Basic";
  print $tmp <<END;
Subject:
Name: $mc->{name}
EMail: $mc->{email}
Homepage: $mc->{homepage}
Pid: 0
Rpid: 0
Lang: $mc->{lang}
Draft: $mc->{draft}
Tease: $mc->{tease}
Markup: $markup
Tags:

END
  system("vi $tmp");
  openreadclose($tmp, \@result);
  parseArticle(\@result, \%newarticle);
  if ($newarticle{body} eq ""){
    print "Skipping article due to empty body\n";
    return;
  }
  print $backend->updateOrEditArticle(\%newarticle)."\n";
  $backend->setTags($newarticle{id}, $newarticle{tags});
  unlink $tmp;
  pingURLs(\%newarticle);
}

sub help{
  print $OUT <<END;
d|delete <article-id>     delete the article with the given ID
e|edit   <article-id>     open the article with the given ID in the editor
h|help                    show this help text
l|list                    list all articles
  [d|draft]               list all drafts
  [s|series]              list all configured series
  [<page>]                list the given page (1-n, default 1)
n|new                     prepare a new article and open in the editor
p|print  <article-id>     print the article with the given ID
q|quit                    exit this program
u|update                  update/create SQL databases
END
}

sub main{
  my $term = new Term::ReadLine 'AwfulCMS Blog';
  my $prompt = "> ";
  $OUT = $term->OUT || \*STDOUT;
  my %article;

  print $OUT "Using blog at $mcm->{baselink}\n";
  connectDB();
  while ( defined ($_ = $term->readline($prompt)) ) {
    my @cmd=split(/ /, $_);

    if ($cmd[0] eq "d" || $cmd[0] eq "delete"){
      if ($cmd[1] eq ""){
        print $OUT "Missing article ID. See `help' for details.";
        next;
      }
      $backend->deleteArticle($cmd[1]);
    } elsif ($cmd[0] eq "e" || $cmd[0] eq "edit"){
      if ($cmd[1] eq ""){
        print $OUT "Missing article ID. See `help' for details.";
        next;
      }
      editArticle($cmd[1]);
    } elsif($cmd[0] eq "h" || $cmd[0] eq "help"){
      help();
    } elsif ($cmd[0] eq "l" || $cmd[0] eq "list"){
      listArticles($cmd[1]);
    } elsif ($cmd[0] eq "p" || $cmd[0] eq "print"){
      if ($cmd[1] eq ""){
        print $OUT "Missing article ID. See `help' for details.";
        next;
      }
      printArticle($cmd[1]);
    } elsif ($cmd[0] eq "n" || $cmd[0] eq "new"){
      newArticle();
    } elsif ($cmd[0] eq "u" || $cmd[0] eq "update"){
      $backend->createdb();
    } elsif ($cmd[0] eq "q" || $cmd[0] eq "quit"){
      exit(0);
    } else {
      print "Unknown command `$cmd[0]'\n" unless ($cmd[0] eq "");
    }
    $term->addhistory($_) if /\S/;
  }
}

main();
