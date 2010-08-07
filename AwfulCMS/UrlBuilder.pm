package AwfulCMS::UrlBuilder;

=head1 AwfulCMS::UrlBuilder

This library provides a few functions for graphic manipulation

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

C<our @EXPORT_OK=qw(thumbnail);>

=over

=cut

use strict;

use CGI;
use Exporter 'import';
use URI::Escape;
our @EXPORT_OK=qw(getrequest);

sub new {
  shift;
  my $_request=shift;
  my $_baseurl=shift;
  my $s={};
  bless $s;
  $s->{rq}=shift;

  #FIXME, make this configurable
  $s->{pathsep}=",,";
  $s->{args}={};
  $s->{baseurl}=$_baseurl;

  $_request=~s/^\/*//;
  $_request=~s/^$_baseurl//;
  $_request=~s/^\/*//;
  $_request=~s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;

  # sometimes we need req= as additional argument
  $s->{arguments}=$_request;
  ($s->{request}, $s->{xarguments})=$_request=~m/(.*?)\/(.*)/;
  $s->{request}=~s/,.*$//;

  my $cgi=new CGI;
  my $vars=$cgi->Vars();

  foreach my $key (sort(keys(%$vars))){
    $s->{args}->{$key}=$vars->{$key};
  }

  my @_arguments=split('/', $s->{arguments});
  foreach (@_arguments){
    # FIXME, url quote/unquote
    $_=~s,$s->{pathsep},/,g;
    $_=~s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
    my @_argarr=split(',', $_);
    my $key=shift(@_argarr);
    my $value=join(',',@_argarr);
    $s->{args}->{$key}=$value;
  }
  $s;
}

sub param {
  my $s=shift;
  my $key=shift;

  return $s->{args}->{$key};
}

sub encodeurl {

}

sub buildurl {
  # FIXME, initialize with dir or params, and return cgi style urls, too
  # FIXME, allow removal of baseurl
  my $s=shift;
  my $args=shift;
  my $baseurl=shift;
  my $url;
  my $request;

  $baseurl=$s->{baseurl} if ($baseurl eq "");

  $request=uri_unescape($args->{req}) if (defined $args->{req});
  delete $args->{req};
  foreach my $key (sort(keys(%{$args}))){
    if ($key eq $request){
      $request.=",$args->{$key}";
    } else {
      $args->{$key}=~s,/+,$s->{pathsep},g;
      $args->{$key}=~s,^$s->{pathsep},,g;
      $url.="$key,$args->{$key}/";
    }
  }
  "/$baseurl/$request/$url";
}

sub myurl {
  my $s=shift;
  my $url;

  #fixme, check for https
  $url="http://".$s->{rq}->{host}."/".$s->{rq}->{dir}."/".$s->{page}->{rq}->{file}
}
sub cgihandler {
  my $s=shift;

  $s->{baseurl};
}

sub publish {
  my $s=shift;
  my $url=shift;

  $url=$s->buildurl($url) if (ref $url eq "HASH");
  #fixme, check for https
  $url=$s->{rq}->{host}."/$url";
  $url=~s,/+,/,g;
  $url=~s/([^A-Za-z0-9\.])/sprintf("%%%02X", ord($1))/seg;
  $url=~s,%2F,/,g;
  "http://$url";
}

1;

=back

=cut
