package AwfulCMS::LibUtil;

=head1 AwfulCMS::LibAwfulCMS

This is the AwfulCMS core library.

=head2 Configuration parameters

There are no configuration parameters outside this module. 

=head2 Module functions

our @EXPORT_OK=qw(navwidget);

=over

=cut

use strict;
use AwfulCMS::Page qw(:tags);

use Exporter 'import';
our @EXPORT_OK=qw(navwidget);

=item navwidget(%options)

TODO

=cut

sub navwidget{
  my $nav;
  my $x=shift;

  my $curpage=$x->{'curpage'}||1;
  my $minpage=$x->{'minpage'}||1;
  my $maxpage=$x->{'maxpage'}||1;
  my $param=$x->{'param'}||"?page";

  # format 1...c-1 c c+1...l

  $nav=a('&lt;&lt', {'href'=>"$param=".($curpage-1)}) unless ($curpage==$minpage);
  if ($curpage>$minpage+3){
    $nav.=a(1, {'href'=>"$param=$minpage"}).
      " ... ".a($curpage-1, {'href'=>"$param=".($curpage-1)});
  } else {
    # there is only a one number gap at the beginning, don't use ...
    for (my $i=0;$i<3;$i++){ 
      $nav.=a($minpage+$i, {'href'=>"$param=".($minpage+$i)}) unless ($curpage<=$minpage+$i);
    }
  }

  $nav.=" $curpage ";
  # the part to append to the current page
  if ($curpage<$maxpage-3){
    $nav.=" ".a($curpage+1, {'href'=>"$param=".($curpage+1)}).
      " ... ".a($maxpage, {'href'=>"$param=".$maxpage});
  } else {
    # there is only a one number gap at the end, don't use ...
    for (my $i=1;$i<=3;$i++){ 
      $nav.=a($curpage+$i, {'href'=>"$param=".($curpage+$i)}) unless ($curpage>=$maxpage-$i+1);
    }
  }

  $nav.=a('&gt;&gt;', {'href'=>"$param=".($curpage+1)}) unless ($curpage>=$maxpage);
  $nav;
}

1;

=back

=cut
