#!/usr/pkg/bin/perl

#sync-gnats-ports.pl
#Copyright 2013 Waitman Gobble <waitman@waitman.net>
#read README and LICENCE for more information.

if ($#ARGV !=0) {
        print "\nUsage: sync-gnats-ports.pl DESTDIR\n";
        exit;
}

if (-e '/tmp/pr-up-running') {
	exit();
}

$t=`touch /tmp/pr-up-running`;

my $destdir = $ARGV[0];
unless (-d $destdir) {
        print "\n$destdir does not Exist.\n";
        exit;
}
$destdir =~ s!/*$!/!;



$t=`/usr/pkg/bin/rsync -av rsync://bit0.us-west.freebsd.org/FreeBSD-bit/gnats/ports/ $destdir`;
$t=`/usr/local/bin/parse-gnats-ports.pl $destdir`;
$t=`unlink /tmp/pr-up-running`;

