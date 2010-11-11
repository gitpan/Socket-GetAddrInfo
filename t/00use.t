#!/usr/bin/perl -w

use strict;
use Test::More tests => 1;

use_ok( "Socket::GetAddrInfo", ':newapi' ); # Tag to avoid the deprecation warning

# Declare which case is being used; can be useful in test reports

if( \&Socket::GetAddrInfo::getaddrinfo == \&Socket::GetAddrInfo::fake_getaddrinfo ) {
   diag "Using emulation using legacy resolvers";
}
else {
   diag "Using native getaddrinfo(3)";
}
