#!/usr/bin/perl -w

use strict;

use Test::More tests => 6;
use Test::Exception;

use Socket::GetAddrInfo qw( :no_Socket6 getnameinfo NI_NUMERICHOST NI_NUMERICSERV NI_NAMEREQD );

use Socket qw( AF_INET IPPROTO_TCP SOCK_STREAM pack_sockaddr_in pack_sockaddr_un unpack_sockaddr_in inet_aton inet_ntoa );

sub do_test_getnameinfo
{
   SKIP: {
      my ( $addr, $flags ) = @_;
      $flags ||= 0;

      my ( $port, $inetaddr ) = unpack_sockaddr_in( $addr );
      my ( $node ) = $flags & NI_NUMERICHOST ? inet_ntoa( $inetaddr ) 
                                             : gethostbyaddr( $inetaddr, AF_INET );
      my $service = $flags & NI_NUMERICSERV ? "$port"
                                            : getservbyport( $port, "" ) || "$port";

      my @expect;

      if( defined $node ) {
         @expect = ( $node, $service );

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
   my $candidate_inetaddr = inet_aton( "192.168.$_.$_" );

   my $node = gethostbyaddr( $candidate_inetaddr, AF_INET );
   if( defined $node ) {
      next;
   }
   else {
      $addr = pack_sockaddr_in( 80, $candidate_inetaddr );
      $num = $_;
      last;
   }
}

if( defined $addr ) {
   my $service = getservbyport( 80, "" );
   $service = "80" if !defined $service;

   my @nameinfo = getnameinfo( $addr, 0 );

   is_deeply( \@nameinfo, [ "192.168.$num.$num", $service ], "\@nameinfo for getnameinfo unnamed address" );

   @nameinfo = getnameinfo( $addr, NI_NAMEREQD );

   is_deeply( \@nameinfo, [], "\@nameinfo for getnameinfo unnamed address using NI_NAMEREQD" );
}
else {
   SKIP: { skip "Cannot find an IP address without a name in 192.168/24", 2 };
}

dies_ok( sub { getnameinfo( pack_sockaddr_un( "/somepath" ) ) },
         "getnameinfo on family != AF_INET dies" );
