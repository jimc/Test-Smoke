#!/usr/bin/perl -w

# Create matrix for smoke test results
# (c)'01 H.Merijn Brand [27 August 2001]

# mkovz.pl [ e-mail [ folder ]]

use strict;

use vars qw($VERSION);
$VERSION = "1.10";

use Config;
my $email = shift || getpwuid $<;
my $testd = shift || "/usr/3gl/CPAN/perl-current";
my (%rpt, @confs, %confs, @manifest);

open RPT, "> $testd/mktest.rpt" or die "mktest.rpt: $!";
select RPT;

my $perlio = "";
my $conf   = "";
my $debug  = "";
$rpt{patch} = "?";
my ($out, @out) = ("$testd/mktest.out", 1 .. 5);
open OUT, "<$out" or die "Can't open $out: $!";
for (<OUT>) {
    m/^\s*$/ and next;
    m/^-+$/  and next;

    # Buffer for broken lines (Win32, VMS)
    pop @out;
    unshift @out, $_;
    chomp $out[0];

    if (m/^\s*Smoking patch (\d+)/) {
	$rpt{patch} = $1;
	next;
	}
    if (m/^MANIFEST /) {
	push @manifest, $_;
	next;
	}
    if (s/^Configuration:\s*//) {
	# Unable to build in previous conf was hidden by crash junk?
	exists $rpt{$conf}{$debug}{stdio}  or $rpt{$conf}{$debug}{stdio}  = "-";
	exists $rpt{$conf}{$debug}{perlio} or $rpt{$conf}{$debug}{perlio} = "-";

	s/-Dusedevel\s+//;
	$debug = s/-DDEBUGGING\s*// ? "D" : "";
	s/\s+-des//;
	s/\s+$//;
	$conf = $_;
	$confs{$_}++ or push @confs, $conf;
	next;
	}
    if (m/PERLIO\s*=\s*(\w+)/) {
	$perlio = $1;
	next;
	}
    if (m/^\s*All tests successful/) {
	$rpt{$conf}{$debug}{$perlio} = "O";
	next;
	}
    if (m/^\s*Skipped this configuration/) {
	if ($^O =~ m/^(?: hpux | freebsd )$/x) {
	    (my $dup = $conf) =~ s/ -Duselongdouble//;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{qw(stdio perlio)} =
		    @{$rpt{$dup}{$debug}}{qw(stdio perlio)};
		next;
		}
	    $dup =~ s/ -Dusemorebits/ -Duse64bitint/;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{qw(stdio perlio)} =
		    @{$rpt{$dup}{$debug}}{qw(stdio perlio)};
		next;
		}
	    $dup =~ s/ -Duse64bitall/ -Duse64bitint/;
	    if (exists $rpt{$dup}{$debug}{stdio}) {
		@{$rpt{$conf}{$debug}}{qw(stdio perlio)} =
		    @{$rpt{$dup}{$debug}}{qw(stdio perlio)};
		next;
		}
	    }
	$rpt{$conf}{$debug}{stdio}  = ".";
	$rpt{$conf}{$debug}{perlio} = ".";
	next;
	}
    if (m/^\s*Unable to (?=([cbmt]))(?:build|configure|make|test) perl/) {
	$rpt{$conf}{$debug}{stdio}  = $1;
	$rpt{$conf}{$debug}{perlio} = $1;
	next;
	}
    # /Fix/ broken lines
    if (m/^\s*FAILED/ || m/^\s*DIED/) {
	foreach my $out (@out) {
	    $out =~ m/\.\./ or next;
	    push @{$rpt{$conf}{$debug}{$perlio}}, $out . substr $_, 3;
	    last;                
	    }
	next;
	}
    if (m/FAILED/) {
	ref $rpt{$conf}{$debug}{$perlio} or
	    $rpt{$conf}{$debug}{$perlio} = [];	# Clean up sparse garbage
	push @{$rpt{$conf}{$debug}{$perlio}}, $_;
	next;
	}
    }

my $ccv = $Config{ccversion}||$Config{gccversion};
print <<EOH;
Automated smoke report for patch $rpt{patch} on $Config{osname} - $Config{osvers}
          v$VERSION         using $Config{cc} version $ccv
O = OK
F = Failure(s), extended report at the bottom
? = still running or test results not (yet) available
Build failures during:       - = unknown
    c = Configure, m = make, t = make test-prep

         Configuration
-------  --------------------------------------------------------------------
EOH

my @fail;
for my $conf (@confs) {
    for my $debug ("", "D") {
	for my $perlio ("stdio", "perlio") {
	    my $res = $rpt{$conf}{$debug}{$perlio};
	    if (ref $res) {
		print "F ";
		my $s_conf = $conf;
		$debug and substr ($s_conf, 0, 0) = "-DDEBUGGING ";
		if ($perlio eq "stdio" && ref $rpt{$conf}{$debug}{perlio} and
		    "@{$rpt{$conf}{$debug}{perlio}}" eq "@{$rpt{$conf}{$debug}{stdio}}") {
		    # Squeeze stdio/perlio errors together
		    print "F ";
		    push @fail, [ "stdio/perlio", $s_conf, $res ];
		    last;
		    }
		push @fail, [ $perlio, $s_conf, $res ];
		next;
		}
	    print $res ? $res : "?", " ";
	    }
	}
    print "$conf\n";
    }

print <<EOE;
| | | +- PERLIO = perlio -DDEBUGGING
| | +--- PERLIO = stdio  -DDEBUGGING
| +----- PERLIO = perlio
+------- PERLIO = stdio
EOE

@fail and print "\nFailures:\n\n";
for my $i (0 .. $#fail) {
    my $ref = $fail[$i];
    printf "%-12s %-16s %s\n", $^O, @{$ref}[0,1];
    if ($i < $#fail) {	# More squeezing
	my $nref = $fail[$i + 1];
	$ref->[0] eq $nref->[0] and
	    "@{$ref->[-1]}" eq "@{$nref->[-1]}" and next;
	}
    print @{$ref->[-1]}, "\n";
    }

@manifest and print RPT "\n\n", @manifest;

close RPT;
select STDOUT;

my $mailer = "mailx";
my $subject = "Smoke $rpt{patch} $Config{osname} $Config{osvers} $testd";
if ($mailer =~ m/sendmail/) {
    local (*MAIL, *BODY, $/);
    open  BODY, "< $testd/mktest.rpt";
    open  MAIL, "| $mailer -i -t";
    print MAIL join "\n",
	"To: $email",
	"From: ...",
	"Subject: $subject",
	"",
	<BODY>;
    close BODY;
    close MAIL;
    }
else {
    system "$mailer -s '$subject' $email < $testd/mktest.rpt";
    }
