package AwfulCMS::ModBlog::CLI;
use parent 'AwfulCMS::CLIModule';

=head1 CLI.pm

CLI module for ModBlog. Most of this code is old blog.pl code
packed into a nice module

=head2 Module functions

=over

=cut

use strict;
use Term::ReadKey;
use POSIX 'strftime';
use Text::ASCIITable;
use AwfulCMS::LibFS qw(openreadclose);
use AwfulCMS::ModBlog::BackendMySQL;
use AwfulCMS::SynBasic;

sub new{
  shift;
  my $o=shift;
  my $s={};

  if (ref($o) eq "HASH"){
    $s->{dbh}=$o->{dbh} if (defined $o->{dbh});
    $s->{instance}=$o->{instance} if (defined $o->{instance});
  }

  $s->{features} = {
                    trackbacks => {
                                   available => 1,
                                   modules => ["Net::Trackback::Client", "Net::Trackback::Ping", "HTML::FormatText::WithLinks::AndTables"],
                                  },
                    pingbacks => {
                                  available => 0,
                                  modules => ["RPC::XML::Client", "HTML::FormatText::WithLinks::AndTables"],
                                 },
                   };

  bless $s;

  $s->{OUT}=\*STDOUT;
  $s->get_config("ModBlog", $s->{instance});
  $s->check_features();

  $s->{mc}->{'title-prefix'}="Blog" unless (defined $s->{mc}->{'title-prefix'});
  $s->{mc}->{baselink}="" unless (defined $s->{mc}->{baselink});
  $s->{mc}->{description}="Some blog without description" unless (defined $s->{mc}->{description});

  $s->{backend}=new AwfulCMS::ModBlog::BackendMySQL;
  $s->{backend}->{cb_err}=sub{my $e=shift;$s->cb_die($e)};

  $s->connect_db();

  $s;
}

sub cb_die{
  my $s=shift;
  my $e=shift;

  print {$s->{OUT}} "Critical error: $e\n";
}

sub formatArticle{
  my $s=shift;
  my $d=shift;
  my @keys=('pid', 'rpid', 'subject', 'body', 'lang', 'name', 'email', 'homepage', 'draft', 'tease', 'markup');

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
  my $s=shift;
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


sub listArticles{
  my $s=shift;
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

  my ($cnt)=$s->{backend}->getArticleCount(0);
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

  $s->{backend}->getArticleList({
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

  print {$s->{OUT}} $t;
}

sub createArticle{
  my $s=shift;
  my %newarticle;
  my @result;
  my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
  my $markup=$s->{mc}->{markup}||"Basic";
  print $tmp <<END;
Subject:
Name: $s->{mc}->{name}
EMail: $s->{mc}->{email}
Homepage: $s->{mc}->{homepage}
Pid: 0
Rpid: 0
Lang: $s->{mc}->{lang}
Draft: $s->{mc}->{draft}
Tease: $s->{mc}->{tease}
Markup: $markup
Tags:

END
  system("vi $tmp");
  openreadclose($tmp, \@result);
  $s->parseArticle(\@result, \%newarticle);
  if ($newarticle{body} eq ""){
    print "Skipping article due to empty body\n";
    return;
  }
  print $s->{backend}->createOrEditArticle(\%newarticle)."\n";
  $s->{backend}->setTags($newarticle{id}, $newarticle{tags});
  unlink $tmp;
  $s->pingURLs(\%newarticle);
}

sub editArticle{
  my $s=shift;
  my $ID=shift;
  my @result;
  my %newarticle;

  my $d=$s->{backend}->getArticle({id=>$ID, draft=>'%'});
  if (defined $d){
    my $tmp = new File::Temp( UNLINK => 0, SUFFIX => '.dat' );
    @{$d->{tags}}=$s->{backend}->getTagsForArticle($d->{id});
    print $tmp $s->formatArticle($d);
    system("vi $tmp");
    openreadclose($tmp, \@result);
    $s->parseArticle(\@result, \%newarticle);
    if ($newarticle{body} eq ""){
      print "Skipping article due to empty body\n";
      return;
    }
    my %newhash=(%$d, %newarticle);
    print $s->{backend}->createOrEditArticle(\%newhash)."\n";
    $s->{backend}->setTags($d->{id}, $d->{tags}, $newhash{tags});
    $s->pingURLs(\%newhash);
    unlink $tmp;
  } else {
    print {$s->{OUT}} "No such article\n";
  }
}

sub printArticle{
  my $s=shift;
  my $ID=shift;
  my $d=$s->{backend}->getArticle({id=>$ID, draft=>'%'});
  if (defined $d){
    @{$d->{tags}}=$s->{backend}->getTagsForArticle($d->{id});
    print {$s->{OUT}} $s->formatArticle($d)
  } else {
    print {$s->{OUT}} "No such article\n";
  }
}

sub pingURLs{
  my $s=shift;
  my $args=shift;

  return if ($args->{draft}!=0);

  my $body=AwfulCMS::SynBasic->format($args->{body},
                                      {blogurl=>$s->{mc}->{'content-prefix'}});

  my $text=HTML::FormatText::WithLinks::AndTables->convert($body);
  my $excerpt=substr($text, 0, 240);
  $excerpt.=" [...]" if (length $text > 240);
  my $url="$s->{mc}->{'baselink'}/article,$args->{id}/";

  my @urls=$args->{body}=~m{\[\[(http://[^ |\]]*)}gx;
  foreach(@urls){
    if (/\.exe$/ || /\.gz$/ || /\.zip$/ || /\.bz2$/){
      print {$s->{OUT}} "Skipping '$_'.\n";
      next;
    } else {
      print {$s->{OUT}} "Checking '$_'... ";
    }

    # attempt sending both trackbacks and pingbacks
    my $tb_sent=0;

    # first try to send a trackback
    if ($s->{features}->{trackbacks}->{available}==1){
      my $client = Net::Trackback::Client->new;
      my $data = $client->discover($_);
      if ($data){ # we found a trackback url
        for my $resource (@$data) {
          #print {$s->{OUT}} "(".$resource->ping.")";
          print {$s->{OUT}} "sending trackback... ";
          my $p = {
                   ping_url=>$resource->ping,
                   blog_name=>$s->{mc}->{'title-prefix'},
                   excerpt=>$excerpt,
                   url=>"$url",
                   title=>$args->{title}
                  };
          my $ping = Net::Trackback::Ping->new($p);
          my $msg = $client->send_ping($ping);
          if ($msg->is_success){
            print {$s->{OUT}} "done\n";
            $tb_sent=1;
          } else {
            print {$s->{OUT}} "failed (".$msg->message().")\n";
          }
        }
      }
    }

    # if that fails (or trackbacks are not available), try sending a pingback
    if ($s->{features}->{pingbacks}->{available}==1 && $tb_sent==0){
      my $ua=LWP::UserAgent->new();
      my $response=$ua->head($_);
      my $ping;
      if ($response->is_success && ($ping=$response->header("X-Pingback"))){
        print {$s->{OUT}} "sending pingback... ";
        #print {$s->{OUT}} "Pingback to: $ping\n";
        my $client = RPC::XML::Client->new($ping);
        my $response = $client->send_request('pingback.ping', $url, $_);
        #fixme, properly parse return codes
        if (not ref $response) {
          print {$s->{OUT}} "Failed to ping back '$ping': $response\n";
        } else {
          print {$s->{OUT}} "Got a response from '$ping': \n" . $response->as_string . "\n";
        }
      } else {
        print {$s->{OUT}} "trackback/pingback url not found\n";
      }
    }
  }
}

=back

=cut

1;
