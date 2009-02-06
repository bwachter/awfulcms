# http://www.troubleshooters.com/codecorn/littperl/perlreg.htm
package AwfulCMS::Page;

use CGI;
use strict;

use Exporter 'import';
our @EXPORT_OK=qw(a div h1 h2 h3 h4 h5 h6 hr p);
our %EXPORT_TAGS = ( tags=>[ @EXPORT_OK ] );

sub new {
  shift;
  my $o=shift;
  my %opt;
  my $s={};

  # a hash to hold all main divs
  $s->{divmap}={};
  $s->{divmap}->{500}={'id'=>'content',
		       'class'=>'content'};
  # a hash to hold divname -> number mappings
  $s->{divhash}={};
  #$s->{divhash}->{content}="<hr/>Sample content<hr/>";

  #die (ref($s->{divhash}));

  if (defined $o){
    if (ref($o) eq "HASH"){ %opt=$o; }
    else { %opt=(); $s->{title}=$o; }
  }

  # now set some defaults
  # TODO: read defaults from config
  $s->{doctype}='<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">'."\n"
    unless defined $s->{doctype};

  $s->{header}={};
  $s->{header}->{"Content-type"}="text/html" unless defined $s->{header}->{"Content-type"};
  $s->{cgi}=new CGI;
  $s->{rq_host}=$s->{cgi}->virtual_host();
  $s->{rq_fileabs}=$s->{cgi}->url(-absolute => 1);
  $s->{rq_fileabs}=~s/^\///;
  $s->{rq_fileabs}=~s/%20/ /;
  ($s->{rq_dir})=$s->{rq_fileabs}=~m/(.*)\/(.*)/;
  $s->{rq_dir}="." if ($s->{rq_dir} eq "");
  ($s->{rq_file})=$s->{rq_fileabs}=~m/.*\/(.*)/;
  $s->{rq_vars}=$s->{cgi}->Vars();

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
		     "long"=>"Your requested a page which is not available (anymore)"}
	      };


  bless $s;
  $s;
}

sub DESTROY {
  my $s=shift;
  $s->{'dbh'}->disconnect if (defined $s->{dbh});
}

# DB functions

sub dbhandle {
  my $s=shift;
  my $dbcon=shift;

  eval "require DBI";
  $s->status(400, $@) if ($@);

  $s->{dbh}=DBI->connect($dbcon->{dsn}, $dbcon->{user}, 
			 $dbcon->{password}, $dbcon->{attr}) ||
			   $s->status(500, "DBI->connect($dbcon->{handle}): ". DBI->errstr);
}

sub setModule{
  my $s=shift;
  my $module=shift;

  $s->{module}=$module;
}

sub out {
  my $s=shift;

  if (defined $s->{header}){
    if (ref($s->{header}) eq "HASH"){
      my ($key, $value);
      print "$key: $value\n" while (($key, $value)=each(%{$s->{header}}));
    } else { print $s->{header}; }
    print "\n";
  }

  print $s->{doctype} if defined $s->{doctype};
  print "<html><head>$s->{head}\n";
  print "<title>$s->{title}</title>\n";
  print "</head><body>\n";

  print $s->{preinclude} if ($s->{preinclude});
  # a hash to hold all main divs
  #  $s->{divmap}->{500}={'id'=>'content'};
  # a hash to hold divname -> number mappings
  #  $s->{divhash}->{content}=500;

  my $divmap=$s->{divmap};
  my $divhash=$s->{divhash};
  foreach my $divid (sort (keys(%$divmap))){
    my $divattr=$divmap->{$divid};
    print div($s->{divhash}->{$divattr->{id}}, $divattr);
  }

  print $s->{postinclude} if ($s->{postinclude});
  print "</body></html>\n";
}

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
}

sub title {
  my $s=shift;
  my $title=shift;
  $s->{'title'}=$title;
}

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
  #		       'class'=>'content'};

  $s->{divhash}->{$divname}.=$content;
}

sub clear {
  my $s=shift;
  my $content=shift;
  my $divdesc=shift;

  my $divname="content";
  $s->{divhash}->{$divname}=""
}

sub prepend {
  my $s=shift;
  my $content=shift;
  my $divdesc=shift;

  my $divname="content";
  $s->{divhash}->{$divname}=$content+$s->{divhash}->{$divname};
}

sub preinclude{
  my $s=shift;
  my $content=shift;

  $s->{preinclude}.=$content;
}

sub postinclude{
  my $s=shift;
  my $content=shift;

  $s->{postinclude}.=$content;
}

sub setHeader {
  my $s=shift;
  my $headerName=shift;
  my $headerValue=shift;

  $s->{header}->{$headerName}=$headerValue;
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

1;
