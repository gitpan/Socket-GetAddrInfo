use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new
  (
   module_name => 'Socket::GetAddrInfo',
   dist_version_from => 'lib/Socket/GetAddrInfo.pm',
   requires => {
                 # We need a version of Socket new enough to have sockaddr_family
                 # 1.72 (perl 5.6.1) is too old
                 # 1.75 (perl 5.8.0) is new enough
                 'Socket' => 1.75,
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
