use ExtUtils::MakeMaker;
use Config;

warn "\n'Makefile.PL' no longer configures your perl core smoke suite!!!\n" .
     "Please use:\n\tperl Configure.pl\nor\n\tperl configsmoke.pl\n\n";

WriteMakefile(
    NAME	 => "Test-Smoke",
    DISTNAME	 => "Test-Smoke",
    VERSION_FROM => "smokeperl.pl",
    AUTHOR	 => 'H.Merijn Brand <h.m.brand@hccnet.nl>, '.
		    'Nicholas Clark <nick@plum.flirble.org> and ' .
                    'Abe Timmerman <abeltje@cpan.org>',

    dist	 => { COMPRESS => "gzip -9f",
		      SUFFIX   => ".gz",
		    },
    SKIP         => [qw( install )],
);

warn "\n\nYou can now run\n\t$Config{make} test\nafter success\n" .
     "\t$Config{make} distclean\n\n";
