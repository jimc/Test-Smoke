#! /usr/bin/perl -w
use strict;
$|=1;

use Cwd;
use File::Spec;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );

use Getopt::Long;
my %options = ( config => 'smokeperl_config', fetch => 1, mail => 1 );
GetOptions( \%options, 'config|c=s', 'fetch!', 'mail!' );

use vars qw( $conf $VERSION );
$VERSION = '1.16_15';

=head1 NAME

smokeperl.pl - Wrapperscript to replace smoke.sh/smokew32.bat

=head1 SYNOPSIS

    $ ./smokeperl.pl [-c configname]

or
    C:\Perlsmoke>perl perlsmoke.pl [-c configname]

=head1 OPTIONS

It can take these options

  --config|-c <configname> See configsmoke.pl (smokeperl_config)
  --nofetch                Skip the synctree step
  --nomail                 Skip the mail step

=cut

# Try cwd() first, then $FindBin::Bin
my $config_file = File::Spec->catfile( cwd(), $options{config} );
-e $config_file and eval { require $config_file; };
if ( $@ ) {
    $config_file = File::Spec->catfile( $FindBin::Bin, $options{config} );
    eval { require $config_file; };
}
$@ and die "!!!Please run 'configsmoke.pl'!!!\nCannot find configuration: $!";

use Test::Smoke::Syncer;
use Test::Smoke::Mailer;
use Cwd;

FETCHTREE: {
    unless ( $options{fetch} ) {
        $conf->{v} and print "Skipping synctree\n";
        last FETCHTREE;
    }
    my $syncer = Test::Smoke::Syncer->new( $conf->{sync_type}, $conf );
    $syncer->sync;
}

my $cwd = cwd();
chdir $conf->{ddir} or die "Cannot chdir($conf->{ddir}): $!";
MKTEST: {
    local @ARGV = ( $conf->{cfg} );
    push  @ARGV, ( "--locale", $conf->{locale} ) if $conf->{locale};
    push  @ARGV, "--forest",  $conf->{fdir}
       if $conf->{sync_type} eq 'forest' && $conf->{fdir};
    push  @ARGV, "-v", $conf->{v} if $conf->{v};
    push  @ARGV, @{ $conf->{w32args} } if exists $conf->{w32args};
    my $mktest = File::Spec->catfile( $FindBin::Bin, 'mktest.pl' );
    $conf->{v} > 1 and print "$mktest @ARGV\n";
    do $mktest or die "Error 'mktest': $@";
}

MKOVZ: {
    local @ARGV = ( 'nomail', $conf->{ddir} );
    push  @ARGV, $conf->{locale} if $conf->{locale};
    my $mkovz = File::Spec->catfile( $FindBin::Bin, 'mkovz.pl' );
    do $mkovz or die "Error in mkovz.pl: $@";
}

MAILRPT: {
    unless ( $options{mail} ) {
        $conf->{v} and print "Skipping mailrpt\n";
        last MAILRPT;
    }
    my $mailer = Test::Smoke::Mailer->new( $conf->{mail_type}, $conf );
    $mailer->mail;
}
chdir $cwd;

=head1 SEE ALSO

L<configsmoke.pl>, L<mktest.pl>, L<mkovz.pl>

=head1 COPYRIGHT

(c) 2002, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
