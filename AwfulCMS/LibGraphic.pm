package AwfulCMS::LibGraphic;

use strict;
use GD;

use Exporter 'import';
our @EXPORT_OK=qw(thumbnail);

sub thumbnail {
  my $opts=shift;

  my ($im, $tn, $image, $dx, $dy);
  return if (ref($opts) ne "HASH");

  my $infile="$opts->{directory}/$opts->{filename}";
  my $outfile="$opts->{directory}/.$opts->{filename}";

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
    if ($x < $opts->{maxx}){ $dx=$x; $dy=$y; }
    else {
      $dx=$opts->{maxx};
      $dy=(($y/$x)*$dx);
    }
  } else {
    if ($y < $opts->{maxy}){ $dy=$y; $dx=$x; }
    else { 
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
