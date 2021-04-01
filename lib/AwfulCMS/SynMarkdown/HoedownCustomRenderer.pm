package  AwfulCMS::SynMarkdown::HoedownCustomRenderer;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT_OK=qw(hoedown_escape_href hoedown_escape_html);
use Text::Markdown::Hoedown;

my $g_urltypes;

# Those values are taken from hoedown C source
# In earlier versions those were exported by the perl bindings
use constant {
  HOEDOWN_TABLE_ALIGNMASK => 3,
  HOEDOWN_TABLE_HEADER => 4,
  HOEDOWN_TABLE_ALIGN_LEFT => 1,
  HOEDOWN_TABLE_ALIGN_RIGHT => 2,
  HOEDOWN_TABLE_ALIGN_CENTER => 3,
  HOEDOWN_AUTOLINK_EMAIL => 2,
  HOEDOWN_LIST_ORDERED => (1 << 0),
};

sub new {
    shift;
    my $opts=shift;
    my $urltypes=shift;

    my $s={};

    if (ref($opts) eq "HASH"){
        $s->{extensions}=$opts->{extensions} if (defined $opts->{extensions});
      }

    if (ref($urltypes) eq "HASH"){
      $s->{urltypes}=$urltypes;
      $g_urltypes=$urltypes;
    }

    bless $s;

    $s->{cb} = Text::Markdown::Hoedown::Renderer::Callback->new();
    $s->{cb}->blockcode(\&hoedown_html_cb_blockcode);
    $s->{cb}->blockquote(\&hoedown_html_cb_blockquote);
    $s->{cb}->header(\&hoedown_html_cb_header);
    $s->{cb}->hrule(\&hoedown_html_cb_hrule);
    $s->{cb}->list(\&hoedown_html_cb_list);
    $s->{cb}->listitem(\&hoedown_html_cb_listitem);
    $s->{cb}->paragraph(\&hoedown_html_cb_paragraph);
    $s->{cb}->table(\&hoedown_html_cb_table);
    $s->{cb}->table_header(\&hoedown_html_cb_table_header);
    $s->{cb}->table_body(\&hoedown_html_cb_table_body);
    $s->{cb}->table_row(\&hoedown_html_cb_table_row);
    $s->{cb}->table_cell(\&hoedown_html_cb_table_cell);
    $s->{cb}->footnotes(\&hoedown_html_cb_footnotes);
    $s->{cb}->footnote_def(\&hoedown_html_cb_footnote_def);
    $s->{cb}->blockhtml(\&hoedown_html_cb_blockhtml);
    $s->{cb}->autolink(\&hoedown_html_cb_autolink);
    $s->{cb}->codespan(\&hoedown_html_cb_codespan);
    $s->{cb}->double_emphasis(\&hoedown_html_cb_double_emphasis);
    $s->{cb}->emphasis(\&hoedown_html_cb_emphasis);
    $s->{cb}->underline(\&hoedown_html_cb_underline);
    $s->{cb}->highlight(\&hoedown_html_cb_highlight);
    $s->{cb}->quote(\&hoedown_html_cb_quote);
    $s->{cb}->image(\&hoedown_html_cb_image);
    $s->{cb}->linebreak(\&hoedown_html_cb_linebreak);
    $s->{cb}->link(\&hoedown_html_cb_link);
    $s->{cb}->triple_emphasis(\&hoedown_html_cb_triple_emphasis);
    $s->{cb}->strikethrough(\&hoedown_html_cb_strikethrough);
    $s->{cb}->superscript(\&hoedown_html_cb_superscript);
    $s->{cb}->footnote_ref(\&hoedown_html_cb_footnote_ref);
    $s->{cb}->math(\&hoedown_html_cb_math);
    $s->{cb}->raw_html(\&hoedown_html_cb_raw_html);
    # NULL (entity)
    $s->{cb}->normal_text(\&hoedown_html_cb_normal_text);
    # NULL (doc_header)
    # NULL (doc_footer)

    $s;
}

sub hoedown_escape_href {
    my $str = shift;
    $str;
}

sub hoedown_escape_html {
    my $str = shift;
    $str;
}

sub hoedown_html_cb_blockcode {
    # TODO: for comparing output of native module and this the
    # if (ob->size) hoedown_buffer_putc(ob, '\n'); lines
    # should somehowe work as well
    my ($text, $lang) = @_;
    my $r;

    if ($lang) {
        $r = "<pre><code class=\"language-";
        $r .= hoedown_escape_html($lang);
        $r .= "\">";
    } else {
        $r = "<pre><code>";
    }

    if ($text) {
        $r .= hoedown_escape_html($text);
    }

    $r .= "</code></pre>\n";
    $r;
}

sub hoedown_html_cb_blockquote {
    my ($content) = @_;
    my $r = "\n";

    $r .= "<blockquote>\n";

    if ($content){
        $r .= $content;
    }
    $r .= "</blockquote>\n";
    $r;
}

sub hoedown_html_cb_header {
    my ($content, $level) = @_;
    my $r="\n";

    # TODO: implement TOC handling
    $r .= "<h$level>";

    $r .= "$content</h$level>\n";
    $r;
}

sub hoedown_html_cb_hrule {
    # TODO: handle xhtml
    "\n<hr>\n";
}

sub hoedown_html_cb_list {
    my ($content, $flags) = @_;
    my $r = "\n";

    $r .= ($flags & HOEDOWN_LIST_ORDERED ? "<ol>\n" : "<ul>\n");
    $r .= $content;
    $r .= ($flags & HOEDOWN_LIST_ORDERED ? "</ol>\n" : "</ul>\n");
}

sub hoedown_html_cb_listitem {
    my ($content, $flags) = @_;
    my $r = "<li>";

    $r .= $content;
    $r .= "</li>\n";
    $r;
}

#TODO
sub hoedown_html_cb_paragraph {
    my ($text) = @_;
    my $r;

    $r .= "<p id=\"\">$text</p>\n";

    $r;
}

sub hoedown_html_cb_table {
    my ($content) = @_;

    my $r = "\n";
    $r .= "<table>\n$content</table>\n";
    $r;
}

sub hoedown_html_cb_table_header {
    my ($content) = @_;

    my $r = "\n";
    $r .= "<thead>\n$content</thead>\n";
    $r;
}

sub hoedown_html_cb_table_body {
    my ($content) = @_;

    my $r = "\n";
    $r .= "<tbody>\n$content</tbody>\n";
    $r;
}

sub hoedown_html_cb_table_row {
    my ($content) = @_;

    my $r = "<tr>\n$content</tr>\n";
    $r;
}

sub hoedown_html_cb_table_cell {
    my ($content, $flags) =@_;
    my $r;

    if ($flags & HOEDOWN_TABLE_HEADER) {
        $r = "<th";
    } else {
        $r = "<td";
    }

    if (($flags & HOEDOWN_TABLE_ALIGNMASK) == HOEDOWN_TABLE_ALIGN_CENTER){
        $r .= " style=\"text-align: center\">";
    } elsif (($flags & HOEDOWN_TABLE_ALIGNMASK) == HOEDOWN_TABLE_ALIGN_LEFT){
        $r .= " style=\"text-align: left\">";
    } elsif (($flags & HOEDOWN_TABLE_ALIGNMASK) == HOEDOWN_TABLE_ALIGN_RIGHT){
        $r .= " style=\"text-align: right\">";
    } else {
        $r .= ">";
    }

    $r .= $content;

    if ($flags & HOEDOWN_TABLE_HEADER) {
        $r .= "</th>\n";
    } else {
        $r .= "</td>\n";
    }

    $r;
}

sub hoedown_html_cb_footnotes {
    my ($content) = @_;
    my $r = "\n";

    $r .= "<div class=\"footnotes\">\n";
    #TODO: handle xhtml
    $r .= "<hr>\n";
    $r .= "<ol>\n$content\n</ol>\n</div>\n";
    $r;
}

sub hoedown_html_cb_footnote_def {
    my ($content, $num) = @_;

    my $r;

    $r .= "\n<li id=\"fn$num\">\n";

    if ($content =~ /<\/p>/i){
        $content =~ s,</p>,&nbsp;<a href=\"#fnref$num\" rev=\"footnote\">&#8617;</a></p>,i;
        $r .= $content;
    } else {
        $r .= $content;
    }

    $r .= "</li>\n";
    $r;
}

# raw_block() in html renderer
sub hoedown_html_cb_blockhtml {
    my ($text) = @_;
    $text;
}

sub hoedown_html_cb_autolink {
    my ($link, $type) = @_;

    return if ($link eq "");

    my $r;

    $r .= "<a href=\"";

    $r .= "mailto:"  if ($type == HOEDOWN_AUTOLINK_EMAIL);
    $r .= hoedown_escape_href($link);

    # TODO: add link attribute support
    $r .= "\">";

    if ($link =~ /^mailto:/){
        $r .= hoedown_escape_html(substr $link, 7);
    } else {
        $r .= hoedown_escape_html($link);
    }

    $r .= "</a>";
    $r;
}

sub hoedown_html_cb_codespan {
    my ($text) = @_;

    my $r = "<code>";
    $r .= hoedown_escape_html($text);
    $r .= "</code>";
    $r;
}

sub hoedown_html_cb_double_emphasis {
    my ($content) = @_;

    my $r = "<strong>$content</strong>";
    $r;
}

sub hoedown_html_cb_emphasis {
    my ($content) = @_;

    my $r = "<em>$content</em>";
    $r;
}

sub hoedown_html_cb_underline {
    my ($content) = @_;

    my $r = "<u>$content</u>";
    $r;
}

sub hoedown_html_cb_highlight {
    my ($content) = @_;

    my $r = "<mark>$content</mark>";
    $r;
}

sub hoedown_html_cb_quote {
    my ($content) = @_;

    my $r = "<q>$content</q>";
    $r;
}

sub hoedown_html_cb_image {
    my ($link, $title, $alt) = @_;

    $alt = "Who needs alt texts anyway?" if (!defined $alt);
    $title = "" if (!defined $title);

    return if ($link eq "");

    my ($method)=$link=~m/^(.*?):/;

    if (defined $g_urltypes->{$method}){
      if (defined $g_urltypes->{$method}->{url}){
        my ($old_link)=$link=~m/^.*?:(.*)/;
        $link=$g_urltypes->{$method}->{url};
        $link=~s/\%1/$old_link/;
      }
    }

    my $r = "<img src=\"";
    $r .= hoedown_escape_href($link);
    $r .= "\" alt=\"";
    $r .= hoedown_escape_html($alt);
    $r .= "\" title=\"";
    $r .= hoedown_escape_html($title);
    $r .= "\">";
    $r;
    # TODO: handle xhtml
}

sub hoedown_html_cb_linebreak {
    # TODO: handle xhtml
    "\n<br>\n";
}

sub hoedown_html_cb_link {
    my ($content, $link, $title) = @_;

    $title = "" if (!defined $title);

    my ($method)=$link=~m/^(.*?):/;

    if (defined $g_urltypes->{$method}){
      if (defined $g_urltypes->{$method}->{url}){
        my ($old_link)=$link=~m/^.*?:(.*)/;
        $link=$g_urltypes->{$method}->{url};
        $link=~s/\%1/$old_link/;
      }
      # order matters here to avoid putting the icon in the title
      if (defined $g_urltypes->{$method}->{description} && $title eq ""){
        $title="$content (".$g_urltypes->{$method}->{description}.")";
      }
      if (defined $g_urltypes->{$method}->{icon}){
        $content.="<img src=\"$g_urltypes->{$method}->{icon}\" class=\"svg-icon\" />"
      }
    }

    my $r = "<a href=\"";
    $r .= hoedown_escape_html($link);

    if ($title ne ""){
        $r .= "\" title=\"";
        $r .= hoedown_escape_html($title);
        $r .= '"';
    }

    # TODO: handle link attributes
    $r .= "\">";
    $r .= $content;
    $r .= "</a>";
    $r;
}

sub hoedown_html_cb_triple_emphasis {
    my ($content) = @_;

    my $r = "<strong><em>$content</em></strong>";
    $r;
}

sub hoedown_html_cb_strikethrough {
    my ($content) = @_;

    my $r = "<del>$content</del>";
    $r;
}

sub hoedown_html_cb_superscript {
    my ($content) = @_;

    my $r = "<sup>$content</sup>";
    $r;
}

sub hoedown_html_cb_footnote_ref {
    my ($num) = @_;

    "<sup id=\"fnref$num\"><a href=\"#fn$num\" rel=\"footnote\">$num</a></sup>";
}

sub hoedown_html_cb_math {
    my ($text, $displaymode) = @_;
    my $r;

    $r = ($displaymode ? "\\[" : "\\(");
    $r .= hoedown_escape_html($text);
    $r .= ($displaymode ? "\\]" : "\\)");
    $r;
}

sub hoedown_html_cb_raw_html {
    my ($text) = @_;

    # TODO: handle ESCAPE and SKIP_HTML
    $text;
}

#sub hoedown_html_cb_NULL (entity)

sub hoedown_html_cb_normal_text {
    my ($text) = @_;
    my $r = hoedown_escape_html($text);
    $r;
}

#sub hoedown_html_cb_NULL (doc_header)
#sub hoedown_html_cb_NULL (doc_footer)

sub render {
    my $s=shift;
    my $opts=shift;

    my $md = Text::Markdown::Hoedown::Markdown->new($s->{extensions}, 16, $s->{cb});
    $md->render($opts);
}

1;
