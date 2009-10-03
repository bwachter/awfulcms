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

use Exporter 'import';
our @EXPORT_OK=qw(getrequest);

sub new {
  shift;
  my $_request=shift;
  my $_baseurl=shift;
  my $s={};
  bless $s;

  $s->{args}={};
  $s->{baseurl}=$_baseurl;

  $_request=~s/^\/*//;
  $_request=~s/^$_baseurl//;
  $_request=~s/^\/*//;

  # sometimes we need req= as additional argument
  $s->{arguments}=$_request;
  ($s->{request}, $s->{xarguments})=$_request=~m/(.*?)\/(.*)/;

  my @_arguments=split('/', $s->{arguments});
  foreach (@_arguments){
    # FIXME, url quote/unquote
    $_=~s/\%2C/,/g;
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

sub buildurl {
  # FIXME, initialize with dir or params, and return cgi style urls, too
  # FIXME, allow removal of baseurl
  my $s=shift;
  my $args=shift;
  my $baseurl=shift;
  my $url;
  my $request;

  $baseurl=$s->{baseurl} if ($baseurl eq "");

  foreach my $key (sort(keys(%{$args}))){
    if ($key eq "req"){
      $request=$args->{$key};
    } else {
      $url.="$key,$args->{$key}/";
    }
  }
  "/$baseurl/$request/$url";
}

1;

=back

=cut
