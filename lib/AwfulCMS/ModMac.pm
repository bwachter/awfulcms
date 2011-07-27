package AwfulCMS::ModMac;

=head1 AwfulCMS::ModMac

This module allows manufacturer lookups for MAC-addresses against a
MySQL database.

=head2 Configuration parameters

This module does not have any configurable options.

=cut

use strict;

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;

  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"defaultpage",
                           -content=>"html",
                           -dbhandle=>"mac"},
               "createdb"=>{-handler=>"createdb",
                            -content=>"html",
                            -dbhandle=>"mac",
                            -role=>"admin"}
               };

  bless $s;
  $s;
}

sub lookupMAC {
  my $s=shift;
  my $p=$s->{page};
  my $dbh=$s->{page}->{dbh};
  my $mac=shift;

  my $q_c = $dbh->prepare("select mac,manufacturer from mac where mac=?")||
    $p->status(400, "Unable to prepare query: $!");

  $q_c->execute($mac)||
    $p->status(400, "Unable to execute query: $!");
  my @id = $q_c->fetchrow_array();
  return @id;
}

sub defaultpage{
  my $s=shift;
  my $p=$s->{page};

  $p->title("MAC manufacturer lookup");
  $p->excerpt("A simple script to allow looking up the manufacturer of your ethernet card");
  $p->add("<p>This script allows you to look up the manufacturer behind a MAC address,
using a local database based on the IEEE assignments. You need to give at least
the first 24 bits of the address (i.e. 01:23:45), if you give more digits the script
will consult a device database to find out if it can give you more details. You can
enter multiple MAC addresses separated by ';' at once (e.g. 01:23:45:67;C0:FF:EE will
work)</p>");

  my $mac=$p->{url}->param('mac');
  my $url=$p->{url}->publish({'mac'=>$mac});
  $url=~s/\r\n/%0D%0A/g;

  $p->add("<form action=\"/".$p->{url}->cgihandler()."\" method=\"post\">
    <table border=\"0\"><tr>
    <tr><td>MAC: </td><td><input type=\"text\" name=\"mac\" value=\"$mac\" /></td></tr>
    </tr><td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td></tr>
    </table></form><hr>");

  if ($mac =~ /.*[\da-zA-z][\da-zA-z]:[\da-zA-z][\da-zA-z]:[\da-zA-z][\da-zA-z].*/ ){
    my @macs=split(";", $mac);
    $p->add("<p>Your query returned the following result: </p><dl>");
    foreach (@macs) {
      $_ =~ s/.*?([\da-zA-z][\da-zA-z]:[\da-zA-z][\da-zA-z]:[\da-zA-z][\da-zA-z]).*/$1/;
      my @qresult=$s->lookupMAC($_);
      $p->add("<dt>$qresult[0]</dt><dd>$qresult[1]</dd>");
    }
    $p->add("</dl>");
    $p->add("You can use this link to save the query: <a href=\"$url\">$url</a>");
  } else {
    $p->add("<p>Sorry, but the MAC address you gave me ($mac) seems not to be valid</p>")
      if ($mac ne "");
  }
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
