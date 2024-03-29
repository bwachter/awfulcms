package AwfulCMS::Config;

=head1 AwfulCMS::Config

This module provides functions to read and interpret the AwfulCMS config file.

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 File format

The configuration file is divided in several section, starting with
`section <sectionname>' and ending with `endsection'. All text which
is not between those keywords is treated as comments. Inside a section
everything after a `#' sign is ignored.

Each section can have its own syntax, though most sections just use
simple key=value-pairs.

=head3 Section parsers

This module comes with two predefined section parsers, a key=value-parser,
and a parser for the database section. You can change parser assignments
to section keywords in the code of this module. If there's no assignment
for a section the key=value-parser is used.

=head2 Module functions

=over

=cut

use strict;
use Sys::Hostname;

=item new()

Create a new configuration object. It's possible to specify a vhost for
this instance, or specify an alternate path to the configuration file,
which is mostly useful for CLI usage.

C<AwfulCMS::Config->new()>
C<AwfulCMS::Config->new($vhost)>
C<AwfulCMS::Config->new({vhost => "vhost", filepath => "filepath"})>

=cut

sub new(){
  shift;
  my $o=shift;
  my $hostname=hostname;
  my $s={};

  my $cfg="";
  # for backwards compatibility it's possible to specify vhost as single
  # string argument
  if (defined $o){
    if (ref($o) eq "HASH"){
      $cfg=$o->{filepath} if (defined $o->{filepath});
      $s->{vhost}=$o->{vhost} if (defined $o->{vhost});
    }
    else { $s->{vhost}=$o; }
  }


  my @lines;

  $s->{parsers}={
                 "main"=>"mainParser",
                 "modules"=>"mainParser",
                 "database"=>"dbParser",
                 "urltypes"=>"urlParser"
                };

  # locate the configuration file
  my $home="/tmp";
  if (defined $ENV{HOME}){ $home=$ENV{HOME}; }
  else {
    my @pw=getpwuid($<);
    $home=$pw[7];
  }

  if (-f $cfg){ }
  elsif (-f "$home/.awfulcms/config-$s->{vhost}"){ $cfg="$home/.awfulcms/config-$s->{vhost}" }
  elsif (-f "$home/.awfulcms/config-$hostname"){ $cfg="$home/.awfulcms/config-$hostname" }
  elsif (-f "$home/.awfulcms/config"){ $cfg="$home/.awfulcms/config" }
  elsif (-f "$home/.awfulcms/awfulcmsrc"){ $cfg="$home/.awfulcms/awfulcmsrc" }
  elsif (-f "$home/.awfulcmsrc"){ $cfg="$home/.awfulcmsrc" }
  elsif(-f "/etc/awfulcms/config"){ $cfg="/etc/awfulcms/config" }
  elsif (-f "/etc/awfulcms/awfulcmsrc"){ $cfg="/etc/awfulcms/awfulcmsrc" }

  # TODO: This probably should get logged now
  #return "Unable to find a configuration file" if ($cfg eq "");

  if (open(F,'<:encoding(UTF-8)',"$cfg")){
    @lines=<F>;
    close(F);

    $s->{filepath}=$cfg;

    my ($section, $type);
    foreach(@lines){
      $_=~s/#.*//;
      $_=~s/ +/ /g;
      $_=~s/^ +//;
      $_=~s/[\t\n]//g;
      $_=~s/[^\da-zA-Z\@%\:=<>\-_\/,\.\*\?& ]//g;
      next if (/^ *$/);
      if ($type eq ""){
        if (/^section/i){
          $type=$_;#=~/ .*$/;
          $type=~s/^.*? //;
        }
        next;
      } else {
        if (/^endsection/i){
          $s->{"r_$type"}=$section;
          $section=$type="";
          next;
        }
        $section.=$_."\n";
      }
    }
  } else {
    eval "require Module::Path";
    return "Unable to open configuration file '$cfg', Module::Paths not available for fallback: $!\n$@" if ($@);

    my $_modulepath=Module::Path::module_path("AwfulCMS::Config");
    return "Module installation path not found and no configuration available: $!" unless (defined($_modulepath));

    $_modulepath=~s,AwfulCMS/Config\.pm$,,;
    # make ModPerlDoc available
    $s->{"r_modules"}="ModPerlDoc=1";
    # set as default module
    $s->{"r_main"}="defaultmodule=ModPerlDoc";
    # set module path
    $s->{"r_ModPerlDoc"}="modulepath=$_modulepath
doc-dirs=/AwfulCMS";
  }

  bless $s;
  $s;
}

=item getValues()

TODO

=cut

sub getValues(){
  my $s=shift;
  my $type=shift;

  if (not defined $s->{"c_$type"}){
    return if (not defined $s->{"r_$type"});
    $s->parseconfig($type);
  }

  return $s->{"c_$type"};
}

=item getValue()

TODO

=cut

sub getValue(){
  my $s=shift;
  my $type=shift;
  my $value=shift;

  if (not defined $s->{"c_$type"}){
    return "" if (not defined $s->{"r_$type"});
    $s->parseconfig($type);
  }

  return "" if (not defined $s->{"c_$type"}->{$value});
  return $s->{"c_$type"}->{$value};
}

=item parseconfig()

TODO

=cut

sub parseconfig(){
  my $s=shift;
  my $type=shift;

  return if (not defined $s->{"r_$type"});

  if (defined $s->{parsers}->{$type}){
    my $call=$s->{parsers}->{$type};
    $s->$call($type);
  } else {
    $s->mainParser($type);
  }
}

# the parsers

sub mainParser(){
  my $s=shift;
  my $type=shift;

  return if (not defined $s->{"r_$type"});
  my @lines=split('\n', $s->{"r_$type"});

  foreach (@lines){
    if (/=/){
      my ($key,$value)=$_=~/(.*?)=(.*)/;
      $s->{"c_$type"}->{$key}=$value;
    } else {
      $s->{"c_$type"}->{$_}=0;
    }
  }
}

sub urlParser(){
  my $s=shift;
  my $type=shift;
  my $mode="";

  my ($key, $url, $description, $icon);

  return if (not defined $s->{"r_$type"});
  my @lines=split('\n', $s->{"r_$type"});
  foreach (@lines){
    next if ($key eq "" && not /^type/i);
    if (/^type/i){
      $key=$_;
      $key=~s/^.*? //;
      $s->{"c_$type"}->{$key}={};
      next;
    }
    my ($k, $v)=split('=', $_);
    $s->{"c_$type"}->{$key}->{$k}=$v;
  }
}

sub dbParser(){
  my $s=shift;
  my $type=shift;
  my $mode="";

  my ($hname, $server, $base);

  return if (not defined $s->{"r_$type"});
  my @lines=split('\n', $s->{"r_$type"});
  foreach (@lines){
    next if ($hname eq "" && not /^handle/i);
    if (/^handle/i){
      $hname=$_;
      $hname=~s/^.*? //;
      $base=$s->{"c_$type"}->{$hname}={};
      $s->{"c_$type"}->{$hname}->{srvcnt}=0;
      next;
    }
    if (/^server/i){
      $s->{"c_$type"}->{$hname}->{srvcnt}++;
      $base=$s->{"c_$type"}->{$hname}->{$s->{"c_$type"}->{$hname}->{srvcnt}}={};
      next;
    }
    my ($key, $value)=split('=', $_);
    $base->{$key}=$value;
  }
}

1;

=back

=cut
