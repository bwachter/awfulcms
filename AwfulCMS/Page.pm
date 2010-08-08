# http://www.troubleshooters.com/codecorn/littperl/perlreg.htm
package AwfulCMS::Page;

=head1 AwfulCMS::Page

This is the AwfulCMS core library.

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

our @EXPORT_OK=qw(a div h1 h2 h3 h4 h5 h6 hr p);

our %EXPORT_TAGS = ( tags=>[ @EXPORT_OK ] );

=over

=cut

use Time::HiRes qw(gettimeofday tv_interval);
use strict;
use AwfulCMS::Request;
use AwfulCMS::UrlBuilder;

use Exporter 'import';
our @EXPORT_OK=qw(a div h1 h2 h3 h4 h5 h6 hr p);
our %EXPORT_TAGS = ( tags=>[ @EXPORT_OK ] );

sub new {
  shift;
  my $o=shift;
  my $s={};
  bless $s;

  # a hash to hold all main divs
  $s->{divmap}={};
  $s->{divmap}->{500}={'id'=>'content',
                       'class'=>'content'};
  # a hash to hold divname -> number mappings
  $s->{divhash}={};
  #$s->{divhash}->{content}="<hr/>Sample content<hr/>";

  #die (ref($s->{divhash}));

  if (defined $o){
    if (ref($o) eq "HASH"){
      $s->{title}=$o->{title} if (defined $o->{title});
      $s->{mode}=$o->{mode} if (defined $o->{mode});
    }
    else { $s->{title}=$o; }
  }

  $s->{mode}="CGI" unless (defined $s->{mode});

  # now set some defaults
  # TODO: read defaults from config
  $s->{header}={};

  if ($s->{mode} eq "CGI"){
    $s->{doctype}='<!DOCTYPE html>'."\n"
      unless defined $s->{doctype};

    $s->{header}->{"Content-type"}="text/html; charset=utf-8" unless defined $s->{header}->{"Content-type"};
    $s->{rq}=new AwfulCMS::Request;
    $s->{target}="/$s->{rq}->{dir}/$s->{rq}->{file}";
  }

  $s->{sdesc}={
               400=>{"short"=>"Bad Request",
                     "long"=>"Your client made a bad request"},
               401=>{"short"=>"Unauthorized",
                     "long"=>"Your are not authorized to perform this operation"},
               402=>{"short"=>"Payment Required",
                     "long"=>"Give me your money!"},
               403=>{"short"=>"Forbidden",
                     "long"=>"You're not allowed to touch this. Seriously."},
               404=>{"short"=>"Not Found",
                     "long"=>"You requested a page which is not available (anymore)"}
              };


  if ($s->{mode} eq "CLI"){
    eval "require HTML::FormatText::WithLinks::AndTables";
    $s->status(400, "Require HTML::FormatText::WithLinks::AndTables failed ($@)") if ($@);
  }

  $s;
}

sub DESTROY {
  my $s=shift;
  $s->{'dbh'}->disconnect if (defined $s->{dbh});
}

# DB functions

=item dbhandle(%dbcon)

TODO

=cut

sub dbhandle {
  my $s=shift;
  my $dbcon=shift;

  eval "require DBI";
  $s->status(400, $@) if ($@);

  $s->{dbh}=DBI->connect($dbcon->{dsn}, $dbcon->{user},
                         $dbcon->{password}, $dbcon->{attr}) ||
                           $s->status(500, "DBI->connect($dbcon->{handle}): ". DBI->errstr);
}

=item setModule()

TODO

=cut

sub setModule{
  my $s=shift;
  my $module=shift;
  my $instance=shift;
  my $baseurl=shift;
  my $request=shift;

  $s->{url}=new AwfulCMS::UrlBuilder($s->{target}, $baseurl, $s->{rq}) unless ($s->{url});
  $s->{module}=$module;
  $s->{module_instance}=$instance;
  $s->{baseurl}=$baseurl;
}

=item out()

TODO

=cut

sub out {
  my $s=shift;
  my $hdr;
  my $out;

  if ($s->{'custom-content'}){
    print $s->{'custom-content'};
    return;
  }

  if (defined $s->{header}){
    if (ref($s->{header}) eq "HASH"){
      my ($key, $value);
      while (($key, $value)=each(%{$s->{header}})){
        $value=~s/\n*$//;
        $hdr.="$key: $value\n";
      }
    } else { $hdr.=$s->{header}; }
    if (ref($s->{cookies}) eq "ARRAY"){
      foreach(@{$s->{cookies}}){
        $hdr.="Set-Cookie: $_\n";
      }
    }
    $hdr.="\n";
  }

  $out.=$s->{doctype} if defined $s->{doctype};
  $out.="<html><head>$s->{head}\n".
    "<title>$s->{title}</title>\n";

  if (defined $s->{htmlheader} && ref($s->{htmlheader}) eq "HASH"){
    my ($key, $value);
    while (($key, $value)=each(%{$s->{htmlheader}})){
      $out.=tag($key, $value);
    }
  }

  $out.="</head><body>\n";

  if ($s->{tb}){
    # fixme, validate elements of tb hash
    $out.="<!--
           <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\"
             xmlns:dc=\"http://purl.org/dc/elements/1.1/\"
             xmlns:trackback=\"http://madskills.com/public/xml/rss/module/trackback/\">
           <rdf:Description
             rdf:about=\"$s->{tb}->{about}\"
             dc:identifier=\"$s->{tb}->{identifier}\"
             dc:title=\"$s->{title}\"
             trackback:ping=\"$s->{tb}->{trackback}\" />
           </rdf:RDF>
           -->";
  }

  if ($s->{preinclude}){
    $s->expandInclude(\$s->{preinclude});
      $out.=$s->{preinclude};
  }
  # a hash to hold all main divs
  #  $s->{divmap}->{500}={'id'=>'content'};
  # a hash to hold divname -> number mappings
  #  $s->{divhash}->{content}=500;

  my $divmap=$s->{divmap};
  my $divhash=$s->{divhash};
  foreach my $divid (sort (keys(%$divmap))){
    my $divattr=$divmap->{$divid};
    $out.=div($s->{divhash}->{$divattr->{id}}, $divattr);
  }

  if ($s->{postinclude}){
    $s->expandInclude(\$s->{postinclude});
    $out.=$s->{postinclude};
  }

  if ($s->{'display-time'}){
      my $timediff=tv_interval($s->{starttime}, [gettimeofday]);
      $out.="<div id=\"ptime\"><p>Processing took $timediff seconds</p></div>";
  }

  $out.="</body></html>\n";

  if (defined $s->{dumppage}){
    # FIXME, error handling and recent check
    open(F, ">$s->{dumppage}");
    print F $out;
    close(F);
  }

  if ($s->{mode} eq "CLI"){
    my $text=HTML::FormatText::WithLinks::AndTables->convert($out);
    print $text;
  } else {
    print $hdr.$out;
  }
}

=item status($status, $description)

TODO

=cut

sub status {
  my $s=shift;
  my $status=shift;
  $s->status(400, "Programmer too stupid") if (not defined $status);
  my $description=shift;
  $description="Not given" if (not defined $description);

  $s->setHeader("Status", $status);
  $s->title("$status $s->{sdesc}->{$status}->{short} ($s->{module})");
  $s->clear();
  $s->add("<h1>$status $s->{sdesc}->{$status}->{short}</h1>");
  $s->add("<p>$s->{sdesc}->{$status}->{long}</p>");
  $s->add("<p>Additional information:</p><pre>$description</pre>");
  $s->out();
  exit;
  #die "Foo";
}

=item navwidget(%options)

TODO

=cut

sub navwidget{
  my $s=shift;
  my $nav;
  my $x=shift;

  my $curpage=$x->{'curpage'}||1;
  my $minpage=$x->{'minpage'}||1;
  my $maxpage=$x->{'maxpage'}||1;
  my $param=$x->{'param'}||"page";

  # format 1...c-1 c c+1...l

  $nav=a('&lt;&lt', {'href'=>$s->{url}->buildurl({"$param"=>$curpage-1})
                    }) unless ($curpage==$minpage);
  if ($curpage>$minpage+3){
    $nav.=a(1, {'href'=>$s->{url}->buildurl({"$param"=>$minpage})}).
      " ... ".a($curpage-1, {'href'=>$s->{url}->buildurl({"$param"=>$curpage-1})});
  } else {
    # there is only a one number gap at the beginning, don't use ...
    for (my $i=0;$i<3;$i++){
      $nav.=a($minpage+$i, {'href'=>$s->{url}->buildurl({"$param"=>$minpage+$i})}) unless ($curpage<=$minpage+$i);
    }
  }

  $nav.=" $curpage ";
  # the part to append to the current page
  if ($curpage<$maxpage-3){
    $nav.=" ".a($curpage+1, {'href'=>$s->{url}->buildurl({"$param"=>$curpage+1})}).
      " ... ".a($maxpage, {'href'=>$s->{url}->buildurl({"$param"=>$maxpage})});
  } else {
    # there is only a one number gap at the end, don't use ...
    for (my $i=1;$i<=3;$i++){
      $nav.=a($curpage+$i, {'href'=>$s->{url}->buildurl({"$param"=>($curpage+$i)})
                           }) unless ($curpage>=$maxpage-$i+1);
    }
  }

  $nav.=a('&gt;&gt;', {
                      'href'=>$s->{url}->buildurl({"$param"=>$curpage+1})
                     }) unless ($curpage>=$maxpage);
  $nav;
}

=item title($title)

TODO

=cut

sub title {
  my $s=shift;
  my $title=shift;
  $s->{'title'}=$title;
}

=item dumpto($filename)

Dump the page to $filename in addition to stdout

=cut

sub dumpto {
  my $s=shift;
  my $filename=shift;
  $s->{'dumppage'}=$filename;
}

=item add($content, [$divdesc])

TODO

=cut

sub add {
  my $s=shift;
  my $content=shift;
  my $divdesc=shift;

  my $divname="content";
  # a hash to hold all main divs
  #  $s->{divmap}->{500}={'id'=>'content'};
  # a hash to hold divname -> number mappings
  #  $s->{divhash}->{content}=500;

  #$s->{divmap}->{500}={'id'=>'content',
  #                    'class'=>'content'};

  $s->{divhash}->{$divname}.=$content;
}

sub addHead{
  #FIXME
  my $s=shift;
  my $content=shift;
  $s->{head}.=$content;
}

=item clear()

TODO

=cut

sub clear {
  my $s=shift;
  my $content=shift;
  my $divdesc=shift;

  my $divname="content";
  $s->{divhash}->{$divname}=""
}

=item excerpt()

TODO

=cut

sub excerpt {
  my $s=shift;
  my $excerpt=shift;
  $s->{excerpt}=$excerpt;
}

=item prepend()

TODO

=cut

sub prepend {
  my $s=shift;
  my $content=shift;
  my $divdesc=shift;

  my $divname="content";
  $s->{divhash}->{$divname}=$content+$s->{divhash}->{$divname};
}

=item preinclude()

TODO

=cut

sub preinclude{
  my $s=shift;
  my $content=shift;

  $s->{preinclude}.=$content;
}

=item postinclude()

TODO

=cut

sub postinclude{
  my $s=shift;
  my $content=shift;

  $s->{postinclude}.=$content;
}

sub expandInclude{
  my $s=shift;
  my $content=shift;

  $$content=~s/HOSTNAME/$s->{hostname}/g;
  $$content=~s/ADDRESS/$s->{mc}->{'mail-address'}/g;

  if ($s->{mc}->{flattr}){
    my $flattr="";
    my $excerpt;
    if ($s->{excerpt}){
      $excerpt=$s->{excerpt};
    } else {
      $excerpt="";
    }
    if (length $excerpt >= 40){
      $flattr=$s->flattrButton({
                                subject => $s->{title},
                                text => $excerpt,
                                url => $s->{url}->myurl(),
                               });
    }
    $$content=~s/FLATTR/$flattr/g;
  }
}

=item setHeader($headerName, $headerValue)

Sets a HTTP-header to the given value. If a header with this name
already exists it will be overwritten.

C<setHeader("Location", "http://www.example.com")>

=cut

sub setHeader {
  my $s=shift;
  my $headerName=shift;
  my $headerValue=shift;

  $s->{header}->{$headerName}=$headerValue;
}

=item appendHeader($headerName, $headerValue)

TODO

=cut

sub appendHeader {
  my $s=shift;
  my $headerName=shift;
  my $headerValue=shift;

  $s->{header}->{$headerName}.=$headerValue;
}

=item setHtmlHeader($headerName, $headerValue)

Sets a HTML-header to the given value. If a header with this name
already exists it will be overwritten.

C<setHeader("Location", "http://www.example.com")>

=cut

sub setHtmlHeader {
  my $s=shift;
  my $headerName=shift;
  my $headerValue=shift;

  $s->{htmlheader}->{$headerName}=$headerValue;
}

=item addCookie($cookie)

TODO

=cut

sub addCookie {
  my $s=shift;
  my $cookie=shift;
  my $expire=gmtime(time()+365*24*3600)." GMT";
  push (@{$s->{cookies}}, "$cookie; expires=$expire");
}

=item tag()

tag() inserts a new tag into the current page

tag() accepts up to 4 arguments: tag name, attributes, content
and valid attributes.

The first parameter needs to be a scalar containing the tag name.

The first hash is used as argument list, the first array for
argument validation. The second scalar is used as content.

=cut

#TODO: validate attributes contents
sub tag {
  my ($tag, $attributes, $content, $allowedAttributes);
  my $attributeString="";

  for (my $i=0;$i<4;$i++){
    my $x=shift;
    last unless defined $x;
    my $r=ref($x);
    if ($r eq "HASH"){
      unless (defined $attributes) { $attributes=$x; next; }
      unless (defined $allowedAttributes) { $allowedAttributes=$x; next; }
    } else {
      unless (defined $tag) { $tag=$x; next; }
      unless (defined $content) { $content=$x; next; }
    }
  }

  #print "$tag, $attributes, $content, $allowedAttributes\n";

  # called without attributes -> $attributes contains allowed attributes
  # FIXME
  #unless (defined $allowedAttributes) { $attributes={}; }

  while (my($key, $value)=each(%$attributes)){
    if (defined $allowedAttributes){
      next unless defined $allowedAttributes->{$key};
    }
    $attributeString.=" $key=\"$value\""
   }

  if (defined $content){
    #print "-:-<$tag $attributeString>$content</$tag>\n-:-";
    return "<$tag $attributeString>$content</$tag>\n";
  } else {
    #print "-:-<$tag $attributeString/>\n-:-";
    return "<$tag $attributeString/>\n";
  }
}


# a bunch of standard tags, all implemented using tag()

sub div {
  my $content=shift;
  my $attributes=shift;
  $attributes={} unless defined $attributes;
#  my %allowedAttributes=("align"=>("left", "center", "right", "justify"),
  my %allowedAttributes=("align"=>"",
                         "class"=>"", "id"=>"", "style"=>"", "title"=>"");
  tag("div", $content, $attributes, \%allowedAttributes);
}


# http://de.selfhtml.org/html/referenz/elemente.htm

sub a { tag("a", @_); }
sub abbr { tag("abbr", @_); }
sub acronym { tag("acronym", @_); }
sub address { tag("address", @_); }
sub area { tag("area", @_); }
sub b { tag("b", @_); }
sub base { tag("base", @_); }
sub bdo { tag("bdo", @_); }
sub big { tag("big", @_); }
sub blockquote { tag("blockquote", @_); }
sub br { tag("br", @_); }
sub button { tag("button", @_); }
sub caption { tag("caption", @_); }
sub cite { tag("cite", @_); }
sub code { tag("code", @_); }
sub col { tag("col", @_); }
sub colgroup { tag("colgroup", @_); }

sub h { tag(@_, {"class"=>"", "id"=>"", "style"=>"", "title"=>""}); }
sub h1 { h("h1", @_); }
sub h2 { h("h2", @_); }
sub h3 { h("h3", @_); }
sub h4 { h("h4", @_); }
sub h5 { h("h5", @_); }
sub h6 { h("h6", @_); }

sub hr { tag("hr", @_); }
sub p { tag("p", @_); }

sub option { tag("option", @_); }


# historical foo, need better code
sub pOption {
  my $s=shift;
  my $value=shift;
  my $name=shift;
  my $default=shift;
  my $add;

  if ( $value == $default ) { $add="selected" }
  else { $add="" }

  "<option value=\"$value\" $add>$name</option>";
}

sub pRadio {
  my $s=shift;
  my $name=shift;
  my $value=shift;
  my $default=shift;
  my $add;

  if ( $value eq $default ) { $add='checked="checked"' }
  else { $add="" }

  "<input type=\"radio\" name=\"$name\" value=\"$value\" $add />";
}


sub pString {
  my $s=shift;
  my $string=shift;

  $string=~s/\n/<br \/>/g;
  # .*? -- non-greedy matching...
  $string=~s/\[\[img:\/\/(.*?)\|\|(.*?)\]\]/<img src="$1" alt="$2" \/>/g;
  $string=~s/\[\[(.*?)\|\|(.*?)\]\]/<a href="$1">$2<\/a>/g;
  $string=~s/-"(.*?)"-/<\/p><blockquote><p>$1<\/p><\/blockquote><p>/gs;
  $string=~s/-\[(.*?)\]-/<\/p><pre>$1<\/pre><p>/gs;

  $string;
}

sub pRSS {
  my $s=shift;
  my $string=shift;

  $string=~s/<br \/>/\n<br \/>/g;
#  $string=~s/>/&gt;/g;
#  $string=~s/</&lt;/g;

  $string;
}

sub flattrButton {
  my $s=shift;
  my $pm=shift;
  my $code;

  $s->{mc}->{'flattr-js'}="http://api.flattr.com/button/load.js"
    unless (defined $s->{mc}->{'flattr-js'});

  $pm->{lang}="en_GB" unless (defined $pm->{lang});
  $pm->{hide}=$s->{mc}->{'flattr-hide'} || "true" unless (defined $pm->{hide});
  $pm->{cat}=$s->{mc}->{'flattr-cat'} || "text" unless (defined $pm->{cat});
  $pm->{style}=$s->{mc}->{'flattr-style'} || "compact" unless (defined $pm->{style});

  my %flattr_vars=(
                   flattr_btn => $pm->{style},
                   flattr_uid => $s->{mc}->{'flattr-uid'},
                   flattr_tle => $pm->{subject},
                   flattr_dsc => substr($pm->{text}, 0, 240),
                   flattr_cat => $pm->{cat},
                   flattr_lng => $pm->{lang},
                   flattr_tag => $pm->{tags},
                   flattr_url => $pm->{url},
                   flattr_hide => $pm->{hide}
                  );
  $flattr_vars{flattr_dsc}.=" [...]" if (length $pm->{text} > 240);
  $flattr_vars{flattr_dsc}=~s/<.*?>//g;
  $flattr_vars{flattr_tle}.="     " if (length $flattr_vars{flattr_tle} < 5);

  $code="<script type=\"text/javascript\">\n";

  foreach my $key (sort(keys(%flattr_vars))){
    $flattr_vars{$key}=~s/'/\\'/g;
    $flattr_vars{$key}=~s/\n//g;
    $code.="var $key = '$flattr_vars{$key}';\n";
  }
  $code.="</script><script src=\"$s->{mc}->{'flattr-js'}\" type=\"text/javascript\"></script>";
}

1;

=back

=cut
