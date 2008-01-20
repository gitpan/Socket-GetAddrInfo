#!/usr/bin/perl -w

use strict;
use warnings;

use Config;

if( $ENV{NO_XS} ) {
   print "\$ENV{NO_XS} is set - XS code will be disabled\n";
   exit(1) if $ENV{NO_XS};
}

print "Detecting if libc supports getaddrinfo()...\n";

my $test_c   = "test-getaddrinfo.c";
my $test_exe = "test-getaddrinfo";

END {
   defined $test_c   and -f $test_c   and unlink $test_c;
   defined $test_exe and -f $test_exe and unlink $test_exe;
}

my $cc = $Config{cc};
open( my $test_c_fh, "> $test_c" ) or die "Cannot write test.c - $!";

print $test_c_fh <<EOF;
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
int main(int argc, char *argv[]) {
  struct addrinfo hints = { 0 };
  struct addrinfo *res;
  hints.ai_socktype = SOCK_STREAM;
  if(getaddrinfo("127.0.0.1", "80", &hints, &res))
    exit(1);
  freeaddrinfo(res);
  exit(0);
}
EOF

close $test_c_fh;

if( system( $cc, "-o", $test_exe, $test_c ) != 0 ) {
   print "Failed to compile $test_c - XS code will be disabled\n";
   exit(1);
}

print "Compiled $test_exe\n";

if( system( "./$test_exe" ) != 0 ) {
   print "Failed to run $test_exe - XS code will be disabled\n";
   exit(1);
}

print "Successfully ran $test_exe - looks like the libc supports getaddrinfo()\n";
exit(0);
