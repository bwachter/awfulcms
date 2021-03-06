package AwfulCMS::ModBlog;
use parent 'AwfulCMS::Module';

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

use AwfulCMS::Format;

# newer versions come with a make_path function
use File::Path qw(mkpath);

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
               "atom"=>{-handler=>"displayAtom",
                       -content=>"xml",
                       -dbhandle=>"blog"},
               "draft"=>{-handler=>"displayArticle",
                         -content=>"html",
                         -dbhandle=>"blog"},
               "rss"=>{-handler=>"displayRSS",
                       -content=>"xml",
                       -dbhandle=>"blog"},
               "tag"=>{-handler=>"displayTag",
                       -content=>"html",
                       -dbhandle=>"blog"},
               "comment"=>{-handler=>"editform",
                           -content=>"html",
                           -dbhandle=>"blog",
                           -role=>"author"},
               "trackback"=>{-handler=>"trackback",
                             -content=>"html",
                             -dbhandle=>"blog"},
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

  if (defined $s->{mc}->{backend}){
    $s->{backend_type}=$s->{mc}->{backend};
  } else {
    $s->{backend_type}="MySQL";
  }

  eval "require AwfulCMS::ModBlog::Backend$s->{backend_type}";
  if ($@){
    $s->{page}->status(500, "Unable to load blog backend: $@\n");
  }

  my $backend_name="AwfulCMS::ModBlog::Backend$s->{backend_type}";
  $s->{backend}=new $backend_name($r, $s->{page});
  $s->{backend}->{cb_dbh}=sub{$s->cb_dbh()};
  $s->{backend}->{cb_err}=sub{my $e=shift;$s->cb_error($e)};

  bless $s;
  $s;
}

sub defaultHeader{
  my $s=shift;
  my $p=$s->{page};

  my $tagurl=$p->{url}->buildurl({'req'=>'tag'});
  $p->add(div("<p><a href=\"/$p->{baseurl}\">Blog</a> | <a href=\"$tagurl\">Tags</a></p>", {'class'=>'navw'}));

  eval "require XML::RSS";
  if ($@){
    $p->addHead("<!-- XML::RSS not available, no RSS generation -->\n");
  } else {
    my $rssurl=$p->{url}->publish({'req'=>'rss'});
    $p->addHead("<link rel=\"alternate\" type=\"application/rss+xml\" title=\"RSS\" href=\"$rssurl\" />\n");
  }

  eval "require XML::Atom::Feed";
  if ($@){
    $p->addHead("<!-- XML::Atom::Feed not available, no Atom generation -->\n");
  } else {
    my $atomurl=$p->{url}->publish({'req'=>'atom'});
    $p->addHead("<link rel=\"alternate\" type=\"application/atom+xml\" title=\"Atom\" href=\"$atomurl\" />\n");
  }
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
  unless (defined $d->{date}){
    $d->{date}=localtime($d->{created});
  }

  my $f;
  if (defined $d->{markup}){
    $f=new AwfulCMS::Format($d->{markup}, $p);
  } else {
    $f=new AwfulCMS::Format($p);
  }

  my $uid;
  $uid=$d->{id} if (defined $d->{id});
  $uid=$d->{timestamp} if (defined $d->{timestamp});

  my $body.=$f->format($d->{body},
                       {
                        'vars'=>
                        {blogurl=>$s->{mc}->{'content-prefix'}},
                        'urltypes'=>
                        {blogurl=>{
                                   url=>$s->{mc}->{'content-prefix'}.'/%1'
                                  },
                         blog=>{
                                   url=>$s->{mc}->{'content-prefix'}.'/%1'
                               },
                         article=>{
                                   url=>$s->{mc}->{'content-prefix'}.'/'.$d->{subject}.'/%1'
                                  }}
                       });

  my @tags;
  if ($d->{keywords}){
    @tags=@{$d->{keywords}};
  } else {
    @tags=$s->{backend}->getTagsForArticle($uid);
  }

  my @tagref;
  my $tagstr="<a href=\"".$p->{url}->buildurl({'req'=>'tag'})."\">Tags</a>: ";
  push(@tagref, "<a href=\"".
       $p->{url}->buildurl({'req'=>'tag',
                            'tag'=>$_})."\">$_</a>") foreach (@tags);
  $tagstr.=join(', ', @tagref);
  $tagstr.=" None" if (@tagref == 0);

  my $ccnt=$s->{backend}->getCommentCnt($uid);
  my $cmtstring="$ccnt comments";
  $cmtstring = "1 comment" if ($ccnt==1);
  my $url = $p->{url}->buildurl({'req'=>'article',
                                 'article'=>$uid});

  my $flattr;
  if ($s->{mc}->{flattr}){
    $flattr="<br />".$p->flattrButton({
                                       subject => $d->{subject},
                                       text => $body,
                                       tags => join(', ', @tags),
                                       url => $p->{url}->publish($url)
                                      });
  }
  # TODO: Add some social media variable, containing all the codes for flattr, twitter, google+, whatever

  $cmtstring = "<a href=\"".
    $p->{url}->buildurl({'req'=>'article',
                         'article'=>"$uid"})."#comments\">$cmtstring</a>" if ($ccnt>0);

  $d->{name}="<a href=\"$d->{homepage}\">$d->{name}</a>" if ($d->{homepage}=~/^http:\/\//);

  my $ret=
    div("<!-- start news entry --><a name=\"$uid\">[$d->{date}]</a> <a href=\"#$uid\">[#]</a> <a href=\"$url\">$d->{subject}</a>",
        {'class'=>'newshead'}).
          div("$body", {'class'=>'newsbody'}).
            div("<div class=\"tags\">$tagstr$flattr</div><div class=\"from\">Posted by $d->{name} $d->{email}-- $cmtstring</div>", {'class'=>'newsfoot'}).
          "<br class=\"l\" /><br class=\"l\" />";

  $ret;
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
  my $tag=$p->{url}->param("tag");

  $s->defaultHeader();

  my ($tagstr, $header);
  if (defined $tag && $tag ne ""){
    my @tags;
    $header="Articles tagged '$tag'";
    my $data=$s->{backend}->getArticlesWithTag($tag);
    push(@tags, "<a href=\"".$p->{url}->buildurl({'req'=>'article',
                                                  'article'=>$_->{id}}).
         "\">$_->{subject}</a>") foreach (@$data);
    $tagstr.=join(', ', @tags);
  } else {
    my @tags;
    $header="Available tags";

    my $data=$s->{backend}->getTagList();
    # DBI backends return an array with one-element hash refs, while other
    # backends might just return a simple array
    foreach(@$data){
      my $t;
      if (ref($_) eq "HASH"){
        $t=$_->{tag};
      } else {
        $t=$_;
      }
      push(@tags, "<a href=\"".$p->{url}->buildurl({'req'=>'tag',
                                                    'tag'=>$t}).
           "\">$t</a>");
    }
    $tagstr.=join(', ', @tags);
  }
  $p->title($s->{mc}->{'title-prefix'}." - $header");
  $p->add(div(div($header, {'class'=>'newshead'}).
              div($tagstr,{'class'=>'newsbody'})
              , {'class'=>'news'}));
  #push(@tags, $_->{tag}) foreach (@$data);

  if ($s->{mc}->{'cached-tags'}){
    mkpath($s->{page}->{rq}->{dir});
    $p->dumpto($s->{page}->{rq}->{dir}."/index.html");
  }
}


sub trackbackStatus{
  my $s=shift;
  my $status=shift;
  my $message=shift;
  my $p=$s->{page};
  $p->{'custom-content'}="<?xml version=\"1.0\" encoding=\"utf-8\"?><response>
                             <error>$status</error>\n";
  $p->{'custom-content'}.="<message>$message</message>" if ($message);
  $p->{'custom-content'}.="</response>\n";
}

sub trackback{
  my $s=shift;
  my $p=$s->{page};

  my $article=int($p->{url}->param("article")) || return $s->trackbackStatus(1, "No such article");

  $s->trackbackStatus(0);
}

sub displayAtom{
  my $s=shift;
  my $p=$s->{page};
  my $modtime;

  eval "require XML::Atom::Feed";
  if ($@){
    $p->status(500, "XML:Atom not found, RSS generation can't work.\n");
  }

  my $atom = XML::Atom::Feed->new;
  $atom->title(title=>$s->{mc}->{'title-prefix'});
  $atom->id($s->{mc}->{baselink});

  $s->{backend}->getArticleList({
                                 limit=>$s->{mc}->{numarticles},
                                 cb_format=>
                                 sub{
                                   my $d=shift;
                                   my $f;
                                   if (defined $d->{markup}){
                                     $f=new AwfulCMS::Format($d->{markup}, $p);
                                   } else {
                                     $f=new AwfulCMS::Format($p);
                                   }

                                   $modtime=$d->{created} if ($d->{created} > $modtime);

                                   my $body=$f->format($d->{body},
                                                       {'vars'=>
                                                        {blogurl=>$s->{mc}->{'content-prefix'}},
                                                        'urltypes'=>
                                                        {blogurl=>{
                                                                   url=>$s->{mc}->{'content-prefix'}.'/%1'
                                                                  },
                                                         blog=>{
                                                                url=>$s->{mc}->{'content-prefix'}.'/%1'
                                                               },
                                                         article=>{
                                                                   url=>$s->{mc}->{'content-prefix'}.'/'.$d->{subject}.'/%1'
                                                                  }}
                                                       });

                                   #TODO: this is missing link title, published date, updated date, and content type might be off
                                   my $author = XML::Atom::Person->new;
                                   #$author->email($d->{email});
                                   $author->name($d->{name});
                                   $author->uri($d->{homepage});

                                   my $link = XML::Atom::Link->new;
                                   $link->type('text/html');
                                   $link->rel('alternate');
                                   $link->href($p->{url}->publish({'req'=>'article',
                                                                   'article'=>$d->{id}}));

                                   my $entry = XML::Atom::Entry->new;
                                   $entry->author($author);
                                   $entry->title($d->{subject});
                                   $entry->content($body);
                                   $entry->add_link($link);
                                   $atom->add_entry($entry);
                                 },
                                });

  eval "require HTTP::Date";
  if ($@){
    $p->setHeader("D'oh", "HTTP::Date not found");
  } else {
    # TODO: proper timezone definitions
    $p->setHeader("Last-Modified", scalar HTTP::Date::time2str($modtime));
  }
  $p->{'custom-content'}=$atom->as_xml();
}

sub displayRSS{
  my $s=shift;
  my $p=$s->{page};
  my $modtime;

  eval "require XML::RSS";
  if ($@){
    $p->status(500, "XML:RSS not found, RSS generation can't work.\n");
  }

  my $rss = XML::RSS->new(encoding => 'ISO-8859-1');
  $rss->channel(title=>$s->{mc}->{'title-prefix'},
                'link'=>$s->{mc}->{baselink},
                description=>$s->{mc}->{description});

  $s->{backend}->getArticleList({
                                 limit=>$s->{mc}->{numarticles},
                                 cb_format=>
                                 sub{
                                   my $d=shift;
                                   my $f;
                                   if (defined $d->{markup}){
                                     $f=new AwfulCMS::Format($d->{markup}, $p);
                                   } else {
                                     $f=new AwfulCMS::Format($p);
                                   }

                                   $modtime=$d->{created} if ($d->{created} > $modtime);

                                   my $body=$f->format($d->{body},
                                                       {'vars'=>
                                                        {blogurl=>$s->{mc}->{'content-prefix'}},
                                                        'urltypes'=>
                                                        {blogurl=>{
                                                                   url=>$s->{mc}->{'content-prefix'}.'/%1'
                                                                  },
                                                         blog=>{
                                                                url=>$s->{mc}->{'content-prefix'}.'/%1'
                                                               },
                                                         article=>{
                                                                   url=>$s->{mc}->{'content-prefix'}.'/'.$d->{subject}.'/%1'
                                                                  }}
                                                       });

                                   my $created=localtime($d->{created});

                                   $rss -> add_item(title => $d->{subject},
                                                    'link' => $p->{url}->publish({'req'=>'article',
                                                                                  'article'=>$d->{id}}),
                                                    description => AwfulCMS::Page->pRSS($body),
                                                    dc=>{
                                                         date       => $created
                                                        }
                                                   );
                                 },
                                });

  eval "require HTTP::Date";
  if ($@){
    $p->setHeader("D'oh", "HTTP::Date not found");
  } else {
    # TODO: proper timezone definitions
    $p->setHeader("Last-Modified", scalar HTTP::Date::time2str($modtime));
  }
  $p->{'custom-content'}=$rss->as_string();
}

=item displayArticle() CGI(int article)

Displays one posting

=cut

sub displayArticle{
  my $s=shift;
  my $p=$s->{page};
  my $draft=0;

  $s->defaultHeader();

  my $article=($p->{url}->param("article")) || ($p->{url}->param("draft")) ||
    $p->status(404, "No such article");

  $draft=1 if ($p->{url}->param("draft"));

  my $d=$s->{backend}->getArticle({id=>$article, draft=>$draft});
  $p->status(404, "No such article $article") if (!%$d);

  $p->title($s->{mc}->{'title-prefix'}." - ".$d->{subject});
  $p->add(div($s->formatArticle($d), {'class'=>'news'}));

  # fixme, works but is not that nice
  $s->{backend}->getComments({
                              rpid=>$d->{id},
                              cb_format=>sub{my $d=shift; $p->add(div($s->formatArticle($d), {'class'=>'news'}));},
                             });

  if ($s->{mc}->{'trackback'}){
    $p->{tb}=({
               'identifier'=>$p->{url}->publish({'req'=>'article', 'article'=>$article}),
               'trackback'=>$p->{url}->publish({'req'=>'trackback', 'article'=>$article}),
               'about'=>$p->{url}->publish({'req'=>'article', 'article'=>$article})
              });
  }

  if ($s->{mc}->{'pingback'}){
    my $pingback=$p->{url}->publish({'req'=>'pingback',
                                      'article'=>$article});
    $p->setHeader("X-Pingback", $pingback);
  }

  if ($s->{mc}->{'cached-articles'}){
    mkpath($s->{page}->{rq}->{dir});
    $p->dumpto($s->{page}->{rq}->{dir}."/index.html");
  }
}

=item displayPage() CGI(int page)

Displays one page with postings

=cut

sub displayPage{
  my $s=shift;
  my $p=$s->{page};
  my $offset=0;

  $p->title($s->{mc}->{'title-prefix'});
  $s->defaultHeader();

  my ($cnt)=$s->{backend}->getArticleCount(0);
  my $pages=int($cnt/$s->{mc}->{numarticles});
  $pages++ unless ($cnt=~/0$/);

  my $page=int($p->{url}->param("page"))||1;
  $page=1 if ($page<0);
  $offset=($page-1)*$s->{mc}->{numarticles};

  #TODO: urlbuilder

  if ($s->{mc}->{tease}){
      $p->add(div(p("Upcoming articles: ".$s->{backend}->getTeasers()),
                  {'class'=>'navw'})
          );
  }

  $p->add(div(p($p->navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
              {'class'=>'navw'})
         );

  # cb_format gets called for each article
  $s->{backend}->getArticleList({
                                 pid=>0,
                                 limit=>$s->{mc}->{numarticles},
                                 offset=>$offset,
                                 cb_format=>sub{my $d=shift; $p->add(div($s->formatArticle($d), {'class'=>'news'}));},
                                });

  $p->add(div(p("There are $cnt articles on $pages pages").
              p($p->navwidget({'minpage'=>1, 'maxpage'=>$pages, 'curpage'=>$page})),
              {'class'=>'navw-full'})
         );

  if ($s->{mc}->{'cached-page'}){
    mkpath($s->{page}->{rq}->{dir});
    $p->dumpto($s->{page}->{rq}->{dir}."/index.html");
  }
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

1;

=back

=cut
