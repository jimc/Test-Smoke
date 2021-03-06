#! /usr/bin/perl -w
use strict;

# $Id: syncer_snap.t 235 2003-07-15 14:24:23Z abeltje $

use Data::Dumper;
use Test::More tests => 3;

use_ok( 'Test::Smoke::Syncer' );

{
    my $syncer = Test::Smoke::Syncer->new( snapshot => {
        tar  => 'tar -xzf',
        ddir => '/home/abeltje/perlsmoke/bleadperl/perl-current',
        v    => 1,
    } );

    isa_ok( $syncer, 'Test::Smoke::Syncer::Snapshot' );

    is( $syncer->{server}, Test::Smoke::Syncer->config( 'server' ), 
        "ftp server for snapshot" );
}
