#!/usr/bin/perl -w

# Create matrix for smoke test results
# (c)'02 H.Merijn Brand [11 Apr 2002]

# mkovz.pl [ e-mail [ folder ]]

use strict;

use vars qw($VERSION);
$VERSION = "1.13";

use Cwd;

my $testd = shift || cwd ();

my %Config;
get_smoke_Config (qw( version osname osvers cc ccversion gccversion ));

# You can overrule the auto-detected settings here, to be more verbose
# like including the distribution: "Redhat Linux" instead of plain "linux"
#$Config{osname} = "cygwin";			# hpux, AIX, MSWin32, ...
#$Config{osvers} = "1.3.10(0.5132)";		# 11.00, 4.3.3.0, ...
#$Config{cc}     = "msvc";			# cc, xlc, gcc, ...
#$Config{ccvers} = "B.11.11.04 + Patch PHCO_25707";

my $mailer = "/usr/bin/mailx";

=head1 NAME

mkovz.pl - Create matrix for smoke test results.

=head1 SYNOPSYS

	$ ./mkovz.pl [ e-mail [ builddir ]]

=head1 DESCRIPTION

C<mkovz.pl> processes the output created by the C<mktest.pl> program to
 createa nice report and (optionally) send it to the smokers mailinglist.

=head2 ARGUMENTS

C<mkovz.pl> can take two (2) arguments:

=over 4

=item e-mail

This specifies the e-mailaddress to which the report is e-mailed.

You can use B<no-mail> to skip the mailing bit.

If you specify no e-mailaddress the current username is used.

=item builddir

The C<builddir> is the directory where you have just build perl and where the 
B<mktest.out> file is that C<mktest.pl> left there.

The default is the current working directory.

=back

=cut

use File::Spec;

require Win32 if $^O eq "MSWin32";
my $email = shift || ($^O eq "MSWin32" ? Win32::LoginName () : getpwuid $<);

my (%rpt, @confs, %confs, @manifest);

open RPT, "> " . File::Spec->catfile ($testd, "mktest.rpt")
    or die "mktest.rpt: $!";
select RPT;

my $perlio = "";
my $conf   = "";
my $debug  = "";
$rpt{patch} = "?";
my ($out, @out) = (File::Spec->catfile ($testd, "mktest.out"), 1 .. 5);
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
	$conf = $_ || " ";
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

$Config{ccvers}	||= $Config{ccversion} || $Config{gccversion};

print <<EOH;
Automated smoke report for patch $rpt{patch} on $Config{osname} - $Config{osvers}
          v$VERSION      using $Config{cc} version $Config{ccvers}
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

send_mail () unless $email =~ /^no\-?e?mail$/i;

sub send_mail
{
    my $subject = "Smoke $rpt{patch} $Config{osname} $Config{osvers} $testd";
    if ($mailer =~ m/sendmail/) {
        local (*MAIL, *BODY, $/);
        open  BODY, "<" . File::Spec->catfile ($testd, "mktest.rpt");
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
        system "$mailer -s '$subject' $email < " . 
               File::Spec->catfile ($testd, "mktest.rpt");
        }
    } # send_mail

sub get_smoke_Config 
{
    %Config = map { ( lc $_ => "" ) } @_;

    my $smoke_Config_pm = File::Spec->catfile ($testd, "lib", "Config.pm");
    
    open my $fh, $smoke_Config_pm
        or die "Can't open '$smoke_Config_pm': $!";

    while (<$fh>) {
        if (m/^my \$config_sh = <<'!END!';/ .. m/^!END!/) {
            m/!END!(?:';)?$/      and next;
            m/^([^=]+)='([^']*)'$/ or next;
            exists $Config{lc $1} and $Config{lc $1} = $2;
            }
        }
    } # get_smoke_Config

=head1 CHANGES

1.13
	- Moved part of Config to top for easier user changes

1.12

	- Use Config.pm of the smoked perl
	- A bit more Win32 minded :-)

=head1 AUTHOR

H.Merijn Brand <h.m.brand@hccnet.nl>
Abe Timmerman  <abe@ztreet.demon.nl>

=cut

