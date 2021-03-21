package AwfulCMS::ModTemplate;

=head1 AwfulCMS::ModTemplate

This module creates dynamic and optionally static pages from template files

=head2 Configuration parameters

=over

=item * prefix=<string>

TODO

=item * path=<string>

TODO

=item * cache=<string>

The path to use for caching files. If the directory is not writeable for the script the page will not be cached (though no error shown to the user)

=item * content-prefix=<string>

TODO

=item * disable-cache=[0|1]

Disable or enable caching of files

=back

=head2 Template metadata

A template may use additional metadata which will be either used as metadata in the resulting HTML page, or used to change the way the template is parsed. Metadata is specified at the very beginning of the file, starting with {: on an empty line, ended with :} on an empty line.

=over

=item * title

The page title

=item * excerpt

Page excerpt to be used for services like Flattr.

=item * markup

The markup engine to use for parsing this file

=back

=cut


use strict;
use AwfulCMS::Format;

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
               "file"=>{-handler=>"mainsite",
                         -content=>"html"}
               };

  $s->{mc}=$r->{mc};
  bless $s;
  $s;
}

sub info(){
  "foobar
bar
baz";
}

sub mainsite(){
  my $s=shift;
  my $p=$s->{page};
  my @lines;

  my $filename=$s->{page}->{rq}->{dir}."/".$s->{page}->{rq}->{file};
  # FIXME, index.html needs to be found, too
  $filename=~s/\.html$/.tpl/;
  $filename.="index.tpl" if ($filename=~/\/$/);
  $filename.=".tpl" unless ($filename=~/\.tpl$/);

  $filename=~s/^$s->{mc}->{prefix}// if ($s->{mc}->{prefix});
  $filename=$s->{mc}->{path}."/$filename" if ($s->{mc}->{path});

  # if index.tpl does not exist generate a simple overview page;
  # if overview.map exists, use this for the overview
  open(F, "$filename")||
    $p->status(404, "No such file '$filename'");
  @lines=<F>;
  close(F);

  my $content=join('', @lines);
  (my $metadata)=$content=~/^\{:(.*):\}/s;
  $content=~s/^\{:(.*):\}\s*//gs;
  (my $yaml_metadata)=$content=~/^---(.*?)\n---/s;
  $content=~s/^---(.*?)\n---//gs;
  $content=~s/^\s*//;
  $metadata=~s/^\s+/ /;
  my @metadata;
  @metadata=split '\n', $metadata;
  my %metadata;
  foreach (@metadata){
    chomp;
    s/^ *//;
    my ($key, $value)=split(/=/);
    $metadata{"$key"}=$value;
  }

  $p->title($metadata{title});
  $p->setHtmlHeader("meta", {"http-equiv" => "Content-Type",
                             content => "text/html; charset=UTF-8"});
  $p->excerpt($metadata{excerpt}) if ($metadata{excerpt});
  my $body;
  $body.="<h1>$metadata{title}</h1>" if defined $metadata{title};

  my $f;
  if (defined $metadata{markup}){
    $f=new AwfulCMS::Format($metadata{markup});
  } else {
    $f=new AwfulCMS::Format();
  }

  $body.=$f->format($content,
                    {blogurl=>$s->{mc}->{'content-prefix'},
                     htmlhack=>1});

  #foreach my $key (sort(keys(%metadata))){ $body.="'$key' =&gt; '$metadata{$key}'<br />"; }

  # this may override some of the above stuff. Eventually that probably should
  # all be merged into page
  $p->setYamlMetadata($yaml_metadata) if ($yaml_metadata);

  # FIXME, more elegant solution
  $p->add($body);

  unless ($s->{mc}->{'disable-cache'}==1){
    my $dumpfile=$filename;
    $dumpfile=~s/\.tpl$/.html/;

    if ($s->{mc}->{cache}){
      $dumpfile=~s,/,_,g;
      $dumpfile=$s->{mc}->{cache}."/$dumpfile";
    }
    $p->dumpto($dumpfile);
  }
}

1;
