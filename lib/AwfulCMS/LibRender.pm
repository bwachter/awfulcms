package AwfulCMS::LibRender;

use strict;

use Exporter 'import';
our @EXPORT_OK=qw(render);

=item renderDot()

Renders a dot graphics and returns either an error message or an empty string

=cut

sub renderDot{
  eval "require GraphViz2";
  return ($@) if ($@);

  return "Dot";
}

sub renderDitaa{
  eval "require Alien::Ditaa";
  return ($@) if ($@);

}

sub render{
  my $lang=shift;

  my $func = "render".ucfirst($lang);
  no strict 'refs';
  if (defined &{$func}){
    return &{$func};
  } else {
    return "Renderer for $lang not found\n";
  }
}

1;
