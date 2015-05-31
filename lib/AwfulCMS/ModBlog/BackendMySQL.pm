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

=item getCommentCnt($id)

Returns the number of comments for the article $id

=cut

sub getCommentCnt{
  my $s=shift;
  my $id=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  my $q_cm=$dbh->prepare("select count(*) from blog where rpid=? and draft=0") ||
    $s->err("Unable to prepare query: $!", $cb);

  $q_cm->execute($id) || $s->err("Unable to execute query: $!", $cb);
  my ($ccnt)=$q_cm->fetchrow_array();
  $ccnt;
}

### Tag handling

=item deleteTags($id, $tags, $cb)

Delete the list of tags associated with article $id

=cut

sub deleteTags{
  my $s=shift;
  my $id=shift;
  my $tags=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  my $q_i = $dbh->prepare("delete into blog_tags where id=? and tag=?") ||
    $s->err("Unable to prepare query: $!", $cb);

  foreach(@$tags){
    $q_i->execute($id, $_);
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

=item setTags($id, $oldtags, $newtags, $cb)

Set tags on an article, optionally deleting tags only in $oldtags and
not in $newtags

=cut

sub setTags{
  my $s=shift;
  my $id=shift;
  my $oldtags=shift;
  my $newtags=shift;
  my $cb=shift;
  my (@createtags, @deletetags);
  my (%oldhash, %newhash);
  my $dbh=$s->getDbh();
  my $q_i = $dbh->prepare("insert into blog_tags(id, tag) values (?,?)");
  my $q_d = $dbh->prepare("delete from blog_tags where id=? and tag=?");

  $s->err("oldtags ne array", $cb) unless (ref($oldtags) eq "ARRAY");

  if (defined $newtags){
    $s->err("newtags ne array", $cb) unless (ref($newtags) eq "ARRAY");

    $newhash{$_}=1 foreach(@$newtags);
    $oldhash{$_}=1 foreach(@$oldtags);

    foreach(@$newtags){
      push (@createtags, $_) unless (defined $oldhash{$_});
    }

    foreach(@$oldtags){
      push (@deletetags, $_) unless (defined $newhash{$_});
    }


    $q_d->execute($id, $_) foreach(@deletetags);
    $q_i->execute($id, $_) foreach(@createtags);
  } else {
    $q_i->execute($id, $_) foreach(@$oldtags);
  }
}


###

# TODO: Fix error handling
sub updateOrEditArticle{
  my $s=shift;
  my $args=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();
  my $q_u = $dbh->prepare("update blog set pid=?, rpid=?, subject=?, body=?, lang=?, name=?, email=?, homepage=?, draft=?, created=?, tease=?, markup=? where id=?");
  my $q_i = $dbh->prepare("insert into blog(pid, rpid, subject, body, lang, name, email, homepage, draft, tease, markup, created) values (?,?,?,?,?,?,?,?,?,?,?,?)");
  my $q_s = $dbh->prepare("select id from blog where pid=? and rpid=? and subject=? and body=? and lang=? and name=? and email=? and homepage=? and draft=? and markup=? and created=?");

  $args->{homepage}="" unless (defined $args->{homepage});
  foreach (@keys){
    return "Key $_ not found" unless (defined $args->{$_});
  }

  if ($args->{id}){
    $args->{created}=time() if ($args->{olddraft}==1);
    $q_u->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body},
                  $args->{lang}, $args->{name}, $args->{email},
                  $args->{homepage}, $args->{draft}, $args->{created},
                  $args->{tease}, $args->{markup}, $args->{id})||return "Unable to insert new record: $!\n";
  } else {
    my $created=time();
    my $href;
    $q_i->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body},
                  $args->{lang}, $args->{name}, $args->{email},
                  $args->{homepage}, $args->{draft}, $args->{tease}, $args->{markup},
                  $created)||return "Unable to insert new record: $!\n";
    $q_s->execute($args->{pid}, $args->{rpid}, $args->{subject}, $args->{body},
                  $args->{lang}, $args->{name}, $args->{email},
                  $args->{homepage}, $args->{draft}, $args->{markup}, $created)||return "Unable to insert new record: $!\n";
    $href=$q_s->fetchrow_hashref();
    $args->{id}=$href->{id};
  }
}

=item getTeasers($)

Returs a list of teasers

=cut

sub getTeasers{
  my $s=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();
  my ($data, @teasers);

  my $q=$dbh->prepare("select subject from blog where draft=1 and tease=1 order by created desc")||
        $s->err("Unable to prepare query: $!", $cb);
  $q->execute();
  $data=$q->fetchall_arrayref({});

  push(@teasers, $_->{subject}) foreach (@$data);
  join("; ", @teasers);
}


### DB Management

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
