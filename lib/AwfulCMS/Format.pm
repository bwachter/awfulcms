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
  my $p=shift;
  my $s={};
  bless $s;

  if (defined $o){
    if (ref($o) eq "AwfulCMS::Page"){
      $p=$o;
      $o="Basic";
    }
  } else {
    $o="Basic";
    $p={};
  }

  eval "require AwfulCMS::Syn$o";
  if ($@){
    print STDERR "Bad things: $@";
  } else {
    $s->{formatter}="AwfulCMS::Syn$o"->new($p);
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
