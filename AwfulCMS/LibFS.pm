package AwfulCMS::LibFS;

use strict;
use File::Type;

use Exporter 'import';
our @EXPORT_OK=qw(ls lsx);

sub ls {
  my $dir=shift;
  my $files=shift;
  my $dirs=shift;
  my $dotfiles=shift;

  opendir(D, $dir);
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
}

sub lsx{
  my $dir=shift;
  my $files=shift;
  my $dirs=shift;
  my $dotfiles=shift;
  my $checktype=shift;

  if (ref($dotfiles) ne "HASH"){
    $checktype=$dotfiles;
    undef $dotfiles;
  }

  my $ft=File::Type->new();

  opendir(D, $dir);
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
}

1;
