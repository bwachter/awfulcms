package AwfulCMS::ModMidget;

=head1 AwfulCMS::ModMidget

This module allows retrieving a Usenet article by message-ID from either a
NNTP-server or Google groups.

=head2 Configuration parameters

=over

=item * useragent=<string>

The useragent to use for HTTP-Requests. Google will most likely not
allow requests if you don't set this option. Something like Mozilla/5.0
should work fine.

=item * newsserver=<string>

The default newsserver to display in the web form. The name can be changed
before submitting the form, it's just a bit more convenient not having to
type in a newsserver name for every lookup

=back

=cut

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

  my $ua=LWP::UserAgent->new();
  $ua->agent($s->{mc}->{useragent}) if ($s->{mc}->{useragent});

  my $response=$ua->get("http://groups.google.com/groups?selm=$mid&output=gplain");
  if (!$response->is_success){return "Stage 1 failed: ".$response->status_line};
  $parser->parse($response->decoded_content);
  if (@sourceurl>=1){
    $response=$ua->get("http://groups.google.com/$sourceurl[0]&output=gplain");
    if (!$response->is_success){return "Stage 2 failed: ".$response->status_line};
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

  $nntp=Net::NNTP->new($server)||
    $p->status(500, $@);
  $article=$nntp->article("<$mid>");
  $nntp->quit;
  return join('', @$article) if (ref($article) eq "ARRAY");
  return $article;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  my $server=$s->{mc}->{newsserver} if ($s->{mc}->{newsserver});
  $server=$p->{url}->param('server') if ($p->{url}->param('server'));
  my $mid=$p->{url}->param('mid') if ($p->{url}->param('mid'));
  my $submit=$p->{url}->param('submit');

  $p->title("midget");
  $p->add("<h1>midget</h1>
<form name=\"foo\" method=\"post\" action=\"/".$p->{url}->cgihandler()."\"><table border=\"0\">
<tr><td>MID:</td><td><input type=\"text\" name=\"mid\" value=\"$mid\" size=\"40\" /></td></tr>
<tr><td>Server:</td><td><input type=\"text\" name=\"server\" value=\"$server\" size=\"40\" /></td></tr>
<tr><td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td><td><input type=\"submit\" name=\"submit\" value=\"GoGoGoogle!\" /></td></tr>
</table></form><hr />");

  return if ($mid eq "");
  $mid=~s/[<>]//g;

  my $article;

  if ($submit eq "GoGoGoogle!"){
    $article=$s->getArticleGoogle($mid);
  } else {
    $article=$s->getArticleNNTP($server, $mid);
  }

  if ($article eq ""){
    $p->add("<p>Unable to retrieve article &lt;$mid&gt;</p>");
  } else {
    (my $references)=$article=~m/References:((\s*<[\w%\$\+@\.-]*>\s*){1,})/s;
    $article=~s/References:(\s*<[\w%\$\+@\.-]*>\s*){1,}/\[\@REFERENCES\@\]\n/s;
    $references=~s/[\s<]//g;
    my @references=split('>', $references);

    $article=~s/</&lt;/g;
    $article=~s/>/&gt;/g;
    $article=~s/\n/<br \/>/g;

    $references="";
    foreach(@references){
      $references.="<a href=\"".$p->{url}->publish({'mid'=>$_,
                                               'submit'=>$submit})."\">&lt;$_&gt;</a> ";
    }
    $article=~s/\[\@REFERENCES\@\]/References: $references/;

    my $url=$p->{url}->publish({'mid'=>$mid,
                                'submit'=>$submit});
    $p->add("<p>Use this URL to show this article to someone else: <a href=\"$url\">$url</a></p>");
    $p->add("<p>$article</p>");
  }
}

1;
