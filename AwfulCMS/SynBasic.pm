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

  $string=~s{\n{2,}}{\n\n}g;

  # .*? -- non-greedy matching...
  # h2-6
  $string=~s{={6}(.*?)={6}}{<h6>$1</h6>}gs;
  $string=~s{={5}(.*?)={5}}{<h5>$1</h5>}gs;
  $string=~s{={4}(.*?)={4}}{<h4>$1</h4>}gs;
  $string=~s{={3}(.*?)={3}}{<h3>$1</h3>}gs;
  $string=~s{={2}(.*?)={2}}{<h2>$1</h2>}gs;

  $string=~s{-\[(.*?)\]-}{<pre>$1</pre>}gs;
  $string=~s{--"(.*?)"--}{<blockquote><p>$1</p></blockquote>}gs;

  # insert paragraphs after block elements...
  $string=~s{(</.*?>\n*)([^<>]+?)(<.*?>|\n{2})}{$1<p>$2</p>$3}gsm;
  # ...get rid of newline between tags...
  $string=~s{>\n*<}{><}g;
  # ...and create all other paragraphs between double-newline or other <p>
  $string=~s{(</p>|\n{2})([^<>]+?)(<.*?>|\n{2})}{$1<p>$2</p>$3}gsm;
  # now create the last paragraph, if needed...
  $string=~s{\n}{}g;
  $string=~s{(</.*?>)([^<]*?)$}{$1<p>$2</p>}smx;
  # ...and the first
  $string=~s{^([^<>]+)}{<p>$1</p>}sm;

  # inline elements
  $string=~s{'''(.*?)'''}{<b>$1</b>}gs;
  $string=~s{''(.*?)''}{<i>$1</i>}gs;
  $string=~s{\[\[img:\/\/(.*?)\|\|(.*?)\]\]}{<img src="$1" alt="$2" />}g;
  $string=~s{\[\[(.*?)\|\|(.*?)\]\]}{<a href="$1">$2</a>}g;
  $string=~s{'''''(.*?)'''''}{<i><b>$1</b></i>}gs;

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
