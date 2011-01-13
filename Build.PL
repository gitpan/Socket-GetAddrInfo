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
   eval { ExtUtils::CChecker->VERSION( 0.06 ) } or
      die "OS unsupported - ExtUtils::CChecker too old; need at least 0.06";

   my $cc = ExtUtils::CChecker->new(
      defines_to => "config.h",
   );

   print "\nDetecting if libc supports getaddrinfo()...\n";

   my $headers = <<'EOF';
#include <stdlib.h>
#include <stdio.h>
#ifdef WIN32
#undef WINVER
#define WINVER          0x0501
#ifdef __GNUC__
# define USE_W32_SOCKETS
#endif
#include <winsock2.h>
/* We need to include ws2tcpip.h to get the IPv6 definitions.
 * It will in turn include wspiapi.h.  Later versions of that
 * header in the Windows SDK generate C++ template code that
 * can't be compiled with VC6 anymore.  The _WSPIAPI_COUNTOF
 * definition below prevents wspiapi.h from generating this
 * incompatible code.
 */
# define _WSPIAPI_COUNTOF(_Array) (sizeof(_Array) / sizeof(_Array[0]))
# undef UNICODE
#include <ws2tcpip.h>
#ifndef NI_NUMERICSERV
#error Microsoft Platform SDK (Aug. 2001) or later required.
#endif
#ifdef _MSC_VER
# pragma comment(lib, "Ws2_32.lib")
#endif
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#endif
EOF

   $cc->try_find_libs_for(
      define => "HAS_GETADDRINFO",
      # Solaris et.al. use -lsocket or -lsocket -lnsl
      libs => $^O eq 'MSWin32'
                ? [ "", "ws2_32" ]
                : [ "", "socket", "socket nsl" ],
      source => $headers . <<'EOF' );
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
      define => "HAS_SOCKADDR_SA_LEN",
      source => $headers . <<'EOF' );
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
      'ExtUtils::CChecker' => '0.06',
   },
   build_requires => {
      'ExtUtils::CBuilder' => 0,
      'ExtUtils::CChecker' => '0.06',
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
