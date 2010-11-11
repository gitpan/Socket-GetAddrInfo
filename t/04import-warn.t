#!/usr/bin/perl -w

use strict;

use Test::More tests => 4;

# Don't 'use' because we're testing warnings produced by import
require Socket::GetAddrInfo;

# Don't use Test::Warn so we don't pull in non-core deps
my @warnings;
$SIG{__WARN__} = sub { push @warnings, @_ };

undef @warnings;
import Socket::GetAddrInfo qw( :newapi getaddrinfo );
is_deeply( \@warnings,
   [],
   'importing getaddrinfo with tag produces no warning' );

undef &getaddrinfo; # avoids redefine warning

undef @warnings;
import Socket::GetAddrInfo qw( getaddrinfo );
is( scalar @warnings, 1, 'importing getaddrinfo without tag produces 1 warning' );
like( $warnings[0], qr/^Importing Socket::GetAddrInfo without ':newapi' or ':Socket6api' tag\..*$/s,
   'importing getaddrinfo without tag produces correct warning' );

undef @warnings;
import Socket::GetAddrInfo qw( AI_PASSIVE );
is_deeply( \@warnings,
   [],
   'importing AI_PASSIVE without tag produces no warning' );
