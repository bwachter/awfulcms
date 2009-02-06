#!/usr/bin/perl

=head1 awfulcms.cgi


=head2 Configuration parameters

=over

=item * errortext=<string>

The text to display on the 404-page

=back

=cut

use lib "/home/bwachter/www/htdocs";
use strict;

use AwfulCMS::LibAwfulCMS qw(handleCGI);

handleCGI();
