#!/usr/bin/perl -w

use strict;
use Test::More tests => 2;

use_ok( "Socket::GetAddrInfo" );
use_ok( "Socket::GetAddrInfo::Socket6api" );

# Declare which case is being used; can be useful in test reports

if( defined $Socket::GetAddrInfo::PP::VERSION ) {
   diag "Using emulation using legacy resolvers";
}
else {
   diag "Using native getaddrinfo(3)";
}
