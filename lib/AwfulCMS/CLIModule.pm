package AwfulCMS::CLIModule;

=head1 CLIModule.pm

Generic functionality for CLI modules

=head2 Module functions

=over

=cut

use strict;
use AwfulCMS::Config;

=item new

Sample constructor. A module constructor usually looks something like the
following, containing a definition of optional features, followed by setting
up the configuration, optional features, and maybe a database backend.

  shift;
  my $o=shift;
  my $s={};

  $s->{features} = {
                    trackbacks => {
                                   available => 0,
                                   modules => ["Net::Trackback::Client", "Net::Trackback::Ping"],
                                  },
                    pingbacks => {
                                  available => 0,
                                  modules => "RPC::XML::Client",
                                 },
                   };
  bless $s;

  $s->get_config("ModBlog");
  $s->check_features();

  $s->{mc}->{'title-prefix'}="Blog" unless (defined $s->{mc}->{'title-prefix'});

  $s->{backend}=new AwfulCMS::ModBlog::BackendMySQL;
  $s->{backend}->{cb_err}=sub{my $e=shift;$s->cb_die($e)};

  $s->connect_db();

  $s;


The feature specification is a simple nested hash. If just one module is required for a feature it can be passed as scalar, otherwise a list of modules must be passed as hash reference.

=cut

sub new{
  shift;
  my $o=shift;
  my $s={};

  $s->{features} = {
                    trackbacks => {
                                   available => 1,
                                   modules => ["Net::Trackback::Client", "Net::Trackback::Ping"],
                                  },
                    pingbacks => {
                                  available => 0,
                                  modules => [ "RPC::XML::Client" ],
                                 },
                   };

  bless $s;
  $s;
}

=item connect_db

Connect to a database, if configured. This assumes that C<< $s->{backend} >> is a valid backend for the current module.

As it depends on configuration details I<connect_db> usually should get called after I<get_config>

=cut

sub connect_db{
  my $s=shift;

  return unless (defined $s->{dbc});

  my $o={};
  $o->{type}=$s->{dbc}->{type}||"mysql";
  $o->{dbname}=$s->{dbc}->{1}->{dbname}||$s->{dbc}->{dbname};
  $o->{user}=$s->{dbc}->{1}->{user}||$s->{dbc}->{user}||"";
  $o->{password}=$s->{dbc}->{1}->{password}||$s->{dbc}->{password}||"";

  my $dbh=DBI->connect("dbi:$o->{type}:dbname=$o->{dbname}", $o->{user},
                    $o->{password}, {RaiseError=>0,AutoCommit=>1}) ||
                      die "DBI->connect(): ". DBI->errstr;

  # TODO: check if there's a valid backend
  $s->{backend}->{dbh}=$dbh;
}

=item check_features

Check availability of optional features. Modules of all available
features will be loaded after this check (i.e., functionality can be
used without another attempt at loading the module).

A module should check if C<< $s->{features}->{<feature_name>}->{available} >>  is set to 1 before using optional functionality.

=cut

sub check_features{
  my $s=shift;
  # TODO: make those two arrays available outside
  my @missing_modules;
  my @errors;

  foreach my $key(keys(%{$s->{features}})){
    if (ref($s->{features}->{$key}->{modules}) eq "ARRAY"){
      $s->{features}->{$key}->{available} = 1;
      foreach (@{$s->{features}->{$key}->{modules}}){
        eval "require $_";
        if ($@){
          $s->{features}->{$key}->{available} = 0;
          push(@missing_modules, $_);
          push(@errors, $@);
        }
      }
    } elsif (!ref($s->{features}->{$key}->{modules}) && $s->{features}->{$key}->{modules} ne ""){
      eval "require $s->{features}->{$key}->{modules}";
      if ($@){
        print "Feature $key not available\n";
        $s->{features}->{$key}->{available} = 0;
        push(@missing_modules, $s->{features}->{$key}->{modules});
        push(@errors, $@);
      } else {
        $s->{features}->{$key}->{available} = 1;
      }
    } else {
      print "Skipping $key\n";
      $s->{features}->{$key}->{available} = 0;
    }
  }
}

=item get_config($module [,$instance])

Read the configuration for the module, the specific module instance, and CLI specific options. Just like for CGI modules the module configuration will be available in C<< $s->{mc} >>.

If the module has a database configuration section it'll be available in C<< $s->{dbc} >>

=cut

sub get_config{
  my $s=shift;
  my $module=shift;
  my $instance=shift;

  my $c=AwfulCMS::Config->new("");

  # read module configuration for module, instance and cli, returning an empty hash
  # if no configuration exists for easier hash merging later
  my $mc_instance=$c->getValues("$module/$instance") || {};
  my $mc_cli=$c->getValues($module."CLI") || {};
  my $mc=$c->getValues("$module") || {};

  # merge the three configuration hashes
  $s->{mc}={%{$mc}, %{$mc_instance}, %{$mc_cli}};

  # read db config, if available
  my $dbc=$c->getValues("database");
  my $dbhandle=$module;
  $dbhandle="$module/$instance" if (defined $dbc->{"$module/$instance"});
  $s->{dbc}=$dbc->{$dbhandle};
}


=back

=cut

1;
