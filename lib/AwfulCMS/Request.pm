package AwfulCMS::Request;
# Request.pm
# (c) 2010 Bernd Wachter <bwachter@lart.info>

=head1 Request.pm

Foo.

=cut

use strict;
#use Exporter 'import';
#our @EXPORT_OK=qw(method1 method2);

sub new {
  shift;
  my $s={};
  bless $s;

  $s->{remote_host}=$ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 'localhost';
  $s->{remote_ip}=$ENV{'REMOTE_ADDR'} || '127.0.0.2';
  $s->{ssl}=1 if ($ENV{'HTTPS'} eq "on");
  $s->{host}=$s->http('x_forwarded_host') || $s->http('host') || $s->p('SERVER_NAME') || 'localhost';
  $s->{host}=~s/:\d+$//; #remove port number
  $s->{fileabs}=$ENV{'REQUEST_URI'}; # have a look at the other stuff in CGI.pm
  $s->{fileabs}=~s/^\///;
  $s->{fileabs}=~s/%20/ /;
  ($s->{dir})=$s->{fileabs}=~m/(.*)\/(.*)/;
  $s->{dir}="." if ($s->{dir} eq "");
  ($s->{file})=$s->{fileabs}=~m/.*\/(.*)/;
  $s;
}

=item parseCookies()

Parse cookies in the request, and provide them in a hash, cookie values
in arrays. Cookie values remain in the order provided by the client,
most significant first.

Cookies with empty values are ignored.

Cookies with urldecoded values are stored in 'cookies', without decoding
in 'raw_cookies'

=cut

sub parseCookies{
  my $s=shift;

  if (defined $ENV{'HTTP_COOKIE'}){
    my @cookies=split(';', $ENV{'HTTP_COOKIE'});
    foreach(@cookies){
      my ($key, $value)=split(/=/);
      $key=~s/\s*//g;
      push (@{$s->{raw_cookies}->{$key}}, $value) if ($value ne "");
      $value=~s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
      push (@{$s->{cookies}->{$key}}, $value) if ($value ne "");
    }
  }
}

=item p()

Return an entry from the environment

=cut

sub p {
  my $s=shift;
  my $param=shift;

  return $ENV{"$param"};
}

=item http()

Return an entry from the environment, upcasing the argument and prefixing
it with HTTP_

=cut

sub http {
  my $s=shift;
  my $param=shift;

  $param=~s/-/_/g;
  return $s->p("HTTP_\U$param\E");
}

1;
