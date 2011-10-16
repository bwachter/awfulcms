use strict;
use warnings;

use Test::More;

plan tests => 9;

sub done_testing(){ }

use_ok('AwfulCMS::SynBasic');

my $dir="t/synbasic.tests";

opendir(D, $dir);
my @f=readdir(D);
closedir(D);

foreach (@f){
  next unless (/\.in$/);
  open(F, "<$dir/$_")||die "$_ $!";
  my @in=<F>;
  close(F);

  $_=~s/\.in$/.out/;
  open(F, "<$dir/$_");
  my @out=<F>;
  close(F);

  $_=~s/\.out$//;
  is (AwfulCMS::SynBasic->format(join('', @in)), join('', @out), "$_");
}

done_testing();
