package AwfulCMS::ModDig;

=head1 AwfulCMS::ModDig

This module provides a frontend to the `dig' DNS lookup utility

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
  my @digDomains=shift;
  my $digQuery;

  foreach(@digDomains) {
    $digQuery.=`dig $digNS $_ $digTypeName`;
    $digQuery.="<hr>\n";
  }
  $digQuery;
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  my $digType=$p->{cgi}->param('digType');
  my $digNS=$p->{cgi}->param('digNS');
  my $digDomain=$p->{cgi}->param('digDomain');
  my @digDomains=split("\n", $digDomain);
  my ($digTypeName, $digQuery, $url);

  $p->title("digger");
  if ($digType==0) { $digTypeName="any"; }
  elsif ($digType==1) { $digTypeName="A"; }
  elsif ( $digType==2) { $digTypeName="MX"; }
  elsif ( $digType==3) { $digTypeName="SIG"; }
  elsif ( $digType==4) { $digTypeName="CNAME"; }
  elsif ( $digType==5) { $digTypeName="PTR"; }
  elsif ( $digType==6) { $digTypeName="NS"; }
  elsif ( $digType==7) { $digTypeName="AXFR"; }
  else { $digTypeName="any"; }

  if ($digDomain) { $digQuery=$s->queryDig($digNS, $digTypeName, @digDomains); }

  $url="http://$p->{rq_host}/$p->{rq_dir}/$p->{rq_file}?digType=$digType&digNS=$digNS&digDomain=$digDomain";
  $url=~s/\r\n/%0D%0A/g;

  $p->add("
    <form action=\"/$p->{rq_dir}/$p->{rq_file}\" method=\"post\">
    <table border=\"0\">
    <tr>
     <td colspan=\"2\">Domains, one per line</td>
     <td colspan=\"3\">
      <textarea cols=\"40\" rows=\"4\" name=\"digDomain\">$digDomain</textarea>
     </td>
    </tr><tr>
     <td>Type</td>
     <td><select name=\"digType\">".
      $p->pOption(0,"any",$digType).
      $p->pOption(1,"A",$digType).
      $p->pOption(2,"MX",$digType).
      $p->pOption(3,"SIG",$digType).
      $p->pOption(4,"CNAME",$digType).
      $p->pOption(5,"PTR",$digType).
      $p->pOption(6,"NS",$digType).
      $p->pOption(7,"AXFR",$digType).
     "</select>
     </td>
     <td>NS (optional)</td>
     <td><input type=\"text\" name=\"digNS\" value=\"$digNS\" /></td>
    </tr>
    <tr>
     <td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td>
    </tr>
    <tr>
     <th>+</th>
     <th>-</th>
     <th>Option</th>
    </tr>
    <!--
    <tr>
     <td><input type=\"checkbox\" name=\"x_trace\" value=\"yes\"></td>
     <td><input type=\"radio\" name=\"x_trace\" value=\"no\"></td>
     <td>trace</td>
    </tr>
    -->
    </table></form><hr>
    Use this link if you want to show the query to someone else: <a href=\"$url\">$url</a><hr>
    <pre>$digQuery</pre>");
}

1;





