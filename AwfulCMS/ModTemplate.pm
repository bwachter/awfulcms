package AwfulCMS::ModTemplate;

use strict;
use AwfulCMS::SynBasic;

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

  my $filename=$s->{page}->{rq_dir}."/".$s->{page}->{rq_file};
  # FIXME, index.html needs to be found, too
  $filename=~s/\.html$/.tpl/;
  $filename.="index.tpl" if ($filename=~/\/$/);
  $filename.=".tpl" unless ($filename=~/\.tpl$/);
  
  open(F, "$filename")||
    $p->status(404, "No such file '$filename'");
  @lines=<F>;
  close(F);

  my $content=join('', @lines);
  (my $metadata)=$content=~/\{:(.*):\}/s;
  $content=~s/\{:(.*):\}//gs;
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
  my $body;
  $body.="<h1>$metadata{title}</h1>" if defined $metadata{title};
  $body.=AwfulCMS::SynBasic->format($content, 
				      {blogurl=>$s->{mc}->{'content-prefix'},
				      htmlhack=>1});

  #foreach my $key (sort(keys(%metadata))){ $body.="'$key' =&gt; '$metadata{$key}'<br />"; }

  $p->add($body);
}

1;
