#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010 -- leonerd@leonerd.org.uk

package Socket::GetAddrInfo::XS;

use strict;
use warnings;

our $VERSION = '0.19_004';

use Exporter 'import';
our @EXPORT = qw(
   getaddrinfo
   getnameinfo
);

require XSLoader;
XSLoader::load( __PACKAGE__, $VERSION );

# Keep perl happy; keep Britain tidy
1;
