#!/bin/sh

# This should be run with cron

# Change your base dir here
export PC
PC=${1:-/usr/CPAN/perl-current}
CF=${2:-smoke.cfg}

# Set other environmental values here

export PATH
PATH=`pwd`:$PATH

echo "Smoke $PC"
umask 0

cd $PC || exit 1
make -i distclean > /dev/null 2>&1
rsync -avz --delete rsync://ftp.linux.activestate.com/perl-current/ .

(mktest.pl $CF 2>&1) >mktest.log      || echo mktest.pl exited with exit code $?

mkovz.pl smokers-reports@perl.org $PC || echo mkovz.pl  exited with exit code $?
