package AwfulCMS::SynMarkdown;

=head1 AwfulCMS::SynMarkdown.pm

This modules provides a parser for markdown formatted text.

=cut

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

  my $html = markdown($string);

  $html;
}

1;
