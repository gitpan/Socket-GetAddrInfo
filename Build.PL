use strict;
use warnings;

use Module::Build;

my $CAN_XS = 1;

if( system( $^X, "Configure.pl" ) != 0 ) {
   $CAN_XS = 0;
}

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
