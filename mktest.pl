#!/usr/bin/perl -w

# Smoke test for perl-current
# (c)'01 H.Merijn Brand [27 August 2001]
#    and Nicholas Clark

use strict;

sub usage ()
{
    print STDERR "usage: mktest.pl [<smoke.cfg>]\n";
    exit 1;
    } # usage

@ARGV == 1 and $ARGV[0] eq "-?" || $ARGV[0] =~ m/^-+help$/ and usage;

use Config;
use Cwd;
use Getopt::Long;
use File::Find;

my %win32_makefile_map = (
    nmake => "Makefile",
    dmake => "makefile.mk",
    );
my $win32_cctype = "MSVC60"; # 2.0 => MSVC20; 5.0 => MSVC; 6.0 => MSVC60
my $win32_maker  = $Config{make};

my $norun   = 0;
my $verbose = 0;
GetOptions (
    "n|norun|dry-run"  => \$norun,
    "v|verbose:i"      => \$verbose,	# NYI
    "m|win32-maker=s"  => \$win32_maker,
    "c|win32-cctype=s" => \$win32_cctype,
    ) or usage;
my $config_file = shift;

open TTY,    ">&STDERR";	select ((select (TTY),    $| = 1)[0]);
open STDERR, ">&1";		select ((select (STDERR), $| = 1)[0]);
open LOG,    "> mktest.out";	select ((select (LOG),    $| = 1)[0]);
				select ((select (STDOUT), $| = 1)[0]);

sub is_win32 ()
{
    $^O eq "MSWin32";
    } # is_win32

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

sub ttylog (@)
{
    print TTY @_;
    print LOG @_;
    } # ttylog

my @config;
unless (defined $config_file) {
    -s "smoke.cfg" and $config_file = "smoke.cfg";
    }
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
    substr ($ENV{$Config{ldlibpthname}}, 0, 0) = "$testdir$Config{path_sep}";

my $patch;
if (open OK, "<.patch") {
    chomp ($patch = <OK>);
    close OK;
    print LOG "Smoking patch $patch\n\n";
    }
if (!$patch and open OK, "< patchlevel.h") {
    local $/ = undef;
    ($patch) = (<OK> =~ m/^\s+,"DEVEL(\d+)"\s*$/m);
    close OK;
    print LOG "Smoking patch $patch(+)\n\n";
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

close LOG;

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
	ttylog $s_conf;

	# You can put some optimizations (skipping configurations) here
	if ( $^O =~ m/^(?: hpux | freebsd )$/x &&
	     $conf =~ m/longdouble|morebits/) {
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
	run "./Configure $config_args -des", is_win32 ? \&Configure : undef;

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
		open TST, "make _test |";
		}

	    my @nok = ();
	    select ((select (TST), $| = 1)[0]);
	    while (<TST>) {
		# Still to be extended
		m,^ *$, ||
		m,^	AutoSplitting, ||
		m,^\./miniperl , ||
		m,^autosplit_lib, ||
		m,^	Making , ||
		m,^make\[[12], ||
		m,make( TEST_ARGS=)? (_test|TESTFILE=), ||
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
		# Don't know why BSD's make does this
		m,^Extracting .*with variable substitutions, ||
		# Or these
		m,cc\s+-o\s+perl.*perlmain.o\s+lib/auto/DynaLoader/DynaLoader\.a\s+libperl\.a, ||
		m,^\S+ is up to date, ||
		m,^   ### , and next;
		if (m/^u=.*tests=/) {
		    s/(\d\.\d*) /sprintf "%.2f ", $1/ge;
		    print LOG;
		    }
		else {
		    push @nok, $_;
		    }
		print;
		}
	    print LOG map { "    $_" } @nok;
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

sub Configure
{
    my $command = shift;

    local $_;
    my %opt_map = (
	"-Dusethreads"		=> "USE_ITHREADS",
	"-Duseithreads"		=> "USE_ITHREADS",
	"-Duseperlio"		=> "USE_PERLIO",
	"-Dusemultiplicity"	=> "USE_MULTI",
	"-Duseimpsys"		=> "USE_IMP_SYS",
	"-DDEBUGGING"		=> "USE_DEBUGGING",
	);
    my %opts = (
	USE_MULTI	=> 0,
	USE_ITHREADS	=> 0,
	USE_IMP_SYS	=> 0,
	USE_PERLIO	=> 0,
	USE_DEBUGGIMG	=> 0,
	);

    ttylog $command;
    $command =~ m{^\s*\./Configure\s+(.*)} or die "unable to parse command";
    foreach (split " ", $1) {
	m/^-[des]{1,3}$/ and next;
	m/^-Dusedevel$/  and next;
	die "invalid option '$_'" unless exists $opt_map{$_};
	$opts{$opt_map{$_}} = 1;
	}

    local (*IN, *OUT);
    my $in =  "win32/$win32_makefile_map{$win32_maker}";
    my $out = "win32/smoke.mk";

    open IN,  "< $in"  or die "unable to open '$in'";
    open OUT, "> $out" or die "unable to open '$out'";
    while (<IN>) {
	if    (m/^\s*#?\s*(USE_\w+)(\s*\*?=\s*define)$/) {
	    $_ = ($opts{$1} ? "" : "#") . $1 . $2 . "\n";
	    }
	elsif (m/^\s*#?\s*(CFG\s*\*?=\s*Debug)$/) {
	    $_ = ($opts{USE_DEBUGGING} ? "" : "#") . $1 . "\n";
	    }
	elsif (m/^\s*#?\s*(CCTYPE\s*\*?=\s*)(\w+)$/) {
	    $_ = ($2 eq $win32_cctype ? "" : "#" ) . $1 . $2 . "\n";
	    }
	elsif (m/^\s*CC\s*=\s*cl$/) {
	    chomp;
	    $_ .= " -nologo\n";
	    # These two ( CC = .. and CCTYPE = ... ), along with
	    # CCHOME, BCCOLD, BCCVCL, IS_WIN95, are related to
	    # the tester's environment; The options I see are
	    # * add some fake flags ( -cc=... -cctype=, etc )
	    #   This make easy to smoke with various compilers at one time
	    # * put these in some config file ( a new section in
	    #   smoke.cfg, o a new environment.cfg )
	    # * pass them on the command line
	    #   perl mktext.pl CC=xxx CCTYPE=yyy smoke.cfg
	    }

	print OUT $_;
	}
    } # Configure

__END__
#!/bin/sh

# Default Policy.sh

# Be sure to define -DDEBUGGING by default, it's easier to remove
# it from Policy.sh than it is to add it in on the correct places

ccflags='-DDEBUGGING'
