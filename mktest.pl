#!/usr/bin/perl -w

# Smoke test for perl-current
# (c)'01 H.Merijn Brand [27 August 2001]
#    and Nicholas Clark
# 09092002: Abe Timmerman
# REVISION: 1.05
use strict;

sub usage ()
{
    print STDERR "usage: mktest.pl [options] [<smoke.cfg>]\n";
    exit 1;
    } # usage

@ARGV == 1 and $ARGV[0] eq "-?" || $ARGV[0] =~ m/^-+help$/ and usage;

use Config;
use Cwd;
use Getopt::Long;
use File::Find;
use Text::ParseWords;

my %win32_makefile_map = (
    nmake => "Makefile",
    dmake => "makefile.mk",
    );
my $win32_cctype = "MSVC60"; # 2.0 => MSVC20; 5.0 => MSVC; 6.0 => MSVC60
my $win32_maker  = $Config{make};
my $smoker       = $Config{cf_email};

=head1 NAME

mktest.pl - Configure, build and test bleading edge perl

=head1 SYNOPSIS

    $ ./mktest.pl [options] smoke.cfg

=head1 OPTIONS

=over

=item * -n | --norun | --dry-run

=item * -v | --verbose [ level ]

=item * -m | --win32-maker <dmake | nmake>

=item * -c | --win32-cctype <BORLAND | GCC | MSVC20 | MSVC | MSVC60>

=item * -s | --smoker <your-email-address>

=back

All remaining arguments in C<@ARGV> are used for B<MSWin32> to
tweak values in Config.pm and should be C<< key=value >> pairs.

=head1 METHODS

=over

=cut

my $norun   = 0;
my $verbose = 0;
GetOptions (
    "n|norun|dry-run"  => \$norun,
    "v|verbose:i"      => \$verbose,	# NYI
    "m|win32-maker=s"  => \$win32_maker,
    "c|win32-cctype=s" => \$win32_cctype,
    "s|smoker=s"       => \$smoker,
    ) or usage;
my $config_file = shift;
# All remaining stuff in @ARGV is used by Configure_win32()
# They are appended to the CFG_VARS macro
# This is a way to cheat in Win32 and get the "right" stuff into Config.pm

open TTY,    ">&STDERR";	select ((select (TTY),    $| = 1)[0]);
open STDERR, ">&1";		select ((select (STDERR), $| = 1)[0]);
open OUT,    "> mktest.out";	select ((select (OUT),    $| = 1)[0]);
				select ((select (STDOUT), $| = 1)[0]);

=item is_win32( )

C<is_win32()> returns true if  C<< $^O eq "MSWin32" >>.

=cut

sub is_win32 ()
{
    $^O eq "MSWin32";
    } # is_win32

=item run( $command[, $sub] )

C<run()> returns C<< qx( $command ) >> unless C<$sub> is specified.
If C<$sub> is defined (and a coderef) C<< $sub->( $command ) >> will 
be called.

=cut

# Run a system command or a perl subroutine, unless -n was flagged.
sub run ($;$)
{
    my ($command, $sub) = @_;
    $norun       and
	return print TTY "$command\n";

    defined $sub and
	return &$sub ($command);

    return qx($command);
    } # run

=item make( $command )

C<make()> calls C<< run( "make $command" ) >>, and does some extra
stuff to help MSWin32 (the right maker, the directory).

=cut

sub make ($)
{
    my $cmd = shift;

    is_win32 or return run "make $cmd";

    my $kill_err;
    # don't capture STDERR
    $cmd =~ s{2\s*>\s*/dev/null\s*$}{} and $kill_err = 1;
    # Better detection of make vs. nmake vs. dmake required here
    # dmake + MSVC5, make + DJGPP, make + Cygwin, nmake + MSVC6
    $cmd = "$win32_maker -f smoke.mk $cmd";
    chdir "win32" or die "unable to chdir () into 'win32'";
    run ($kill_err ? qq{$^X -e "close STDERR; system '$cmd'"} : $cmd);
    chdir ".." or die "unable to chdir() out of 'win32'";
    } #make

=item ttylog( @message )

C<ttylog()> prints C<@message> to both STDOUT and the logfile.

=cut

sub ttylog (@)
{
    print TTY @_;
    print OUT @_;
    } # ttylog

my @config;
$config_file = get_cfg_filename( $config_file );
if (defined $config_file) {
    open CONF, "< $config_file" or die "Can't open '$config_file': $!";
    my @conf;
    my @target;
    # Cheat. Force a break marker as a line after the last line.
    foreach (<CONF>, "=") {
	m/^#/ and next;
	s/\s+$// if m/\s/;	# Blanks, new-lines and carriage returns. M$
	if (m:^/:) {
	    m:^/(.*)/$:;
	    defined $1 or die "Policy target line didn't end with '/': '$_'";
	    push @target, $1;
	    next;
	    }

	if (!m/^=/) {
	    # Not a break marker
	    push @conf, $_;
	    next;
	    }

	# Break marker, so process the lines we have.
	if (@target > 1) {
	    warn "Multiple policy target lines " .
		join (", ", map {"'$_'"} @target) . " - will use first";
	    }
	my %conf = map { $_ => 1 } @conf;
	if (keys %conf == 1 and exists $conf{""} and !@target) {
	    # There are only blank lines - treat it as if there were no lines
	    # (Lets people have blank sections in configuration files without
	    #  warnings.)
	    # Unless there is a policy target.  (substituting ''  in place of
	    # target is a valid thing to do.)
	    @conf = ();
	    }
	unless (@conf) {
	    # They have no target lines
	    @target and
		warn "Policy target '$target[0]' has no configuration lines, ".
		     "so it will not be used";
	    @target = ();
	    next;
	    }

	while (my ($key, $val) = each %conf) {
	    $val > 1 and warn "Configuration line '$key' duplicated $val times";
	    }
	my $args = [@conf];
	@conf = ();
	if (@target) {
	    push @config, { policy_target => $target[0], args => $args };
	    @target = ();
	    next;
	    }

	push @config, $args;
	}
    }
else {
    @config = (
	[ "",
	  "-Dusethreads -Duseithreads"
	  ],
	[ "-Uuseperlio",
	  "-Duseperlio",
	  "-Duseperlio -Duse64bitint",
	  "-Duseperlio -Duse64bitall",
	  "-Duseperlio -Duselongdouble",
	  "-Duseperlio -Dusemorebits",
	  "-Duseperlio -Duse64bitall -Duselongdouble"
	  ],
	{ policy_target =>       "-DDEBUGGING",
	  args          => [ "", "-DDEBUGGING" ]
	  },
	);
    }

my $testdir = getcwd;

exists $Config{ldlibpthname} && $Config{ldlibpthname} and
    $ENV{$Config{ldlibpthname}} ||= '',
    substr ($ENV{$Config{ldlibpthname}}, 0, 0) = "$testdir$Config{path_sep}";

my $patch;
if (open OK, "<.patch") {
    chomp ($patch = <OK>);
    close OK;
    print OUT "Smoking patch $patch\n\n";
    }
if (!$patch and open OK, "< patchlevel.h") {
    local $/ = undef;
    ($patch) = (<OK> =~ m/^\s+,"DEVEL(\d+)"\s*$/m);
    close OK;
    print OUT "Smoking patch $patch(+)\n\n";
    }

if (open MANIFEST, "< MANIFEST") {
    # I've done no tests yet, and I've been started after the rsync --delete
    # Now check if I'm in sync
    my %MANIFEST = ( ".patch" => 1, map { s/\s.*//s; $_ => 1 } <MANIFEST>);
    find (sub {
	-d and return;
	m/^mktest\.(log|out)$/ and return;
	my $f = $File::Find::name;
	$f =~ s:^$testdir/?::;
	if (exists $MANIFEST{$f}) {
	    delete $MANIFEST{$f};
	    return;
	    }
	$MANIFEST{$f} = 0;
	}, $testdir);
    foreach my $f (sort keys %MANIFEST) {
	ttylog "MANIFEST ",
	    ($MANIFEST{$f} ? "still has" : "did not declare"), " $f\n";
	}
    }

my $Policy = -f "../Policy.sh" && -r _
    ? do {
	local ($/, *POL);
	open POL, "<../Policy.sh" or die "../Policy.sh: $!";
	<POL>;
	}
    : join "", <DATA>;

my @p_conf = ("", "");

run_tests (\@p_conf, $Policy, "-Dusedevel", [], @config);

close OUT;

sub run_tests
{
    # policy.sh
    # configuration command line built up so far
    # hash of substitutions in Policy.sh (mostly cflags)
    # array of things still to test (in @_ ?)

    my ($p_conf, $policy, $old_config_args, $substs, $this_test, @tests) = @_;

    # $this_test is either
    # [ "", "-Dthing" ]
    # or
    # { policy_target => "-DDEBUGGING", args => [ "", "-DDEBUGGING" ] }

    my $policy_target;
    if (ref $this_test eq "HASH") {
	$policy_target = $this_test->{policy_target};
	$this_test     = $this_test->{args};
	}

    foreach my $conf (@$this_test) {
	my $config_args = $old_config_args;
	# Try not to add spurious spaces as it confuses mkovz.pl
	length $conf and $config_args .= " $conf";
	my @substs = @$substs;
	if (defined $policy_target) {
	    # This set of permutations also need to subst inside Policy.sh
	    # somewhere.
	    push @substs, [$policy_target, $conf];
	    }

	if (@tests) {
	    # Another level of tests
	    run_tests ($p_conf, $policy, $config_args, \@substs, @tests);
	    next;
	    }

	# No more levels to expand
	my $s_conf = join "\n" => "", "Configuration: $config_args",
				  "-" x 78, "";

	# Skip officially unsupported combo's
	$config_args =~ m/-Uuseperlio/ && $config_args =~ m/-Dusethreads/
	    and next; # patch 17000

	ttylog $s_conf;

	# You can put some optimizations (skipping configurations) here
	if ( $^O =~ m/^(?: hpux | freebsd )$/x &&
	     $config_args =~ m/longdouble|morebits/) {
	    # longdouble is turned off in Configure for hpux, and since
	    # morebits is the same as 64bitint + longdouble, these have
	    # already been tested. FreeBSD does not support longdoubles
	    # well enough for perl (eg no sqrtl)
	    ttylog " Skipped this configuration for this OS (duplicate test)\n";
	    next;
	    }

	print TTY "Make distclean ...";
	make "-i distclean 2>/dev/null";

	print TTY "\nCopy Policy.sh ...";

	# Turn the array of instructions on what to substitute into one or
	# more regexps. Initially we have a list of target/value pairs.
	my %substs;
	# First group all the values by target.
	foreach (@substs) {
	    push @{$substs{$_->[0]}}, $_->[1];
	    }
	# use Data::Dumper; print Dumper (\@substs, \%substs);
	# Then for each target do the substitution.
	# If more than 1 value wishes to substitute, join them with spaces
	my $this_policy = $policy;
	while (my ($target, $values) = each %substs) {
	    unless ($this_policy =~ s/$target/join " ", @$values/seg) {
		warn "Policy target '$target' failed to match";
		}
	    }

	if ($norun) {
	    print TTY $this_policy;
	    }
	else {
	    unlink "Policy.sh";
	    local *POL;
	    open   POL, "> Policy.sh";
	    print  POL $this_policy;
	    close  POL;
	    }

	print TTY "\nConfigure ...";
	run "./Configure $config_args -des", 
            is_win32 ? \&Configure_win32 : undef;

	unless ($norun or (is_win32 ? -f "win32/smoke.mk"
				    : -f "Makefile" && -s "config.sh")) {
	    ttylog " Unable to configure perl in this configuration\n";
	    next;
	    }

	print TTY "\nMake headers ...";
	make "regen_headers";

	print TTY "\nMake ...";
	make " ";

	my $perl = "perl$Config{_exe}";
	unless ($norun or (-s $perl && -x _)) {
	    ttylog " Unable to make perl in this configuration\n";
	    next;
	    }

	$norun or unlink "t/$perl";
	make "test-prep";
	unless ($norun or is_win32 ? -f "t/$perl" : -l "t/$perl") {
	    ttylog " Unable to test perl in this configuration\n";
	    next;
	    }

	print TTY "\n Tests start here:\n";

	foreach my $perlio (qw(stdio perlio)) {
	    $ENV{PERLIO} = $perlio;
	    $ENV{PERLIO} .= " :crlf" if $^O eq "MSWin32";
	    ttylog "PERLIO = $ENV{PERLIO}\t";

	    if ($norun) {
		ttylog "\n";
		next;
		}

	    #FIXME kludge
	    if (is_win32) {
		chdir "win32" or die "unable to chdir () into 'win32'";
		# Same as in make ()
		open TST, "$win32_maker -f smoke.mk test |";
		chdir ".." or die "unable to chdir () out of 'win32'";
		}
	    else {
		local $ENV{PERL} = "./perl";
		open TST, "make _test |";
		}

	    my @nok = ();
	    select ((select (TST), $| = 1)[0]);
	    while (<TST>) {
		skip_filter( $_ ) and next;

		# make mkovz.pl's life easier
		s/(.)(PERLIO\s+=\s+\w+)/$1\n$2/;

		if (m/^u=.*tests=/) {
		    s/(\d\.\d*) /sprintf "%.2f ", $1/ge;
		    print OUT;
		    }
		else {
		    push @nok, $_;
		    }
		print;
		}
	    print OUT map { "    $_" } @nok;
	    if (grep m/^All tests successful/, @nok) {
		print TTY "\nOK, archive results ...";
		$patch and $nok[0] =~ s/\./ for .patch = $patch./;
		}
	    else {
		my @harness;
		for (@nok) {
		    m|^(?:\.\.[\\/])?(\w+/[-\w/]+).*| or next;
		    # Remeber, we chdir into t, so -f is false for op/*.t etc
		    push @harness, (-f "$1.t") ? "../$1.t" : "$1.t";
		    }
		if (@harness) {
		    local $ENV{PERL_SKIP_TTY_TEST} = 1;
		    print TTY "\nExtending failures with Harness\n";
		    my $harness = is_win32 ?
			join " ", map { s{^\.\.[/\\]}{};
					m/^(?:lib|ext)/ and $_ = "../$_";
					$_ } @harness :
			"@harness";
		    ttylog "\n",
			grep !m:\bFAILED tests\b: &&
			    !m:% okay$: => run "./perl t/harness $harness";
		    }
		}
	    print TTY "\n";
	    }
	}
    } # run_tests

=item Configure_win32( $command )

C<Configure_win32()> alters the settings of the makefile for MSWin32.
It supports these options:

=over

=item * B<-Duseperlio>

set USE_PERLIO = define (default)

=item * B<-Dusethreads>

set USE_ITHREADS = define (also sets USE_MULTI and USE_IMP_SYS)

=item * B<-Duseithreads>: set USE_ITHREADS = define

set USE_ITHREADS = define (also sets USE_MULTI and USE_IMP_SYS)

=item * B<-Dusemultiplicity>

sets USE_MULTI = define (also sets USE_ITHREADS and USE_IMP_SYS)

=item * B<-Duseimpsys>

sets USE_IMP_SYS = define (also sets USE_ITHREADS and USE_MULTI)

=item * B<-DDEBUGGING>

sets CFG = Debug

=item * B<-DINST_DRV=...>

sets INST_DRV to a new value (default is "c:")

=item * B<-DINST_TOP=...>

sets INST_DRV to a new value (default is "$(INST_DRV)\perl")

=back

=cut

sub Configure_win32 {
    my $command = shift;

    local $_;
    my %opt_map = (
	"-Dusethreads"		=> "USE_ITHREADS",
	"-Duseithreads"		=> "USE_ITHREADS",
	"-Duseperlio"		=> "USE_PERLIO",
	"-Dusemultiplicity"	=> "USE_MULTI",
	"-Duseimpsys"		=> "USE_IMP_SYS",
	"-DDEBUGGING"		=> "USE_DEBUGGING",
        "-DINST_DRV"            => "INST_DRV",
        "-DINST_TOP"            => "INST_TOP",
        "-DINST_VER"            => "INST_VER",
        "-DINST_ARCH"           => "INST_ARCH",
        "-Dcf_email"            => "EMAIL",
        "-DCCTYPE"              => "CCTYPE",
        "-Dgcc_v3_2"            => "USE_GCC_V3_2",
        "-DCCHOME"              => "CCHOME",
        "-DCRYPT_SRC"           => "CRYPT_SRC",
        "-DCRYPT_LIB"           => "CRYPT_LIB",
    );
    my %opts = (
	USE_MULTI	=> 0,
	USE_ITHREADS	=> 0,
	USE_IMP_SYS	=> 0,
	USE_PERLIO	=> 1, # useperlio should be the default!
	USE_DEBUGGING	=> 0,
        INST_DRV        => 'C:',
        INST_TOP        => '$(INST_DRV)\perl',
        INST_VER        => '',
        INST_ARCH       => '',
        EMAIL           => $smoker,
        CCTYPE          => $win32_cctype,
        USE_GCC_V3_2    => 0,
        CCHOME          => '',
        CRYPT_SRC       => '',
        CRYPT_LIB       => '',
    );
    my @w32_opts = grep ! /^USE_/, keys %opts;
    my $config_args = join " ", 
        grep /^-D[a-z_]+/, quotewords( '\s+', 1, $command );
    push @ARGV, "config_args=$config_args";

    ttylog $command;
    $command =~ m{^\s*\./Configure\s+(.*)} or die "unable to parse command";
    foreach (split " ", $1) {
	m/^-[des]{1,3}$/ and next;
	m/^-Dusedevel$/  and next;
        my( $option, $value ) = /^(-D\w+)(?:=(.+))?$/;
	die "invalid option '$_'" unless exists $opt_map{$option};
	$opts{$opt_map{$option}} = $value ? $value : 1;
    }

    # If you set one, we do all, so you can have fork()
    if ( $opts{USE_MULTI} || $opts{USE_ITHREADS} || $opts{USE_IMP_SYS} ) {
        $opts{USE_MULTI} = $opts{USE_ITHREADS} = $opts{USE_IMP_SYS} = 1;
    }

    # If you -Dgcc_v3_2 you 'll *want* CCTYPE = GCC
    $opts{CCTYPE} = "GCC" if $opts{USE_GCC_V3_2};

    local (*ORG, *NEW);
    my $in =  "win32/$win32_makefile_map{ $win32_maker }";
    my $out = "win32/smoke.mk";

    open ORG, "< $in"  or die "unable to open '$in': $!";
    open NEW, "> $out" or die "unable to open '$out': $!";
    my $donot_change = 0;
    while (<ORG>) {
        if ( $donot_change ) {
            if (m/^\s*CFG_VARS\s*=/) {
                my $extra_char = $win32_maker =~ /\bnmake\b/ ? "\t" : "~";
                $_ .= join "", map "\t\t$_\t${extra_char}\t\\\n", @ARGV;
            }
            print NEW $_;
            next;
        } else {
            $donot_change = /^#+ CHANGE THESE ONLY IF YOU MUST #+$/;
        }

        if ( m/^\s*#?\s*(USE_\w+)(\s*\*?=\s*define)$/ ) {
            $_ = ($opts{$1} ? "" : "#") . $1 . $2 . "\n";
        } elsif (m/^\s*#?\s*(CFG\s*\*?=\s*Debug)$/) {
            $_ = ($opts{USE_DEBUGGING} ? "" : "#") . $1 . "\n";
        } elsif (m/^\s*CFG_VARS\s*=/) {
            my $extra_char = $win32_maker =~ /\bnmake\b/ ? "\t" : "~";
            $_ .= join "", map {
                "\t\t$_\t${extra_char}\t\\\n"
            } @ARGV;
        } else {
            foreach my $cfg_var ( @w32_opts ) {
                if (  m/^\s*#?\s*($cfg_var\s*\*?=)\s*(.*)$/ ) {
                    $_ =  $opts{ $cfg_var } ?
                        "$1 $opts{ $cfg_var }\n":
                        "#$1 $2\n";
                    last;
                }
            }
        }
	print NEW $_;
    }
    close ORG;
    close NEW;
} # Configure_win32

=item get_cfg_filename( )

C<get_cfg_filename()> tries to find a B<cfg file> and returns it.

=cut

sub get_cfg_filename {
    my( $cfg_name ) = @_;
    return $cfg_name if defined $cfg_name && -f $cfg_name;

    my( $base_dir ) = ( $0 =~ m|^(.*)/| ) || File::Spec->curdir;
    $cfg_name = File::Spec->catfile( $base_dir, 'smoke.cfg' );
    return $cfg_name  if -f $cfg_name && -s _;

    $base_dir = File::Spec->curdir;
    $cfg_name = File::Spec->catfile( $base_dir, 'smoke.cfg' );
    return $cfg_name if -f $cfg_name && -s _;

    return undef;
}

=item skip_filter( $line )

C<skip_filter()> returns true if the filter rules apply to C<$line>.

=cut

sub skip_filter {
    local( $_ ) = @_;
    # Still to be extended
    return m,^ *$, ||
    m,^	AutoSplitting, ||
    m,^\./miniperl , ||
    m,^\s*autosplit_lib, ||
    m,^\s*PATH=\S+\s+./miniperl, ||
    m,^	Making , ||
    m,^make\[[12], ||
    m,make( TEST_ARGS=)? (_test|TESTFILE=|lib/\w+.pm), ||
    m,^make:.*Error\s+\d, ||
    m,^\s+make\s+lib/, ||
    m,^ *cd t &&, ||
    m,^if \(true, ||
    m,^else \\, ||
    m,^fi$, ||
    m,^lib/ftmp-security....File::Temp::_gettemp: Parent directory \((\.|/tmp/)\) is not safe, ||
    m,^File::Temp::_gettemp: Parent directory \((\.|/tmp/)\) is not safe, ||
    m,^ok$, ||
    m,^[-a-zA-Z0-9_/]+\.*(ok|skipping test on this platform)$, ||
    m,^(xlc|cc_r) -c , ||
    m,^\s+$testdir/, ||
    m,^sh mv-if-diff\b, ||
    m,File \S+ not changed, ||
    # cygwin
    m,^dllwrap: no export definition file provided, ||
    m,^dllwrap: creating one. but that may not be what you want, ||
    m,^(GNUm|M)akefile:\d+: warning: overriding commands for target `perlmain.o', ||
    m,^(GNUm|M)akefile:\d+: warning: ignoring old commands for target `perlmain.o', ||
    m,^\s+CCCMD\s+=\s+, ||
    # Don't know why BSD's make does this
    m,^Extracting .*with variable substitutions, ||
    # Or these
    m,cc\s+-o\s+perl.*perlmain.o\s+lib/auto/DynaLoader/DynaLoader\.a\s+libperl\.a, ||
    m,^\S+ is up to date, ||
    m,^(   )?### , ||
    # Clean up Win32's output
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*ok$, ||
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*ok\,\s+\d+/\d+\s+skipped:, ||
    m,^(?:\.\.[/\\])?[\w/\\-]+\.*skipped[: ], ||
    m,^\t?x?copy , ||
    m,\d+\s+[Ff]ile\(s\) copied, ||
    m,\.\.[/\\](?:mini)?perl\.exe ,||
    m,^\t?cd , ||
    m,^\b[nd]make\b, ||
    m,dmake\.exe:?\s+-S, ||
    m,^\s+\d+/\d+ skipped: , ||
    m,^\s+all skipped: , ||
    m,\.+skipped$, ||
    m,^\s*pl2bat\.bat [\w\\]+, ||
    m,^Making , ||
    m,^Skip ,
}

=back

=head1 COPYRIGHT

Copyright (C) 2002 H.Merijn Brand, Nicholas Clark, Abe Timmmerman

This suite is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, without consulting the author.

(Future) Co-Authors and or contributors should agree to this before
submitting patches.

=cut

__DATA__
#!/bin/sh

# Default Policy.sh

# Be sure to define -DDEBUGGING by default, it's easier to remove
# it from Policy.sh than it is to add it in on the correct places

ccflags='-DDEBUGGING'
