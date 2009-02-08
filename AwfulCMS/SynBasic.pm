package AwfulCMS::SynBasic;

=head1 AwfulCMS::SynBasic

This module provides a minimalistic syntax parser

=head2 Syntax

=over

=item * Links

You can add links with [[method://location||description]], e.g. [[http://lart.info||lart.info]]

=item * Images

There's a pseudo-method `img' for images, e.g. [[img://path/to/image||Alt text]]

=item * Cites

You can enclose cites in -\" \"-, like -\"This is a cite\"-

=item * Pre

You can add pre-tags by enclosing text in -[ ]-


=back

=cut



use strict;

sub new {
	shift;

	my $s={};

	bless $s;
	$s;
}

sub format {
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

sub escape {
	my $s=shift;
	my $string=shift;

	$string=~s/</&lt;/g;
	$string=~s/>/&gt;/g;
	$string=~s/&/&amp;/g;
	$string;
}

1;
