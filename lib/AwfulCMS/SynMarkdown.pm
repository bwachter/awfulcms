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
#use Exporter 'import';
#our @EXPORT_OK=qw(method1 method2);

sub new {
  shift;

  my $s={};

  bless $s;
  $s;
}

sub cb_blockcode {
  my ($text, $lang) = @_;
  my $r="\n";

  $lang = lc $lang;

  if ($lang) {
    $r = "<pre class=\"code\"><code class=\"language-";
    $r .= hoedown_escape_html($lang);
    $r .= "\">";
  } else {
    $r = "<pre class=\"code\"><code>";
  }

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
  my $vars=shift;
  my $html;

  foreach my $key (keys(%$vars)){
    $string =~ s/$key:\:/$vars->{$key}/g
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
        });

  $md->{cb}->blockcode(\&cb_blockcode);
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

  $html;
}

1;
