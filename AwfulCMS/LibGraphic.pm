package AwfulCMS::LibGraphic;

=head1 AwfulCMS::LibGraphic

This library provides a few functions for graphic manipulation

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

C<our @EXPORT_OK=qw(thumbnail);>

=over

=cut

use strict;
use GD;

use Exporter 'import';
our @EXPORT_OK=qw(thumbnail);

=item thumbnail(%options)

Generates a thumbnail image.

The option hash must contain the keys directory, filename, type, maxx and maxy.

=cut

sub thumbnail {
  my $opts=shift;

  my ($im, $tn, $image, $dx, $dy);
  return if (ref($opts) ne "HASH");

  my $filename=$opts->{filename};
  return unless $filename;

  my $infile="$opts->{directory}/$filename";
  $filename=$opts->{prepend}.$filename if ($opts->{prepend});
  my $outfile="$opts->{directory}/.$filename";
  $outfile.=$opts->{append} if ($opts->{append});

  my @instat=stat($infile);
  my @outstat=stat($outfile);
  return $outfile unless (@instat[9]>@outstat[9]);

  # valid too: newFromXpm newFromXbm
  if ($opts->{type} eq "image/jpeg"){
    $im=GD::Image->newFromJpeg($infile)||return;
  } elsif ($opts->{type} eq "image/x-png"){
    $im=GD::Image->newFromPng($infile)||return;
  } elsif ($opts->{type} eq "image/gif"){
    $im=GD::Image->newFromGif($infile)||return;
  } else { return; }

  my ($x,$y)=$im->getBounds();

  if (($y/$x) < 1) { # wide not tall
    if ($x < $opts->{maxx}){ # image smaller than thumbnail
      return if ($opts->{ignorelarger});
      $dx=$x; $dy=$y;
    } else {
      $dx=$opts->{maxx};
      $dy=(($y/$x)*$dx);
    }
  } else {
    if ($y < $opts->{maxy}){ # image smaller than thumbnail
      return if ($opts->{ignorelarger});
      $dy=$y; $dx=$x;
    } else {
      $dy=$opts->{maxy};
      $dx=(($x/$y)*$dy);
    }
  }

  $tn=new GD::Image($dx,$dy)||return;

  $tn->copyResampled($im,0,0,0,0,$dx,$dy,$x,$y);

  if ($opts->{type} eq "image/jpeg"){
    $image=$tn->jpeg()||return;
  } elsif ($opts->{type} eq "image/x-png"){
    $image=$tn->png()||return;
  } elsif ($opts->{type} eq "image/gif"){
    $image=$tn->gif()||return;
  } else { return; }

  open(IM, ">$outfile")||return;
  print IM $image||return;
  close(IM);
  return $outfile;
}

1;

=back

=cut
