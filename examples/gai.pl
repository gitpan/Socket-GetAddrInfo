#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Socket qw( AF_INET SOCK_STREAM SOCK_DGRAM inet_ntoa unpack_sockaddr_in );
use constant CAN_IPv6 => eval { require Socket6 };
use Socket::GetAddrInfo qw( getaddrinfo :newapi AI_PASSIVE );

my $host;
my $service;
my %hints;

GetOptions(
   'host=s'    => \$host,
   'service=s' => \$service,

   '4' => sub { $hints{family} = AF_INET },
   '6' => sub { CAN_IPv6 ? $hints{family} = Socket::AF_INET6()
                         : die "Cannot do AF_INET6\n"; },

   'stream' => sub { $hints{socktype} = SOCK_STREAM },
   'dgram'  => sub { $hints{socktype} = SOCK_DGRAM },

   'proto=s' => sub {
      my $proto = $_[1];
      unless( $proto =~ m/^\d+$/ ) {
         my $protonum = getprotobyname( $proto );
         defined $protonum or die "No such protocol - $proto\n";
         $proto = $protonum;
      }
      $hints{protocol} = $proto;
   },

   'passive' => sub { $hints{flags} ||= AI_PASSIVE },
) or exit 1;

$host    = shift @ARGV if @ARGV and !defined $host;
$service = shift @ARGV if @ARGV and !defined $service;

my ( $err, @res ) = getaddrinfo( $host || "", $service || "0", \%hints );

die "Cannot getaddrinfo() - $err\n" if $err;

foreach my $res ( @res ) {
   my $address_string;
   if( $res->{family} == AF_INET ) {
      my ( $port, $host ) = unpack_sockaddr_in $res->{addr};
      $address_string = sprintf "%s:%d", inet_ntoa( $host ), $port;
   }
   elsif( CAN_IPv6 and $res->{family} == Socket6::AF_INET6() ) {
      my ( $port, $host ) = Socket6::unpack_sockaddr_in6( $res->{addr} );
      $address_string = sprintf "[%s]:%d", Socket6::inet_ntop( $res->{family}, $host ), $port;
   }
   else {
      $address_string = sprintf '{family=%d,addr=%v02x}', $res->{family}, $res->{addr};
   }

   printf "family=%d socktype=%d proto=%d addr=%s\n",
      $res->{family}, $res->{socktype}, $res->{protocol}, $address_string;
}
