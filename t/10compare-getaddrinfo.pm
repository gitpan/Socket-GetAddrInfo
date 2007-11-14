#!/usr/bin/perl -w

use strict;

use Test::More;
BEGIN {
   if( defined eval { require Socket6 } ) {
      plan tests => 13;
   }
   else {
      plan skip_all => "No Socket6";
   }
}

use Socket qw( AF_INET SOCK_DGRAM );
use Socket::GetAddrInfo qw( :no_Socket6 getaddrinfo );

sub sprint_scalar
{
   my ( $s ) = @_;

   return "undef" unless defined $s;

   $s =~ s{([^\x20-\x7e])}{sprintf "\\x%02x", ord $1}eg;
   return qq{"$s"};
}

sub longest
{
   my $len = 0;
   length > $len and $len = length foreach @_;
   $len;
}

sub print_sidebyside
{
   my ( $aref, $bref ) = @_;

   my @a = map { sprint_scalar( $_ ) } @$aref;
   my @b = map { sprint_scalar( $_ ) } @$bref;

   my $longest_a = longest @a;

   printf "%${longest_a}s  |  %s\n", "REAL", "FAKE";

   foreach my $i ( 0 .. $#a ) {
      my $sep = ($a[$i]||"") eq ($b[$i]||"") ? " | " : "<=>";
      printf "%${longest_a}s $sep %s\n", $a[$i], $b[$i] || "missing";
   }

   foreach my $i ( scalar @a .. $#b ) {
      printf "%${longest_a}s <=> %s\n", "missing", $b[$i];
   }

   print "\n";
}

sub compare_getaddrinfo
{
   my ( $node, $service, $type, $proto, $flags ) = @_;

   $type ||= 0;
   $proto ||= 0;

   $flags ||= "";

   # Real platform (aka Socket6) and Socket::GetAddrInfo probably have
   # different ideas about the bitfields. Construct them portablly by name
   my $flags_real = 0;
   my $flags_fake = 0;

   {
      no strict 'refs';
      $flags_real ||= "Socket6::$_"->() foreach split( m/,/, $flags );
      $flags_fake ||= "Socket::GetAddrInfo::$_"->() foreach split( m/,/, $flags );
   }

   my @real = Socket6::getaddrinfo( $node, $service, AF_INET, $type, $proto, $flags_real );
   my @faked = getaddrinfo( $node, $service, AF_INET, $type, $proto, $flags_fake );

   if( @faked == 1 and @real == 1 ) {
      # Some form of error - comparing strings will be a futile effort, so
      # just return OK
      ok( 1, "getaddrinfo() for $node:$service returns error" );
   }
   elsif( @faked == 1 ) {
      fail( "Faked getaddrinfo() for $node:$service returns error but real does not" );
   }
   elsif( @real == 1 ) {
      fail( "Real getaddrinfo() for $node:$service returns error but faked does not" );
   }
   else {
      if( -t STDOUT ) {
         # If STDOUT is a terminal, then print more verbose debugging
         print "NODE=$node  SERVICE=$service\n";
         print_sidebyside( \@real, \@faked );
      }

      is_deeply( \@faked, \@real, "getaddrinfo() for $node:$service" );
   }
}

# Failure test
compare_getaddrinfo "", "";

compare_getaddrinfo "localhost", "";
compare_getaddrinfo "127.0.0.1", "";
compare_getaddrinfo "", "smtp";
compare_getaddrinfo "", "80";

# More failures
compare_getaddrinfo "localhost", "53", undef, undef, 'AI_NUMERICHOST';

# Some UDP tests
compare_getaddrinfo "127.0.0.1", "53", SOCK_DGRAM;
compare_getaddrinfo "127.0.0.1", "53", undef, scalar getprotobyname("udp");

compare_getaddrinfo "127.0.0.1", "54";
compare_getaddrinfo "localhost", "imap";

# Now some tests of a few well-known internet hosts
compare_getaddrinfo "cpan.perl.org", "ftp";
compare_getaddrinfo "pause.perl.org", "20";

# Now try with AI_PASSIVE - use a numbered service so we're sure it'll work
compare_getaddrinfo "", "22", undef, undef, 'AI_PASSIVE';
