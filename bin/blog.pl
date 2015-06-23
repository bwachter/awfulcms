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

sub help{
  print {$s->{OUT}} <<END;
d|delete <article-id>     delete the article with the given ID
e|edit   <article-id>     open the article with the given ID in the editor
h|help                    show this help text
l|list                    list all articles
  [d|draft]               list all drafts
  [s|series]              list all configured series
  [<page>]                list the given page (1-n, default 1)
n|new                     prepare a new article and open in the editor
p|print  <article-id>     print the article with the given ID
q|quit                    exit this program
u|update                  update/create SQL databases
END
}

sub main{
  my $term = new Term::ReadLine 'AwfulCMS Blog';
  my $prompt = "> ";
  $s->{OUT} = $term->OUT || \*STDOUT;

  while ( defined ($_ = $term->readline($prompt)) ) {
    my @cmd=split(/ /, $_);

    if ($cmd[0] eq "d" || $cmd[0] eq "delete"){
      if ($cmd[1] eq ""){
        print {$s->{OUT}} "Missing article ID. See `help' for details.";
        next;
      }
      $s->{backend}->deleteArticle($cmd[1]);
    } elsif ($cmd[0] eq "e" || $cmd[0] eq "edit"){
      if ($cmd[1] eq ""){
        print {$s->{OUT}} "Missing article ID. See `help' for details.";
        next;
      }
      $s->editArticle($cmd[1]);
    } elsif($cmd[0] eq "h" || $cmd[0] eq "help"){
      help();
    } elsif ($cmd[0] eq "l" || $cmd[0] eq "list"){
      $s->listArticles($cmd[1]);
    } elsif ($cmd[0] eq "p" || $cmd[0] eq "print"){
      if ($cmd[1] eq ""){
        print {$s->{OUT}} "Missing article ID. See `help' for details.";
        next;
      }
      $s->printArticle($cmd[1]);
    } elsif ($cmd[0] eq "s" || $cmd[0] eq "series"){
      if ($cmd[1] eq ""){
        print {$s->{OUT}} "Missing series name. See `help' for details.";
        next;
      }
      createOrEditSeries($cmd[1]);
    } elsif ($cmd[0] eq "n" || $cmd[0] eq "new"){
      $s->createArticle();
    } elsif ($cmd[0] eq "u" || $cmd[0] eq "update"){
      $s->{backend}->createdb();
    } elsif ($cmd[0] eq "q" || $cmd[0] eq "quit"){
      exit(0);
    } else {
      print "Unknown command `$cmd[0]'\n" unless ($cmd[0] eq "");
    }
    $term->addhistory($_) if /\S/;
  }
}

main();
