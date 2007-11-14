#!/usr/bin/perl -w

use strict;

use Test::More tests => 51;
use Test::Exception;

use Socket qw( AF_INET AF_UNIX IPPROTO_TCP SOCK_STREAM pack_sockaddr_in unpack_sockaddr_in inet_aton );

use Socket::GetAddrInfo qw( :no_Socket6 getaddrinfo );

use Socket qw( pack_sockaddr_in unpack_sockaddr_in inet_aton );

our $failure_OK = 0;

sub do_test_getaddrinfo
{
   SKIP: {
      my ( $node, $service ) = @_;

      my ( $canonname, $aliases, $addrtype, $length, @addrs ) = gethostbyname( $node );
      my $port = $service ? $service =~ m/^\d+$/ ? $service
                                                 : getservbyname( $service, "" )
                          : 0;

      if( $node and @addrs == 0 ) {
         skip "Resolve error on name $node", 1 unless $failure_OK;
         my $expect_fail = "Name or service not known";

         my @addrinfo = getaddrinfo( $node, $service );
         is( scalar @addrinfo, 1, "scalar \@addrinfo is 1 for error for $node:$service" );

         is( $addrinfo[0], $expect_fail, "\$failure for error for $node:$service" );

         ok( 1, "dummy space filler" ) foreach 1 .. 3;
      }
      elsif( $service and !defined $port ) {
         skip "Resolve error on service $service", 1 unless $failure_OK;
         my $expect_fail = "Servname not supported for ai_socktype";

         my @addrinfo = getaddrinfo( $node, $service );
         is( scalar @addrinfo, 1, "scalar \@addrinfo is 1 for error for $node:$service" );

         is( $addrinfo[0], $expect_fail, "\$failure for error for $node:$service" );

         ok( 1, "dummy space filler" ) foreach 1 .. 3;
      }
      else {
         $addrs[0] = inet_aton( "127.0.0.1" ) unless $node;

         my @addrinfo = getaddrinfo( $node, $service );

         if( scalar @addrinfo % 5 ) {
            fail( "Did not get mod5 results for $node:$service" );

            ok( 1, "dummy space filler" ) foreach 1 .. 4;
         }
         else {
            my ( $family, $type, $proto, $addr, $canonname ) = @addrinfo;

            is( $family, AF_INET, "\$family is AF_INET for $node:$service" );
            is( $type, SOCK_STREAM, "\$type is SOCK_STREAM for $node:$service" );
            is( $proto, IPPROTO_TCP, "\$proto is IPPROTO_TCP for $node:$service" );

            my ( $gotport, $gotsinaddr ) = unpack_sockaddr_in( $addr );

            is( $gotport, $port, "\$addr[port] is $port for $node:$service" );
            is( $gotsinaddr, $addrs[0], "\$addr[sinaddr] for $node:$service" );
         }
      }

   } # end SKIP
}

do_test_getaddrinfo "localhost", "";
do_test_getaddrinfo "127.0.0.1", "";
do_test_getaddrinfo "", "smtp";
do_test_getaddrinfo "", "80";

do_test_getaddrinfo "127.0.0.1", "54";
do_test_getaddrinfo "localhost", "imap";

# Now some tests of a few well-known internet hosts
do_test_getaddrinfo "cpan.perl.org", "ftp";
do_test_getaddrinfo "pause.perl.org", "20";

# Now something I hope doesn't exist - we put it in a known-missing TLD
{ local $failure_OK = 1; do_test_getaddrinfo "something.invalid", "50"; }

# Now something I hope doesn't exist - we put it guess at a named port
{ local $failure_OK = 1; do_test_getaddrinfo "localhost", "ZZgetaddrinfoNameTest"; }

dies_ok( sub { getaddrinfo( "somehost", "someservice", AF_UNIX ) },
         "getaddrinfo on family != AF_INET dies" );
