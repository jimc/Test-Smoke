#! /usr/bin/perl -w
use strict;

use Getopt::Long;
use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Test::Smoke::Syncer;

use vars qw( $VERSION );
$VERSION = '0.006';

my %opt = (
    type => 'error',
    ddir => '',
    v    => 0,

    help => 0,
);

my %valid_type = map { $_ => 1 } qw( rsync snapshot copy forest );

=head1 NAME

synctree.pl - Cleanup and sync the perl-current source-tree

=head1 SYNOPSIS

    $ ./synctree.pl -t rsync -d ../perl-current [--help | more options]

=head1 OPTIONS

Options depend on the B<type> option, exept for some.

=over 4

=item * B<General options>

    -d | --ddir <directory>  Set the directory for the source-tree
    -v | --verbose           Be verbose

    -t | --type <type>       'rsync', 'snapshot', 'copy' [mandatory]

=item * B<options for> -t rsync

    --source <rsync-src>     (ftp.linux.activestate.com::perl-current)
    --rsync <path/to/rsync>  (rsync)
    --opts <rsync-opts>      (-az --delete)

=item * B<options for> -t snapshot

    --server <ftp-server>    (ftp.funet.fi)
    --sdir <directory>       (/pub/languages/perl/snap)
    --snapext <ext>          (tgz)
    --tar <un-tar-gz>        (gzip -dc %s | tar -xf -)

    --patchup                patch a snapshot [needs the patch program]
    --pserver <ftp-server>   (ftp2.activestate.com)
    --pdir <directory>       (/pub/staff/gsar/APC/perl-current-diffs)
    --unzip <command>        (gzip -dc)
    --patch <command>        (patch)
    --cleanup <level>        (0) none; (1) snapshot; (2) diffs; (3) both

=item B<options for> -t copy

    --cdir <directory>       Source directory for copy_from_MANIFEST()

=item B<options for> -t forest

    --fsync <synctype>       Master sync-type (One of the above)
    --mdir <directory>       Master directory for primary sync
    --fdir <directory>       Intermediate directory (pass to mktest.pl)
    All options that are needed for the master sync-type

=back

=cut

GetOptions( \%opt,
    'type|t=s', 'ddir|d=s', 'v|verbose+',

    'source=s', 'rsync=s', 'opts',

    'server=s', 'sdir=s', 'snapext=s', 'tar=s',
    'patchup!',  'pserver=s', 'pdir=s', 'unzip=s', 'patch=s', 'cleanup=i',

    'cdir=s',

    'ftype=s', 'fdir=s', 'hdir=s',

    'help|h', 'man|m',
) or do_pod2usage( verbose => 1 );

$opt{man}  and do_pod2usage( verbose => 2, exitval => 0 );
$opt{help} and do_pod2usage( verbose => 1, exitval => 0 );

exists $valid_type{ $opt{type} } or do_pod2usage( verbose => 0 );
$opt{ddir} or do_pod2usage( verbose => 0 );

my $patchlevel;

my $syncer = Test::Smoke::Syncer->new( $opt{type} => \%opt );

$patchlevel = $syncer->sync;

$opt{v} and print "$opt{ddir} now up to patchlevel $patchlevel\n";

##### forest()
#
# This is an idea from Nicholas Clark: $opt{type} eq 'forest'
# set up a master directory for the sourcetree ($opt{f_type})
# Copy the master directory as hardlinks to an intermediate directory
# run the regenheaders.pl script in the intermediate directory
# use this as your sync source and again use hardlinks to set up the
# actual build directory.
# looks like:
#   ./synctree.pl -t forest -d perl -ftype rsync -fdir master590 -hdir tree590
#     * master590/  : rsynced
#     * tree590/    : hardlinks (run regenheaders.pl)
#     * perl/       : hardlinks (from tree590/)
# I still need a way to clean a hardlinked source-tree!
#
#####

sub do_pod2usage {
    eval { require Pod::Usage };
    if ( $@ ) {
        print <<EO_MSG;
Usage: $0 -t <type> -d <directory> [options]

Use 'perldoc $0' for the documentation.
Please install 'Pod::Usage' for easy access to the docs.

EO_MSG
        my %p2u_opt = @_;
        exit( exists $p2u_opt{exitval} ? $p2u_opt{exitval} : 1 );
    } else {
        Pod::Usage::pod2usage( @_ );
    }
}

=head1 SEE ALSO

L<perlhack|"Keeping in sync">, L<Test::Smoke::Syncer>

=head1 COPYRIGHT

(c) 2002, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
