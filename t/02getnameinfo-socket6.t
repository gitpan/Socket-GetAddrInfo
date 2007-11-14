#!/usr/bin/perl -w

use strict;

use Test::More;
BEGIN {
   if( defined eval { require Socket6 } ) {
      import Socket6 qw( NI_NAMEREQD );
      plan tests => 5;
   }
   else {
      plan skip_all => "No Socket6";
   }
}

use Socket::GetAddrInfo qw( getnameinfo NI_NUMERICHOST NI_NUMERICSERV NI_NAMEREQD );

use Socket qw( pack_sockaddr_in inet_aton );

our $failure_OK = 0;

sub do_test_getnameinfo
{
   SKIP: {
      my ( $addr, $flags ) = @_;
      $flags ||= 0;

      my @expect = Socket6::getnameinfo( $addr, $flags );

      if( @expect ) {
         my @nameinfo = getnameinfo( $addr, $flags );

         is_deeply( \@nameinfo, \@expect, "\@nameinfo for getnameinfo" );
      }
      else {
         print "Nameinfo failed on address\n";
      }
   }
}

do_test_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) );
do_test_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ), NI_NUMERICHOST;
do_test_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ), NI_NUMERICSERV;

# This is hard. We need to find an IP address we can guarantee will not have
# a name. Simple solution is to find one.

my $addr;
my $num;

foreach ( 1 .. 254 ) {
   my $candidate_addr = pack_sockaddr_in( 80, inet_aton( "192.168.$_.$_" ) );

   my @nameinfo = Socket6::getnameinfo( $candidate_addr, NI_NAMEREQD );
   if( @nameinfo ) {
      next;
   }
   else {
      $addr = $candidate_addr;
      $num = $_;
      last;
   }
}

if( defined $addr ) {
   my ( undef, $service ) = Socket6::getnameinfo( pack_sockaddr_in( 80, inet_aton( "0.0.0.0" ) ) );
   $service = "80" if !defined $service;

   my @nameinfo = getnameinfo( $addr, 0 );

   is_deeply( \@nameinfo, [ "192.168.$num.$num", $service ], "\@nameinfo for getnameinfo unnamed address" );

   @nameinfo = getnameinfo( $addr, NI_NAMEREQD );

   is_deeply( \@nameinfo, [], "\@nameinfo for getnameinfo unnamed address using NI_NAMEREQD" );
}
else {
   SKIP: { skip "Cannot find an IP address without a name in 192.168/24", 2 };
}
