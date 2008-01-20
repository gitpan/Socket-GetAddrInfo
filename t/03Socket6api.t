#!/usr/bin/perl -w

use strict;

use Test::More no_plan => 1;

use Socket::GetAddrInfo qw( :Socket6api getaddrinfo getnameinfo NI_NUMERICHOST NI_NUMERICSERV );
use Socket qw( AF_INET SOCK_STREAM IPPROTO_TCP pack_sockaddr_in inet_aton );

my @res;

@res = getaddrinfo( "127.0.0.1", "80", 0, SOCK_STREAM, 0, 0 );
is( scalar @res, 5, '@res has 1 result' );

is( $res[0], AF_INET,
   '$res[0] is AF_INET' );
is( $res[1], SOCK_STREAM,
   '$res[1] is SOCK_STREAM' );
ok( $res[2] == 0 || $res[2] == IPPROTO_TCP,
   '$res[2] is 0 or IPPROTO_TCP' );
is( $res[3], pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ),
   '$res[3] is { "127.0.0.1", 80 }' );

@res = getaddrinfo( "something.invalid", 80, 0, SOCK_STREAM, 0, 0 );
is( scalar @res, 1, '@res contains an error' );

my ( $host, $service ) = getnameinfo( pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ), NI_NUMERICHOST|NI_NUMERICSERV );
is( $host, "127.0.0.1", '$host is 127.0.0.1' );
is( $service, "80", '$service is 80' );
