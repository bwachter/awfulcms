package AwfulCMS::ModPerlDoc;

=head1 AwfulCMS::ModPerlDoc

This module extracts and displays POD-Information from AwfulCMS modules and scripts.

=head2 Configuration parameters

=over

=item * doc-dirs=<string>

Directories to include in the listing. Defaults to "/" (top level only)

=back

=item * modulepath=<string>

The directory containing the perl modules to export

=back

=item * title=<string>

The title to use for the overview page. Defaults to "Documentation for <modulepath>"

=back

=item * vendor-perl=<int>

If set to 1 appends vendor_perl/<perl_version> to the documentation directory

=head2 Related information

=over

=item * L<http://perldoc.perl.org/Pod/Simple/HTML.html>

=item * L<http://perldoc.perl.org/Pod/Simple/PullParser.html>

=item * L<http://perldoc.perl.org/perlpod.html>

=back

=cut

use AwfulCMS::LibFS qw(ls openreadclose);
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
               "pod"=>{-handler=>"podview",
                        -content=>"html"}
               };

  $s->{mc}=$r->{mc};

  if ($s->{mc}->{'vendor-perl'} == 1 && defined $s->{mc}->{modulepath}){
    my $version=sprintf("%vd",$^V);
    $s->{mc}->{modulepath} .= "/vendor_perl/$version";
  }
  bless $s;
  $s;
}

sub contentlisting(){
  my $s=shift;
  my $p=$s->{page};


  my @dirs=("/");
  if (defined $s->{mc}->{'doc-dirs'}){
    $s->{mc}->{'doc-dirs'}=~s/ //g;
    @dirs=split(',', $s->{mc}->{'doc-dirs'});
  }

  $p->status(500, "modulepath not set, unable to find modules") unless (defined $s->{mc}->{modulepath});

  $p->add("<ul>");
  foreach my $dir (@dirs){
    my @files;
    ls($s->{mc}->{modulepath}."$dir", \@files)||
      $p->status(500, "Unable to open directory $dir");
    $p->add("<li>$dir<ul>");
    foreach(sort(@files)){
      next unless ($_=~/(\.p[ml])$|(\.pod)$|(\.cgi)$/);
      $p->add("<li><a href=\"".$p->{url}->buildurl({'req'=>'pod', 'file'=>"$dir/$_"})."\">$_</a></li>");
    }
    $p->add("</ul></li>");
  }
  $p->add("</ul>");
}

sub defaultpage(){
  my $s=shift;
  my $p=$s->{page};

  if (defined $s->{mc}->{title}){
    $p->title($s->{mc}->{title});
  } else {
    $p->title("Documentation for $s->{mc}->{modulepath}");
  }
  $s->contentlisting();
}

sub podview(){
  my $s=shift;
  my $p=$s->{page};
  my $file=$p->{url}->param("file");

  $p->add("<p><a href=\"".$p->{url}->buildurl()."\">Go back to the index</a></p>");

  eval "require Pod::Simple::HTML";
  $p->status(500, $@) if ($@);

  $file=~s/^[^a-zA-Z0-9]*//;

  $s->contentlisting() if ($file eq "");
  $p->title("Documentation for $file");

  my $input=openreadclose($s->{mc}->{modulepath}."/$file");
  $p->status(404, "Sorry, $file does not exist") if ($input eq "");

  my $output;
  my $parser = Pod::Simple::HTML->new();
  $parser->output_string(\$output);
  $parser->set_source(\$input);
  $parser->run();
  $output="<p>Sorry, no documentation exists for $file</p>" if ($output eq "");
  $output=~s/.*<!-- start doc -->//s;
  $output=~s/<!-- end doc -->.*//s;
  $p->add($output);
  return;
}

1;
