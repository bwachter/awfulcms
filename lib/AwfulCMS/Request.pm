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

  # Those variables are based on what lighttpd sets
  # TODO: Check with (and enable support for) other webservers
  # This piece should be the only webserver-specific code

  # information about the remote side
  $s->{remote_host}=$ENV{'REMOTE_HOST'} || $ENV{'REMOTE_ADDR'} || 'localhost';
  $s->{remote_ip}=$ENV{'REMOTE_ADDR'} || '127.0.0.2';
  $s->{remote_port}=$ENV{'REMOTE_PORT'} || '0';
  $s->{user_agent}=$ENV{'HTTP_USER_AGENT'} || "Unknown";

  # information about the server side
  $s->{host}=$ENV{'HTTP_X_FORWARDED_HOST'} || $ENV{'HTTP_HOST'} || $ENV{'SERVER_NAME'} || 'localhost';
  $s->{host}=~s/:\d+$//; #remove port number
  $s->{port}=$ENV{'SERVER_PORT'};
  $s->{ip}=$ENV{'SERVER_ADDR'};
  $s->{protocol}=$ENV{'SERVER_PROTOCOL'};
  $s->{cgi}=$ENV{'GATEWAY_INTERFACE'};
  $s->{software}=$ENV{'SERVER_SOFTWARE'};

  # information about the request
  $s->{ssl}=1 if ($ENV{'HTTPS'} eq "on");
  $s->{referer}=$ENV{'HTTP_REFERER'} || '';
  $s->{method}=$ENV{'REQUEST_METHOD'};
  $s->{length}=$ENV{'CONTENT_LENGTH'};

  # raw header, needs to be parsed later
  # 'HTTP_AUTHORIZATION' => 'Basic Zm9vOmJhcg==',
  $s->{authorization}=$ENV{'HTTP_AUTHORIZATION'};
  $s->{user}=$ENV{'REMOTE_USER'};
  # TODO: Unused request variables:
  # 'HTTP_ACCEPT_ENCODING' => 'gzip, deflate',
  # 'HTTP_CONNECTION' => 'keep-alive',
  # 'HTTP_ACCEPT' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
  # 'REDIRECT_STATUS' => '200',
  # 'HTTP_ACCEPT_LANGUAGE' => 'en-US,en;q=0.7,de-DE;q=0.3',


  # information about the called file
  $s->{docroot}=$ENV{'DOCUMENT_ROOT'};
  # script relative to docroot; may be nonsensical
  $s->{scriptrel}=$ENV{'SCRIPT_NAME'};
  # script path in the filesystem
  # docroot/scriptrel _should_ be same as scriptabs, though in some cases
  # (blog) an additional directory gets added to SCRIPT_NAME for some reason
  $s->{scriptabs}=$ENV{'SCRIPT_FILENAME'};

  $s->{fileabs}=$ENV{'REQUEST_URI'}; # have a look at the other stuff in CGI.pm
  $s->{fileabs}=~s/^\///;
  $s->{fileabs}=~s/%20/ /;
  ($s->{dir})=$s->{fileabs}=~m/(.*)\/(.*)/;
  $s->{dir}="." if ($s->{dir} eq "");
  ($s->{file})=$s->{fileabs}=~m/.*\/(.*)/;

  $s->parseCookies();

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
