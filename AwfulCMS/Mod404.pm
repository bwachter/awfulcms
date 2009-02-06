package AwfulCMS::Mod404;

=head1 AwfulCMS::Mod404

This module returns a 404 (not found) state, together with a configurable error message.
You can use this as the default module if you don't want every url to match something.

=head2 Configuration parameters

=over

=item * errortext=<string>

The text to display on the 404-page

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
  $s->{mc}->{errortext}="Page not found" unless (defined $r->{mc}->{errortext});

  bless $s;
  $s;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  $p->status(404, $s->{mc}->{errortext});
}

1;
