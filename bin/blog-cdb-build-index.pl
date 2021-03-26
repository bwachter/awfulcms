#!/usr/bin/perl
# blog-cdb-build-index.pl
# (c) 2021 Bernd Wachter bwachter@lart.info

=head1 blog-cdb-build-index.pl

Foo.

=cut

use strict;
use AwfulCMS::ModBlog::BackendFS;

my $backend=new AwfulCMS::ModBlog::BackendFS;
$backend->{rootdir}=".";
$backend->createIndex();
