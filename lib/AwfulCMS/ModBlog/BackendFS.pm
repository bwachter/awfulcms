package AwfulCMS::ModBlog::BackendFS;
use parent 'AwfulCMS::Backend';
use CDB::TinyCDB;
use YAML::XS;
use Digest::SHA qw(sha256_hex);
use Date::Parse;
use Term::ANSIColor;
use File::Touch;
use utf8;

=head1 AwfulCMS::ModBlog::BackendFS

This module proveds FS backend specific code for ModBlog. Note that for
this backend the assumption is that everything gets pushed in via git or
similar methods, so all editing related functions are just stubs.

=cut

sub new{
  shift;
  my $r=shift;
  my $page=shift;
  my $s={};
  $s->{page}=$page;

  if (ref($r) eq "HASH"){
    $s->{mc}=$r->{mc};
  }

  $s->{rootdir}=$s->{page}->{rq}->{dir};
  $s->{rootdir}=$s->{mc}->{root} if (defined $s->{mc}->{root});
  if (defined $s->{mc}->{rootdir}){
    if (defined $s->{mc}->{root}){
      $s->{rootdir}=$s->{mc}->{rootdir}."/".$s->{mc}->{root};
    } else {
      $s->{rootdir}=$s->{mc}->{rootdir};
    }
  }

  if (defined $s->{mc}->{cdbfile}){
    $s->{cdbfile}=$s->{mc}->{cdbfile};
  } else {
    $s->{cdbfile}=$s->{rootdir}."/index.cdb";
  }
  bless $s;

  unless (-f $s->{cdbfile}){
    print STDERR "index.cdb not available, expected at $s->{cdbfile}\n";
    $s->createIndex();
  } elsif (defined $s->{mc}->{cdbmaxage}) {
    my $now=time();
    $s->{cdb_mtime}=(stat($s->{cdbfile}))[9];
    if ($s->{cdb_mtime} + $s->{mc}->{cdbmaxage} < $now){
      printf STDERR "⏰ cdb too old, regenerating (%s < %s)\n", colored($s->{cdb_mtime} + $s->{mc}->{cdbmaxage}, 'green'), colored($now, 'green');
      $s->{blog_mtime} = $s->{cdb_mtime};
      $s->createIndex();
    }
  }

  $s->{cdb}=CDB::TinyCDB->open($s->{cdbfile});

  $s;
}

=item getCommentCnt($id)

Returns the number of comments for the article $id

=cut

sub getCommentCnt{
  my $s=shift;
  my $id=shift;
  my $cb=shift;

  if (defined $s->{cdb}){
    0;
    #$s->err("Unable to prepare query: $!", $cb);
  } else {
    0;
  }
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

  # TODO some fallback if no formatting callback is provided
  #while (my $d=$q->fetchrow_hashref()){
  #  if (ref $o->{cb_format} eq 'CODE'){
  #    $o->{cb_format}->($d);
  #  }
  #}
}

### Tag handling

=item deleteTags($id, $tags, $cb)

Delete the list of tags associated with article $id

=cut

sub deleteTags{
  -1;
}

=item getArticlesWithTag($tag, $cb)

Get a list of articles tagged with a specific tag.

The expected format is an array with hash elements, each containing at least
'id' and 'subject' keys.

=cut

sub getArticlesWithTag{
  my $s=shift;
  my $tag=shift;
  my $cb=shift;

  my @r;
  my @articles=$s->{cdb}->getall($tag."_content");
  foreach (@articles){
    my $i={};
    $i->{id}=$_;
    $i->{subject}=$s->{cdb}->get("t_$_");
    push @r, $i;
  }
  \@r;
}

=item getTagsForArticle($id)

Returns an array with the tags for article $id. A function reference may
be passed as optional argument as callback for error handling.

The FS backend already has tags in the article metadata.

=cut

sub getTagsForArticle{
  -1;
}

=item getTagList($cb)

Returns an array reference with a complete list of tags

=cut

sub getTagList{
  my $s=shift;
  my $cb=shift;
  my @tags=sort { lc($a) cmp lc($b) } $s->{cdb}->getall("tags");

  \@tags;
}

=item setTags($id, $oldtags, $newtags, $cb)

Set tags on an article, optionally deleting tags only in $oldtags and
not in $newtags

=cut

sub setTags{
  -1;
}


###

=item getArticle($id)

Return a hash with one article, or an empty hash if the article does not exist.

=cut

sub getArticle{
  my $s=shift;
  my $o=shift;
  my $cb=shift;

  if (ref $o eq 'HASH'){
    # TODO: error handling
  } else {
    my $id=$o;
    $o->{id}=$id;
  }

  $o->{draft}=0 unless (defined $o->{draft});

  my $ts=$s->{cdb}->get("id_".$o->{id});
  if ($ts ne ""){
    $o->{id}=$ts;
  }

  my $file=$s->{cdb}->get("f_".$o->{id});

  return {} if ($file eq "");

  $s->loadArticle($file);
}

=item getArticleCount

Return the number of blog articles

=cut

sub getArticleCount{
  my $s=shift;
  my $o=shift;
  my $cb=shift;

  my @r;

  if (ref $o eq 'HASH'){
    # TODO: error handling
  } else {
    my $id=$o;
    $o->{pid}=$id;
  }

  # TODO: implement handling pids other than 0 (i.e., comment counting)
  if (defined $o->{draft}){
    $r[0]=$s->{cdb}->get("dcnt");
  } else {
    $r[0]=$s->{cdb}->get("cnt");
  }

  @r;
}

sub getArticleList{
  my $s=shift;
  my $o=shift;
  my $cb=shift;

  $o->{pid}=0 unless (defined $o->{pid});
  $o->{draft}=0 unless (defined $o->{draft});
  $o->{limit}=0 unless (defined $o->{limit});
  $o->{offset}=0 unless (defined $o->{offset});

  my @r;

  if ($o->{draft}==0){
    @r=sort { $b <=> $a } $s->{cdb}->getall("a");
  } else {
    @r=sort { $b <=> $a } $s->{cdb}->getall("d");
  }

  foreach(@r){
    print STDERR "📋 $_\n" if (defined $s->{mc}->{debug_articles});
  }

  my @l=@r[$o->{offset}..$o->{offset}+$o->{limit}-1];
  # TODO: add support for comments

  foreach(@l){
    if (ref $o->{cb_format} eq 'CODE'){
      my $file=$s->{cdb}->get("f_$_");
      if ($file){
        print STDERR "$file\n"  if (defined $s->{mc}->{debug_articles});
        my $d=$s->loadArticle($file);
        $d->{timestamp}=$_;
        $o->{cb_format}->($d);
      }
    }
  }
}

sub deleteArticle{
  -1;
}

sub getSeries{
  my $s=shift;
  my $name=shift;
  my $cb=shift;
  my $dbh=$s->getDbh();

  # TODO, add series support
  #my $q=$dbh->prepare("select * from blog_series_description where name=?") ||
  #  $s->err("Unable to prepare query: $!", $cb);
  #$q->execute($name);
  #
  #my $d=$q->fetchrow_hashref();
  #return {} if ($q->rows == 0);
  $d;
}

sub createOrEditSeries{
  -1;
}

sub createOrEditArticle{
  -1;
}

=item getTeasers($)

Returs a list of teasers

=cut

sub getTeasers{
  my $s=shift;
  my $cb=shift;
  my ($data, @teasers);

  # TODO, add teaser support
  #my $q=$dbh->prepare("select subject from blog where draft=1 and tease=1 order by created desc")||
  #      $s->err("Unable to prepare query: $!", $cb);
  #$q->execute();
  #$data=$q->fetchall_arrayref({});
  #
  #push(@teasers, $_->{subject}) foreach (@$data);
  #join("; ", @teasers);
}


### DB Management

=item loadArticle($filename)

Load an article from disk, and extract YAML metadata, if available. Returns a
hash with parsed metadata and the article body.

=cut

sub loadArticle{
  my $s=shift;
  my $filename=shift;

    # load file, extract yaml, read body, parse yaml, add body to yaml, add compat keys, return hash
  open(F,'<:encoding(UTF-8)', $filename)||$s->err("Unable to open $filename: $!\n");
  my @lines=<F>;
  close(F);

  my $content=join('', @lines);
  my ($yaml_metadata)=$content=~/^---(.*?)\n---/s;
  $content=~s/^---(.*?)\n---//gs;
  $content=~s/^\s*//;

  my $article=YAML::XS::Load $yaml_metadata;
  $article->{body}=$content;

  $article->{subject}=$article->{title};
  $article->{name}=$article->{author};

  unless (defined $article->{markup}){
    if ($filename=~/\.md$/){
      $article->{markup}="Markdown";
    }
  }
  $article;
}

=item findCallback()

Callback to process all files found during index generation.

=cut

sub findCallback{
  my $s=shift;

  if (-f && /^index\./){
    return if /index\.cdb$/;

    my ($dir)=$File::Find::dir;
    if (defined $s->{articles}->{$dir}){
      # TODO: check for preferred files, and make sure we have the preferred one here
      print STDERR "Additional match for $dir\n";
      $s->{articles}->{$dir}->{index}=$_;
    } else {
      $s->{articles}->{$dir}->{index}=$_;
    }

    # no need to stat if we already know we need to regenerate
    if (defined $s->{cdb_mtime} && defined $s->{blog_mtime} && $s->{cdb_mtime} <= $s->{blog_mtime}){
      my $filename=(File::Spec->splitpath($File::Find::name))[2];
      my $mtime=(stat($filename))[9];
      if ($mtime > $s->{blog_mtime}){
        $s->{blog_mtime}=$mtime;
        printf STDERR "❗ New newest article %s found, with time %s\n", $File::Find::name, colored("$mtime", 'green');
      }
    }

    print STDERR "🔎 ".$dir."--".$File::Find::name."\n" if (defined $s->{mc}->{debug_find});
  }
}

=item createIndex()

Create a cdb index for the current blog.

=cut

sub createIndex{
  my $s=shift;
  eval "require File::Find";
  $s->err("Require File::Find failed ($@)") if ($@);

  print STDERR "Root directory: ".$s->{rootdir}."\n" if (defined $s->{mc}->{debug_cdb});
  File::Find::find({wanted=>sub{$s->findCallback()}}, $s->{rootdir});

  if (defined $s->{cdb_mtime} && defined $s->{blog_mtime} && $s->{cdb_mtime} >= $s->{blog_mtime}){
    print STDERR "⏰ cdb newer than blog contents, skipping index update\n";
    touch($s->{cdbfile});
    return;
  }

  my $cdb=CDB::TinyCDB->create("$s->{cdbfile}", "$s->{cdbfile}.$$");
  my $tags={};
  my $timestamps={};
  my $article_cnt=0,$draft_cnt=0;
  foreach my $key (sort(keys(%{$s->{articles}}))){
    print STDERR "🕵️ $key...\n" if (defined $s->{mc}->{debug_cdb});

    my $y=$s->loadArticle("$key/".$s->{articles}->{$key}->{index});
    # this makes sure we only have unique article IDs
    my $timestamp=str2time($y->{date})+0.1;
    while (defined $timestamps{$timestamp}){
      print STDERR "Duplicate timestamp, compensating.\n" if (defined $s->{mc}->{debug_cdb});
      $timestamp+=0.1
    }
    $timestamps{$timestamp}=1;

    # we need to open the article anyway, so we anly need to extract data here
    # which makes building the pages / navigation faster:
    # - title
    # - id
    # - tags
    # those keys are shared between drafts and published articles
    $cdb->put_replace("f_$timestamp", "$key/".$s->{articles}->{$key}->{index});
    $cdb->put_replace("t_$timestamp", $y->{title});
    $cdb->put_replace("i_$timestamp", $y->{id}) if ($y->{id});
    $cdb->put_replace("id_".$y->{id}, $timestamp) if ($y->{id});

    if (defined $y->{draft} &&
        $y->{draft}!=0){
      $draft_cnt++;
      # a list with all drafts identified by timestamp for easy sorting
      $cdb->put_add("d", $timestamp);
    } else {
      $article_cnt++;
      # a list with all articles identified by timestamp for easy sorting
      $cdb->put_add("a", $timestamp);

      # keywords on drafts get ignored
      if (defined $y->{keywords}){
        foreach (@{$y->{keywords}}){
          unless (defined $tags->{$_}){
            $cdb->put_add("tags", $_);
            $tags->{$_}=1;
          }
          $cdb->put_add($_."_content", $timestamp);
        }
      }
    }
  }
  $cdb->put_replace("cnt", $article_cnt);
  $cdb->put_replace("dcnt", $draft_cnt);
  $cdb->finish();
}

1;

=back

=cut
