use strict;
use warnings;

use Module::Build;

use ExtUtils::CBuilder;

sub Configure
{
   if( $ENV{NO_XS} ) {
      print "\$ENV{NO_XS} is set - XS code will be disabled\n";
      return 0;
   }

   my $cbuilder = ExtUtils::CBuilder->new();

   print "Detecting if the environment has a C compiler...\n";
   return 0 unless $cbuilder->have_compiler;

   print "\nDetecting if libc supports getaddrinfo()...\n";

   my $test_source = "test-getaddrinfo.c";

   open( my $test_source_fh, "> $test_source" ) or die "Cannot write $test_source - $!";
   END { defined $test_source and -f $test_source and unlink $test_source; }

   print $test_source_fh <<EOF;
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

   close $test_source_fh;

   my $test_obj = eval { $cbuilder->compile( source => $test_source ) };
   END { defined $test_obj and -f $test_obj and unlink $test_obj; }

   if( not defined $test_obj ) {
      print "\nFailed to compile $test_source - XS code will be disabled\n";
      return 0;
   }

   print "Compiled $test_source to $test_obj\n\n";

   my $test_exe = eval { $cbuilder->link_executable( objects => $test_obj ) };
   END { defined $test_exe and -f $test_exe and unlink $test_exe; }

   if( not defined $test_exe ) {
      print "\nFailed to link $test_obj to an executable - XS code will be disabled\n";
      return 0;
   }

   print "Linked $test_obj to $test_exe\n\n";

   if( system( "./$test_exe" ) != 0 ) {
      print "\nFailed to run $test_exe - XS code will be disabled\n";
      return 0;
   }

   print "\nSuccessfully ran $test_exe - looks like the libc supports getaddrinfo()\n";
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
                 'ExtUtils::CBuilder' => 0,
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
