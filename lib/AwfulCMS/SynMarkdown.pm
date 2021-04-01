package AwfulCMS::SynMarkdown;

=head1 AwfulCMS::SynMarkdown.pm

This modules provides a parser for markdown formatted text.

=cut

# documentation for definition lists in extended markdown:
# http://michelf.ca/projects/php-markdown/extra/#def-list

use strict;

use Text::Markdown::Hoedown;
use AwfulCMS::SynMarkdown::HoedownCustomRenderer 'hoedown_escape_html';
use Syntax::SourceHighlight;
use AwfulCMS::LibRender 'render';
#use Exporter 'import';
#our @EXPORT_OK=qw(method1 method2);

sub new {
  shift;
  my $p=shift;
  my $s={};

  if (ref($p) eq "AwfulCMS::Page"){
    $s->{urltypes}=$p->{urltypes};
  }

  $s->{urltypes}={} unless (defined $s->{urltypes});

  bless $s;
  $s;
}

# custom blockcode callback to allow code formatting through SourceHighlight
# this method is a member of the SynMarkdown class, allowing storage of parsed
# blobs in the class for later use
#
# ```
# this is code
# ```
# would be an unhighlighted code block, while
# ```lisp
# foo
# ```
# would try to highlight as lisp. An additional special form exists for dot
# and similar graphs to generate them before displaying:
# ```{lang=dot;}
# graphviz instructions
# ```
sub cb_blockcode {
  my $s=shift;
  my ($text, $lang) = @_;
  my %langopt;
  my $r="\n";
  my $rnd;

  $lang = lc $lang;

  if ($lang) {
    # this semes to be {foo=bar;bar=baz}
    if ($lang =~ /^\s*{.*}\s*$/){
      $lang =~ s/^\s*{(.*)}\s*$/$1/;
      $lang =~ s/\s//g;

      my @optlist=split(';', $lang);

      foreach(@optlist){
        my @tmp=split('=', $_);
        $langopt{$tmp[0]}=$tmp[1];
      }

      if (defined $langopt{lang}){
        $lang=$langopt{lang};
      }

      # allow 3 modes:
      # 1. generate and display picture
      # 2. generate and display formatted code
      # 3. generate and display nothing
      # options 2 and 3 allow autogeneration while giving freedom about where to place the picture
      $rnd=render($lang);

      # just return an empty string if the code is not supposed to be displayed
      return "" if ($langopt{display} ne "code" && $langopt{display} ne "both");
    }

    $r = "<pre class=\"code\"><code class=\"language-";
    $r .= hoedown_escape_html($lang);
    $r .= "\">";
  } else {
    $r = "<pre class=\"code\"><code>";
  }

  $r .= $rnd;
  if ($text) {
    my $hl = Syntax::SourceHighlight::SourceHighlight->new("htmlcss.outlang");
    my $lm = Syntax::SourceHighlight::LangMap->new();
    my $map = $lm->getMappedFileName($lang);

    $text =~ s/^\s*//;
    $text =~ s/\s*$//;
    $text = hoedown_escape_html($text);

    if ($map){
      $hl->setGenerateLineNumbers(1);
      $hl->setGenerateLineNumberRefs(1);
      $hl->setOptimize(1);
      $hl->setCss("1");
      my $h_text=$hl->highlightString($text, $map);
      $h_text =~ s/<pre>//g;
      $h_text =~ s/<\/pre>//g;
      $r .= $h_text;
    } else {
      $r .= $text;
    }
  }

  $r .= "</code></pre>\n";
  $r;
}

sub cb_paragraph {
  my ($text) = @_;
  my $r;

  # hoedown parses html tags if they're prefixed with whitespace
  # abuse this functionality, and skip inserting paragraphs if
  # something looks like an html block with at least two spaces
  # at the beginning. This might cause issues by not putting
  # paragraphs around badly placed non-block elements

  if ($text =~ /^  \s*<.*>.*<\/.*>\s*$/is){
    $r .= $text
  } else {
    $r .= "<p id=\"\">$text</p>\n";
  }

  $r;
}

sub format {
  my $s=shift;
  my $string=shift;
  my $opts=shift;
  my $html;

  if (defined $opts->{vars}){
    foreach my $key (keys(%{$opts->{vars}})){
      $string =~ s/$key:\:/$opts->{vars}->{$key}/g
    }
  }

  #if (defined $opts->{urltypes} && defined $s->{urltypes}){
  if (defined $opts->{urltypes}){
    $s->{urltypes}={%{$s->{urltypes}}, %{$opts->{urltypes}}};
  }

  # [@...||@]
  #$string=~s{\[\@([^<(]*?)\@\]\((.*?)\)}{<a name="$2" id="$2">$1</a>}g;

  my $md = AwfulCMS::SynMarkdown::HoedownCustomRenderer->
    new(
        {extensions =>
         HOEDOWN_EXT_NO_INTRA_EMPHASIS |
         HOEDOWN_EXT_TABLES |
         HOEDOWN_EXT_FENCED_CODE |
         HOEDOWN_EXT_AUTOLINK |
         HOEDOWN_EXT_STRIKETHROUGH |
         HOEDOWN_EXT_UNDERLINE |
         HOEDOWN_EXT_SPACE_HEADERS |
         HOEDOWN_EXT_SUPERSCRIPT |
         HOEDOWN_EXT_FOOTNOTES |
         HOEDOWN_EXT_QUOTE |
         HOEDOWN_EXT_HIGHLIGHT
        },
        $s->{urltypes});

  $md->{cb}->blockcode(sub{$s->cb_blockcode(@_)});
  $md->{cb}->paragraph(\&cb_paragraph);
  $html = $md->render($string);

  # allow anchor generation with mixed markdown/synBasic style:
  # [@Description@](anchor name)
  # It's easier to have markdown generate its links, and we pick off the ones
  # that should be anchors later on
  $html=~s{<a href="([^\"]*?)">@([^<]*?)@</a>}{<a name="$1" id="$1">$2</a>}g;

  # process synBasic style anchor generation with [@..@]
  # this needs checking added to make sure it's not happening inside of <pre></pre>
  $html=~s{\[\@([^ @]*)(.*?)\@\]}{<a name="$1" id="$1">$1$2</a>}g;

  # TODO: search & replace references to code generated by the blockcode callback

  $html;
}

1;
