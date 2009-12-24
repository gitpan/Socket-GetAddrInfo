use strict;
use warnings;

use Module::Build;

eval { require ExtUtils::CBuilder; 1 } or
   die "OS unsupported - missing ExtUtils::CBuilder";

my $HAVE_SOCKADDR_SA_LEN;

sub try_compile_run
{
   my ( $cbuilder, $name, $source ) = @_;

   my $test_source = "test-$name.c";

   open( my $test_source_fh, "> $test_source" ) or die "Cannot write $test_source - $!";

   print $test_source_fh $source;

   close $test_source_fh;

   my $test_obj = eval { $cbuilder->compile( source => $test_source ) };

   unlink $test_source;

   if( not defined $test_obj ) {
      print "\nFailed to compile $test_source\n";
      return 0;
   }

   print "Compiled $test_source to $test_obj\n\n";

   my $test_exe = eval { $cbuilder->link_executable( objects => $test_obj ) };
   END { defined $test_exe and -f $test_exe and unlink $test_exe; }

   unlink $test_obj;

   if( not defined $test_exe ) {
      print "\nFailed to link $test_obj to an executable\n";
      return 0;
   }

   print "Linked $test_obj to $test_exe\n\n";

   if( system( "./$test_exe" ) != 0 ) {
      print "\nFailed to run $test_exe\n";
      unlink $test_exe;
      return 0;
   }

   unlink $test_exe;

   return 1;
}

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

   my $gai_test = <<EOF;
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
int main(int argc, char *argv[]) {
  struct addrinfo hints = { 0 };
  struct addrinfo *res;
  hints.ai_socktype = SOCK_STREAM;
  if(getaddrinfo("127.0.0.1", "80", &hints, &res))
    return 1;
  freeaddrinfo(res);
  return 0;
}
EOF

   return 0 unless try_compile_run( $cbuilder, "getaddrinfo", $gai_test );

   print "\nLooks like the libc supports getaddrinfo()\n";

   print "Detecting if sockaddr has sa_len field...\n";

   my $sa_len_test = <<EOF;
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
int main(int argc, char *argv[]) {
   struct sockaddr sa;
   sa.sa_len = 0;
   return 0;
}
EOF

   $HAVE_SOCKADDR_SA_LEN = try_compile_run( $cbuilder, "sa_len", $sa_len_test );

   return 1;
}

my $CAN_XS = Configure();

my $build = Module::Build->new
  (
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   extra_compiler_flags => [ "-DHAVE_SOCKADDR_SA_LEN=$HAVE_SOCKADDR_SA_LEN" ],
   requires => {
               },
   recommends => {
               },
   configure_requires => {
                 'ExtUtils::CBuilder' => 0,
   },
   build_requires => {
                 'ExtUtils::CBuilder' => 0,
                 'Module::Build' => 0,
                 'Module::Build::Compat' => 0,
                 'Scalar::Util' => 0,
                 'Test::More' => 0,
                 'Test::Exception' => 0,
                 'Test::Warn' => 0,
               },
   license => 'perl',
   create_makefile_pl => 'small',
   create_license => 1,
   create_readme  => 1,

   $CAN_XS ? () : ( xs_files => {} ),
  );

$build->create_build_script;
