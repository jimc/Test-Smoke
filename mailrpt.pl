#! /usr/bin/perl -w
use strict;

use Getopt::Long;
use File::Spec;
use Cwd;
use FindBin;
use lib File::Spec->catdir( $FindBin::Bin, 'lib' );
use Test::Smoke::Mailer;

use vars qw( $VERSION );
$VERSION = '0.001';

my %opt = (
    type => 'error',
    ddir => cwd(),
    to   => 'smokers-reports@perl.org',
    v    => 0,

    help => 0,
);

my %valid_type = map { $_ => 1 } qw( mail mailx sendmail Mail::Sendmail );

=head1 NAME

mailrpt.pl - Send the smoke report by mail

=head1 SYNOPSIS

    $ ./mailrpt.pl -t mailx -d ../perl-current [--help | more options]

=head1 OPTIONS

Options depend on the B<type> option, exept for some.

=over 4

=item * B<General options>

    -d | --ddir <directory>  Set the directory for the source-tree (cwd)
    --to <emailaddresses>    Comma separated list (smokers-reports@perl.org)
    --cc <emailaddresses>    Comma separated list
    -v | --verbose           Be verbose

    -t | --type <type>       mail mailx sendmail Mail::Sendmail [mandatory]

=item * B<options for> -t mail/mailx

none

=item * B<options for> -t sendmail

    --from <address>

=item * B<options for> -t Mail::Sendmail

    --from <address>
    --mserver <smtpserver>  (localhost)

=back

=cut

GetOptions( \%opt,
    'type|t=s', 'ddir|d=s', 'to=s', 'cc=s', 'v|verbose+',

    'from=s', 'mserver=s',

    'help|h', 'man|m',
) or do_pod2usage( verbose => 1 );

$opt{man}  and do_pod2usage( verbose => 2, exitval => 0 );
$opt{help} and do_pod2usage( verbose => 1, exitval => 0 );

exists $valid_type{ $opt{type} } or do_pod2usage( verbose => 0 );
$opt{ddir} or do_pod2usage( verbose => 0 );

my $mailer = Test::Smoke::Mailer->new( $opt{type} => \%opt );

$mailer->mail;

sub do_pod2usage {
    eval { require Pod::Usage };
    if ( $@ ) {
        print <<EO_MSG;
Usage: $0 -t <type> -d <directory> [options]

Use 'perldoc $0' for the documentation.
Please install 'Pod::Usage' for easy access to the docs.

EO_MSG
        exit;
    } else {
        Pod::Usage::pod2usage( @_ );
    }
}

=head1 SEE ALSO

L<Test::Smoke::Mailer>, L<mkovz.pl>

=head1 COPYRIGHT

(c) 2002, All rights reserved.

  * Abe Timmerman <abeltje@cpan.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
