package AwfulCMS::Backend;

=head1 Backend.pm

Generic functionality modules can use to build data(base) backends with. This
base class does not depend on DBI, and should eventually be able to handle
plain text backends as well.

=head2 Module functions

=over

=cut

use strict;

=item new()

Module constructor, which usually should be copied to backends derived from
this.

=cut

sub new{
  shift;
  my $o=shift;
  my $s={};

  if (ref($o) eq "HASH"){
    $s->{dbh}=$o->{dbh} if (defined $o->{dbh});
  }

  bless $s;
  $s;
}

=item getDbh()

Calls a callback to retrieve the DB handle, if set, or just
returns a DB handle set already.

=cut

# execute callback for receiving dbh, if set
sub getDbh{
  my $s=shift;

  if (defined $s->{cb_dbh} and ref $s->{cb_dbh} eq 'CODE'){
    $s->{dbh}=$s->{cb_dbh}->();
  }

  $s->{dbh};
}

=item err($e, $cb)

Handle DB errors C<$e>, calling a callback function C<$cb> if set. C<$cb> overrides
a globally set callback function

=cut

sub err{
  my $s=shift;
  my $e=shift;
  my $cb=shift;

  if (defined $cb and ref $cb eq 'CODE'){
    &$cb($e);
  } elsif (defined $s->{cb_err} and ref $s->{cb_err} eq 'CODE'){
    $s->{cb_err}->($e);
  } else {
    print STDERR "Warning: Using fallback error handler\n";
    die $e;
  }
}

=back

=cut

1;
