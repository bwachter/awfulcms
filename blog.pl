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
use AwfulCMS::Page;
require DBI;
use strict;
use XML::RSS;

# config part
my $handle="ModBlog";

my @keys=('pid', 'rpid', 'subject', 'body', 'lang', 'name', 'email', 'homepage', 'draft');
my @fixedkeys=('id');

# global values
my $c=AwfulCMS::Config->new("");
my $mc=$c->getValues("ModBlogCLI");
my $mcm=$c->getValues("ModBlog");
my $dbh;
my $OUT;

$mcm->{'title-prefix'}="Blog" unless (defined $mcm->{'title-prefix'});
$mcm->{baselink}="" unless (defined $mcm->{baselink});
$mcm->{description}="Some blog without description" unless (defined $mcm->{description});

sub updateRSS{
  my $result;
  return unless (defined $mcm->{rsspath});
  my $rss = new XML::RSS(encoding => 'ISO-8859-1');
  $rss->channel(title=>$mcm->{'title-prefix'},
		'link'=>$mcm->{baselink},
		description=>$mcm->{description});

  my $q = $dbh->prepare("select id,subject,body,created from blog where pid=0 and draft=0 order by created desc limit 15") ||
    return;
  #&myDie("Unable to prepare query for updating RSS: $!");
  $q->execute() || return;
    #&myDie("Unable to execute the query for updating RSS: $!");
  while ($result=$q->fetchrow_hashref()) {
    my $body=AwfulCMS::Page->pString($result->{body});
    my $created=localtime($result->{created});
    # update RSS feed
    $rss -> add_item(title => $result->{subject},
		     'link' => "$mcm->{baselink}/?req=article&article=$result->{id}",
		     description => AwfulCMS::Page->pRSS($body),
		     dc=>{
			  date       => $created
			 }
		    );
  }
  $rss->save($mcm->{docroot}."/".$mcm->{rsspath});
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
  my $q_u = $dbh->prepare("update blog set pid=?, rpid=?, subject=?, body=?, lang=?, name=?, email=?, homepage=?, draft=?, created=? where id=?");
  my $q_i = $dbh->prepare("insert into blog(pid, rpid, subject, body, lang, name, email, homepage, draft, created) values (?,?,?,?,?,?,?,?,?,?)");
  my $q_s = $dbh->prepare("select id from blog where pid=? and rpid=? and subject=? and body=? and lang=? and name=? and email=? and homepage=? and draft=? and  created=?");

  $args->{homepage}="" unless (defined $args->{homepage});
  foreach (@keys){
    return "Key $_ not found" unless (defined $args->{$_});
  }

  if ($args->{id}){
    $args->{created}=time() if ($args->{olddraft}==1);
    $q_u->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body}, 
		  $args->{lang}, $args->{name}, $args->{email},
		  $args->{homepage}, $args->{draft}, $args->{created}, $args->{id})||return "Unable to insert new record: $!\n";
  } else {
    my $created=time();
    my $href;
    $q_i->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body}, 
		  $args->{lang}, $args->{name}, $args->{email},
		  $args->{homepage}, $args->{draft}, $created)||return "Unable to insert new record: $!\n";
    $q_s->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body}, 
		  $args->{lang}, $args->{name}, $args->{email},
		  $args->{homepage}, $args->{draft}, $created)||return "Unable to insert new record: $!\n";
    $href=$q_s->fetchrow_hashref();
    $args->{id}=$href->{id};
  }
}


sub getTags{
  my $id=shift;
  my ($data, @tags);

  my $q_a=$dbh->prepare("select tag from blog_tags where id=?");
  $q_a->execute($id);
  $data=$q_a->fetchall_arrayref({});

  push(@tags, $_->{tag}) foreach (@$data);
  @tags;
}

sub setTags{
  my $id=shift;
  my $oldtags=shift;
  my $newtags=shift;
  my (@createtags, @deletetags);
  my (%oldhash, %newhash);
  my $q_i = $dbh->prepare("insert into blog_tags(id, tag) values (?,?)");
  my $q_d = $dbh->prepare("delete from blog_tags where id=? and tag=?");

  die "oldtags ne array" unless (ref($oldtags) eq "ARRAY");
  if (defined $newtags){
    die "newtags ne array" unless (ref($newtags) eq "ARRAY");

    $newhash{$_}=1 foreach(@$newtags);
    $oldhash{$_}=1 foreach(@$oldtags);

    foreach(@$newtags){
      push (@createtags, $_) unless (defined $oldhash{$_});
    }

    foreach(@$oldtags){
      push (@deletetags, $_) unless (defined $newhash{$_});
    }


    $q_d->execute($id, $_) foreach(@deletetags);
    $q_i->execute($id, $_) foreach(@createtags);
  } else {
    $q_i->execute($id, $_) foreach(@$oldtags);
  }
}

sub deleteTags{
  my $id=shift;
  my $tags=shift;
  my $q_i = $dbh->prepare("delete into blog_tags where id=? and tag=?");
  foreach(@$tags){
    $q_i->execute($id, $_);
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
    @{$d->{tags}}=getTags($d->{id});
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
    setTags($d->{id}, $d->{tags}, %newhash->{tags});
    updateRSS();
    unlink $tmp;
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
    @{$d->{tags}}=getTags($d->{id});
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
Subject: 
Name: $mc->{name}
EMail: $mc->{email}
Homepage: $mc->{homepage}
Pid: 0
Rpid: 0
Lang: $mc->{lang}
Draft: $mc->{draft}
Tags: 

END
  system("vi $tmp");
  openreadclose($tmp, \@result);
  parseArticle(\@result, \%newarticle);
  if (%newarticle->{body} eq ""){
    print "Skipping article due to empty body\n";
    return;
  }
  print writeArticleDB(\%newarticle)."\n";
  setTags(%newarticle->{id}, %newarticle->{tags});
  unlink $tmp;
  updateRSS();
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
