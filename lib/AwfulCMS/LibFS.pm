package AwfulCMS::LibFS;

=head1 AwfulCMS::LibFS

This library provides a few functions for file(system) operations.

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

C<our @EXPORT_OK=qw(ls lsx openreadclose);>

=over

=cut

use strict;
use File::Type;

use Exporter 'import';
our @EXPORT_OK=qw(ls lsx openreadclose);

=item ls($dir, \@files, [\@dirs, [\@dotfiles]])

Lists the contents of the directory in `$dir', and fills the arrays
provided by reference with the files, directories and dotfiles.

The function returns 0 on error, 1 on success.

=cut

sub ls {
  my $dir=shift;
  my $files=shift;
  my $dirs=shift;
  my $dotfiles=shift;

  opendir(D, $dir)||return 0;
  my @f = readdir(D);
  closedir(D);

  foreach my $file (@f) {
    $file=~s/%20/ /g;
    my $filename = $dir . '/' . $file;
    if ($file eq '..') {
      push(@$dirs,$file);
      next;
    } elsif ($file =~ /^\./||$file eq 'CVS') {
      push(@$dotfiles,$file);
      next;
    } elsif (-d $filename) {
      push(@$dirs,$file);
      next;
    } else {
      push(@$files,$file);
      next;
    }
  }
  return 1;
}

=item lsx($dir, \%files, [\@dirs, [\%dotfiles], [$checktype]])

Lists the contents of the directory in `$dir', and fills the arrays/hashes
provided by reference with the files, directories and dotfiles.

If $checktype is set to 1 the function will perform file type and size
lookup, and include this information in the referenced hash. If $checktype
is set to any other value the hash will just include the filename.

It's possible to specify $checktype without a hash for %dotfiles.

The function returns 0 on error, 1 on success.

=cut

sub lsx{
  my $dir=shift;
  my $files=shift;
  my $dirs=shift;
  my $dotfiles=shift;
  my $checktype=shift;

  if (ref($dotfiles) ne "HASH"){
    $checktype=$dotfiles;
    undef $dotfiles;
    if (ref($dirs) ne "ARRAY"){
      $checktype=$dirs;
      undef $dirs;
    }
  }

  my $ft=new File::Type;

  opendir(D, $dir)||return 0;
  my @f = readdir(D);
  closedir(D);

  foreach my $file (@f) {
    $file=~s/%20/ /g;
    my $filename = $dir . '/' . $file;
    if ($file eq '..') {
      push(@$dirs,$file);
      next;
    } elsif ($file =~ /^\./||$file eq 'CVS') {
      if ($checktype==1){
        my $type = $ft->checktype_filename("$filename");
        $dotfiles->{$file}={'type'=>$type,
                            'size'=>-s $filename};
      } else {
        $dotfiles->{$file}={'foo'=>'bar'};
      }
      next;
    } elsif (-d $filename) {
      push(@$dirs,$file);
      next;
    } else {
      if ($checktype==1){
        my $type = $ft->checktype_filename("$filename");
        $files->{$file}={'type'=>$type,
                         'size'=>-s $filename};
        } else {
          $files->{$file}={$filename};
        }
    }
  }
  return 1;
}

=item openreadclose($file, [\@resultlist])

Opens the file `$file', reads it completely, joins the line, and returns a
scalar containing the file contents.

=cut

sub openreadclose{
  my $file=shift;
  my $result=shift;

  open(FILE, "<$file")||return;
  my @fcontent=<FILE>;
  close(FILE);
  @$result=@fcontent if (ref($result) eq "ARRAY");
  join('', @fcontent);
}

1;

=back

=cut
