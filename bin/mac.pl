#!/usr/bin/perl
# Created Sun Dec 27 2009 by Bernd Wachter bwachter-usenet@lart.info

=head1 mac.pl

Foo.

=cut

use AwfulCMS::Config;
use LWP::Simple;
use strict;

require DBI;

# get the oui database from:
my $oui_url="http://standards-oui.ieee.org/oui/oui.txt";
# get the iab database from:
my $iab_url="http://standards-oui.ieee.org/oui/iab.txt";

my %macs;
my $lastmac;

if ( ! -f "oui.txt"){
  print "oui.txt does not exist, trying to retrieve it\n";
  my $ret=getstore($oui_url, "oui.txt");
  print "Unable to retreive $oui_url ($ret)\n" if ($ret != 200);
}

open(OUI, "<oui.txt")||die "Unable to open oui.txt: $!";
# get rid of the oui header
seek(OUI, 61, 0);
while(<OUI>){
  next if (/^\s*[\da-zA-z]{6}\s*\(base 16\)/);
  next if (/^$/);
  if (/^\s*[\da-zA-z]{2}-[\da-zA-z]{2}-[\da-zA-z]{2}/){
    my ($mac, $manufacturer)=m/^\s*([\da-zA-z]{2}-[\da-zA-z]{2}-[\da-zA-z]{2})\s*\(.*?\)\s*(.*)/;
    $mac=~s/-/:/g;
    $macs{$mac}={'manufacturer'=>$manufacturer,
                   'address'=>''};
    #print "New Mac: $mac / $manufacturer\n";
    $lastmac=$mac;
  } else {
    # the file header changes now and then, this makes sure
    # recording only starts after first mac found
    next unless defined $lastmac;
    $_=~s/^\s*//;
    $macs{$lastmac}->{'address'}.=$_;
  }
  #print $_;
}
close(OUI);
unlink("oui.txt");

my $dbh;
my $q;
if ($ARGV[0] eq "mysql"){
  my $c=AwfulCMS::Config->new("");
  my $dbc=$c->getValues("database");

  my $dbhandle;
  if (defined $dbc->{"ModMac"}){
    print "Using ModMac DB handle\n";
    $dbhandle="ModMac";
  } elsif (defined $dbc->{"default"}){
    print "Using default DB handle\n";
    $dbhandle="default";
  } else {
    die("There's no usable DB configuration");
  }

  my $o={};
  $o->{type}=$dbc->{$dbhandle}->{type}||"mysql";
  $o->{dbname}=$dbc->{$dbhandle}->{1}->{dbname}||$dbc->{$dbhandle}->{dbname};
  $o->{user}=$dbc->{$dbhandle}->{1}->{user}||$dbc->{$dbhandle}->{user}||"";
  $o->{password}=$dbc->{$dbhandle}->{1}->{password}||$dbc->{$dbhandle}->{password}||"";

  $dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}", $o->{user},
                    $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
                      die "DBI->connect(): ". DBI->errstr;
  $q=$dbh->prepare("insert into mac (mac, manufacturer, address) values (?, ?, ?) on duplicate key update manufacturer=?, address=?")||
    die("Database problem: $!");
} elsif ($ARGV[0] eq "cdb"){
  eval "require CDB::TinyCDB";
  die "Unable to lead TinyCDB: $@" if ($@);
  $q=CDB::TinyCDB->create("mac.cdb", "mac.cdb.$$");
}

foreach my $key (sort(keys(%macs))){
  if ($ARGV[0] eq "csv"){
    print "$key;".$macs{$key}->{'manufacturer'}.";".$macs{$key}->{'address'}.";0\n";
  } elsif ($ARGV[0] eq "mysql") {
    if ($macs{$key}->{'manufacturer'} eq ""){
      print "Problem for ".$macs{$key}->{'address'}." (".$macs{$key}->{'address'}."), skipping\n";
    } else {
      print "Inserting $key\n";
      $q->execute($key, $macs{$key}->{'manufacturer'}, $macs{$key}->{'address'},
                  $macs{$key}->{'manufacturer'}, $macs{$key}->{'address'})||
                    die("Database problem: $!");
    }
  } elsif ($ARGV[0] eq "cdb"){
    $q->put_replace($key, $macs{$key}->{'manufacturer'});
    $q->put_replace("a_$key", $macs{$key}->{'address'});
  } else {
    print "$key ".$macs{$key}->{'manufacturer'}."\n";
    print $macs{$key}->{'address'}."\n";
  }
}

$q->finish() if ($ARGV[0] eq "cdb");
