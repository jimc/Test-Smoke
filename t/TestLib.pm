package TestLib;
use strict;

use vars qw( $VERSION @EXPORT );
use base 'Exporter';
$VERSION = '0.01';

@EXPORT = qw( 
    &whereis 
    &find_unzip &do_unzip
    &find_untargz &do_untargz
    &get_dir &get_file 
    &rmtree &mkpath
);

use File::Find;
use File::Spec;
require File::Path;
use Cwd;

sub whereis {
    my $prog = shift;
    return undef unless $prog; # you shouldn't call it '0'!

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

sub get_dir($) {
    my( $path ) = @_;
    my @files;
    find sub {
        -f or return;
        (my $name = $File::Find::name ) =~ s/^\Q$path\E//;
        push @files, $name;
    }, $path;

    return @files;
}

sub get_file {
    my $filename = File::Spec->catfile( @_ );

    local *MYFILE;
    my @content;
    if ( open MYFILE, "< $filename" ) {
        @content = <MYFILE>;
        close MYFILE;
    } else {
        warn "(@{[cwd]})$filename: $!";
    }

    return wantarray ? @content : join "", @content;
}

sub rmtree { File::Path::rmtree( @_ ) }
sub mkpath { File::Path::mkpath( @_ ) }

sub find_unzip {
    my $unzip = whereis( 'gzip' );

    my $dounzip = $unzip ? "$unzip -cd " : "";

    unless ( $dounzip ) {
        eval { require Compress::Zlib };
        $dounzip = 'Compress::Zlib' unless $@;
    }

    return $dounzip;
}
        
sub do_unzip {
    my( $unzip, $uzfile ) = @_;
    return undef unless -f $uzfile;

    my $content;
    if ( $unzip eq 'Compress::Zlib' ) {
        require Compress::Zlib;
        my $unzipper = Compress::Zlib::gzopen( $uzfile, 'rb' ) or do {
            require Carp;
            Carp::carp "Can't open '$uzfile': $Compress::Zlib::gzerrno";
            return undef;
        };

        my $buffer;
        $content .= $buffer while $unzipper->gzread( $buffer ) > 0;

        unless ( $Compress::Zlib::gzerrno == Compress::Zlib::Z_STREAM_END() ) {
            require Carp;
            Carp::carp "Error reading '$uzfile': $Compress::Zlib::gzerrno" ;
        }

        $unzipper->gzclose;
    } else {

        # this calls out for `$unzip $uzfile`
        # {unzip} could be like 'zcat', 'gunzip -c', 'gzip -dc'

        $content = `$unzip $uzfile`;
    }

    return $content;

}

sub find_untargz {
    my $tar = whereis( 'tar' );

    my $uncompress = '';
    if ( $tar ) {
        my $zip = whereis( 'gzip' );
        $uncompress = "$zip -cd %s | $tar -xf -" if $zip;
    }

    unless ( $uncompress ) {
        eval { require Archive::Tar; };
        unless ( $@ ) {
            eval { require Compress::Zlib; };
            $uncompress = 'Archive::Tar' unless $@;
        }
    }

    if ( $tar && !$uncompress ) { # try tar by it self
        $uncompress = "$tar -xzf %s";
    }

    return $uncompress;
}

sub do_untargz {
    my( $untgz, $tgzfile ) = @_;

    if ( $untgz eq 'Archive::Tar' ) {
        require Archive::Tar;

        my $archive = Archive::Tar->new() or do {
            warn "Can't Archive::Tar->new: " . $Archive::Tar::error;
            return undef;
        };

        $archive->read( $tgzfile, 1 );
        $Archive::Tar::error and do {
            warn "Error reading '$tgzfile': ".$Archive::Tar::error;
            return undef;
        };
        my @files = $archive->list_files;
        $archive->extract( @files );

    } else { # assume command
        my $command = sprintf $untgz, $tgzfile;
        $command .= " $tgzfile" if $command eq $untgz;

        if ( system $command ) {
            my $error = $? >> 8;
            warn "Error in command: $error";
            return undef;
        };
    }
    return 1;
}

1;
