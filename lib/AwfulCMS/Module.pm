package AwfulCMS::Module;

=head1 Module.pm

Generic functionality useful for modules more complex than 'hello world'.

=head2 Module functions

=over

=cut

use strict;

=item new()

Generic constructor, currently useless.

=cut

sub new{
  shift;
  my $o=shift;
  my $s={};

  bless $s;
  $s;
}

=item cb_dbh()

Callback for querying a database handle before running a query.

This is required for most modules, as the database handle only
gets allocated I<after> module initialization.

C<< $s->{backend}->{cb_dbh}=sub{$s->cb_dbh()}; >>
=cut

# callback to get the db handle just before a call is made
# the initial module setup does not contain db handles, they're
# only set when actually needed
sub cb_dbh{
  my $s=shift;
  $s->{page}->{dbh};
}

=item cb_error()

Callback for reporting database errors through a B<Page>

To make sure it runs inside of the module scope it's usually
called like this:

C<< $s->{backend}->{cb_err}=sub{my $e=shift;$s->cb_error($e)}; >>

=cut

sub cb_error{
  my $s=shift;
  my $e=shift;
  my $p=$s->{page};

  $p->status(400, $e);
}

=back

=cut

1;
