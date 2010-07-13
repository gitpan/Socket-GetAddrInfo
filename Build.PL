use strict;
use warnings;

use Module::Build;

eval { require ExtUtils::CChecker; 1 } or
   die "OS unsupported - missing ExtUtils::CChecker";
eval { ExtUtils::CChecker->VERSION( 0.04 ) } or
   die "OS unsupported - ExtUtils::CChecker too old; need at least 0.04";

my $cc = ExtUtils::CChecker->new();

my $CAN_XS = 0;
my $HAVE_SOCKADDR_SA_LEN;

TRY_XS: {
   if( $ENV{NO_XS} ) {
      print "\$ENV{NO_XS} is set - XS code will be disabled\n";
      last TRY_XS;
   }

   print "\nDetecting if libc supports getaddrinfo()...\n";

   last TRY_XS unless $cc->try_find_libs_for(
      # Solaris et.al. use -lsocket or -lsocket -lnsl
      libs => [ "", "socket", "socket nsl" ],
      source => <<'EOF' );
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

   $CAN_XS = 1;

   print "\nLooks like the libc supports getaddrinfo()\n";

   print "Detecting if sockaddr has sa_len field...\n";

   $cc->try_compile_run(
      define => "HAVE_SOCKADDR_SA_LEN",
      source => <<'EOF' );
#include <stdlib.h>
#include <sys/types.h>
#include <sys/socket.h>
int main(int argc, char *argv[]) {
   struct sockaddr sa;
   sa.sa_len = 0;
   return 0;
}
EOF
}

my $build = $cc->new_module_build(
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   requires => {
      'XSLoader' => 0,
   },
   configure_requires => {
      'ExtUtils::CChecker' => '0.04',
   },
   build_requires => {
      'ExtUtils::CChecker' => '0.04',
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
