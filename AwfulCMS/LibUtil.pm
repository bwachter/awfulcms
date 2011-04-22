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
use Encode qw(decode encode FB_QUIET);

use Exporter 'import';
our @EXPORT_OK=qw(navwidget escapeShellMetachars stripFilename stripShellMetachars toUTF8);

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

=item toUTF8()

toUTF8() tries to guess proper encoding of the input string,
and hopefully returns an UTF8-encoded string.

toUTF8 will simply try to use encode to decode the input string like it
was UTF-8. If it's ISO-8859 decode() will most likely barf when encountering
non-ASCII characters. If it barfs the result of encode() to UTF-8 gets
returned, if not the input string which, with a certain probability, is
UTF-8

=cut

sub toUTF8{
  my $input=shift;
  my $tmp=$input;

  while (length($tmp)){
    decode("utf-8", $tmp, FB_QUIET);
    if (length($tmp)){
      return encode ("utf-8", $input, FB_QUIET);
    } else {
      return $input;
    }
  }
}

=item stripFilename()

stripFilename() removes unwanted characters from filenames

=cut

sub stripFilename{
  my $name=shift;

  $name=~s,^[./]*,,;

  $name;
}

=item stripShellMetachars()

stripShellMetachars() removes characters having a special meaning
for the Bourne shell

=cut

sub stripShellMetachars {
  my $s=shift;
  $s=~s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"])//g;
  $s
}

=item escapeShellMetachars()

escapeShellMetachars() escapes characters having a special meaning
for the Bourne shell

=cut

sub escapeShellMetachars {
  my $s=shift;
  $s=~s/\\//g;
  # FIXME, should check for properly escaped chars and ignore them
  $s=~s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"])/\\$1/g;
  $s
}


1;

=back

=cut
