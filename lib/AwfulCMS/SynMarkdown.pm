package AwfulCMS::SynMarkdown;

=head1 AwfulCMS::SynMarkdown.pm

This modules provides a parser for markdown formatted text.

=cut

# documentation for definition lists in extended markdown:
# http://michelf.ca/projects/php-markdown/extra/#def-list

use strict;
use Text::Markdown 'markdown';
#use Exporter 'import';
#our @EXPORT_OK=qw(method1 method2);

sub new {
  shift;

  my $s={};

  bless $s;
  $s;
}

sub format {
  my $s=shift;
  my $string=shift;
  my $vars=shift;

  foreach my $key (keys(%$vars)){
    $string =~ s/$key:\:/$vars->{$key}/g
  }

  # [@...||@]
  #$string=~s{\[\@([^<(]*?)\@\]\((.*?)\)}{<a name="$2" id="$2">$1</a>}g;

  my $html = markdown($string);

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
