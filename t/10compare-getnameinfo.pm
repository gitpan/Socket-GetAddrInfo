#!/usr/bin/perl -w

use strict;

use Test::More;
BEGIN {
   if( defined eval { require Socket6 } ) {
      plan tests => 5;
   }
   else {
      plan skip_all => "No Socket6";
   }
}

use Socket qw( inet_aton pack_sockaddr_in unpack_sockaddr_in );
use Socket::GetAddrInfo qw( :no_Socket6 getnameinfo );

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

sub compare_getnameinfo
{
   my ( $addr, $flags ) = @_;

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

   my @real = Socket6::getnameinfo( $addr, $flags_real );
   my @faked = getnameinfo( $addr, $flags_fake );

   my ( $port, $sinaddr ) = unpack_sockaddr_in( $addr );
   my $sinaddr_str = sprintf( '%vd', $sinaddr );

   if( @faked == 1 and @real == 1 ) {
      # Some form of error - comparing strings will be a futile effort, so
      # just return OK
      ok( 1, "getnameinfo() for $sinaddr_str:$port returns error" );
   }
   elsif( @faked == 1 ) {
      fail( "Faked getnameinfo() for $sinaddr_str:$port returns error but real does not" );
   }
   elsif( @real == 1 ) {
      fail( "Real getnameinfo() for $sinaddr_str:$port returns error but faked does not" );
   }
   else {
      if( -t STDOUT ) {
         # If STDOUT is a terminal, then print more verbose debugging
         my ( $port, $sinaddr ) = unpack_sockaddr_in( $addr );
         print "SINADDR=$sinaddr_str  PORT=$port\n";
         print_sidebyside( \@real, \@faked );
      }

      is_deeply( \@faked, \@real, "getnameinfo() for $sinaddr_str:$port" );
   }
}

compare_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) );
compare_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ), 'NI_NUMERICHOST';
compare_getnameinfo pack_sockaddr_in( 80, inet_aton( "127.0.0.1" ) ), 'NI_NUMERICSERV';

compare_getnameinfo pack_sockaddr_in( 512, inet_aton( "127.0.0.1" ) );
compare_getnameinfo pack_sockaddr_in( 512, inet_aton( "127.0.0.1" ) ), 'NI_DGRAM';
