#! /usr/bin/perl -w
use strict;

use Config;
use Cwd;
use File::Spec;
use File::Path;
use Data::Dumper;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );

use Getopt::Long;
my %options = ( config => 'smokeperl_config', jcl => 'mysmoke' );
GetOptions( \%options, 'config|c=s', 'jcl|j=s' );

use vars qw( $VERSION );
$VERSION = '0.005';

=head1 NAME

configsmoke.pl - Create a configuration for B<smokeperl.pl>

=head1 SYNOPSIS

   $ perl configsmoke.pl [options]

=head1 OPTIONS

Current options:

  -c configname When ommited 'smokeperl_config' is used
  -j jclname    When ommited 'mysmoke' is used

=cut

sub is_win32() { $^O eq 'MSWin32' }

my %mailers = get_avail_mailers();
my @mailers = sort keys %mailers;

my %opt = (
    # Destination directory
    ddir => {
        msg => 'Where would you like the new source-tree?',
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-current' ) ),
    },
    use_old => {
        msg => "It looks like there is already a source-tree there.\n" .
               "Should it still be used for smoke testing?",
        alt => [qw( N y )],
        dft => 'n',
    },
    # misc
    cfg => {
        msg => 'Which configuration file would you like to use?',
        alt => [ ],
        dft => File::Spec->rel2abs( is_win32
                                    ? 'smokew32.cfg' : 'smoke.cfg' ),
    },
    umask => {
        msg => 'What umask can be used (0 preferred)?',
        alt => [ ],
        dft => '0',
    },
    renice => {
        msg => "With which value should 'renice' be run " .
               "(leave '0' for no 'renice')?",
        alt => [ 0..20 ],
        dft => 0,
    },
    v => {
        msg => 'How verbose do you want the output?',
        alt => [qw( 0 1 2 )],
        dft => 0,
    },
    # syncing the source-tree
    want_forest => {
        msg => "Would you like the 'Nick Clark' master sync trees?",
        alt => [qw( N y )],
        dft => 'n',
    },
    forest_mdir => {
        msg => 'Where would you like the master source-tree?',
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-master' ) ),
    },
    forest_hdir => {
        msg => 'Where would you like the intermediate source-tree?',
        alt => [ ],
        dft => File::Spec->rel2abs( File::Spec->catdir( File::Spec->updir,
                                                        'perl-inter' ) ),
    },
    fsync => { 
        msg => 'How would you like to sync your master source-tree?',
        alt => [ get_avail_sync() ], 
        dft => 'rsync' 
    },
    sync_type => { 
        msg => 'How would you like to sync your source-tree?',
        alt => [ get_avail_sync() ], 
        dft => 'rsync' 
    },
    source => {
        msg => 'Where would you like to rsync from?',
        alt => [ ],
        dft => 'ftp.linux.activestate.com::perl-current',
    },
    rsync => {
        msg => 'Which rsync program should be used?',
        alt => [ ],
        dft => whereis( 'rsync' ),
    },
    opt => {
        msg => 'Which arguments should be used for rsync?',
        alt => [ ],
        dft => '-az --delete',
    },

    server => {
        msg => 'Where would you like to FTP the snapshots from?',
        alt => [ ],
        dft => 'ftp.funet.fi',
    },

    sdir => {
        msg => 'Which directory should the snapshots be FTPed from?',
        alt => [ ],
        dft => '/pub/languages/perl/snap',
    },

    tar => {
        msg => <<EOMSG,
How should the snapshots be extracted?
Examples:@{[ map "\n\t$_" => get_avail_tar() ] }
EOMSG
        alt => [ ],
        dft => (get_avail_tar())[0],
    },

    snapext => {
        msg => 'What type of snapshots shoul be FTPed?',
        alt => [qw( tgz tbz )],
        dft => 'tgz',
    },

    patchup => {
        msg => 'Would you like to try to patchup your snapshot?',
        alt => [qw( N y ) ],
        dft => 'n',
    },

    pserver => {
        msg => 'Which server would you like the patches FTPed from?',
        alt => [ ],
        dft => 'ftp2.activestate.com',
    },

    pdir => {
        msg => 'Which directory should the patches FTPed from?',
        alt => [ ],
        dft => '/pub/staff/gsar/APC/perl-current-diffs',
    },

    unzip => {
        msg => 'How should the patches be unzipped?',
        alt => [ ],
        dft => whereis( 'gzip' ) . " -cd",
    },

    patch => {
        msg => undef,
        alt => [ ],
        dft => whereis( 'patch' ) . ' -p1',
    },

    cleanup => {
        msg => "Remove applied patch-files?\n" .
               "0(none) 1(snapshot)",
        alt => [qw( 0 1 )],
        dft => 1,
    },

    cdir => {
        msg => 'From which directory should the source-tree be copied?',
        alt => [ ],
        dft => undef,
    },

    # mail stuff
    mail_type => {
        msg => 'Which mail facility should be used?',
        alt => [ @mailers ],
        dft => $mailers[0],
        nocase => 1,
    },
    mserver => {
        msg => 'Which SMTP server should be used to send the report?' .
               "\nLeave empty to use local sendmail",
        alt => [ ],
        dft => 'localhost',
    },

    to => {
       msg => "To which address(es) should the report be send " .
              "(comma separated list)?",
       alt => [ ],
       dft => 'smokers-reports@perl.org',
    },

    cc => {
       msg => "To which address(es) should the report be CC'ed " .
              "(comma separated list)?",
       alt => [ ],
       dft => '',
    },

    from => {
        msg => 'Which address should be used for From?',
        alt => [ ],
        dft => '',
    },
    locale => {
        msg => 'What locale should be used for extra testing ' .
               '(leave empty for none)?',
        alt => [ ],
        dft => '',
    },
);

my %conf;

print <<EOMSG;

Welcome to the Perl core smoke test suite.
You will be asked some questions in order to configure this test suite.

EOMSG

my $arg ='ddir';
BUILDDIR: {
    $conf{ $arg } = prompt_dir( $arg );
    my $cwd = cwd;
    unless ( chdir $conf{ $arg } ) {
        warn "Can't chdir($conf{ $arg }): $!\n";
        redo BUILDDIR;
    }
    my $bdir = $conf{ $arg } = cwd;
    chdir $cwd or die "Can't chdir($cwd) back: $!\n";
    if ( $cwd eq $bdir ) {
        print "The current directory *cannot* be used for smoke testing\n";
        redo BUILDDIR;
    }

    my $manifest  = File::Spec->catfile( $conf{ $arg }, 'MANIFEST' );
    my $dot_patch = File::Spec->catfile( $conf{ $arg }, '.patch' );
    if ( -e $manifest && -e $dot_patch ) {
        my $use_old = lc prompt( 'use_old' );
        redo BUILDDIR unless $use_old eq 'y';
    }
    print "Got [$conf{ $arg }]\n";
}

$arg = 'cfg';
$conf{ $arg } = prompt_file( $arg );
print "Got [$conf{ $arg }]\n";

# Check to see if you want the Nick Clark forest
$arg = 'want_forest';
my $want_forest = lc prompt( $arg );
print "Got [$want_forest]\n";
FOREST: {
    last FOREST unless $want_forest eq 'y';

    $conf{mdir} = prompt_dir( 'forest_mdir' );
    print "Got [$conf{mdir}]\n";

    $conf{fdir} = prompt_dir( 'forest_hdir' );
    print "Got [$conf{fdir}]\n";

    $conf{sync_type} = 'forest';
}

$arg = $want_forest eq 'y' ? 'fsync' : 'sync_type';
$conf{ $arg } = lc prompt( $arg );
print "Got [$conf{ $arg }]\n";
SYNCER: {
    local $_ = $conf{ $arg};
    /^rsync$/ && do {
        $arg = 'source';
        $conf{ $arg } = prompt( $arg );
        print "Got [$conf{ $arg }]\n";
        $arg = 'rsync';
        $conf{ $arg } = prompt( $arg );
        print "Got [$conf{ $arg }]\n";
        $arg = 'opt';
        $conf{ $arg } = prompt( $arg );
        print "Got [$conf{ $arg }]\n";
        last SYNCER;
    };

    /^snapshot$/ && do {
        for $arg ( qw( server sdir tar snapext ) ) {
            $conf{ $arg } = prompt( $arg );
            print "Got [$conf{ $arg }]\n";
        }

        $arg = 'patchup';
        if ( whereis( 'patch' ) ) {
            $conf{ $arg } = lc prompt( $arg ) eq 'y' ? 1 : 0;
            print "Got [$conf{ $arg }]\n";

            if ( $conf{ $arg } ) {
                for $arg (qw( pserver pdir unzip patch )) {
                    $conf{ $arg } = prompt( $arg );
                    print "Got [$conf{ $arg }]\n";
                }
                $opt{cleanup}->{msg} .= " 2(patches) 3(both)";
                $opt{cleanup}->{alt}  = [0, 1, 2, 3];
            }
	} else {
	    $conf{ $arg } = 0;
        }
        $arg = 'cleanup';
        $conf{ $arg } = prompt( $arg );
        print "Got [$conf{$arg}]\n";
        last SYNCER;
    };

    /^copy$/ && do {
        $arg = 'cdir';
        $conf{ $arg } = prompt( $arg );
        print "Got [$conf{ $arg }]\n";
        last SYNCER;
    };
}

my @locale_utf8 = check_locale();
if ( @locale_utf8 ) {

    my $list = join " |", @locale_utf8;
    format STDOUT =
^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<~~
$list
.
    local $: = "|";
    $arg = 'locale';
    print "\nI found these UTF-8 locales:\n";
    write;
    $conf{ $arg } = prompt( $arg );
    print "Got [$conf{ $arg }]\n";
}

MAIL: {
    $arg = 'mail_type';
    $conf{ $arg } = prompt( $arg );
    print "Got [$conf{ $arg }]\n";

    $arg = 'to';
    while ( !$conf{ $arg } ) { $conf{ $arg } = prompt( $arg ) }
    print "Got [$conf{ $arg }]\n";

    MAILER: {
        local $_ = $conf{ 'mail_type' };

        /^mailx?$/         && do { last MAILER };
        /^sendmail$/       && do {
            $arg = 'from';
            $conf{ $arg } = prompt( $arg );
            print "Got [$conf{ $arg }]\n";
	};

        /^Mail::Sendmail$/ && do {
            $arg = 'from';
            $conf{ $arg } = prompt( $arg );
            print "Got [$conf{ $arg }]\n";

            $arg = 'mserver';
            $conf{ $arg } = prompt( $arg );
            print "Got [$conf{ $arg }]\n";
        };
    }
    $arg = 'cc';
    $conf{ $arg } = prompt( $arg );
    print "Got [$conf{ $arg }]\n";
}

WIN32: {
    last WIN32 unless is_win32;

    my $osvers = get_Win_version();
    my %compilers = get_avail_w32compilers();

    $opt{w32compiler} = {
        msg => 'What compiler should be used?',
        alt => [ keys %compilers ],
        dft => ( sort keys %compilers )[-1],
    };

    print <<EO_MSG;

I see you are on $^O ($osvers).
No problem, but we need extra information.

EO_MSG

    my $w32compiler = prompt( 'w32compiler' );
    print "Got [$w32compiler]\n";

    $opt{w32maker} = {
        alt => $compilers{ $w32compiler }->{maker},
        dft => ( sort @{ $compilers{ $w32compiler }->{maker} } )[-1],
    };
    $opt{w32maker}->{msg} = @{ $compilers{ $w32compiler }->{maker} } > 1 
        ? "Which make should be used" : undef;

    my $w32maker = prompt( 'w32maker' );
    print "Got [$w32maker]\n";

    $conf{w32args} = [ 
        "--win32-cctype", $w32compiler,
        "--win32-maker",  $w32maker,
        "osvers=$osvers", $compilers{ $w32compiler }->{ccversarg},
    ];
}

# Some unixy stuff...
my( $umask, $renice );
unless ( is_win32 ) {
    $umask = prompt( 'umask' );
    print "Got [$umask]\n";

    $renice = prompt( 'renice' );
    print "Got [$renice]\n";
}

$arg = 'v';
$conf{ $arg } = prompt( $arg );
print "Got [$conf{ $arg}]\n";

SAVEALL: {
    save_config();
    if ( is_win32 ) {
        write_bat();
    } else {
        write_sh();
    }
}

sub save_config {
    local *CONFIG;
    open CONFIG, "> $options{config}" or
        die "Cannot write '$options{config}': $!";
    print CONFIG Data::Dumper->Dump( [\%conf], ['conf'] );
    close CONFIG or warn "Error writing '$options{config}': $!" and return;

    print "Finished writing '$options{config}'\n";
}

sub write_sh {
    my $cwd = cwd();
    my $jcl = "$options{jcl}.sh";
    local *MYSMOKESH;
    open MYSMOKESH, "> $jcl" or
        die "Cannot write '$jcl': $!";
    print MYSMOKESH <<EO_SH;
#! /bin/sh
#
# Written by $0 v$VERSION
# @{[ scalar localtime ]}
#
@{[ renice( $renice ) ]}
cd $cwd
PATH=$cwd:$ENV{PATH}
umask $umask
./smokeperl.pl -c $options{config} > perlsmoke.log 2>&1
EO_SH
    close MYSMOKESH or warn "Error writing '$jcl': $!";

    chmod 0755, $jcl or warn "Cannot chmod 0755 $jcl: $!";
    print "Finished writing '$jcl'\n";
}

sub write_bat {
    my $cwd = File::Spec->canonpath( cwd() );
    my $jcl = "$options{jcl}.cmd";
    local *MYSMOKEBAT;
    open MYSMOKEBAT, "> $jcl" or
        die "Cannot write '$jcl': $!";
    print MYSMOKEBAT <<EO_BAT;
\@echo off

REM Written by $0 v$VERSION
REM @{[ scalar localtime ]}


REM Uncomment next line for scheduled run every day at 22:25
REM at 22:25 /EVERY:M,T,W,Th,F,S,Su $cwd\\$jcl

set WD=$cwd\
cd \%WD\%
set OLD_PATH=\%PATH\%
set PATH=$cwd;\%PATH\%
$^X smokeperl.pl -c $options{config} > \%WD\%perlsmoke.log 2>&1
set PATH=\%OLD_PATH\%
set WD=
EO_BAT
    close MYSMOKEBAT or warn "Error writing '$jcl': $!";

    print "Finished writing '$jcl'\n";
}

sub prompt {
    my( $message, $alt, $df_val ) = @{ $opt{ $_[0] } }{qw( msg alt dft )};

    return $df_val unless defined $message;
    $message =~ s/\s+$//;

    my $default = defined $df_val ? $df_val : 'undef';
    my $alts    = @$alt ? "<" . join( "|", @$alt ) . "> " : "";
    print "\n$message\n";

    my %ok_val;
    %ok_val = map { (lc $_ => 1) } @$alt if @$alt;
    my $input;
    INPUT: {
        print "$alts\[$default] \$ ";
        chomp( $input = <STDIN> );
        $input =~ s/^\s+//;
        $input =~ s/\s+$//;
        $input = $df_val unless length $input;

        last INPUT unless %ok_val;
        printf "Expected one of: '%s'\n", join "', '", @$alt and redo 
             unless exists $ok_val{ lc $input };
    }

    return length $input ? $input : $df_val;
}

sub prompt_dir {

    GETDIR: {
        my $dir = prompt( @_ );

        # thaks to perlfaq5
        $dir =~ s{^ ~ ([^/]*)}
                 {$1 ? ( getpwnam $1 )[7] : 
                       ( $ENV{HOME} || $ENV{LOGDIR} || 
                         "$ENV{HOMEDRIVE}$ENV{HOMEPATH}" )}ex;
        my $cwd = cwd();
        $dir = File::Spec->abs2rel( $dir, $cwd )
            if File::Spec->file_name_is_absolute( $dir );
        $dir = File::Spec->rel2abs( $dir);

        File::Path::mkpath( $dir, 1, 0755 ) unless -d $dir;

        print "$dir is not a directory or cannot be created: $!\n" and redo
	    unless -d $dir;

        return $dir;
    }
}

sub prompt_file {

    GETFILE: {
        my $file = prompt( @_ );

        # thaks to perlfaq5
        $file =~ s{^ ~ ([^/]*)}
                  {$1 ? ( getpwnam $1 )[7] : ( $ENV{HOME} || $ENV{LOGDIR} )}ex;
        $file = File::Spec->rel2abs( $file );

        print "'$file' does not exist: $!\n" and redo
	    unless -f $file;

        return $file;
    }
}

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

sub renice {
    my $rn_val = shift;

    return $rn_val ? <<EORENICE : <<EOCOMMENT
# Run renice:
(renice -n $rn_val \$$ >/dev/null 2>&1) || (renice $rn_val \$$ >/dev/null 2>&1)
EORENICE
# Uncomment this to be as nice as possible. (Jarkko)
# (renice -n 20 \$$ >/dev/null 2>&1) || (renice 20 \$$ >/dev/null 2>&1)
EOCOMMENT

}

sub get_avail_sync {

    my @synctype = ( 'copy' );
    eval { require Net::FTP };
    unshift @synctype, 'snapshot' unless $@;
    unshift @synctype, 'rsync' if whereis( 'rsync' );
    return @synctype;
}

sub get_avail_tar {

    my $use_modules = 0;
    eval { require Archive::Tar };
    unless ( $@ ) {
        eval { require Compress::Zlib };
        $use_modules = !$@;
    }

    my $fmt = tar_fmt();

    return $fmt && $use_modules 
        ? ( $fmt, 'Archive::Tar' )
        : $fmt ? ( $fmt ) : $use_modules ? ( 'Archive::Tar' ) : ();
    
}

sub tar_fmt {
    my $tar  = whereis( 'tar' );
    my $gzip = whereis( 'gzip' );

    return $tar && $gzip 
        ? "$gzip -cd %s | $tar -xf -"
        : $tar ? "tar -xzf %s" : "";
}

sub check_locale {
    # I only know one way...
    my $locale = whereis( 'locale' );
    return 0 unless $locale;
    return grep /utf-?8$/i => split /\n/, `$locale -a`;
}

sub get_avail_mailers {
    my %map;
    my $mailer = 'mail';
    $map{ $mailer } = whereis( $mailer );
    $mailer = 'mailx';
    $map{ $mailer } = whereis( $mailer );
    {
        $mailer = 'sendmail';
        local $ENV{PATH} = "$ENV{PATH}$Config{path_sep}/usr/sbin";
        $map{ $mailer } = whereis( $mailer );
    }

    eval { require Mail::Sendmail; };
    $map{ 'Mail::Sendmail' } = $@ ? '' : 'Mail::Sendmail';

    return map { ( $_ => $map{ $_ }) } grep length $map{ $_ } => keys %map;
}
        
sub get_avail_w32compilers {

    my %map = (
        MSVC => { ccname => 'cl',    maker => [ 'nmake' ] },
        BCC  => { ccname => 'bcc32', maker => [ 'dmake' ] },
        GCC  => { ccname => 'gcc',   maker => [ 'dmake' ] },
    );

    my $CC = 'MSVC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        # No, cl doesn't support --version (One can but try)
        my $output =`"$map{ $CC }->{ccbin}" --version 2>&1`;
        my $ccvers = $output =~ /^.*Version\s+([\d.]+)/ ? $1 : '?';
        $map{ $CC }->{ccversarg} = "ccversion=$ccvers";
        my $mainvers = $ccvers =~ /^(\d+)/ ? $1 : 1;
        $map{ $CC }->{CCTYPE} = $mainvers < 12 ? 'MSVC' : 'MSVC60';
    }

    $CC = 'BCC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        # No, bcc32 doesn't support --version (One can but try)
        my $output = `"$map{ $CC }->{ccbin}" --version 2>&1`;
        my $ccvers = $output =~ /(\d+.*)/ ? $1 : '?';
        $ccvers =~ s/\s+copyright.*//i;
        $map{ $CC }->{ccversarg} = "ccversion=$ccvers";
        $map{ $CC }->{CCTYPE} = 'BORLAND';
    }

    $CC = 'GCC';
    if ( $map{ $CC }->{ccbin} = whereis( $map{ $CC }->{ccname} ) ) {
        local *STDERR;
        open STDERR, ">&STDOUT"; #do we need an error?
        select( (select( STDERR ), $|++ )[0] );
        my $output = `"$map{ $CC }->{ccbin}" --version`;
        my $ccvers = $output =~ /(\d+.*)/ ? $1 : '?';
        $ccvers =~ s/\s+copyright.*//i;
        $map{ $CC }->{ccversarg} = "gccversion=$ccvers";
        $map{ $CC }->{CCTYPE} = $CC
    }

    return map {
       ( $map{ $_ }->{CCTYPE} => $map{ $_ } )
    } grep length $map{ $_ }->{ccbin} => keys %map;
}

sub get_Win_version {
    my @osversion = Win32::GetOSVersion();

    my $win_version = join '.', @osversion[ 1, 2 ];
    $win_version .= " $osversion[0]" if $osversion[0];

    return $win_version;
}

=head1 TODO

Use the values in the configfile if it already exists as defaults

=head1 COPYRIGHT

(c) 2002, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
