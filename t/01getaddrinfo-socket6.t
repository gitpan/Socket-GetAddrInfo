#!/usr/bin/perl -w

use strict;

use Test::More;
BEGIN {
   if( defined eval { require Socket6 } ) {
      plan tests => 20;
   }
   else {
      plan skip_all => "No Socket6";
   }
}

use Socket::GetAddrInfo qw( getaddrinfo );

use Socket qw( pack_sockaddr_in inet_aton );

our $failure_OK = 0;

sub do_test_getaddrinfo
{
   SKIP: {
      my ( $node, $service ) = @_;

      my @expect = Socket6::getaddrinfo( $node, $service );

      if( @expect == 0 ) {
         print "Name not known - $node\n";
      }
      elsif( @expect == 1 ) {
         skip "Resolve error $expect[0] - $node", 2 unless $failure_OK;
         my $expect_fail = $expect[0];

         my @addrinfo = getaddrinfo( $node, $service );
         is( scalar @addrinfo, 1, "scalar \@addrinfo is 1 for error for $node:$service" );

         is( $addrinfo[0], $expect_fail, "\$failure for error for $node:$service" );
      }
      else {
         my @addrinfo = getaddrinfo( $node, $service );

         is_deeply( \@addrinfo, \@expect, "\@addrinfo for $node:$service" );
         ok( 1, "dummy space filler" ); # To make sure both ways take the same number of tests
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
