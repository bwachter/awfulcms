package AwfulCMS::ModDig;

=head1 AwfulCMS::ModDig

This module provides a frontend to the `dig' DNS lookup utility

=head2 Configuration parameters

This module does not have any configurable options.

=cut

# TODO: Allow saving default options in a cookie
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
                           -content=>"html"},
               "roles"=>{-handler=>"mainsite",
                         -content=>"html",
                         -role=>"author"},
               "orq"=>{-handler=>"orq",
                       -content=>"html"}
               };
  bless $s;
  $s;
}

sub queryDig {
  my $s=shift;
  my $digNS=shift;
  my $digTypeName=shift;
  my $digDomains=shift;
  my $digOptionString=shift;
  my $digQuery;

  $digNS="\@$digNS" unless ($digNS eq "");

  foreach(@$digDomains) {
    $digQuery.=`dig $digOptionString $digNS $_ $digTypeName`;
    $digQuery.="<hr>\n";
  }
  $digQuery;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  my $digDomain=$p->{url}->param('digDomain');
  my ($digType, $digNS, $url, $digQuery);

  my %digTypes=(
                '0' => "any",
                '01' => "A",
                '02' => "AAAA",
                '03' => "MX",
                '04' => "CNAME",
                '05' => "PTR",
                '06' => "NS",
                '07' => "AXFR",
                '08' => "SIG",
                '09' => "SOA",
                '10' => "SRV",
                '11' => "TXT"
               );

  my %digOptions=(
                  ttl => { default => 'yes', opt => 'ttlid',
                           description => "Display the TTL" },
                  trc => { default => 'no',  opt => 'trace',
                           description => "Enable tracing of the delegation path from root name servers "},
                  cmt => { default => 'yes', opt => 'comments',
                           description => "Toggle the display of comment lines in the output" },
                  sts => { default => 'yes', opt => 'stats',
                           description => 'Display query statistics' },
                  qst => { default => 'yes', opt => 'question',
                           description => "Display the question section of a query as a comment" },
                  ans => { default => 'yes', opt => 'answer',
                           description => "Display the answer section of a reply" },
                  aut => { default => 'yes', opt => 'authority',
                           description => "Display the authority section of a reply" },
                  add => { default => 'yes', opt => 'additional',
                           description => "Display the additional section of a reply" },
                  mlt => { default => 'no',  opt => 'multiline',
                           description => 'Print records like SOA-records in a multi-line format with verbose comments' },
                 );

  # maybe: tcp, ign, aaflag, adflag, cdflag, cl, nssearch, recurse,
  # qr, fail, besteffort, dnssec, sigchase, topdown, nsid

  $p->title("digger");
  $p->excerpt("digger is a web frontend to the 'dig' commandline tool for querying web servers");

  if ($digDomain){
    my %digOpt;
    my @digDomains=split("\n", $digDomain);

    $digType=$p->{url}->param('digType');
    $digNS=$p->{url}->param('digNS');

    my $_optstring="";
    foreach my $key(keys(%digOptions)){
      my $_opt=$p->{url}->param($key);
      if (($_opt eq "yes" || $_opt eq "no") && $_opt ne %digOptions->{$key}->{default}){
        my $_optname=%digOptions->{$key}->{opt};
        %digOpt->{$key}=$_opt;
        if ($_opt eq "yes"){
          $_optstring.=" +$_optname";
        } else {
          $_optstring.=" +no$_optname";
        }
      }
    }

    $digType=0 if ($digType > keys(%digTypes) || $digType < 0);
    $digQuery=$s->queryDig($digNS, %digTypes->{$digType}, \@digDomains, $_optstring);

    $url=$p->{url}->buildurl({'digType'=>$digType,
                              'digNS'=>$digNS,
                              'digDomain'=>$digDomain,
                              %digOpt
                             });
    $url=$p->{url}->publish($url);
  }

  my ($optString, $typeString);
  foreach my $key(sort(keys(%digTypes))){
    $typeString.=$p->pOption($key, %digTypes->{$key}, $digType);
  }
  foreach my $key(sort(keys(%digOptions))){
    my $_description=%digOptions->{$key}->{description};
    my $_name=%digOptions->{$key}->{opt};
    $optString.="<tr>
     <td>$_name</td>
     <td>".$p->pRadio($key, "yes", $p->{url}->param($key)||%digOptions->{$key}->{default})."</td>
     <td>".$p->pRadio($key, "no", $p->{url}->param($key)||%digOptions->{$key}->{default})."</td>
     <td>$_description</td>
    </tr>";
  }
  $p->add("
    <form action=\"/".$p->{url}->cgihandler()."\" method=\"post\">
    <table>
    <tr>
     <td colspan=\"3\">Domains, one per line</td>
     <td rowspan=\"5\"><table>
      <tr>
       <th>Option</th>
       <th>+</th>
       <th>-</th>
       <th>Description</th>
      </tr>
      $optString
      </table></td>
    </tr><tr>
     <td colspan=\"3\">
      <textarea cols=\"40\" rows=\"8\" name=\"digDomain\">$digDomain</textarea>
     </td>
    </tr><tr>
     <td>NS (optional)</td>
     <td colspan=\"2\"><input type=\"text\" name=\"digNS\" value=\"$digNS\" /></td>
    </tr><tr>
     <td>Type</td>
     <td><select name=\"digType\">$typeString</select></td>
     <td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td>
    </tr>
    <tr>
     <td colspan=\"3\">
      <!-- <input type=\"checkbox\" name=\"save\" value=\"yes\" />Save current options for future use -->
     </td>
    </tr>
    </table></form>
    <hr>
     Please <a href=\"mailto:$p->{mc}->{'mail-address'}\">drop me a note</a> if
     you see any breakage or have feature requests. If you want to support my work
     you could use the above flattr button, or follow this
     <a href=\"$p->{mc}->{'paypal-donation'}\">paypal donation link</a>.<hr>");

  $p->add("Use this link if you want to show the query to someone else: <a href=\"$url\">$url</a><hr>") if ($digDomain);

  $p->add("<pre>$digQuery</pre>");
}

1;
