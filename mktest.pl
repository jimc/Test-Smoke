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

use Cwd;
use Getopt::Long;

my $norun   = 0;
my $verbose = 0;
GetOptions (
    "n|norun|dry-run" => \$norun,
    "v|verbose:i"     => \$verbose,	# NYI
    ) or usage;
my $config_file = shift || "smoke.cfg";

open TTY,    ">&STDERR";	select ((select (TTY),    $| = 1)[0]);
open STDERR, ">&1";		select ((select (STDERR), $| = 1)[0]);
open LOG,    "> mktest.out";	select ((select (LOG),    $| = 1)[0]);
				select ((select (STDOUT), $| = 1)[0]);

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

sub ttylog (@)
{
    print TTY @_;
    print LOG @_;
    } # ttylog

my @config;
if (defined $config_file && -s $config_file) {
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
	[ "", "-Duselongdouble"
	  ],
	{ policy_target =>       "-DDEBUGGING",
	  args          => [ "", "-DDEBUGGING" ]
	  },
	);
    }
#use Data::Dumper; print Dumper (@config); exit;

my $testdir = cwd;
run ("unlink qw(perl.ok perl.nok)", sub {unlink qw(perl.ok perl.nok)});

my $patch;
if (open OK, "<.patch") {
    chomp ($patch = <OK>);
    close OK;
    print LOG "Smoking patch $patch\n\n";
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
	run "make -i distclean 2>/dev/null";

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
	run "./Configure $config_args -des";

	unless ($norun or (-f "Makefile" && -s "config.sh")) {
	    ttylog " Unable to configure perl in this configuration\n";
	    next;
	    }

	print TTY "\nMake headers ...";
	run "make regen_headers";

	print TTY "\nMake ...";
	run "make";

	unless ($norun or (-s "perl" && -x _)) {
	    ttylog " Unable to make perl in this configuration\n";
	    next;
	    }

	$norun or unlink "t/perl";
	run "make test-prep";
	unless ($norun or -l "t/perl") {
	    ttylog " Unable to test perl in this configuration\n";
	    next;
	    }

	print TTY "\n Tests start here:\n";

	foreach my $perlio (qw(stdio perlio)) {
	    $ENV{PERLIO} = $perlio;
	    ttylog "PERLIO = $perlio\t";

	    if ($norun) {
		ttylog "\n";
		next;
		}

	    open TST, "make test |";
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
		# make {,n}okfile now, cause a failure might not be able to
		-f "perl.ok"  or run "make okfile";
		run "cp perl.ok perl.nok";
		open  OK, ">> perl.ok.$$";
		print OK $p_conf->[0] eq $s_conf ? "\n" :
			($p_conf->[0] =  $s_conf);
		print OK "PERLIO = $perlio\n", @nok;
		close OK;
		}
	    else {
		my @harness;
		for (@nok) {
		    m:^(\w+/[-\w/]+).*: or next;
		    push @harness, "../$1.t";
		    }
		if (@harness) {
		    local $ENV{PERL_SKIP_TTY_TEST} = 1;
		    print TTY "\nExtending failures with Harness\n";
		    push @nok, "\n",
			grep !m:\bFAILED tests\b: &&
			    !m:% okay$: => run "./perl t/harness @harness";

		    open  NOK, ">> perl.nok.$$";
		    print NOK $p_conf->[1] eq $s_conf ? "\n" :
			     ($p_conf->[1] =  $s_conf);
		    print NOK "PERLIO = $perlio\n", @nok;
		    close NOK;
		    }
		}
	    print TTY "\n";
	    }
	}
    } # run_tests

if (-s "perl.ok.$$") {
    print TTY "\nOK file ...";
    open OK, -s "perl.nok.$$" ? "< perl.ok.$$" : "< mktest.out";
    my @nok = <OK>;
    close OK;
    unlink "perl.ok.$$";
    open  OK, "< perl.ok";
    my @ok = <OK>;
    close OK;
    shift @ok;
    $ok[0] =~ s/Subject:\s+//;
    $patch and $ok[0] =~ s/\+DEVEL\d+/+DEVEL$patch/;
    $ok[0] =~ s/-stdio//;
    splice @ok, 1, 2;
    splice @ok, 8, 2, map { "    $_\n" } (
			    "category=dailybuild",
			    "category=install",
			    "osname=$^O",
			    "severity=none",
			    "status=ok",
			    "ack=no");
    splice @ok, 6, 0, "\n", @nok, "\n";
    open  OK, "> perl.ok";
    print OK @ok;
    close OK;
    }
else {	# Let's hope not!
    unlink "perl.ok";
    }

if (-s "perl.nok.$$") {
    print TTY "\nNot OK file ...";
    open NOK, "< perl.nok.$$";
    my @nok = <NOK>;
    close NOK;
    shift @nok;
    $nok[0] =~ s/Subject:\s+//;
    $nok[0] =~ s/OK/Not OK/;
    $patch and $nok[0] =~ s/\+DEVEL\d+/+DEVEL$patch/;
    $nok[0] =~ s/-stdio//;
    splice @nok, 1, 2;
    $nok[2] =~ s/success/build failure/;
    splice @nok, 8, 2, map { "    $_\n" } (
			     "category=dailybuild",
			     "category=install",
			     "osname=$^O",
			     "severity=none",
			     "status=open",
			     "ack=no");
    open NOK, "< perl.nok.$$";
    splice @nok, 5, 1, (<NOK>);
    close NOK;
    unlink "perl.nok.$$";
    open  NOK, "> perl.nok";
    print NOK @nok;
    close NOK;
    }
else {
    unlink "perl.nok";
    }

__END__
#!/bin/sh

# Default Policy.sh

# Be sure to define -DDEBUGGING by default, it's easier to remove
# it from Policy.sh than it is to add it in on the correct places

ccflags='-DDEBUGGING'
