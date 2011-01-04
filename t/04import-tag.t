#!/usr/bin/perl -w

use strict;

use Test::More tests => 10;

use Socket::GetAddrInfo qw( :Socket6api getaddrinfo );
use Socket qw( SOCK_STREAM AF_INET IPPROTO_TCP );

my @res;

@res = getaddrinfo( "127.0.0.1", "80", 0, SOCK_STREAM, 0, 0 );
is( scalar @res, 5, '@res has 1 result' );

is( $res[0], AF_INET,
   '$res[0] is AF_INET' );
is( $res[1], SOCK_STREAM,
   '$res[1] is SOCK_STREAM' );
ok( $res[2] == 0 || $res[2] == IPPROTO_TCP,
   '$res[2] is 0 or IPPROTO_TCP' );

ok( !defined &AI_NUMERICHOST, 'AI_NUMERICHOST not defined before import' );
Socket::GetAddrInfo->import(qw( :AI ));
ok( defined &AI_NUMERICHOST, 'AI_NUMERICHOST defined after import' );

ok( !defined &NI_NUMERICHOST, 'NI_NUMERICHOST not defined before import' );
Socket::GetAddrInfo->import(qw( :NI ));
ok( defined &NI_NUMERICHOST, 'NI_NUMERICHOST defined after import' );

ok( !defined &EAI_NONAME, 'EAI_NONAME not defined before import' );
Socket::GetAddrInfo->import(qw( :EAI ));
ok( defined &EAI_NONAME, 'EAI_NONAME defined after import' );
