use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   dist_abstract     => "a wrapper for Socket6's getaddrinfo() and getaddrinfo(), or emulation",
   requires => {
               },
   recommends => {
               },
   build_requires => {
                 'Test::More' => 0,
               },
   license => 'perl',
   create_makefile_pl => 'traditional',
  );

$build->create_build_script;
