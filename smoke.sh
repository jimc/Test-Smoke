#!/bin/sh

# This should be run with cron

# Change your base dir here
export PC
PC=${1:-/usr/CPAN/perl-current}
CF=${2:-"`pwd`/smoke.cfg"}
TS_LF=${3:-"`pwd`/mktest.log"}
# Set other environmental values here

export PATH
PATH="`pwd`:$PATH"

echo "Smoke $PC"
umask 0

cd "$PC" || exit 1
echo "Smokelog: builddir is $PC" > "$TS_LF"
make -i distclean > /dev/null 2>&1

# Abigail pointed out that older rsync's might want older syntax
# as did Jarkko, and he doesn't want this stuff in his cronmail
(rsync -avz --delete ftp.linux.activestate.com::perl-current . 2>&1) >>"$TS_LF"

(mktest.pl "$CF" 2>&1) >>"$TS_LF" || echo mktest.pl exited with exit code $?

mkovz.pl 'daily-build@perl.org' "$PC" || echo mkovz.pl  exited with exit code $?
