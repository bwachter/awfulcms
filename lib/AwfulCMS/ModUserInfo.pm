package AwfulCMS::ModUserInfo;

=head1 AwfulCMS::ModUserInfo

This module displays information about users. For non-authorized users
not much more than default role permissions is displayed.

With suitable backends this may become useable for user management.

=head2 Configuration parameters

This module does not have any configurable options.

=cut

use strict;
use AwfulCMS::Page qw(:tags);

sub new(){
  shift;
  my $r=shift;
  return -1 if (ref($r) ne "HASH");
  my $s={};
  $s->{page}=shift;
  return -1 if (ref($s->{page}) ne "AwfulCMS::Page");

  $r->{content}="html";
  $r->{rqmap}={"default"=>{-handler=>"mainsite",
                           -role=>"reader",
                           -content=>"html"}
               };
  $s->{mc}=$r->{mc};
  bless $s;
  $s;
}

sub mainsite(){
  my $s=shift;
  my $p=$s->{page};
  $p->h1("User Information");
  $p->ul(li("User authorized: ".($p->{rq}->{authorized}?'yes':'no')),
         li("Effective role: ".$p->{rq}->{'effective-role'}
            ." (".$p->{rq}->{'effective-role-uid'}.")"),
         li("Max. role: ".$p->{rq}->{'max-role'}
            ." (".$p->{rq}->{'max-role-uid'}.")"),
         li("Assigned role: ".($p->{rq}->{'assigned-role'}?'yes':'no'))
         );

  if ($p->{rq}->{authorized}==1){
    $p->h2("User profile for ".$p->{rq}->{user});
  }
}

1;
