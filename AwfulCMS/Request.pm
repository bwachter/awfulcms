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
  $s->{host}=http('x_forwarded_host') || http('host') || p('SERVER_NAME') || 'localhost';
  $s->{host}=~s/:\d+$//; #remove port number
  $s->{fileabs}=$ENV{'REQUEST_URI'}; # have a look at the other stuff in CGI.pm
  $s->{fileabs}=~s/^\///;
  $s->{fileabs}=~s/%20/ /;
  ($s->{dir})=$s->{fileabs}=~m/(.*)\/(.*)/;
  $s->{dir}="." if ($s->{dir} eq "");
  ($s->{file})=$s->{fileabs}=~m/.*\/(.*)/;
  $s;
}

sub p {
  my $s=shift;
  my $param=shift;

  return $ENV{"$param"};
}

sub http {
  my $s=shift;
  my $param=shift;

  $param=~s/-/_/g;
  return p("HTTP_\U$param\E");
}

1;
