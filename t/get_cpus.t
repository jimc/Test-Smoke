#! perl -w
use strict;

# $Id: get_cpus.t 235 2003-07-15 14:24:23Z abeltje $

use Config;

use Test::More tests => 3;
BEGIN { use_ok( 'Test::Smoke::Util', 'get_ncpu' ); }

ok( defined &get_ncpu, "get_ncpu() is defined" );
SKIP: {
    my $ncpu = get_ncpu( $Config{osname} );
    skip "OS does not seem to be supported ($Config{osname})", 1
        unless $ncpu;
    like( $ncpu, '/^\d+/', "Found: $ncpu" );
}


