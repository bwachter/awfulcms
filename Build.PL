#!/usr/bin/perl
# Build.PL
# (c) 2011 Bernd Wachter <bwachter@lart.info>

=head1 Build.PL

Foo.

=cut

use strict;

use Module::Build;

my %module_build_args = (
                         'build_requires' => {
                                              'Module::Build' => '0.2808',
                                              'Test::More' => '0.80'
                                             },
                         'configure_requires' => {
                                                  'Module::Build' => '0.2808'
                                                 },
                         'dist_abstract' => 'An attempt at creating an ugly CMS',
                         'dist_author' => [
                                           'Bernd Wachter <bwachter@lart.info>'
                                          ],
                         'dist_name' => 'AwfulCMS',
                         'dist_version' => '0.1',
                         'license' => 'artistic_2',
                         'module_name' => 'AwfulCMS',
                         'recommends' => {
                                          'HTML::FormatText::WithLinks::AndTables' => '0',
                                          # Used by ModMidget
                                          'LWP::UserAgent' => '0',
                                          'HTML::LinkExtor' => '0',
                                          'Net::NNTP' => '0',
                                          # Used by ModGallery
                                          'Image::ExifTool' => '8.15',
                                          # Required to enable wildcard configuration
                                          'Tie::RegexpHash' => '0.15',
                                          # Required for DB support in modules
                                          'DBI' => '0',
                                          # Requirements for trackbacks
                                          'Net::Trackback::Client' => '0',
                                          'Net::Trackback::Ping' => '0',
                                          'RPC::XML::Client' => '0',
                                         },
                         'recursive_test_files' => 1,
                         'requires' => {
                                        'CGI' => '0',
                                        'Date::Format' => '1.1600',
                                        'Encode' => '0',
                                        'File::Path' => '0',
                                        'File::Temp' => '0',
                                        'File::Type' => '0.22',
                                        'GD' => '2.39',
                                        'LWP::Simple' => '0',
                                        'Pod::Simple::HTML' => '0',
                                        'Sys::Hostname' => '0',
                                        'Text::Markdown' => '0',
                                        'Time::HiRes' => '0',
                                        'URI::Escape' => '1.35',
                                        'XML::RSS' => '0',
                                        'perl' => 'v5.8.1'
                                       },
                        );


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
