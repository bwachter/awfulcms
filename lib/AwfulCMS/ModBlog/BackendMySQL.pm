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

=item getComments($id)

Get the comments for a given article, using a format callback for each comment
found in the database.

=cut

sub getComments{
  my $s=shift;
  my $o=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  if (ref $o eq 'HASH'){

  } else {
    my $id=$o;
    $o->{rpid}=$id;
  }

  $o->{draft}=0 unless (defined $o->{draft});

  my $q=$dbh->prepare("select * from blog where rpid=? and draft=? order by created desc") ||
    $s->err("Unable to prepare query: $!", $cb);

  $q->execute($o->{rpid}, $o->{draft});

  # TODO some fallback if no formatting callback is provided
  while (my $d=$q->fetchrow_hashref()){
    if (ref $o->{cb_format} eq 'CODE'){
      $o->{cb_format}->($d);
    }
  }
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

=item getArticlesWithTag($tag, $cb)

Get a list of articles tagged with a specific tag

=cut

sub getArticlesWithTag{
  my $s=shift;
  my $tag=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  my $q=$dbh->prepare("select blog_tags.tag,blog.subject,blog.id from blog_tags left join (blog) on (blog_tags.id=blog.id) where tag=? and draft=0 order by tag")||
    $s->err("Unable to prepare query: $!", $cb);

  $q->execute($tag) || $s->err("Unable to execute query: $!", $cb);
  $q->fetchall_arrayref({});
}

=item getTagsForArticle($id)

Returns an array with the tags for article $id. A function reference may
be passed as optional argument as callback for error handling.

=cut

sub getTagsForArticle{
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

=item getTagList($cb)

Returns an array reference with a complete list of tags

=cut

sub getTagList{
  my $s=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  my $q=$dbh->prepare("select tag from blog_tags group by tag order by tag") ||
    $s->err("Unable to prepare query: $!", $cb);

  $q->execute() || $s->err("Unable to execute query: $!", $cb);
  $q->fetchall_arrayref({});
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

=item getArticle($id)

Return a hash with one article, or an empty hash if the article does not exist.

=cut

sub getArticle{
  my $s=shift;
  my $o=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  if (ref $o eq 'HASH'){
    # TODO: error handling
  } else {
    my $id=$o;
    $o->{id}=$id;
  }

  $o->{draft}=0 unless (defined $o->{draft});

  my $q=$dbh->prepare("select * from blog where id=? and draft=?") ||
    $s->err("Unable to prepare query: $!", $cb);
  $q->execute($o->{id}, $o->{draft});

  my $d=$q->fetchrow_hashref();
  return {} if ($q->rows == 0);
  $d;
}

=item getArticleCount

Return the number of blog articles

=cut

sub getArticleCount{
  my $s=shift;
  my $o=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  if (ref $o eq 'HASH'){
    # TODO: error handling
  } else {
    my $id=$o;
    $o->{pid}=$id;
  }

  $o->{draft}=0 unless (defined $o->{draft});

  my $q=$dbh->prepare("select count(*) from blog where pid=? and draft=?") ||
    $s->err("Unable to prepare query: $!", $cb);
  $q->execute($o->{pid}, $o->{draft});
  $q->fetchrow_array();
}

sub getArticleList{
  my $s=shift;
  my $o=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  $o->{pid}=0 unless (defined $o->{pid});
  $o->{draft}=0 unless (defined $o->{draft});
  $o->{limit}=0 unless (defined $o->{limit});
  $o->{offset}=0 unless (defined $o->{offset});

  my $q=$dbh->prepare("select * from blog where pid=? and draft=? order by created desc limit ? offset ?") ||
    $s->err("Unable to prepare query: $!", $cb);
  $q->execute($o->{pid}, $o->{draft}, $o->{limit}, $o->{offset});

  # TODO some fallback if no formatting callback is provided
  while (my $d=$q->fetchrow_hashref()){
    if (ref $o->{cb_format} eq 'CODE'){
      $o->{cb_format}->($d);
    }
  }
}

sub deleteArticle{
  my $s=shift;
  my $cb=shift;
  my $id=shift;
  my $dbh=$s->getDbh();

  my $q_d=$dbh->prepare("delete from blog where id=?");
  $q_d->execute($id) || $s->err("Error executing query", $cb);
}

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

=item createdb()

Create databases, unless they exist

=cut

sub createdb{
  my $s=shift;
  my $dbh=$s->{page}->{dbh};
  my @queries;

  # TODO: have those queries in a hash, and have them created on demand
  push(@queries, "DROP TABLE IF EXISTS blog");
  push(@queries, "CREATE TABLE blog (".
       "id int(11) NOT NULL auto_increment,".
       "subject tinytext NOT NULL,".
       "body text NOT NULL,".
       "created bigint(20) default NULL,".
       "lang tinyint(4) NOT NULL default '0',".
       "pid int(11) NOT NULL default '0',".
       "rpid int(11) NOT NULL default '0',".
       "`name` tinytext NOT NULL,".
       "email tinytext NOT NULL,".
       "homepage tinytext,".
       "markup tinytext,",
       "`changed` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,".
       "draft int(4) NOT NULL default '1',".
       "PRIMARY KEY  (id),".
       "UNIQUE KEY id_2 (id),".
       "KEY id (id)".
       ") ENGINE=MyISAM AUTO_INCREMENT=195 DEFAULT CHARSET=latin1;");
  push(@queries, "DROP TABLE IF EXISTS blog_mp");
  push(@queries, "CREATE TABLE blog_mp (".
       "pid int(11) NOT NULL default '0',".
       "id varchar(255) NOT NULL default '',".
       "`time` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,".
       "PRIMARY KEY  (pid,id)".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");
  push(@queries, "DROP TABLE IF EXISTS blog_tb");
  push(@queries, "CREATE TABLE blog_tb (".
       "id int(11) NOT NULL auto_increment,".
       "pid int(11) NOT NULL default '0',".
       "url varchar(255) NOT NULL default '',".
       "excerpt text,".
       "title varchar(255) default NULL,".
       "blog_name varchar(255) default NULL,".
       "PRIMARY KEY  (id),".
       "UNIQUE KEY id_2 (id),".
       "KEY id (id)".
       ") ENGINE=MyISAM AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;");
  push(@queries, "DROP TABLE IF EXISTS blogdel");
  push(@queries, "CREATE TABLE blogdel (".
       "id int(11) NOT NULL default '0',".
       "subject tinytext NOT NULL,".
       "body text NOT NULL,".
       "created bigint(20) default NULL,".
       "lang tinyint(4) NOT NULL default '0',".
       "pid int(11) NOT NULL default '0',".
       "`name` tinytext NOT NULL,".
       "email tinytext NOT NULL,".
       "homepage tinytext,".
       "markup tinytext,".
       "`changed` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");
  push(@queries, "DROP TABLE IF EXISTS blog_tags");
  push(@queries, "CREATE TABLE blog_tags (".
       "id int(11) NOT NULL,".
       "tag varchar(50) NOT NULL,".
       "PRIMARY KEY (id, tag)".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");
  push(@queries, "CREATE TABLE blog_series (".
       "article_id int(11) NOT NULL,".
       "name varchar(50) NOT NULL,".
       "PRIMARY KEY (article_id, name)".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");
  push(@queries, "CREATE TABLE blog_series_description (".
       "name varchar(50) NOT NULL,",
       "description varchar (500),",
       "PRIMARY KEY (name),",
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");

  foreach(@queries){
    $dbh->do($_);
  }
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

=back

=cut
