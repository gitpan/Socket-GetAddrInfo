#!/usr/bin/perl -w

use strict;
use Test::More tests => 1;

use_ok( "Socket::GetAddrInfo", ':newapi' ); # Tag to avoid the deprecation warning
