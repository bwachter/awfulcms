package AwfulCMS::ModMidget;

use strict;

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
			   -content=>"html"}
	       };

  $s->{mc}=$r->{mc};
  bless $s;
  $s;
}

my @sourceurl;

sub cb{
  my($tag, %links) = @_;
  return if $tag ne 'a';
  while (my ($key,$value)=each(%links)){
    if ($value=~/source$/){
      push(@sourceurl, $value);
    }
  }
}

sub getArticleGoogle(){
  my $s=shift;
  my $p=$s->{page};
  my $mid=shift;
  my $article;

  eval "require LWP::UserAgent";
  $p->status(500, $@) if ($@);

  eval "require HTML::LinkExtor";
  $p->status(500, $@) if ($@);

  my $parser=HTML::LinkExtor->new(\&cb);

  my $ua=LWP::UserAgent->new;
  $ua->agent($s->{mc}->{useragent}) if ($s->{mc}->{useragent});

  my $response=$ua->get("http://groups.google.com/groups?selm=$mid&output=gplain");
  if (!$response->is_success){return $response->status_line};
  $parser->parse($response->decoded_content);
  if (@sourceurl>=1){
    $response=$ua->get("http://groups.google.com/$sourceurl[1]&output=gplain");
    if (!$response->is_success){return $response->status_line};
    $article=$response->decoded_content;
  }

  $article;
}

sub getArticleNNTP(){
  my $s=shift;
  my $p=$s->{page};
  my $server=shift;
  my $mid=shift;
  my $nntp;
  my $article;

  eval "require Net::NNTP";
  $p->status(500, $@) if ($@);

  $nntp = Net::NNTP->new($server)||
    $p->status(500, $@);
  $article=$nntp->article($mid);
  $nntp->quit;
  $article;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  my $server=$s->{mc}->{newsserver} if ($s->{mc}->{newsserver});
  $server=$p->{cgi}->param('server') if ($p->{cgi}->param('server'));
  my $mid=$p->{cgi}->param('mid') if ($p->{cgi}->param('mid'));
  my $submit=$p->{cgi}->param('submit');

  $p->title("midget");
  $p->add("<h1>midget</h1>
<form name=\"foo\" method=\"post\" action=\"/$p->{rq_dir}/$p->{rq_file}\"><table border=\"0\">
<tr><td>MID:</td><td><input type=\"text\" name=\"mid\" value=\"$mid\" size=\"40\" /></td></tr>
<tr><td>Server:</td><td><input type=\"text\" name=\"server\" value=\"$server\" size=\"40\" /></td></tr>
<tr><td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td><td><input type=\"submit\" name=\"submit\" value=\"GoGoGoogle!\" /></td></tr>
</table></form><hr>");

  return if ($mid eq "");

  my $article;
    $article=$s->getArticleGoogle($mid);
  if ($submit eq "GoGoGoogle!"){
    $article=$s->getArticleGoogle($mid);
  } else {
    $article=$s->getArticleNNTP($server, $mid);
  }

  if ($article eq ""){
    $p->add("<p>Unable to retrieve article <$mid></p>");
  } else {
    $p->add("<pre>$article</pre>");
  }
}

1;
