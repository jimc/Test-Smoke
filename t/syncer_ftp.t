#! /usr/bin/perl -w
use strict;

##### syncer_ftp.t
#
# Here we try to test the actual syncing process from a snapshot
# This is done by overriding all the used Net::FTP handlers
# and provide a fake FTP mechanism through them
# For this there is the 't/ftppub' directory with:
#     't/ftppub/snap' contains two fake snapshots (with files)
#     't/ftppub/perl-current-diffs' contains a few fake diffs
# Now that we have controlable FTP (if you have Net::FTP), 
# we can concentrate on doing the untargz and patch stuff
#
#####

use File::Spec;
use File::Path;
use Test::More;

BEGIN {
    eval { require Net::FTP; };
    $@ and plan( skip_all => "No 'Net::FTP' found!\n" . 
                             "!!!You will not be able to smoke from " .
                             "snapshots without it!!!" );
    plan tests => 7;
}

# Can we get away with redefining the Net::FTP stuff?

BEGIN { $^W = 0; } # no warnings 'redefine';
sub Net::FTP::new { bless {}, 'Net::FTP' }
sub Net::FTP::login { return 1 }
sub Net::FTP::binary { return 1 }
sub Net::FTP::quit {return 1 }
sub Net::FTP::cwd { 
    my $self = shift;
    ( my $dir = shift ) =~ s|^.*/||;
    $self->{cwd} = File::Spec->catdir( 't', 'ftppub', $dir );
}
sub Net::FTP::ls { 
    my $self = shift;
    local *DLDIR;
    opendir DLDIR, $self->{cwd} or return ( );
    return grep ! /\.{1,2}$/ => readdir DLDIR;
}
sub Net::FTP::size {
    my $self = shift;
    my $file = File::Spec->catfile( $self->{cwd}, shift );
    return -s $file;
}
sub Net::FTP::get {
    my $self = shift;
    my $source = shift;
    my $file = File::Spec->catfile( $self->{cwd}, $source );
    my $dest = shift || $source;
    local( *SRC, *DST );

    if ( open SRC, "< $file" ) {
        binmode SRC;
        if ( open DST, "> $dest" ) {
            binmode DST;
            print  DST do { local $/; <SRC> };
            close DST;
        } else {
            die "Can't write '$dest': $!";
        }
    } else {
        die "Can't write '$dest': $!";
    }
}
BEGIN { $^W = 1; }

sub whereis {
    my $prog = shift;
    return undef unless $prog; # you shouldn't call it '0'!

    require Config;
    my $p_sep = $Config::Config{path_sep};
    my @path = split /\Q$p_sep\E/, $ENV{PATH};
    my @pext = split /\Q$p_sep\E/, $ENV{PATHEXT} || '';
    unshift @pext, '';

    foreach my $dir ( @path ) {
        foreach my $ext ( @pext ) {
            my $fname = File::Spec->catfile( $dir, "$prog$ext" );
            return $fname if -x $fname;
        }
    }
    return '';
}

# Now begin testing
use_ok( 'Test::Smoke::Syncer' );

SKIP: { # Here we try for 'Archive::Tar'/'Compress::Zlib'

    eval { require Archive::Tar; };
    $@ and skip "Can't load 'Archive::Tar'", 3;

    eval { require Compress::Zlib; };
    $@ and skip "Can't load 'Compress::Zlib'", 3;

    my $syncer = Test::Smoke::Syncer->new( snapshot => { v => 0,
        ddir    => File::Spec->catdir( 't', 'perl-current' ),
        sdir    => '/t/snap',
        tar     => 'Archive::Tar',
        unzip   => 'Compress::Zlib',
        cleanup => 3,
    } );

    isa_ok( $syncer, 'Test::Smoke::Syncer::Snapshot' );

    my $plevel  = $syncer->sync;

    is( $plevel, 20000, "Patchlevel $plevel by $syncer->{tar}" );

    my $plevel2 = $syncer->patch_a_snapshot( $plevel );

    is( $plevel2, 20004, "A patched snapshot $plevel2 by $syncer->{unzip}" );

}

SKIP: { # Here we try for gzip/tar

    my $tar = whereis( 'tar' ) or skip "Can't find a 'tar'", 3;

    my $gzip = whereis( 'gzip' );
    # lets try something...

    my $unpack = $gzip ? "$gzip -dc %s | $tar -xf -" : "$tar -xzf %s";

    $gzip .= " -dc" if $gzip;
    $gzip = whereis( 'gunzip' ) unless $gzip;
    $gzip = whereis( 'zcat' ) unless $gzip;

    my $syncer = Test::Smoke::Syncer->new( snapshot => { v => 0,
        ddir    => File::Spec->catdir( 't', 'perl-current' ),
        sdir    => '/t/snap',
        tar     => $unpack,
        unzip   => $gzip,
        cleanup => 3,
    } );

    isa_ok( $syncer, 'Test::Smoke::Syncer::Snapshot' );

    my $plevel  = $syncer->sync;

    is( $plevel, 20000, "Patchlevel $plevel by $syncer->{tar}" );

    skip "Can't seem to find 'gzip/gunzip/zcat'", 1 unless $gzip;

    my $plevel2 = $syncer->patch_a_snapshot( $plevel );

    is( $plevel2, 20004, "A patched snapshot $plevel2 by $syncer->{unzip}" );

}

# Cleanup testfiles!
my $snapshot = File::Spec->catfile( 't', "perl\@20000.tgz" );
1 while unlink $snapshot;

require File::Path;
File::Path::rmtree( File::Spec->catdir( 't', 'perl-current' ) );
