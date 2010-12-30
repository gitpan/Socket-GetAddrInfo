#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2007-2010 -- leonerd@leonerd.org.uk

package Socket::GetAddrInfo;

use strict;
use warnings;

use Carp;

our $VERSION = '0.19_002';

our @EXPORT = qw(
   getaddrinfo
   getnameinfo
);

require XSLoader;
eval { XSLoader::load(__PACKAGE__, $VERSION ) };

if( !defined &getaddrinfo ) {
   require Socket::GetAddrInfo::PP;
   Socket::GetAddrInfo::PP->import;

   no warnings 'once';
   push @EXPORT, @Socket::GetAddrInfo::PP::EXPORT;
}

=head1 NAME

C<Socket::GetAddrInfo> - RFC 2553's C<getaddrinfo> and C<getnameinfo>
functions.

=head1 SYNOPSIS

 use Socket qw( SOCK_STREAM );
 use Socket::GetAddrInfo qw( :newapi getaddrinfo getnameinfo );
 use IO::Socket;

 my $sock;

 my %hints = ( socktype => SOCK_STREAM );
 my ( $err, @res ) = getaddrinfo( "www.google.com", "www", \%hints );

 die "Cannot resolve name - $err" if $err;

 while( my $ai = shift @res ) {

    $sock = IO::Socket->new();
    $sock->socket( $ai->{family}, $ai->{socktype}, $ai->{protocol} ) or
       undef $sock, next;

    $sock->connect( $ai->{addr} ) or undef $sock, next;

    last;
 }

 if( $sock ) {
    my ( $err, $host, $service ) = getnameinfo( $sock->peername );
    print "Connected to $host:$service\n" if !$err;
 }

=head1 DESCRIPTION

The RFC 2553 functions C<getaddrinfo> and C<getnameinfo> provide an abstracted
way to convert between a pair of host name/service name and socket addresses,
or vice versa. C<getaddrinfo> converts names into a set of arguments to pass
to the C<socket()> and C<connect()> syscalls, and C<getnameinfo> converts a
socket address back into its host name/service name pair.

These functions provide a useful interface for performing either of these name
resolution operation, without having to deal with IPv4/IPv6 transparency, or
whether the underlying host can support IPv6 at all, or other such issues.
However, not all platforms can support the underlying calls at the C layer,
which means a dilema for authors wishing to write forward-compatible code.
Either to support these functions, and cause the code not to work on older
platforms, or stick to the older "legacy" resolvers such as
C<gethostbyname()>, which means the code becomes more portable.

This module attempts to solve this problem, by detecting at compiletime
whether the underlying OS will support these functions. If it does not, the
module will use emulations of the functions using the legacy resolver
functions instead. The emulations support the same interface as the real
functions, and behave as close as is resonably possible to emulate using the
legacy resolvers. See below for details on the limits of this emulation.

=cut

sub import
{
   my $class = shift;
   my %symbols = map { $_ => 1 } @_;

   my $api;
   $api = "new"     if delete $symbols{':newapi'};
   $api = "Socket6" if delete $symbols{':Socket6api'};

   if( $symbols{getaddrinfo} or $symbols{getnameinfo} ) {
      defined $api or carp <<EOF;
Importing Socket::GetAddrInfo without ':newapi' or ':Socket6api' tag.
Defaults to :Socket6api currently but default will change in a future version.
EOF
      if( !defined $api or $api eq "Socket6" ) {
         my $callerpkg = caller;

         no strict 'refs';
         *{"${callerpkg}::getaddrinfo"} = \&Socket6_getaddrinfo if delete $symbols{getaddrinfo};
         *{"${callerpkg}::getnameinfo"} = \&Socket6_getnameinfo if delete $symbols{getnameinfo};
      }
   }

   return unless keys %symbols;

   require Exporter;

   local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
   Exporter::import( $class, keys %symbols );
}

=head1 FUNCTIONS

The functions in this module are provided in one of two API styles, selectable
at the time they are imported into the caller, by the use of the following
tags:

 use Socket::GetAddrInfo qw( :newapi getaddrinfo );

 use Socket::GetAddrInfo qw( :Socket6api getaddrinfo );

The choice is implemented by importing different functions into the caller,
which means different importing packages may choose different API styles. It
is recommended that new code import the C<:newapi> style to take advantage of
neater argument / return results, and error reporting. The C<:Socket6api>
style is provided as backward-compatibility for code that wants to use
C<Socket6>.

If neither style is selected, then this module will provide a Socket6-like API
to be compatible with earlier versions of C<Socket::GetAddrInfo>. This
behaviour will change in a later version of the module - make sure to always
specify the required API type.

=cut

=head2 ( $err, @res ) = getaddrinfo( $host, $service, $hints )

When given both host and service, this function attempts to resolve the host
name to a set of network addresses, and the service name into a protocol and
port number, and then returns a list of address structures suitable to
connect() to it.

When given just a host name, this function attempts to resolve it to a set of
network addresses, and then returns a list of these addresses in the returned
structures.

When given just a service name, this function attempts to resolve it to a
protocol and port number, and then returns a list of address structures that
represent it suitable to bind() to.

When given neither name, it generates an error.

The optional C<$hints> parameter can be passed a HASH reference to indicate
how the results are generated. It may contain any of the following four
fields:

=over 8

=item flags => INT

A bitfield containing C<AI_*> constants

=item family => INT

Restrict to only generating addresses in this address family

=item socktype => INT

Restrict to only generating addresses of this socket type

=item protocol => INT

Restrict to only generating addresses for this protocol

=back

Errors are indicated by the C<$err> value returned; which will be non-zero in
numeric context, and contain a string error message as a string. The value can
be compared against any of the C<EAI_*> constants to determine what the error
is.

If no error occurs, C<@res> will contain HASH references, each representing
one address. It will contain the following five fields:

=over 8

=item family => INT

The address family (e.g. AF_INET)

=item socktype => INT

The socket type (e.g. SOCK_STREAM)

=item protocol => INT

The protocol (e.g. IPPROTO_TCP)

=item addr => STRING

The address in a packed string (such as would be returned by pack_sockaddr_in)

=item canonname => STRING

The canonical name for the host if the C<AI_CANONNAME> flag was provided, or
C<undef> otherwise.

=back

=head2 ( $err, $host, $service ) = getnameinfo( $addr, $flags )

This function attempts to resolve the given socket address into a pair of host
and service names.

The optional C<$flags> parameter is a bitfield containing C<NI_*> constants.

Errors are indicated by the C<$err> value returned; which will be non-zero in
numeric context, and contain a string error message as a string. The value can
be compared against any of the C<EAI_*> constants to determine what the error
is.

=cut

=head1 SOCKET6 COMPATIBILITY FUNCTIONS

=head2 @res = getaddrinfo( $host, $service, $family, $socktype, $protocol, $flags )

This version of the API takes the hints values as separate ordered parameters.
Unspecified parameters should be passed as C<0>.

If successful, this function returns a flat list of values, five for each
returned address structure. Each group of five elements will contain, in
order, the C<family>, C<socktype>, C<protocol>, C<addr> and C<canonname>
values of the address structure.

If unsuccessful, it will return a single value, containing the string error
message. To remain compatible with the C<Socket6> interface, this value does
not have the error integer part.

=cut

sub Socket6_getaddrinfo
{
   @_ >= 2 and @_ <= 6 or 
      croak "Usage: getaddrinfo(host, service, family=0, socktype=0, protocol=0, flags=0)";

   my ( $host, $service, $family, $socktype, $protocol, $flags ) = @_;

   my ( $err, @res ) = getaddrinfo( $host, $service, {
      flags    => $flags    || 0,
      family   => $family   || 0,
      socktype => $socktype || 0,
      protocol => $protocol || 0,
   } );

   return "$err" if $err;
   return map { $_->{family}, $_->{socktype}, $_->{protocol}, $_->{addr}, $_->{canonname} } @res;
}

=head2 ( $host, $service ) = getnameinfo( $addr, $flags )

This version of the API returns only the host name and service name, if
successfully resolved. On error, it will return an empty list. To remain
compatible with the C<Socket6> interface, no error information will be
supplied.

=cut

sub Socket6_getnameinfo
{
   @_ >= 1 and @_ <= 2 or
      croak "Usage: getnameinfo(addr, flags=0)";

   my ( $addr, $flags ) = @_;

   my ( $err, $host, $service ) = getnameinfo( $addr, $flags );

   return () if $err;
   return ( $host, $service );
}

=head1 LIMITS OF EMULATION

If the real C<getaddrinfo(3)> and C<getnameinfo(3)> functions are not
available, they will be emulated using the legacy resolvers C<gethostbyname>,
etc... These emulations are not a complete replacement of the real functions,
because they only support IPv4 (the C<AF_INET> socket family). In this case,
the following restrictions will apply.

=head2 getaddrinfo

=over 4

=item *

If C<$family> is supplied, it must be C<AF_INET>. Any other value will result
in an error thrown by C<croak>.

=item *

The only supported C<$flags> values are C<AI_PASSIVE>, C<AI_CANONNAME>, and
C<AI_NUMERICHOST>.

=back

=head2 getnameinfo

=over 4

=item *

If the sockaddr family of C<$addr> is anything other than C<AF_INET>, an error
will be thrown with C<croak>.

=item *

The only supported C<$flags> values are C<NI_NUMERICHOST>, C<NI_NUMERICSERV>,
C<NI_NAMEREQD> and C<NI_DGRAM>.

=back

=cut

# Keep perl happy; keep Britain tidy
1;

__END__

=head1 BUGS

=over 4

=item *

At the time of writing, there are no test reports from the C<MSWin32> platform
either PASS or FAIL. I suspect the code will not currently work as it stands
on that platform, but it should be fairly easy to fix, as C<Socket6> is known
to work there. Patches welcomed. :)

=back

=head1 SEE ALSO

=over 4

=item *

L<http://tools.ietf.org/html/rfc2553> - Basic Socket Interface Extensions for
IPv6

=back

=head1 ACKNOWLEDGEMENTS

Christian Hansen <chansen@cpan.org> - for help with some XS features and Win32
build fixes.

Zefram <zefram@fysh.org> - for help with fixing some bugs in the XS code.

=head1 AUTHOR

Paul Evans <leonerd@leonerd.org.uk>
