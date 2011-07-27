package AwfulCMS::ModRedirect;

=head1 AwfulCMS::ModRedirect

This module allows redirection using the HTTP location header
in case it's more convenient to do redirections using the
application than the webserver configuration.

=head2 Configuration parameters

=over

=item * location=<string>

The location where to redirect. Use different configuration
instances for different mounts if you need to redirect to
different locations.

=back

=cut

use strict;
use AwfulCMS::Page qw(:tags);

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;
  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"mainsite",
                           -content=>"html"}
               };
  $s->{mc}=$r->{mc};
  bless $s;
  $s;
}

sub mainsite(){
  my $s=shift;
  my $p=$s->{page};
  $p->status(500, "No redirection URL specified")
    unless defined ($s->{mc}->{location});

  my $newLocation=$s->{mc}->{location};
  $p->setHeader("Location", "$newLocation");
  $p->h1("Moved content");
  $p->p("This site has moved. If you're not redirected please ".
          "follow <a href=\"$newLocation\">this link</a>");
}


1;
