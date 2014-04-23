use strict;
use warnings;

use Test::More;

use_ok('AwfulCMS::Format');

my $f1=new AwfulCMS::Format;
ok (defined $f1);
ok ($f1->isa('AwfulCMS::Format'));
ok ($f1->{formatter}->isa('AwfulCMS::SynBasic'), 'Default module is SynBasic');

my @modules=("Basic");

foreach (@modules){
  my $dir="t/syn".lc($_).".tests";
  my $syn=new AwfulCMS::Format($_);
  ok (defined $syn);
  ok ($syn->isa('AwfulCMS::Format'));

  ok(opendir(D, $dir));
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
}

done_testing();
