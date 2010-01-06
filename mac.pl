#!/usr/bin/perl
# Created Sun Dec 27 2009 by Bernd Wachter bwachter-usenet@lart.info

=head1 mac.pl

Foo.

=cut

use AwfulCMS::Config;
use strict;

require DBI;

# get the oui database from: http://standards.ieee.org/regauth/oui/oui.txt
# get the iab database from: http://standards.ieee.org/regauth/oui/iab.txt

my %macs;
my $lastmac;

open(OUI, "<oui.txt")||die "Unable to open oui.txt: $!";
# get rid of the oui header
seek(OUI, 61, 0);
while(<OUI>){
    next if (/^[\da-zA-z]{6}/);
    next if (/^$/);
    if (/^[\da-zA-z]{2}-[\da-zA-z]{2}-[\da-zA-z]{2}/){
        my ($mac, $manufacturer)=m/^([\da-zA-z]{2}-[\da-zA-z]{2}-[\da-zA-z]{2})\s*\(.*?\)\s*(.*)/;
        $mac=~s/-/:/g;
        %macs->{$mac}={'manufacturer'=>$manufacturer,
                       'address'=>''};
        #print "New Mac: $mac / $manufacturer\n";
        $lastmac=$mac;
    } else {
        $_=~s/^\s*//;
        %macs->{$lastmac}->{'address'}.=$_;
    }
    #print $_;
}
close(OUI);

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
    $q=$dbh->prepare("insert into mac (mac, manufacturer) values (?, ?) on duplicate key update manufacturer=?")||
        die("Database problem: $!");
}

foreach my $key (sort(keys(%macs))){
    if ($ARGV[0] eq "csv"){
        print "$key;".%macs->{$key}->{'manufacturer'}.";0\n";
    } elsif ($ARGV[0] eq "mysql") {
        $q->execute($key, %macs->{$key}->{'manufacturer'}, %macs->{$key}->{'manufacturer'})||
            die("Database problem: $!");
    } else {
        print "$key ".%macs->{$key}->{'manufacturer'}."\n";
        print %macs->{$key}->{'address'}."\n";
    }
}