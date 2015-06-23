#!/usr/bin/perl
# new headers: obsoletes
# add `description' to tags (separate table, join)
# descrition-header; only visible in the blog
# faq autogeneration

=head1 blog.pl

A command line client for ModBlog

=head2 Configuration parameters

There are no configuration parameters outside this module.

=head2 Module functions

=over

=cut

#TODO: LibCLI as CLI<>Module-wrapper; move as much code as possible to ModBlog

use AwfulCMS::ModBlog::CLI;
use strict;

my $s=AwfulCMS::ModBlog::CLI->new({instance => $ARGV[0]});
$s->mainloop();
