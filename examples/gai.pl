#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use Socket;
eval { require Socket6 };
use Socket::GetAddrInfo qw( getaddrinfo :newapi AI_PASSIVE );

my $host;
my $service;
my %hints;

GetOptions(
   'host=s'    => \$host,
   'service=s' => \$service,

   '4' => sub { $hints{family} = AF_INET },
   '6' => sub { defined \&Socket6::AF_INET6 ? $hints{family} = Socket::AF_INET6()
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

my ( $err, @addrs ) = getaddrinfo( $host || "", $service || "0", \%hints );

die "Cannot getaddrinfo() - $err\n" if $err;

foreach my $addr ( @addrs ) {
   printf "family=%d socktype=%d proto=%d addr=%v02x\n",
      $addr->{family}, $addr->{socktype}, $addr->{protocol}, $addr->{addr};
}
