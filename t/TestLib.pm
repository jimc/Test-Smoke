package TestLib;
use strict;

use vars qw( $VERSION @EXPORT );
use base 'Exporter';
$VERSION = '0.01';

@EXPORT = qw( &whereis &get_dir &rmtree );

use File::Find;
use File::Spec;
require File::Path;

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

sub rmtree { File::Path::rmtree( @_ ) }

1;
