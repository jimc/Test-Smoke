#!/usr/local/bin/perl -w

use strict;

use ExtUtils::MakeMaker;
use File::Copy;
use Cwd qw(cwd abs_path);

print "\nConfiguring the smoke test suite ...\n\n";

$^O =~ m/^(?: VMS | MSWin32 )$/x and
    die "OS type $^O is not (yet) supported for automatic configuration";

WriteMakefile (
    NAME	=> "Test::Smoke",
    DISTNAME	=> "Test-Smoke",
    VERSION	=> "1.07",
    AUTHOR	=> 'H.Merijn Brand <h.m.brand@hccnet.nl> and '.
		   'Nicholas Clark <nick@plum.flirble.org>',

    dist	=> { COMPRESS => "gzip -9f",
		     SUFFIX   => ".gz",
		     },
    );

my $sh = "";
{   local (*SH, $/);
    open SH, "< smoke.sh" or die "smoke.sh: $!";
    $sh = <SH>;
    close SH;
    }

my $sd = cwd;
$sh =~ s/`pwd`:/$sd:/;

while (1) {
    print "What directory do you want to use for the source tree ?\n";
    print "[ /usr/CPAN/perl-current ] > ";
    chomp (my $dir = scalar <STDIN>);
    $dir ||= "/usr/CPAN/perl-current";

    unless (-d $dir) {
	my ($p, $d) = ("", $dir);
	while ($d =~ m:^(.*?/)(.*):) {
	    $p .= $1;
	    $d  = $2;
	    mkdir $p, 0755;
	    }
	}
    mkdir $dir, 0755;
    unless (-d $dir) {
	print "$dir is not a directory or cannot be created: $!\n";
	redo;
	}
    $dir = abs_path ($dir);
    $dir ne "/usr/CPAN/perl-current" and $sh =~ s:/usr/CPAN/perl-current:$dir:;
    if ($dir eq $sd) {
	print "You cannot choose the current folder as you smoking dir,\n",
	      "because 'rsync --delete' will throw away the test files\n\n";
	redo;
	}
    opendir DIR, $dir;
    my %f = map { $_ => 1 } grep !m/^\.+$/, readdir DIR;
    closedir DIR;
    if (exists $f{".patch"} && exists $f{MANIFEST} && exists $f{Configure}) {
	print "$dir looks like it already has a source tree.\n",
	      "Do you still want to use it for smoke tests? [y/N] > N\b";
	scalar <STDIN> =~ m/^[YyJjOoTt1]/ or # Yes, Ja, Oui, True, 1
	    redo;
	}
    elsif (grep !m/^\.(patch|config)$/, grep m/^\./, keys %f) {
	print "$dir has dot-files, which is likely an unsafe location to\n",
	      "start smoking from since these are deleted during smoke.\n\n",
	      "Are you sure you want to use it? [y/N] > N\b";
	scalar <STDIN> =~ m/^[YyJjOoTt1]/ or # Yes, Ja, Oui, True, 1
	    redo;
	}
    elsif (keys %f) {
	print "WARNING: $dir has files.\n\n",
	      "         these will - most probably - be deleted during rsync\n",
	      "         check if you are unsure!\n\n";
	}
    last;
    }

open STDERR, ">&STDOUT";
my $time = "random";
if (grep m/cron$/, `ps -ef`) {
    my ($m, $h);
    while (1) {
	print "At what time do you want the smoke to start ?\n";
	print "[ 22:25 ] > ";
	chomp ($time = scalar <STDIN>);
	$time ||= "22:25";
	($h, $m) = ($time =~ m/^([01]?\d|2[0-3]):([0-5]?\d)$/) and last;
	}
    if (open CRON, "crontab -l |") {
	my @cron = <CRON>;
	close CRON;
	grep m/\bsmoke\.sh\b/, @cron or
	    push @cron, "$m $h * * * sh $sd/smoke.sh 2>&1\n";
	for (@cron) {
	    m/\bsmoke\.sh\b/ or next;
	    s/^\d+\s+\d+/$m $h/ and last;
	    }
	print "I've changed your crontab entries like this\n",
	      (map { "  $_" } @cron),
	      "Shall I use it? [Y/n] > Y\b";
	unless (scalar <STDIN> =~ m/^[NnFf0]/) { # No, Nee, Nein, Non, False, 0
	    open CRON, "> cron.tab" or die "cron.tab: $!";
	    system "cron cron.tab";
	    unlink "cron.tab";
	    }
	}
    else {
	print "Cannot read current crontab\n";
	}
    }
else {
    print "I can't find a cron process. No automatic starting\n";
    }

my $conf = "";
while (!(-f $conf && -s _)) {
    print "What configuration file do you want to use ?\n";
    print "[ smoke.cfg ] > ";
    chomp ($conf = scalar <STDIN>);
    $conf ||= "smoke.cfg";
    -f $conf && -s _ or print "$conf is not a valid smoke configuration\n";
    }
$conf ne "smoke.cfg" and $sh =~ s:\bsmoke\.cfg\b:$conf:;

move ("smoke.sh", "smoke.sh.org");
open  SH, "> smoke.sh" or die "smoke.sh: $!";
print SH $sh;
close SH;
chmod 0755, "smoke.sh";

my $mail = "mail";
for (split m/:/, $ENV{PATH}) {
    -x "$_/mailx" or next;
    $mail = "mailx";
    last;
    }
if ($mail eq "mail") {
    local $/ = undef;
    open OVZ, "< mkovz.pl" or die "mkovz.pl: $!";
    my $ovz = <OVZ>;
    close OVZ;
    $ovz =~ s/\byour_no_mailx_sys\b/$^O/;
    move ("mkovz.pl", "mkovz.pl.org");
    open  OVZ, "> mkovz.pl" or die "mkovz.pl: $!";
    print OVZ $ovz;
    close OVZ;
    chmod 0755, "mkovz.pl";
    }

print <<EOM;

All done.

If everything works out fine, and you allowed me to persue the changes,
Perl Core smoking will take place everyday at $time.

Thanks for participating
EOM
