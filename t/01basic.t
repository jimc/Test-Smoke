#! perl -w
use strict;

use File::Spec;

my @scripts;
BEGIN {
    @scripts = qw( mktest.pl mkovz.pl 
                   synctree.pl mailrpt.pl smokeperl.pl
                   Util.pm Syncer.pm SourceTree.pm Mailer.pm
                   Makefile.PL Configure.pl configsmoke.pl );
}

use Test::Simple tests => scalar @scripts;

my $dev_null = File::Spec->devnull;

my @libpath = qw( lib Test Smoke );

foreach my $script ( @scripts ) {
    my $s_name = File::Spec->catfile( ($script =~ /\.pm$/ ? @libpath : () ),
                                      $script );

    ok( system( qq{$^X  "-Ilib" "-c" "$s_name" > $dev_null 2>&1} ) == 0,
        "perl -c '$s_name' okay" );
}
    