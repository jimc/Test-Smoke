#! /usr/bin/perl -w
use strict;

# $Id: syncer_rsync.t 1158 2008-01-04 19:33:37Z abeltje $

use Data::Dumper;
use Cwd;
use File::Spec;
use Test::More tests => 33;

use_ok( 'Test::Smoke::Syncer' );

my %df_rsync = (
    rsync => 'rsync',
    source => 'public.activestate.com::perl-current',
    opts   => '-az --delete',
    ddir   => File::Spec->rel2abs( 'perl-current', File::Spec->curdir ),
);

{
    my $sync = eval { Test::Smoke::Syncer->new() };
    ok( !$@, "No error on no type" );
    isa_ok( $sync, 'Test::Smoke::Syncer::Rsync' );
    for my $field (sort keys %df_rsync ) {
        ok( exists $sync->{$field}, "{$field} exists" ) or
            skip "expected {$field} but is not there", 1;
        is( $sync->{$field}, $df_rsync{$field}, "{$field} value" );
    }
}
{
    my %rsync = %df_rsync;
    $rsync{source} = 'ftp.linux.ActiveState.com::perl-current'; 
    $rsync{ddir}   = File::Spec->canonpath( cwd() );
    my $sync = eval { 
        Test::Smoke::Syncer->new( 'rsync', 
            source => $rsync{source},
            -ddir  => $rsync{ddir},
            nonsence => 'who cares',
        ) 
    };
    ok( !$@, "No error on type 'rsync'" );
    isa_ok( $sync, 'Test::Smoke::Syncer::Rsync' );
    for my $field (sort keys %rsync ) {
        ok( exists $sync->{ $field }, "{$field} exists" ) or
            skip "expected {$field} but is not there", 1;
        is( $sync->{ $field }, $rsync{ $field }, 
            "{$field} value $sync->{ $field }" );
    }
}
{
    my %rsync = %df_rsync;
    $rsync{source} = 'ftp.linux.ActiveState.com::perl-current'; 
    $rsync{ddir}   = File::Spec->canonpath( cwd() );
    my $sync = eval { 
        Test::Smoke::Syncer->new( rsync => {
            source => $rsync{source},
            -ddir  => $rsync{ddir},
            nonsense => 'who cares',
        }) 
    };
    ok( !$@, "No errror when options passed as hashref" );
    isa_ok( $sync, 'Test::Smoke::Syncer::Rsync' );
    for my $field (sort keys %rsync ) {
        ok( exists $sync->{ $field }, "{$field} exists" ) or
            skip "expected {$field} but is not there", 1;
        is( $sync->{ $field }, $rsync{ $field }, 
            "{$field} value $sync->{ $field }" );
    }
}

{ # Set the line, helps predicting the error-message :-)
#line 500
    my $sync = eval { Test::Smoke::Syncer->new( 'nogo' ) };
    ok( $@, "Error on unknown type" );
    like( $@, qq|/Invalid sync_type 'nogo' at t.syncer_rsync\.t line 500/|,
        "Error message on unknown type" );
}
