package AwfulCMS::ModBlog::BackendMySQL;

=head1 AwfulCMS::ModBlog::BackendMySQL

This module proveds MySQL backend specific code for ModBlog

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

# execute callback for receiving dbh, if set
sub getDbh{
  my $s=shift;

  if (defined $s->{cb_dbh} and ref $s->{cb_dbh} eq 'CODE'){
    $s->{dbh}=$s->{cb_dbh}->();
  }

  $s->{dbh};
}

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

=item getTags($id)

Returns an array with the tags for article $id. A function reference may
be passed as optional argument as callback for error handling.

=cut

sub getTags{
  my $s=shift;
  my $id=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();
  my ($data, @tags);

  my $q_a=$dbh->prepare("select tag from blog_tags where id=?") || $s->err("Unable to prepare query: $!", $cb);
  $q_a->execute($id) || $s->err("Unable to execute query: $!", $cb);
  $data=$q_a->fetchall_arrayref({});

  push(@tags, $_->{tag}) foreach (@$data);
  @tags;
}

=item dropdb()

Drops all blog databases

=cut

sub dropdb{
  my $s=shift;
  my $dbh=$s->getDbh();
  my @queries;
  push(@queries, "DROP TABLE IF EXISTS blog");
  push(@queries, "DROP TABLE IF EXISTS blog_mp");
  push(@queries, "DROP TABLE IF EXISTS blog_tb");
  push(@queries, "DROP TABLE IF EXISTS blogdel");
  foreach(@queries){
    $dbh->do($_);
  }
}

1;
