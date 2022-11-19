#!/usr/bin/perl

=head1 awfulcms.cgi

awfulcms.cgi is the CGI-wrapper around the AwfulCMS modules. You can adjust
the parameters in this script to your needs, or create a custom script.

To use AwfulCMS you only need to include AwfulCMS::LibAwfulCMS, and call
handleCGI()

=head2 Configuration parameters

awfulcms.cgi is used to `bootstrap' AwfulCMS. Therefore we can't access
AwfulCMS configuration settings in this script.

=head3 Error log

By using CGI::Carp we allow logging of script errors to a seperate log file.
You can remove the below BEGIN block if you don't need this functionality.
Otherwise you need to adjust the path to the logfile.

=cut

BEGIN {
    use CGI::Carp qw(carpout);
    open(LOG, ">>/home/bwachter/mycgi-log") or
        die("Unable to open mycgi-log: $!\n");
    carpout(LOG);
}

=head3 Module path

Unless you installed AwfulCMS in global module directories you need to
set the module path containing AwfulCMS with a "use lib" statement

=cut

use lib "/home/bwachter/www/htdocs";
use utf8;
use strict;

use AwfulCMS::LibAwfulCMS qw(handleCGI);

handleCGI();
