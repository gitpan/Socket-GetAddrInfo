#!/usr/bin/perl -w

use strict;

use Test::More tests => 24;
use Test::Exception;

use Socket::GetAddrInfo qw( :newapi getaddrinfo AI_NUMERICHOST EAI_NONAME EAI_SERVICE );

use Socket qw( AF_INET SOCK_STREAM IPPROTO_TCP pack_sockaddr_in inet_aton );

my ( $err, @res );

# Some OSes require a socktype hint when given raw numeric service names
( $err, @res ) = getaddrinfo( "127.0.0.1", "80", { socktype => SOCK_STREAM } );
is( $err+0, 0,  '$err == 0 for host=127.0.0.1/service=80/socktype=STREAM' );
is( "$err", "", '$err eq "" for host=127.0.0.1/service=80/socktype=STREAM' );
is( scalar @res, 1,
   '@res has 1 result' );

is( $res[0]->{family}, AF_INET,
   '$res[0] family is AF_INET' );
is( $res[0]->{socktype}, SOCK_STREAM,
   '$res[0] socktype is SOCK_STREAM' );
ok( $res[0]->{protocol} == 0 || $res[0]->{protocol} == IPPROTO_TCP,
   '$res[0] protocol is 0 or IPPROTO_TCP' );
is( $res[0]->{addr}, pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ),
   '$res[0] addr is {"127.0.0.1", 0}' );

( $err, @res ) = getaddrinfo( "127.0.0.1", "" );
is( $err+0, 0,  '$err == 0 for host=127.0.0.1' );
# Might get more than one; e.g. different socktypes
ok( scalar @res > 0, '@res has results' );

# Just pick the first one
is( $res[0]->{family}, AF_INET,
   '$res[0] family is AF_INET' );
is( $res[0]->{addr}, pack_sockaddr_in( 0, inet_aton( "127.0.0.1" ) ),
   '$res[0] addr is {"127.0.0.1", 0}' );

( $err, @res ) = getaddrinfo( "", "80", { family => AF_INET, socktype => SOCK_STREAM } );
is( $err+0, 0,  '$err == 0 for service=80/family=AF_INET/socktype=STREAM' );
is( scalar @res, 1, '@res has 1 result' );

# Just pick the first one
is( $res[0]->{family}, AF_INET,
   '$res[0] family is AF_INET' );
is( $res[0]->{socktype}, SOCK_STREAM,
   '$res[0] socktype is SOCK_STREAM' );
ok( $res[0]->{protocol} == 0 || $res[0]->{protocol} == IPPROTO_TCP,
   '$res[0] protocol is 0 or IPPROTO_TCP' );

# Now some tests of a few well-known internet hosts

( $err, @res ) = getaddrinfo( "cpan.perl.org", "ftp", { socktype => SOCK_STREAM } );
is( $err+0, 0,  '$err == 0 for host=cpan.perl.org/service=ftp/socktype=STREAM' );
# Might get more than one; e.g. different families
ok( scalar @res > 0, '@res has results' );

# Now something I hope doesn't exist - we put it in a known-missing TLD

( $err, @res ) = getaddrinfo( "something.invalid", "ftp", { socktype => SOCK_STREAM } );
is( $err+0, EAI_NONAME, '$err == EAI_NONAME for host=something.invalid/service=ftp/socktype=SOCK_STREAM' );

# Now something I hope doesn't exist - we put it guess at a named port

( $err, @res ) = getaddrinfo( "127.0.0.1", "ZZgetaddrinfoNameTest", { socktype => SOCK_STREAM } );
is( $err+0, EAI_SERVICE, '$err == EAI_SERVICE for host=127.0.0.1/service=ZZgetaddrinfoNameTest/socktype=SOCK_STREAM' );

# Now check that names with AI_NUMERICHOST fail

( $err, @res ) = getaddrinfo( "localhost", "ftp", { flags => AI_NUMERICHOST, socktype => SOCK_STREAM } );
is( $err+0, EAI_NONAME, '$err == EAI_NONAME for host=localhost/service=ftp/flags=AI_NUMERICHOST/socktype=SOCK_STREAM' );

# Some sanity checking on the hints hash
lives_ok( sub { getaddrinfo( "127.0.0.1", "80", undef ) },
         'getaddrinfo() with undef hints works' );
dies_ok( sub { getaddrinfo( "127.0.0.1", "80", "hints" ) },
         'getaddrinfo() with string hints dies' );
dies_ok( sub { getaddrinfo( "127.0.0.1", "80", [] ) },
         'getaddrinfo() with ARRAY hints dies' );
