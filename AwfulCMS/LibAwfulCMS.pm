package AwfulCMS::LibAwfulCMS;

use strict;
use AwfulCMS::Page;
use AwfulCMS::Config;
use AwfulCMS::LibFS qw(openreadclose);

use Exporter 'import';
our @EXPORT_OK=qw(handleCGI);

my ($p, # the page object
    $c, # the configuration object
    $call, # the final request call in the module
    $m, # the module object handle
    $module, # the module name
    $module_short, # the module shortname (i.e. without AwfulCMS::)
    $request, # the name of the request to pass through
    $role, # the current role
    $roles);

my $r={}; # the hash reference for the module configuration / request handlers

sub init{
  # set up a page for later use and find out about module and request foo
  $p=AwfulCMS::Page->new("");

  # read the configuration file
  $c=AwfulCMS::Config->new($p->{rq_host});
  $p->status(400, "$c") if (ref($c) ne "AwfulCMS::Config");

  eval "require Tie::RegexpHash" if ($c->getValue("main", "filematch"));
  $p->status(400, "Require Tie::RegexpHash failed ($@)") if ($@);

  $roles=$c->getValues("roles");

  # add stylesheets
  my $stylesheets=$c->getValues("stylesheets");
  while (my ($media,$stylesheet)=each(%$stylesheets)){
    $p->{head}.="<link rel=\"stylesheet\" type=\"text/css\" media=\"$media\" href=\"$stylesheet\" />\n";
  }

  if (defined($p->{rq_vars}->{req})){
    $request=$p->{rq_vars}->{req};
  } else {
    ($request)=$p->{rq_dir}=~/.*\/(.*)$/;# if ($p->{rq_dir}=~/\//);
    #($request)=$p->{rq_file}=~/\/.*\/(.*)$/ if ($p->{rq_file}=~/\//);
  }
  #die $request."--".$p->{rq_dir}."--".$p->{rq_file}."--".$p->{cgi}->param("req")."--";
}

sub lookupModule{
  my $_modules=$c->getValues("mapping");
my %hash=$c->getValues("mapping");
  my $_defaultmodule=$c->getValue("main", "defaultmodule")||"ModExample";
  my $_request=$p->{rq_dir};
  my $_rqfile=$p->{rq_file};

  $_request=$p->{rq_file} if ($c->getValue("main", "filematch") 
			      && $_request eq "." 
			      && $p->{rq_file});

  return $_modules->{$_request} if (exists $_modules->{$_request});

  if ($c->getValue("main", "wildcardmappings")){
    my @t=split('/', $_request);
    my $t="";
    foreach(@t){
      $t.=$_;
      return $_modules->{"$t*"} if (exists $_modules->{"$t*"});
      $t.='/';
    }
  }

  if ($c->getValue("main", "filematch")){
    my $rehash = Tie::RegexpHash->new();
    while (my($key, $value)=each(%$_modules)){
      next if ($key eq ".");
      $key=~s/\*$// if ($c->getValue("main", "wildcardmappings"));
      $rehash->add(qr/^$key/, $value);
    }
    my $match=$rehash->match($_rqfile);
    return $match if ($match);
  }

  return $_defaultmodule;
}

sub doModule{
  $module=lookupModule();
  if (defined($p->{rq_vars}->{mod})){
    # module validation, whatever
  } else {
  }

  if ($module=~/^AwfulCMS::/){
    $module_short=$module;
    $module_short=~s/^AwfulCMS:://;
  } else {
    $module_short=$module;
    $module="AwfulCMS::$module";
  }

  $p->status(400, "Module '$module' not available") if ($c->getValue("modules", $module) != 1 &&
					      $c->getValue("modules", $module_short) != 1);
  $p->status(404, "Module '$module' not found") if ($module eq "");

  eval "require $module";
  $p->status(400, "Require $module failed ($@)") if ($@);

  $r->{mc}=$c->getValues($module_short);
  $m=$module->new($r, $p);
  $p->status(400, "Unable to load module '$module'") if (ref($m) ne $module);
}

sub doRequest{
  $p->add(openreadclose($c->getValue("main", "top-include")))
    if ($c->getValue("main", "top-include") && $r->{mc}->{'no-global-includes'}!=1);
  $p->add(openreadclose($r->{mc}->{'top-include'}))
    if (defined $r->{mc}->{'top-include'});

  unless (defined $r->{rqmap}->{$request}->{-handler}){
    if (defined $r->{rqmap}->{default}->{-handler}){
      $request="default";
    } else {
      $p->status(400, "No default method defined in module '$module'");
    }
  }

  # check and enforce roles
  if (defined $r->{rqmap}->{$request}->{-role}){

    my $rolename=$r->{rqmap}->{$request}->{-role};
    if ($c->getValue("main", "static-cookies")){
      #$module_short $request
    #  $p->cgi->raw_cookie();
    }
    $p->status(400, "There's no such role '$rolename'") if (not defined $roles->{$rolename});
    $p->status(401, "You don't have the privileges required to perform this operation") if ($role < $roles->{$rolename});
  }

  if (defined $r->{rqmap}->{$request}->{-dbhandle}){
    my $dbc=$c->getValues("database");
    my $handle=$r->{rqmap}->{$request}->{-dbhandle};
    my $snum=1;
    $handle="default" if (not defined $dbc->{$handle});
    $p->status(400, "There's no configuration for DB-handle '$handle'") if (not defined $dbc->{$handle});
    my $o={};
    if ($dbc->{$handle}->{access} eq "rr"){
      $snum=int(rand($dbc->{$handle}->{srvcnt})+1);
      # get random server
    }

    $o->{type}=$dbc->{$handle}->{type}||"mysql";
    $o->{dbname}=$dbc->{$handle}->{$snum}->{dbname}||$dbc->{$handle}->{dbname};
    $o->{user}=$dbc->{$handle}->{$snum}->{user}||$dbc->{$handle}->{user}||"";
    $o->{password}=$dbc->{$handle}->{$snum}->{password}||$dbc->{$handle}->{password}||"";

    $p->dbhandle({dsn=>"dbi:$o->{type}:dbname=$o->{dbname}", user=>"$o->{user}",
		  password=>"$o->{password}", attr=>{RaiseError=>0,AutoCommit=>1}});
  }

  $call=$r->{rqmap}->{$request}->{-handler};

  $p->add(openreadclose($c->getValue("main", "bottom-include")))
    if ($c->getValue("main", "bottom-include") && $r->{mc}->{'no-global-includes'}!=1);
  $p->add(openreadclose($r->{mc}->{'bottom-include'}))
    if (defined $r->{mc}->{'bottom-include'});
}

sub done{
  $m->$call();
  $p->out();
}

sub handleCGI{
  init();
  doModule();
  doRequest();
  done();
}

1;
