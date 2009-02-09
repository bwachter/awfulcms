package AwfulCMS::ModBlog;

=head1 AwfulCMS::ModBlog

This module provides a minimalistic blog, currently read only for web access. A simple command line client exists.

=head2 Configuration parameters

=over

=item * numarticles=<int>

The number of articles to display on one page

=back

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
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
			   -content=>"html",
			   -dbhandle=>"blog"},
	       "article"=>{-handler=>"getArticle",
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
  $s->{target}="/$s->{page}->{rq_dir}/$s->{page}->{rq_file}";
  #FIXME
  $s->{page}->addHead("<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"/$s->{mc}->{rsspath}\">")
    if defined ($s->{mc}->{rsspath});
  bless $s;
  $s;
}

sub defaultHeader{
  my $s=shift;
  my $p=$s->{page};

  $p->add(div("<p><a href=\"$s->{target}\">Blog</a> | <a href=\"$s->{target}?req=tag\">Tags</a></p>", {'class'=>'navw'}));
}

sub formatArticle{
  my $s=shift;
  my $d=shift;

  if ($d->{email}=~/^\(/ && $d->{email}=~/\)$/) {
    $d->{email}=" $d->{email} ";
  } else {
    $d->{email}="";
  }
  $d->{date}=localtime($d->{created});

  my $body=AwfulCMS::SynBasic->format($d->{body});

  my $ret=
    div("<a name=\"$d->{id}\">[$d->{date}]</a> [<a href=\"#$d->{id}\">#</a><a href=\"$s->{target}?article=$d->{id}\">$d->{id}] $d->{subject}</a>", {'class'=>'newshead'}).
      div("<p>$body</p>", {'class'=>'newsbody'}).
	div("Posted by $d->{name} $d->{email}-- <a href=\"$s->{target}?comment&pid=$d->{id}\">comment</a>", {'class'=>'newsfoot'}).
	  "<br class=\"l\" /><br class=\"l\" />";

  $ret;
}

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

sub displayTag{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $tag=$p->{cgi}->param("tag");

  $s->defaultHeader();

  my $q_a=$dbh->prepare("select tag from blog_tags group by tag order by tag") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_t=$dbh->prepare("select blog_tags.tag,blog.subject,blog.id from blog_tags left join (blog) on (blog_tags.id=blog.id) where tag=? order by tag")||
    $p->status(400, "Unable to prepare query: $!");

  my ($tagstr, $header);
  if (defined $tag){
    my @tags;
    $header="Articles tagged '$tag'";
    $q_t->execute($tag);
    my $data=$q_t->fetchall_arrayref({});
    push(@tags, "<a href=\"$s->{target}?req=article&article=$_->{id}\">$_->{subject}</a>") foreach (@$data);
    $tagstr.=join(', ', @tags);
  } else {
    my @tags;
    $header="Available tags";
    $q_a->execute();
    my $data=$q_a->fetchall_arrayref({});

    push(@tags, "<a href=\"$s->{target}?req=tag&tag=$_->{tag}\">$_->{tag}</a>") foreach (@$data);
    $tagstr.=join(', ', @tags);
  }
  $p->title($s->{mc}->{'title-prefix'}." - $header");
  $p->add(div(div($header, {'class'=>'newshead'}).
	      div($tagstr,{'class'=>'newsbody'})
	      , {'class'=>'news'}))
  #push(@tags, $_->{tag}) foreach (@$data);
}

sub getArticle{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};

  $s->defaultHeader();

  my $article=int($p->{cgi}->param("article"))||
    $p->status(404, "No such article");
  my $q_a=$dbh->prepare("select * from blog where id=?") ||
    $p->status(400, "Unable to prepare query: $!");

  $q_a->execute($article) || $p->status(400, "Unable to execute query: $!");

  my $d=$q_a->fetchrow_hashref();
  $p->title($s->{mc}->{'title-prefix'}." - ".$d->{subject});
  $p->add(div($s->formatArticle($d), {'class'=>'news'}));
}

sub getPosts{
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $offset=0;

  my $q_c=$dbh->prepare("select count(*) from blog where pid=? and draft=0") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_cm=$dbh->prepare("select count(*) from blog where rpid=? and draft=0") ||
    $p->status(400, "Unable to prepare query: $!");
  my $q_s=$dbh->prepare("select * from blog where pid=? and draft=0 order by created desc limit ? offset ?") ||
    $p->status(400, "Unable to prepare query: $!");

  $q_c->execute(0) || $p->status(400, "Unable to execute query: $!");
  my ($cnt)=$q_c->fetchrow_array();
  my $pages=int($cnt/$s->{mc}->{numarticles});
  $pages++ unless ($cnt=~/0$/);

  my $page=int($p->{cgi}->param("page"))||1;
  $page=1 if ($page<0);
  $offset=($page-1)*$s->{mc}->{numarticles};

#  $p->add("There are $cnt articles on $pages pages\n");
#  $p->add("Displaying page $page with offset $offset, $s->{mc}->{numarticles} articles per page\n");

  #TODO: urlbuilder

  $p->add(div(p(navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
	      {'class'=>'navw'})
	 );

  $q_s->execute(0, $s->{mc}->{numarticles}, $offset) || $p->status(400, "Unable to execute query: $!");
  while (my $d=$q_s->fetchrow_hashref()){
    $q_cm->execute($d->{id}) || $p->status(400, "Unable to execute query: $!");
    my ($ccnt)=$q_cm->fetchrow_array();

    if ($d->{email}=~/^\(/ && $d->{email}=~/\)$/) {
      $d->{email}=" $d->{email} ";
    } else {
      $d->{email}="";
    }
    $d->{date}=localtime($d->{created});

    $d->{name}="<a href=\"$d->{homepage}\">$d->{name}</a>" if ($d->{homepage}=~/^http:\/\//);

    my $body=AwfulCMS::SynBasic->format($d->{body});
    #$p->add($s->formatArticle($d));
    my $cmtstring="$ccnt comments";
    $cmtstring = "1 comment" if ($ccnt==1);

    my @tags=$s->getTags($d->{id});
    my @tagref;
    my $tagstr="<a href=\"$s->{target}?req=tag\">Tags</a>: ";
    push(@tagref, "<a href=\"$s->{target}?req=tag&tag=$_\">$_</a>") foreach (@tags);
    $tagstr.=join(', ', @tagref);
    $tagstr.=" None" if (@tagref == 0);
    $p->add(div("<!-- start news entry -->".
		    div("<a name=\"$d->{id}\">[$d->{date}]</a> [<a href=\"#$d->{id}\">#</a><a href=\"$s->{target}?req=article&article=$d->{id}\">$d->{id}] $d->{subject}</a>", {'class'=>'newshead'}).
		    div("<p>$body</p>", {'class'=>'newsbody'}).
		    div("<div class=\"tags\">$tagstr</div><div class=\"from\">Posted by $d->{name} $d->{email}-- <a href=\"$s->{target}?comment&pid=$d->{id}\">$cmtstring</a></div>", {'class'=>'newsfoot'}).
		    "<br class=\"l\" /><br class=\"l\" />", {'class'=>'news'}));
  }

  $p->add(div(p("There are $cnt articles on $pages pages").
	      p(navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
	      {'class'=>'navw-full'})
	 );
}

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

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  #$p->add("<a href=\"?req=dropdb\">Drop database</a> | <a href=\"?req=createdb\">Drop and create database</a> | <a href=\"/\">Blog</a>");
  $p->title($s->{mc}->{'title-prefix'});
  $s->defaultHeader();
  $s->getPosts();
}

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

