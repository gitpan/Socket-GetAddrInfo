use strict;
use warnings;

use Module::Build;

use Config;

sub Configure
{
   if( $ENV{NO_XS} ) {
      print "\$ENV{NO_XS} is set - XS code will be disabled\n";
      return 0;
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
      return 0;
   }

   print "Compiled $test_exe\n";

   if( system( "./$test_exe" ) != 0 ) {
      print "Failed to run $test_exe - XS code will be disabled\n";
      return 0;
   }

   print "Successfully ran $test_exe - looks like the libc supports getaddrinfo()\n";
   return 1;
}

my $CAN_XS = Configure();

my $build = Module::Build->new
  (
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   requires => {
               },
   recommends => {
               },
   build_requires => {
                 'Module::Build' => 0,
                 'Module::Build::Compat' => 0,
                 'Test::More' => 0,
                 'Test::Exception' => 0,
               },
   license => 'perl',
   create_makefile_pl => 'small',

   $CAN_XS ? () : ( xs_files => {} ),
  );

$build->create_build_script;
