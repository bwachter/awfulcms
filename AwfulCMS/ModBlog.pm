package AwfulCMS::ModBlog;

=head1 AwfulCMS::ModBlog

This module provides a minimalistic blog, currently read only for web access. A simple command line client exists.

=head2 Configuration parameters

=over

=item * numarticles=<int>

The number of articles to display on one page

=back

=head2 Module functions

=over

=cut

use strict;
use AwfulCMS::Page qw(:tags);
use AwfulCMS::LibUtil qw(navwidget);

use AwfulCMS::SynBasic;

sub new{
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"displayPage",
                           -content=>"html",
                           -dbhandle=>"blog"},
               "article"=>{-handler=>"displayArticle",
                           -content=>"html",
                           -dbhandle=>"blog"},
               "draft"=>{-handler=>"displayArticle",
                           -content=>"html",
                           -dbhandle=>"blog"},
               "tag"=>{-handler=>"displayTag",
                       -content=>"html",
                       -dbhandle=>"blog"},
               "comment"=>{-handler=>"editform",
                       -content=>"html",
                       -dbhandle=>"blog",
                       -role=>"author"},
               "edit"=>{-handler=>"editsite",
                        -content=>"html",
                        -role=>"moderator"},
               "createdb"=>{-handler=>"createdb",
                            -content=>"html",
                            -dbhandle=>"blog",
                            -role=>"admin"},
               "dropdb"=>{-handler=>"dropdb",
                          -content=>"html",
                          -dbhandle=>"blog",
                          -role=>"admin"}
               };
  #$r->{mc}={} unless (defined $r->{mc});
  $s->{mc}=$r->{mc};
  $s->{mc}->{numarticles}=10 unless (defined $r->{mc}->{numarticles});
  $s->{mc}->{'title-prefix'}="Blog" unless (defined $r->{mc}->{'title-prefix'});
  #FIXME
  my $rssfile="http://".$s->{page}->{rq_host}."/".$s->{mc}->{rsspath};
  $s->{page}->addHead("<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"$rssfile\" />")
    if defined ($s->{mc}->{rsspath});
  bless $s;
  $s;
}

sub defaultHeader{
  my $s=shift;
  my $p=$s->{page};

  my $tagurl=$p->{url}->buildurl({'req'=>'tag'});
  $p->add(div("<p><a href=\"/$p->{baseurl}\">Blog</a> | <a href=\"$tagurl\">Tags</a></p>", {'class'=>'navw'}));
}

=item formatArticle(%data)

Formats the article data in %data for display

=cut

sub formatArticle{
  my $s=shift;
  my $d=shift;
  my $p=$s->{page};

  if ($d->{email}=~/^\(/ && $d->{email}=~/\)$/) {
    $d->{email}=" $d->{email} ";
  } else {
    $d->{email}="";
  }
  $d->{date}=localtime($d->{created});

  my $body=AwfulCMS::SynBasic->format($d->{body},
                                     {blogurl=>$s->{mc}->{'content-prefix'}});

  my @tags=$s->getTags($d->{id});
  my @tagref;
  my $tagstr="<a href=\"".$p->{url}->buildurl({'req'=>'tag'})."\">Tags</a>: ";
  push(@tagref, "<a href=\"".
       $p->{url}->buildurl({'req'=>'tag',
                            'tag'=>$_})."\">$_</a>") foreach (@tags);
  $tagstr.=join(', ', @tagref);
  $tagstr.=" None" if (@tagref == 0);

  my $ccnt=$s->getCommentCnt($d->{id});
  my $cmtstring="$ccnt comments";
  $cmtstring = "1 comment" if ($ccnt==1);

  $cmtstring = "<a href=\"".
    $p->{url}->buildurl({'req'=>'article',
                         'article'=>"$d->{id}"})."#comments\">$cmtstring</a>" if ($ccnt>0);

  $d->{name}="<a href=\"$d->{homepage}\">$d->{name}</a>" if ($d->{homepage}=~/^http:\/\//);

  my $ret=
    div("<!-- start news entry --><a name=\"$d->{id}\">[$d->{date}]</a> [<a href=\"#$d->{id}\">#</a><a href=\"".
        $p->{url}->buildurl({'req'=>'article',
                            'article'=>$d->{id}})."\">$d->{id}] $d->{subject}</a>", {'class'=>'newshead'}).
                              div("$body", {'class'=>'newsbody'}).
                                div("<div class=\"tags\">$tagstr</div><div class=\"from\">Posted by $d->{name} $d->{email}-- $cmtstring</div>", {'class'=>'newsfoot'}).
          "<br class=\"l\" /><br class=\"l\" />";

  $ret;
}

=item getCommentCnt($id)

Returns the number of comments for the article $id

=cut

sub getCommentCnt{
  my $s=shift;
  my $id=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};

  my $q_cm=$dbh->prepare("select count(*) from blog where rpid=? and draft=0") ||
    $p->status(400, "Unable to prepare query: $!");

  $q_cm->execute($id) || $p->status(400, "Unable to execute query: $!");
  my ($ccnt)=$q_cm->fetchrow_array();
  $ccnt;
}

=item getTags($id)

Returns an array with the tags for article $id

=cut

sub getTags{
  my $s=shift;
  my $id=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my ($data, @tags);

  my $q_a=$dbh->prepare("select tag from blog_tags where id=?") ||
    $p->status(400, "Unable to prepare query: $!");
  $q_a->execute($id);
  $data=$q_a->fetchall_arrayref({});

  push(@tags, $_->{tag}) foreach (@$data);
  @tags;
}

=item getTeasers($)

Returs a list of teasers

=cut

sub getTeasers{
    my $s=shift;
    my $dbh=$s->{page}->{dbh};
    my $p=$s->{page};
    my ($data, @teasers);
    my $q=$dbh->prepare("select subject from blog where draft=1 and tease=1 order by created desc")||
        $p->status(400, "Unable to prepare query: $!");
    $q->execute();
    $data=$q->fetchall_arrayref({});

    push(@teasers, $_->{subject}) foreach (@$data);
    join("; ", @teasers);
}

=back

=head2 Module handlers

=over

=cut

=item displayTag() CGI(tag)

Displays tag overview/detail

=cut

sub displayTag{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $tag=$p->{url}->param("tag");

  $s->defaultHeader();

  my $q_a=$dbh->prepare("select tag from blog_tags group by tag order by tag") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_t=$dbh->prepare("select blog_tags.tag,blog.subject,blog.id from blog_tags left join (blog) on (blog_tags.id=blog.id) where tag=? and draft=0 order by tag")||
    $p->status(400, "Unable to prepare query: $!");

  my ($tagstr, $header);
  if (defined $tag && $tag ne ""){
    my @tags;
    $header="Articles tagged '$tag'";
    $q_t->execute($tag);
    my $data=$q_t->fetchall_arrayref({});
    push(@tags, "<a href=\"".$p->{url}->buildurl({'req'=>'article',
                                                  'article'=>$_->{id}}).
         "\">$_->{subject}</a>") foreach (@$data);
    $tagstr.=join(', ', @tags);
  } else {
    my @tags;
    $header="Available tags";
    $q_a->execute();
    my $data=$q_a->fetchall_arrayref({});

    push(@tags, "<a href=\"".$p->{url}->buildurl({'req'=>'tag',
                                                  'tag'=>$_->{tag}}).
         "\">$_->{tag}</a>")  foreach (@$data);
    $tagstr.=join(', ', @tags);
  }
  $p->title($s->{mc}->{'title-prefix'}." - $header");
  $p->add(div(div($header, {'class'=>'newshead'}).
              div($tagstr,{'class'=>'newsbody'})
              , {'class'=>'news'}))
  #push(@tags, $_->{tag}) foreach (@$data);
}

=item displayArticle() CGI(int article)

Displays one posting

=cut

sub displayArticle{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $draft=0;

  $s->defaultHeader();

  my $article=int(($p->{url}->param("article")) || ($p->{url}->param("draft"))) ||
    $p->status(404, "No such article");

  $draft=1 if (int($p->{url}->param("draft")));
  my $q_a=$dbh->prepare("select * from blog where id=? and draft=?") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_c=$dbh->prepare("select * from blog where rpid=? and draft=0 order by created desc") ||
    $p->status(400, "Unable to prepare query: $!");

  $q_a->execute($article, $draft) || $p->status(400, "Unable to execute query: $!");
  $p->status(404, "No such article") if ($q_a->rows == 0);

  my $d=$q_a->fetchrow_hashref();
  $p->title($s->{mc}->{'title-prefix'}." - ".$d->{subject});
  $p->add(div($s->formatArticle($d), {'class'=>'news'}));

  # fixme, works but is not that nice
  $q_c->execute($d->{id}) || $p->status(400, "Unable to execute query: $!");
  while (my $d=$q_c->fetchrow_hashref()){
    $p->add(div($s->formatArticle($d), {'class'=>'news'}));
  }
}

=item displayPage() CGI(int page)

Displays one page with postings

=cut

sub displayPage{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $offset=0;

  $p->title($s->{mc}->{'title-prefix'});
  $s->defaultHeader();

  my $q_c=$dbh->prepare("select count(*) from blog where pid=? and draft=0") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_s=$dbh->prepare("select * from blog where pid=? and draft=0 order by created desc limit ? offset ?") ||
    $p->status(400, "Unable to prepare query: $!");

  $q_c->execute(0) || $p->status(400, "Unable to execute query: $!");
  my ($cnt)=$q_c->fetchrow_array();
  my $pages=int($cnt/$s->{mc}->{numarticles});
  $pages++ unless ($cnt=~/0$/);

  my $page=int($p->{url}->param("page"))||1;
  $page=1 if ($page<0);
  $offset=($page-1)*$s->{mc}->{numarticles};

#  $p->add("There are $cnt articles on $pages pages\n");
#  $p->add("Displaying page $page with offset $offset, $s->{mc}->{numarticles} articles per page\n");

  #TODO: urlbuilder

  if ($s->{mc}->{tease}){
      $p->add(div(p("Upcoming articles: ".$s->getTeasers()),
                  {'class'=>'navw'})
          );
  }

  $p->add(div(p($p->navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
              {'class'=>'navw'})
         );

  $q_s->execute(0, $s->{mc}->{numarticles}, $offset) || $p->status(400, "Unable to execute query: $!");

  while (my $d=$q_s->fetchrow_hashref()){
    $p->add(div($s->formatArticle($d), {'class'=>'news'}));
  }

  $p->add(div(p("There are $cnt articles on $pages pages").
              p($p->navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
              {'class'=>'navw-full'})
         );
}

=item editform() CGI(int article)

FIXME, displays an article create/edit form

=cut

sub editform{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};


  my ($digType, $name, $email, $body, $subject);

  my $pid=0;
  # get rid of double posts due to reload
  my $q=$dbh->prepare("insert into blog_mp(id, pid) values (?,? )") || die("Database problem: $!");
  my $id=crypt(time(), time());
  $q->execute($id, $pid)||die("Database problem: $!");

  $p->add("
  <ul>
   <li>HTML is not allowed. Special chars will be converted</li>
   <li>an email-address is mandatory, but will not be shown per default. Set your address in brackets if you want it visible to everyone.</li>
   <li>you can add links with [[method://location||description]], e.g. [[http://lart.info||lart.info]]</li>
   <li>you can enclose cites in -\" \"-, like -\"This is a cite\"-</li>
   <li>you can add pre-tags by enclosing text in -[ ]-</li>
   <li>there's a pseudo-method `img' for images, e.g. [[img://path/to/image||Alt text]]. You can have URLs as path</li>
  </ul>
  <form action=\"/\" method=\"post\">
  <input type=\"hidden\" name=\"id\" value=\"$id\">
  <input type=\"hidden\" name=\"pid\" value=\"$pid\">
  <input type=\"hidden\" name=\"q\" value=\"add\">
  <table border=\"0\">
  <tr>
   <td>Subject:</td>
   <td><input size=\"30\" type=\"text\" name=\"subject\" value=\"$subject\"></td>
   <td>Language:</td>
   <td><select name=\"lang\">".
    $p->pOption(1,"en",$digType).
    $p->pOption(2,"de",$digType).
   "</select></td>
  </tr>
  <tr>
   <td>Your name:</td>
   <td><input size=\"30\" type=\"text\" name=\"name\" value=\"$name\"></td>
   <td>Your email:</td>
   <td><input size=\"30\" type=\"text\" name=\"email\" value=\"$email\"></td>
   <td><input type=\"submit\" name=\"submit\" value=\"Go!\"></td>
  </tr>
  <tr>
   <td>Your text:</td>
   <td colspan=\"4\">
    <textarea cols=\"80\" rows=\"10\" name=\"body\">$body</textarea>
   </td>
  </tr>
  </table></form><hr>
         ");
}

=item createdb()

Drops and creates all blog databases

=cut

sub createdb{
  my $s=shift;
  my $dbh=$s->{page}->{dbh};
  my @queries;
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
       "`changed` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");
  push(@queries, "DROP TABLE IF EXISTS blog_tags");
  push(@queries, "CREATE TABLE blog_tags (".
       "id int(11) NOT NULL,".
       "tag varchar(50) NOT NULL,".
       "PRIMARY KEY (id, tag)".
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
  my $dbh=$s->{page}->{dbh};
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
