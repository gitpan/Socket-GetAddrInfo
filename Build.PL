use strict;
use warnings;

use Module::Build;
use ExtUtils::CBuilder;

my $extra_compiler_flags;
my $extra_linker_flags;
my $no_xs;

if( ExtUtils::CBuilder->new->have_compiler ) {
   eval { require ExtUtils::CChecker; 1 } or
      die "OS unsupported - missing ExtUtils::CChecker";
   eval { ExtUtils::CChecker->VERSION( 0.04 ) } or
      die "OS unsupported - ExtUtils::CChecker too old; need at least 0.04";

   my $cc = ExtUtils::CChecker->new();

   print "\nDetecting if libc supports getaddrinfo()...\n";

   $cc->try_find_libs_for(
      define => "HAVE_GETADDRINFO",
      # Solaris et.al. use -lsocket or -lsocket -lnsl
      libs => [ "", "socket", "socket nsl", "ws2_32" ],
      source => <<'EOF' );
#include <stdlib.h>
#include <stdio.h>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#endif

int main(int argc, char *argv[]) {
  struct addrinfo hints = { 0 };
  struct addrinfo *res;
  int rc;
#ifdef _WIN32
  WSADATA wsadata;
  rc = WSAStartup(MAKEWORD(2, 0), &wsadata);
  if (rc != 0) {
    printf("WSAStartup() failed: %d\n", rc);
    return 1;
  }
#endif
  hints.ai_socktype = SOCK_STREAM;
  rc = getaddrinfo("127.0.0.1", "80", &hints, &res);
  if (rc != 0) {
    printf("getaddrinfo() failed: %d\n", rc);
    return 1;
  }
  freeaddrinfo(res);
  return 0;
}
EOF

   print "Detecting if sockaddr has sa_len field...\n";

   $cc->try_compile_run(
      define => "HAVE_SOCKADDR_SA_LEN",
      source => <<'EOF' );
#include <stdlib.h>
#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#endif
int main(int argc, char *argv[]) {
   struct sockaddr sa;
   sa.sa_len = 0;
   return 0;
}
EOF

   $extra_compiler_flags = $cc->extra_compiler_flags;
   $extra_linker_flags = $cc->extra_linker_flags;
}
else {
   $no_xs = 1;
}

my $build = Module::Build->new(
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   requires => {
      'XSLoader' => 0,
   },
   configure_requires => {
      'ExtUtils::CBuilder' => 0,
      'ExtUtils::CChecker' => '0.04',
   },
   build_requires => {
      'ExtUtils::CBuilder' => 0,
      'ExtUtils::CChecker' => '0.04',
      'Module::Build' => 0,
      'Module::Build::Compat' => 0,
      'Scalar::Util' => 0,
      'Test::More' => 0,
   },
   extra_compiler_flags => $extra_compiler_flags,
   extra_linker_flags => $extra_linker_flags,
   ( $no_xs ? ( xs_files => {} ) : () ),
   license => 'perl',
   create_makefile_pl => 'small',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
