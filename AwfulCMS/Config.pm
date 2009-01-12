package AwfulCMS::Config;

use strict;

sub new(){
  shift;
  my $vhost=shift;
  my $s={};

  my $cfg="";
  my @lines;

  $s->{parsers}={
		 "main"=>"mainParser",
		 "modules"=>"mainParser",
		 "database"=>"dbParser"
		};

  # locate the configuration file
  my $home="/tmp";
  if (defined $ENV{HOME}){ $home=$ENV{HOME}; } 
  else {
    my @pw=getpwuid($<);
    $home=$pw[7];
  }

  if (-f "$home/.awfulcms/config-$vhost"){ $cfg="$home/.awfulcms/config-$vhost" }
  elsif (-f "$home/.awfulcms/config"){ $cfg="$home/.awfulcms/config" }
  elsif (-f "$home/.awfulcms/awfulcmsrc"){ $cfg="$home/.awfulcms/awfulcmsrc" }
  elsif (-f "$home/.awfulcmsrc"){ $cfg="$home/.awfulcmsrc" }
  elsif(-f "/etc/awfulcms/config"){ $cfg="/etc/awfulcms/config" }
  elsif (-f "/etc/awfulcms/awfulcmsrc"){ $cfg="/etc/awfulcms/awfulcmsrc" }

  return "Unable to find a configuration file" if ($cfg eq "");

  open(F, "<$cfg")||return "Unable to open configuration file: $!";
  @lines=<F>;
  close(F);

  my ($section, $type);
  foreach(@lines){
    $_=~s/#.*//;
    $_=~s/ +/ /g;
    $_=~s/^ +//;
    $_=~s/[\t\n]//g;
    $_=~s/[^\da-zA-Z=<>\-_\/\.\* ]//g;
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

  bless $s;
  $s;
}

sub getValues(){
  my $s=shift;
  my $type=shift;

  if (not defined $s->{"c_$type"}){
    return if (not defined $s->{"r_$type"});
    $s->parseconfig($type);
  }

  return $s->{"c_$type"};
}

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
      my ($key,$value)=split('=', $_);
      $s->{"c_$type"}->{$key}=$value;
    } else {
      $s->{"c_$type"}->{$_}=0;
    }
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
