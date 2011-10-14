package AwfulCMS::LibAwfulCMS;

=head1 AwfulCMS::LibAwfulCMS

This is the AwfulCMS core library.

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

our @EXPORT_OK=qw(handleCGI);

=over

=cut

## implement command-line stuff by having a param-flag 'interactive',
## and executing different code for interactive usage
## optional, export parameters expected by forms

use strict;
use Time::HiRes qw(gettimeofday);
use Date::Format;
use AwfulCMS::Page;
use AwfulCMS::Config;
use AwfulCMS::LibFS qw(openreadclose);

use Exporter 'import';
our @EXPORT_OK=qw(handleCGI);

my ($p, # the page object
    $c, # the configuration object
    $call, # the final request call in the module
    $instance, # the module instance, if not default
    $m, # the module object handle
    $mode, # operating mode, CLI or CGI
    $baseurl, # the base url for the module, without parameters or subdirs
    $module, # the module name
    $module_short, # the module shortname (i.e. without AwfulCMS::)
    $request, # the name of the request to pass through
    $role, # the current role
    $roles,
    $starttime);

my $r={}; # the hash reference for the module configuration / request handlers

=item init()

TODO

=cut

sub init{
  # set up a page for later use and find out about module and request foo
  $p=new AwfulCMS::Page({'mode'=>$mode});

  # read the configuration file
  $c=new AwfulCMS::Config($p->{rq}->{host});
  $p->status(400, "$c") if (ref($c) ne "AwfulCMS::Config");

  eval "require Tie::RegexpHash" if ($c->getValue("main", "filematch"));
  $p->status(400, "Require Tie::RegexpHash failed ($@)") if ($@);

  $roles=$c->getValues("roles");

  $p->{hostname}=$c->getValue("main", "hostname") if ($c->getValue("main", "hostname"));
  $p->{starttime}=$starttime;
  $p->{mc}={};
  $p->{mc}={%{$p->{mc}}, %{$c->getValues("default")}} if ($c->getValues("default"));
  $p->{mc}={%{$p->{mc}}, %{$c->getValues("page")}} if ($c->getValues("page"));

  # add stylesheets
  my $stylesheets=$c->getValues("stylesheets");
  while (my ($media,$stylesheet)=each(%$stylesheets)){
    $p->{head}.="<link rel=\"stylesheet\" type=\"text/css\" media=\"$media\" href=\"$stylesheet\" />\n";
  }
  if (my $favicon=$c->getValue("main", "favicon")){
    # todo, check icon type. so far only png is supported
    $p->{head}.="<link rel=\"icon\" href=\"$favicon\" type=\"image/png\" />\n";
  }
}

=item lookupModule()

TODO

=cut

sub lookupModule{
  my $_modules=$c->getValues("mapping");
  my $_defaultmodule=$c->getValue("main", "defaultmodule")||"ModExample";
  my $_request=$p->{rq}->{dir};
  my $_rqfile=$p->{rq}->{fileabs};

  $_request=$p->{rq}->{fileabs} if ($c->getValue("main", "filematch")
                 && $_request eq "."
                 && $p->{rq}->{fileabs});

  # FIXME, need to check physical directories in some cases
  $baseurl=$_modules->{$_request};
  return $_modules->{$_request} if (exists $_modules->{$_request});

  if ($c->getValue("main", "wildcardmappings")){
    my @t=split('/', $_request);
    while(@t){
      my $t=join('/', @t);
      $baseurl=$t;
      return $_modules->{"$t*"} if (exists $_modules->{"$t*"});
      pop(@t);
    }
  }

  # match all keys (=directories configured) against the beginning
  # of the URL. Return an array with the matching module as well
  # as the configured pathname
  if ($c->getValue("main", "filematch")){
    my $rehash = new Tie::RegexpHash;
    while (my($key, $value)=each(%$_modules)){
      next if ($key eq ".");
      $key=~s/\*$// if ($c->getValue("main", "wildcardmappings"));
      $rehash->add(qr/^$key/, [$key, $value]);
    }
    my $match=$rehash->match($_rqfile);
    if ($match){
      $baseurl=@$match[0];
      return @$match[1];
    }
  }

  # FIXME, unlikely to return anything. Can we get a baseurl here?
  $baseurl=$_modules->{$_request};
  return $_defaultmodule;
}

=item doModule()

TODO

=cut

sub doModule{
  $module=lookupModule();

  if ($module=~/\//){
    ($instance)=$module=~m/\/(.*)$/;
    $module=~s/\/.*//;
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

  $r->{mc}={};
  $r->{mc}->{'display-time'}=$c->getValue("main", "display-time") if ($c->getValue("main", "display-time"));
  $r->{mc}->{'mail-address'}=$c->getValue("main", "mail-address") if ($c->getValue("main", "mail-address"));
  $r->{mc}={%{$r->{mc}}, %{$c->getValues("default")}} if ($c->getValues("default"));
  $r->{mc}={%{$r->{mc}}, %{$c->getValues($module_short)}} if ($c->getValues($module_short));
  $r->{mc}={%{$r->{mc}}, %{$c->getValues($module_short."/".$instance)}} if ($c->getValues($module_short."/".$instance));
  # merge module parameters into page
  $p->{mc}={%{$p->{mc}}, %{$r->{mc}}};

  $p->{'display-time'}=1 if ($r->{mc}->{'display-time'});
  if ($r->{mc}->{'mail-address'}){
    $r->{mc}->{'mail-address'}=time2str($r->{mc}->{'mail-address'}, time);
    $p->{mc}->{'mail-address'}=$r->{mc}->{'mail-address'};
  } else {
    $p->{'mail-address'}=$r->{mc}->{'mail-address'}='somebody-needs-to-fix-the-configuration@invalid.invalid';
  }

  $m=new $module($r, $p);
  $p->status(400, "Unable to load module '$module'") if (ref($m) ne $module);
}

=item doRequest()

TODO

=cut

sub doRequest{
  $p->setModule($module, $instance, $baseurl);

  # cgi style requests are broken until basic cgi support gets added to url
  # tool scripts still work since all requests are default
  #$request=getrequest($p->{target}, $baseurl);
  $request=$p->{url}->{request};

  # FIXME, include code needs some serious redesigning
  $p->preinclude(openreadclose($c->getValue("main", "top-include")))
    if ($c->getValue("main", "top-include") && $r->{mc}->{'no-global-includes'}!=1);
  $p->preinclude(openreadclose($r->{mc}->{'top-include'}))
    if (defined $r->{mc}->{'top-include'});
  $p->postinclude(openreadclose($c->getValue("main", "bottom-include")))
    if ($c->getValue("main", "bottom-include") && $r->{mc}->{'no-global-includes'}!=1);
  $p->postinclude(openreadclose($r->{mc}->{'bottom-include'}))
    if (defined $r->{mc}->{'bottom-include'});

  unless (defined $r->{rqmap}->{$request}->{-handler}){
    if (defined $r->{rqmap}->{default}->{-handler}){
      $request="default";
    } else {
      $p->status(400, "No default method defined in module '$module'");
    }
  }

  # check if we should only display over a secure channel
  if (defined $r->{rqmap}->{$request}->{-ssl}){
    $p->status(403, "Viewing this page is not allowed over unencrypted connections")
      unless ($p->{rq}->{ssl}==1);
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
    # dbhandle lookup order:
    # module:handle/instance, module/instance, module:handle, module, default
    my $dbc=$c->getValues("database");
    # the handle asked by the module
    my $mhandle=$r->{rqmap}->{$request}->{-dbhandle};
    my $handle="default";
    if ($instance ne "" && defined $dbc->{"$module_short:$mhandle/$instance"}){
      $handle="$module_short:$mhandle/$instance"
    } elsif ($instance ne "" && defined $dbc->{"$module_short/$instance"}){
      $handle="$module_short/$instance"
    } elsif (defined $dbc->{"$module_short:$mhandle"}){
      $handle="$module_short:$mhandle"
    } elsif (defined $dbc->{"$module_short"}){
      $handle="$module_short"
    }

    my $snum=1;
    $p->status(500, "There's no configuration for DB-handle '$handle', and there's no default handle")
      if (not defined $dbc->{$handle});
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
          password=>"$o->{password}", attr=>{RaiseError=>0,AutoCommit=>1},
         handle=>$handle});
  }

  if (defined $r->{rqmap}->{$request}->{-setup}){
    my $setup=$r->{rqmap}->{$request}->{-setup};
    $m->$setup();
  }

  $call=$r->{rqmap}->{$request}->{-handler};
}

=item done()

TODO

=cut

sub done{
  $m->$call();
  $p->out();
}

=item handleCGI()

TODO

=cut

sub handleCGI{
  $mode="CGI";
  #$starttime=DateTime->now();
  $starttime=[gettimeofday];
  init();
  doModule();
  doRequest();
  done();
}

=item handleCLI()

TODO

=cut

sub handleCLI{
  $mode="CLI";
  init();
  doModule();
  doRequest();
  done();
}

1;

=back

=cut
