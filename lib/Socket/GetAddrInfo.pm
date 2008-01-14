#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2007,2008 -- leonerd@leonerd.org.uk

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

our $VERSION = "0.06";

use Carp;

=head1 NAME

C<Socket::GetAddrInfo> - a wrapper for Socket6's C<getaddrinfo> and
C<getnameinfo>, or emulation for platforms that do not support it

=head1 SYNOPSIS

 use Socket::GetAddrInfo qw( getaddrinfo getnameinfo );
 use IO::Socket;

 my $sock;

 my @res = getaddrinfo( "www.google.com", "www" );

 while( @res >= 5 ) {
    my ( $family, $socktype, $proto, $addr, $canonname ) = splice @res, 0, 5;

    $sock = IO::Socket->new();
    $sock->socket( $family, $socktype, $proto ) or undef $sock, next;
    $sock->connect( $addr ) or undef $sock, next;

    last;
 }

 if( $sock ) {
    my ( $host, $service ) = getnameinfo( $sock->peername );
    print "Connected to $host:$service\n";
 }

=head1 DESCRIPTION

The intention of this module is that any code wishing to perform
name-to-address or address-to-name resolutions should use this instead of
using C<Socket6> directly. If the underlying platform has C<Socket6>
installed, then it will be used, and the complete range of features it
provides can be used. If the platform does not support it, then this module
will instead provide emulations of the relevant functions, using the legacy
resolver functions of C<gethostbyname()>, etc... 

These emulations support the same interface as the real C<Socket6> functions,
and behave as close as is resonably possible to emulate using the legacy
functions. See below for details on the limits of this emulation.

Any existing code that already uses C<Socket6> to do this can simply change

 use Socket6 qw( getaddrinfo );

into

 use Socket::GetAddrInfo qw( getaddrinfo );

and require no further changes, in order to be backward-compatible with older
machines that do not or cannot support C<Socket6>.

=cut

# We can't set up the symbols until the first 'import' time, to know if we're
# going to get the :no_Socket6 import flag. But to guard against 'constant
# subroutine redefined ...' warnings, we'll track if we've done it once.
my $DIDSYMBOLS = 0;

sub import
{
   my $class = shift;
   my %symbols = map { $_ => 1 } @_;

   my $can_socket6 = 0;
   $can_socket6 = defined eval { require Socket6 } unless delete $symbols{':no_Socket6'};

   if( not $DIDSYMBOLS ) {
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

      $DIDSYMBOLS = 1;
   }

   local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
   $class->SUPER::import( keys %symbols );
}

# Borrowed from Regexp::Common::net
my $REGEXP_IPv4_DECIMAL = qr/25[0-5]|2[0-4][0-9]|1?[0-9][0-9]{1,2}/;
my $REGEXP_IPv4_DOTTEDQUAD = qr/$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL/;

=head1 LIMITS OF EMULATION

These emulations are not a complete replacement of C<Socket6>, because they
only support IPv4 (the C<AF_INET> socket family).

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

If the sockaddr family of C<$addr> is anything other than C<AF_INET>, an error
will be thrown with C<croak>.

=item *

The only supported C<$flags> values are C<NI_NUMERICHOST>, C<NI_NUMERICSERV>,
C<NI_NAMEREQD> and C<NI_DGRAM>.

=back

=cut

sub _fake_getnameinfo
{
   my ( $addr, $flags ) = @_;

   my ( $port, $inetaddr );
   eval { ( $port, $inetaddr ) = Socket::unpack_sockaddr_in( $addr ) }
      or croak "Cannot emulate getnameinfo() on socket family != AF_INET";

   my $family = Socket::AF_INET();

   $flags ||= 0;

   my $flag_numerichost = $flags & NI_NUMERICHOST(); $flags &= ~NI_NUMERICHOST();
   my $flag_numericserv = $flags & NI_NUMERICSERV(); $flags &= ~NI_NUMERICSERV();
   my $flag_namereqd    = $flags & NI_NAMEREQD();    $flags &= ~NI_NAMEREQD();
   my $flag_dgram       = $flags & NI_DGRAM()   ;    $flags &= ~NI_DGRAM();

   $flags == 0 or croak sprintf "Cannot emulate getnameinfo() with unknown flags 0x%x", $flags;


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
