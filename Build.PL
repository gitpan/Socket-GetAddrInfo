use strict;
use warnings;

use Module::Build;

eval { require ExtUtils::CChecker; 1 } or
   die "OS unsupported - missing ExtUtils::CChecker";

my $HAVE_SOCKADDR_SA_LEN;

sub Configure
{
   if( $ENV{NO_XS} ) {
      print "\$ENV{NO_XS} is set - XS code will be disabled\n";
      return 0;
   }

   my $cc = ExtUtils::CChecker->new();

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

   return 0 unless $cc->try_compile_run( source => $gai_test );

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

   $HAVE_SOCKADDR_SA_LEN = $cc->try_compile_run( source => $sa_len_test );

   return 1;
}

my $CAN_XS = Configure();

my $build = Module::Build->new
  (
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   extra_compiler_flags => [ "-DHAVE_SOCKADDR_SA_LEN=$HAVE_SOCKADDR_SA_LEN" ],
   requires => {
      'XSLoader' => 0,
   },
   configure_requires => {
      'ExtUtils::CChecker' => 0,
   },
   build_requires => {
      'ExtUtils::CChecker' => 0,
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
