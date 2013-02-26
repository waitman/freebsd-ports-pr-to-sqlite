#!/usr/pkg/bin/perl -w

#parse-gnats-ports.pl
#Copyright 2013 Waitman Gobble <waitman@waitman.net>
#see LICENSE and README for important Information

use strict;
use warnings;
use DBI;
use Time::Piece;
use Sys::Syslog;

local $SIG{__WARN__} = sub {}; #fun! 


my $did_update = 0;
my $file;
my $chk_dt = 0;
my $max_dt = 0;
my $dbh = DBI->connect("dbi:SQLite:dbname=ports-pr.db") or die $DBI::errstr;

if (-e '/var/db/lastrun.txt') {
	open FILE, '/var/db/lastrun.txt';
	$chk_dt = <FILE>;
	close FILE;
} else {
	$dbh->do("CREATE TABLE pr (status TEXT,postdate TEXT,pr TEXT,who TEXT,desc TEXT,last_activity TEXT,num_msgs TEXT)");
}

my @files = <*>;
foreach $file (@files) {

	my $state = '';
	my $responsible = '';
	
	next if ($file =~ m/\./);
	my $pr = "ports/".$file;
	my $this_dt = (stat $file)[9];
	next if ($this_dt<=$chk_dt);

	if ($this_dt>$max_dt) { $max_dt = $this_dt; }

#largest file so far is < 5M so "should" be OK to read into memory.

	open FILE, $file;
	my @fs = <FILE>;
	close FILE;
	my @arr = grep (/^Subject:/,@fs);
	my $subject = '';
	eval { $subject = $arr[0] }; #only need first subject
	if ($@) {
		$subject='';
	} else {
		$subject =~ s/\r//;
		$subject =~ s/\n//;
		$subject =~ s/Subject://;
                $subject =~ s/^\s+//;
                $subject =~ s/\s+^//;
                $subject =~ s/\h+/ /g;
		$subject =~ s/'/''/g;
	}

	@arr = grep (/^Date:/,@fs);
	my $date='';
	eval { $date = $arr[0] };
	if ($@) {
		$date = '';
	}
	my $ds = fundate($date,$file);
	my $es = $ds;
	my $num = 1;

	if ($#arr>0) {
		$num = $#arr+1;
		$es = fundate(pop @arr,$file);
	}

	@arr = grep (/^State-Changed-From-To:/,@fs);
	eval { $state = pop @arr };
	if ($@) {
		$state = '';
	} else {
		if (length $state) {
			$state =~ s/\n//;
			$state =~ s/\r//;
			my @n = {};
			eval { @n = split(/->/,$state) };
			if ($@) {
				$state = '';
			} else {
				$state = pop @n;
			}
		}
	}

        @arr = grep (/^Responsible-Changed-From-To:/,@fs);
        eval { my $responsible = pop @arr };
	if ($@) {
		$responsible = '';
	} else {
		if (length $responsible) {
			$responsible =~ s/\n//;
			$responsible =~ s/\r//;
			my @n = {};
			eval { @n = split(/->/,$responsible) };
			if ($@) {
				$responsible = '';
			} else {
				$responsible = pop @n;
			}
		}
	}
	
	if ($chk_dt>0) {
		$dbh->do("DELETE FROM pr WHERE pr='".$pr."'");
	}
	my $sql = "INSERT INTO pr VALUES ('".$state."','".$ds."','".$pr."','".$responsible."','".$subject."','".$es."','".$num."')";
	print $pr."\n"; #so we can see the wheels spinning.
	$did_update++;
	$dbh->do($sql);
}

$dbh->disconnect();

if ($max_dt>$chk_dt) {
	open (FILE, '>/var/db/lastrun.txt');
	print FILE $max_dt;
	close(FILE);
}

if ($did_update>0) {
openlog('update-pr-db','cons,pid','user');
syslog('info','%s','Found '.$did_update.' PR updates.');
closelog();
}
print "\ndone...\n";


sub fundate {
	my $date = $_[0];
	my $file = $_[1];
	my $ed;
	my $ds;

	if (defined $date and length $date) {
		#yay for RFCs and strange email clients.
		#works mostly, fallback is the date of the file.
		$date =~ s/Date://;
		$date =~ s/^\s+//;
		$date =~ s/\s+^//;
		$date =~ s/\n//;
		$date =~ s/\r//;
		$date =~ s/\h+/ /g;
		$date =~ s/UT$/GMT/;
		$date =~ s/ DST//g;
		$date =~ s/\sDaylight Time//g;
		$date =~ s/\(\+0800\)//g;
		eval { my $ed = Time::Piece->strptime($date,'%a, %d %b %Y %T %z (%Z)') };
		if ($@) {
			eval { $ed = Time::Piece->strptime($date, '%a, %d %b %Y %T %Z') };
			if ($@) {
				eval { $ed = Time::Piece->strptime($date, '%a, %d %b %Y %T %z') };
				if ($@) {
					eval { $ed = Time::Piece->strptime($date, '%e %h %Y %T %z') };
					if ($@) {
						eval { $ed = Time::Piece->strptime($date, '%a, %e %h %y %T %Z') };
                                        }
                                }
                        }
                }
                my $ts = eval { $ed->epoch };
                if ($@) {
                        $ds = localtime((stat $file)[9])->ymd('-');
                } else {
                        $ds = $ed->ymd('-');
                }
        } else {
                $ds = localtime((stat $file)[9])->ymd('-');
        }
	return ($ds);
}

#EOF
