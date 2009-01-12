package AwfulCMS::ModMac;

use strict;

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"mainsite",
			   -content=>"html"},
	       "createdb"=>{-handler=>"createdb",
			    -content=>"html",
			    -dbhandle=>"blog",
			    -role=>"admin"},
	       "orq"=>{-handler=>"orq",
		       -content=>"html"}
	       };
  bless $s;
  $s;
}

sub info(){
  "foobar
bar
baz";
}

sub mainsite{

}

sub createdb{
  my $s=shift;
  my $dbh=$s->{page}->{dbh};
  my @queries;
  push(@queries, "DROP TABLE IF EXISTS blog");
  push(@queries, "CREATE TABLE mac ( ".
       "mac varchar(17) NOT NULL default '', ".
       "manufacturer varchar(255) NOT NULL default '0', ".
       "deviceinfo int(11) NOT NULL default '0', ".
       "PRIMARY KEY  (mac), ".
       "UNIQUE KEY mac_2 (mac), ".
       "KEY mac (mac) ".
       ") ENGINE=MyISAM DEFAULT CHARSET=latin1;");

  foreach(@queries){
    $dbh->do($_);
  }
}

1;
