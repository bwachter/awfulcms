package AwfulCMS::Format;

=head1 AwfulCMS::Format

This module provides access to different markup parsers.

=cut

use strict;
use Exporter 'import';
#our @EXPORT_OK=qw(method1 method2);

sub new {
  shift;
  my $o=shift;
  my $s={};
  bless $s;

  $o="Basic" unless (defined $o);

  eval "require AwfulCMS::Syn$o";
  if ($@){
    print "bad things. $@";
  } else {
    $s->{formatter}="AwfulCMS::Syn$o"->new();
  }

  $s;
}

sub DESTROY {
  my $s=shift;
}

sub format {
  my $s=shift;
  my $string=shift;
  my $vars=shift;

  # TODO, check if $s is not a hash, but AwfulCMS::Format -> called directly
  #       could be supported for direct calling by constructing an object in that case
  $s->{formatter}->format($string, $vars);
}

1;
