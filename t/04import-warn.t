#!/usr/bin/perl -w

use strict;

use Test::More tests => 3;
use Test::Warn;

# Don't 'use' because we're testing warnings produced by import
require Socket::GetAddrInfo;

warning_is { import Socket::GetAddrInfo qw( :newapi getaddrinfo ) }
   [],
   'importing getaddrinfo with tag produces no warning';

undef &getaddrinfo; # avoids redefine warning

warning_like { import Socket::GetAddrInfo qw( getaddrinfo ) }
   [{ carped => qr/^Importing Socket::GetAddrInfo without ':newapi' or ':Socket6api' tag\..*$/s }],
   'importing getaddrinfo without tag produces warning';

warning_like { import Socket::GetAddrInfo qw( AI_PASSIVE ) }
   [],
   'importing AI_PASSIVE without tag produces no warning';
