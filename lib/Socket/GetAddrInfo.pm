#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2007 -- leonerd@leonerd.org.uk

package Socket::GetAddrInfo;

use strict;

use Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw(
   getaddrinfo
   getnameinfo

   AI_PASSIVE
   AI_CANONNAME
   AI_NUMERICHOST

   NI_NUMERICHOST
   NI_NUMERICSERV
   NI_NAMEREQD
   NI_DGRAM
);

our $VERSION = "0.02";

use Carp;

=head1 NAME

C<Socket::GetAddrInfo> - a wrapper for Socket6's C<getaddrinfo> and
C<getaddrinfo>, or emulation for platforms that do not support it

=head1 SYNOPSIS

 use Socket::GetAddrInfo qw( getaddrinfo getnameinfo );
 use IO::Socket;

 my $sock;

 my @res = getaddrinfo( "www.google.com", "www" );

 while( @res >= 5 ) {
    my ( $family, $socktype, $proto, $addr, $canonname ) = splice @res, 0, 5;

    $sock = IO::Socket->new();
    $sock->socket( $family, $socktype, $proto ) or next;
    $sock->connect( $addr ) or next;
 }

 if( $sock ) {
    my ( $host, $service ) = getnameinfo( $sock->peername );
    print "Connected to $host:$service\n";
 }

=head1 DESCRIPTION

This module provides access to the C<getaddrinfo> and C<getnameinfo> functions
of L<Socket6> on systems that have C<Socket6> installed, or provides
emulations of them using the "legacy" functions such as C<gethostbyname()> on
systems that do not.

These emulations are not a complete replacement of C<Socket6>, because they
only support IPv4 (the C<AF_INET> socket family). They do, however, implement
the same interface as the C<Socket6> functions, so any code written to use
this module can be used on systems that do not support C<Socket6>, but will
automatically make use of the extended abilities of C<Socket6> on systems that
do support it.

=cut

sub import
{
   my $class = shift;
   my %symbols = map { $_ => 1 } @_;

   my $can_socket6 = 0;
   $can_socket6 = defined eval { require Socket6 } unless delete $symbols{':no_Socket6'};

   if( $can_socket6 ) {
      import Socket6 @EXPORT;
   }
   else {
      require Socket;

      require constant;

      import constant AI_PASSIVE     => 1;
      import constant AI_CANONNAME   => 2;
      import constant AI_NUMERICHOST => 4;

      import constant NI_NUMERICHOST => 1;
      import constant NI_NUMERICSERV => 2;
      import constant NI_NAMEREQD    => 8;
      import constant NI_DGRAM       => 16;

      *getaddrinfo = \&_fake_getaddrinfo;
      *getnameinfo = \&_fake_getnameinfo;
   }

   local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
   $class->SUPER::import( keys %symbols );
}

# Borrowed from Regexp::Common::net
my $REGEXP_IPv4_DECIMAL = qr/25[0-5]|2[0-4][0-9]|1?[0-9][0-9]{1,2}/;
my $REGEXP_IPv4_DOTTEDQUAD = qr/$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL/;

=head1 LIMITS OF EMULATION

=cut

=head2 @res = getaddrinfo( $node, $service, $family, $socktype, $protocol, $flags )

=over 4

=item *

If C<$family> is supplied, it must be C<AF_INET>. Any other value will result
in an error thrown by C<croak>.

=item *

The only supported C<$flags> values are C<AI_PASSIVE>, C<AI_CANONNAME> and
C<AI_NUMERICHOST>.

=back

=cut

sub _fake_getaddrinfo
{
   my ( $node, $service, $family, $socktype, $protocol, $flags ) = @_;

   $node = "" unless defined $node;

   $service = "" unless defined $service;

   $family = Socket::AF_INET() unless defined $family;
   $family == Socket::AF_INET() or croak "Cannot emulate getaddrinfo() on family $family";

   $socktype ||= 0;

   $protocol ||= 0;

   $flags ||= 0;

   my $flag_passive     = $flags & AI_PASSIVE();     $flags &= ~AI_PASSIVE();
   my $flag_canonname   = $flags & AI_CANONNAME();   $flags &= ~AI_CANONNAME();
   my $flag_numerichost = $flags & AI_NUMERICHOST(); $flags &= ~AI_NUMERICHOST();

   $flags == 0 or croak sprintf "Cannot emulate getaddrinfo() with unknown flags 0x%x", $flags;

   return "Name or service not known" if( $node eq "" and $service eq "" );

   my $canonname;
   my @addrs;
   if( $node ne "" ) {
      return "Name or service not known" if( $flag_numerichost and $node !~ m/^$REGEXP_IPv4_DOTTEDQUAD$/ );
      ( $canonname, undef, undef, undef, @addrs ) = gethostbyname( $node );
      defined $canonname or return "Name or service not known";

      undef $canonname unless $flag_canonname;
   }
   else {
      $addrs[0] = $flag_passive ? Socket::inet_aton( "0.0.0.0" )
                                : Socket::inet_aton( "127.0.0.1" );
   }

   my @ports; # Actually ARRAYrefs of [ socktype, protocol, port ]
   my $protname = "";
   if( $protocol ) {
      $protname = getprotobynumber( $protocol );
   }

   if( $service ne "" and $service !~ m/^\d+$/ ) {
      getservbyname( $service, $protname ) or return "Servname not supported for ai_socktype";
   }

   foreach my $this_socktype ( Socket::SOCK_STREAM(), Socket::SOCK_DGRAM(), Socket::SOCK_RAW() ) {
      next if $socktype and $this_socktype != $socktype;

      my $this_protname = "raw";
      $this_socktype == Socket::SOCK_STREAM() and $this_protname = "tcp";
      $this_socktype == Socket::SOCK_DGRAM()  and $this_protname = "udp";

      next if $protname and $this_protname ne $protname;

      my $port;
      if( $service ne "" ) {
         if( $service =~ m/^\d+$/ ) {
            $port = "$service";
         }
         else {
            ( undef, undef, $port, $this_protname ) = getservbyname( $service, $this_protname );
            next unless defined $port;
         }
      }
      else {
         $port = 0;
      }

      push @ports, [ $this_socktype, scalar getprotobyname( $this_protname ) || 0, $port ];
   }

   my @ret;
   foreach my $addr ( @addrs ) {
      foreach my $portspec ( @ports ) {
         my ( $socktype, $protocol, $port ) = @$portspec;
         push @ret, $family, $socktype, $protocol, Socket::pack_sockaddr_in( $port, $addr ), $canonname;
      }
   }

   return @ret;
}

=head2 ( $node, $service ) = getnameinfo( $addr, $flags )

=over 4

=item *

If the sockaddr family of C<$addr> is C<AF_INET>, an error will be thrown with
C<croak>.

=item *

The only supported C<$flags> values are C<NI_NUMERICHOST>, C<NI_NUMERICSERV>,
C<NI_NAMEREQD> and C<NI_DGRAM>.

=back

=cut

sub _fake_getnameinfo
{
   my ( $addr, $flags ) = @_;

   my $family = Socket::sockaddr_family( $addr );
   $family == Socket::AF_INET() or croak "Cannot emulate getnameinfo() on family $family";

   $flags ||= 0;

   my $flag_numerichost = $flags & NI_NUMERICHOST(); $flags &= ~NI_NUMERICHOST();
   my $flag_numericserv = $flags & NI_NUMERICSERV(); $flags &= ~NI_NUMERICSERV();
   my $flag_namereqd    = $flags & NI_NAMEREQD();    $flags &= ~NI_NAMEREQD();
   my $flag_dgram       = $flags & NI_DGRAM()   ;    $flags &= ~NI_DGRAM();

   $flags == 0 or croak sprintf "Cannot emulate getnameinfo() with unknown flags 0x%x", $flags;

   my ( $port, $inetaddr ) = Socket::unpack_sockaddr_in( $addr );

   my $node;
   if( $flag_numerichost ) {
      $node = Socket::inet_ntoa( $inetaddr );
   }
   else {
      $node = gethostbyaddr( $inetaddr, $family );
      if( !defined $node ) {
         return () if $flag_namereqd;
         $node = Socket::inet_ntoa( $inetaddr );
      }
   }

   my $service;
   if( $flag_numericserv ) {
      $service = "$port";
   }
   else {
      my $protname = $flag_dgram ? "udp" : "";
      $service = getservbyport( $port, $protname );
      if( !defined $service ) {
         $service = "$port";
      }
   }

   return ( $node, $service );
}

# Keep perl happy; keep Britain tidy
1;

__END__

=head1 SEE ALSO

=over 4

=item *

L<Socket6> - IPv6 related part of the C socket.h defines and structure
manipulators

=back

=head1 AUTHOR

Paul Evans E<lt>leonerd@leonerd.org.ukE<gt>
