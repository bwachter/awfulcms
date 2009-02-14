package AwfulCMS::ModLinkdump;

=head1 AwfulCMS::ModLinkdump

This module provides a method to dump links into several categories, 
and display either all links, all links in one category, or a single link.

=head2 Configuration parameters

=over

=item * authcookie=<string>

If this option is configured clients presenting a cookie named `canpost'
and this value are allowed to add new links.

=item * setcookie=<int>

Set a cookie with the value specified in `authcookie' on requests. 
Obviously you need to set `authcookie' for this to work. 
Default is 0 (disabled)

=back

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
			   -dbhandle=>"linkdump"},
	       "createdb"=>{-handler=>"createdb",
			    -content=>"html",
			    -dbhandle=>"linkdump",
			    -role=>"admin"}
	       };

  $s->{mc}=$r->{mc};
  bless $s;
  $s;
}

sub getItem {
  my $s=shift;
  my $p=$s->{page};
  my $item = shift;

  my $q_s = $p->{dbh}->prepare("select link,description from ld where id=? and hide=0 order by description desc") ||
    $p->status(500, "Unable to prepare query for getting items: $!");
  $q_s->execute($item) || $p->status(500, "Unable to execute query for selecting items: $!");
  $p->add("<h2>search results:</h2><ul>");
  while ((my $link, my $description) = $q_s->fetchrow_array()) {
    $p->add("<li><a href=\"$link\">".$p->pString($description)."</a></li>\n");
  }
  $p->add("</ul>");
}

sub getCatItems {
  my $s=shift;
  my $p=$s->{page};
  my $catid = shift;
  my $catname = shift;

  $p->add("<h2>search results: $catname</h2>") if ($catname eq "");
  my $q_s = $p->{dbh}->prepare("select id,link,description from ld where cat=? and hide=0 order by description desc") ||
    $p->status(500, "Unable to prepare query for getting items: $!");
  $p->add("<li><a href=\"$p->{target}?q=c$catid\">$catname</a>") if ($catname ne "");
  $p->add("<ul>");
  $q_s->execute($catid) || $p->status(500, "Unable to execute query for selecting items: $!");
  while ((my $id, my $link, my $description) = $q_s->fetchrow_array()) {
    $p->add("<li><a href=\"$p->{target}?q=$id\">#</a> <a href=\"$link\">".$p->pString($description)."</a></li>\n");
  }
  $p->add("</ul>");
  $p->add("</li>") if ($catname ne "");
}

sub getItems {
  my $s=shift;
  my $p=$s->{page};

  my @result, my $cat, my $id, my $pid, my $pcat;

  my $q_pc = $p->{dbh}->prepare("select id,cat from ld_maincat order by cat asc") ||
    $p->status(500, "Unable to prepare query for getting items: $!");
  my $q_c = $p->{dbh}->prepare("select id,cat from ld_cat where pcat=? order by cat asc") ||
    $p->status(500, "Unable to prepare query for getting items: $!");
  $q_pc->execute() || $p->status(500, "Unable to execute query for selecting items: $!");
  while (($pid, $pcat) = $q_pc->fetchrow_array()){
    $p->add("$pcat<ul>");
    $q_c->execute($pid) || $p->status(500, "Unable to execute query for selecting items: $!");
    while (($id, $cat) = $q_c->fetchrow_array()){
      $s->getCatItems($id, $cat);
    }
    $p->add("</ul>");
  }
  0;
}

sub printAddForm{
  my $s=shift;
  my $p=$s->{page};

  my $q_c = $p->{dbh}->prepare("select id,cat from ld_cat order by cat asc") ||
    $p->status(500, "Unable to prepare query for getting items: $!");
  $q_c->execute() || $p->status(500, "Unable to execute query for selecting items: $!");
  $p->add("<form action=\"$p->{target}\" method=\"get\"><table><tr>
          <td><input type=\"text\" name=\"link\" size=\"50\"/>(Link)</td><td><select name=\"cat\">");
  while ((my $id, my $cat) = $q_c->fetchrow_array()){
    $p->add("<option value=\"$id\">$cat</option>");
  }
  $p->add("</select></td></tr><tr><td><input type=\"text\" name=\"description\" size=\"50\"/>(Description)</td>
          <td><input type=\"submit\" name=\"submit\" value=\"Go!\" /></td></tr></table>
          <input type=\"hidden\" name=\"q\" value=\"add\"></form>");
}

sub addLink{
  my $s=shift;
  my $p=$s->{page};

  my $cat=shift;
  my $link=shift;
  my $description=shift;

  my $q_a = $p->{dbh}->prepare("insert into ld(cat, link, description) values (?,?,?)") ||
    $p->status(500, "cannot prepare query: $!");
  $q_a->execute($cat, $link, $description);
}


sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  $p->addCookie("canpost=$s->{mc}->{authcookie}; path=$p->{target}")
    if ($s->{mc}->{authcookie} && $s->{mc}->{setcookie});

  my $bCookie=$p->{cgi}->raw_cookie('canpost');
  my $bQ=$p->{cgi}->param('q');

  my $canpost=1 if ($bCookie eq $s->{mc}->{authcookie} &&
		   $s->{mc}->{authcookie});
  $p->title("Linkdump");

  $p->add("<h3><a href=\"$p->{target}\">up</a>");
  $p->add("|<a href=\"$p->{target}?q=new\">new</a>") if ($canpost);
  $p->add("</h3>");

  if ($bQ =~ /^\d+$/) {
    $s->getItem($bQ);
  } elsif ($bQ =~ /^c\d+$/) {
    $bQ=~s/^c//;
    $s->getCatItems($bQ);
  } elsif ($bQ eq "new" && $canpost) {
    $s->printAddForm();
  } elsif ($bQ eq "add" && $canpost) {
    $s->addLink($p->{cgi}->param('cat'), $p->{cgi}->param('link'), $p->{cgi}->param('description'));
    $p->add("<h3>added link</h3>");
  } else {
    $p->add("<p>Linkdump. Nothing to see here. Really. I don't know who you are - read only.</p>") if (!$canpost);
    $s->getItems(0, 0);
  }
}

1;
