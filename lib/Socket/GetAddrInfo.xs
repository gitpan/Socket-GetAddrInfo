/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2008 -- leonerd@leonerd.org.uk
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>

SV *err_to_SV(int err)
{
  SV *ret = sv_newmortal();
  SvUPGRADE(ret, SVt_PVNV);

  if(err) {
    const char *error = gai_strerror(err);
    sv_setpv(ret, error);
  }
  else {
    sv_setpv(ret, "");
  }

  SvIV_set(ret, err); SvIOK_on(ret);

  return ret;
}

MODULE = Socket::GetAddrInfo      PACKAGE = Socket::GetAddrInfo

BOOT:
{
  HV *stash;
  stash = gv_stashpvn("Socket::GetAddrInfo", 19, TRUE);

 newCONSTSUB(stash, "AI_PASSIVE",     newSViv(AI_PASSIVE));
 newCONSTSUB(stash, "AI_CANONNAME",   newSViv(AI_CANONNAME));
 newCONSTSUB(stash, "AI_NUMERICHOST", newSViv(AI_NUMERICHOST));

 newCONSTSUB(stash, "EAI_BADFLAGS",   newSViv(EAI_BADFLAGS));
 newCONSTSUB(stash, "EAI_NONAME",     newSViv(EAI_NONAME));
 newCONSTSUB(stash, "EAI_AGAIN",      newSViv(EAI_AGAIN));
 newCONSTSUB(stash, "EAI_FAIL",       newSViv(EAI_FAIL));
 newCONSTSUB(stash, "EAI_NODATA",     newSViv(EAI_NODATA));
 newCONSTSUB(stash, "EAI_FAMILY",     newSViv(EAI_FAMILY));
 newCONSTSUB(stash, "EAI_SOCKTYPE",   newSViv(EAI_SOCKTYPE));
 newCONSTSUB(stash, "EAI_SERVICE",    newSViv(EAI_SERVICE));
 newCONSTSUB(stash, "EAI_ADDRFAMILY", newSViv(EAI_ADDRFAMILY));
 newCONSTSUB(stash, "EAI_MEMORY",     newSViv(EAI_MEMORY));

 newCONSTSUB(stash, "NI_NUMERICHOST", newSViv(NI_NUMERICHOST));
 newCONSTSUB(stash, "NI_NUMERICSERV", newSViv(NI_NUMERICSERV));
 newCONSTSUB(stash, "NI_NAMEREQD",    newSViv(NI_NAMEREQD));
 newCONSTSUB(stash, "NI_DGRAM",       newSViv(NI_DGRAM));
}

void
real_getaddrinfo(host, service, hints=NULL)
    char *host
    char *service
    SV   *hints

  INIT:
    struct addrinfo hints_s = { 0 };
    SV **valp;
    struct addrinfo *res;
    struct addrinfo *res_iter;
    int err;

  PPCODE:
    if(hints && SvOK(hints)) {
      HV *hintshash;

      if(!SvROK(hints) || SvTYPE(SvRV(hints)) != SVt_PVHV)
        croak("hints is not a HASH reference");

      hintshash = (HV*)SvRV(hints);

      if((valp = hv_fetch(hintshash, "flags", 5, 0)) != NULL)
        hints_s.ai_flags = SvIV(*valp);
      if((valp = hv_fetch(hintshash, "family", 6, 0)) != NULL)
        hints_s.ai_family = SvIV(*valp);
      if((valp = hv_fetch(hintshash, "socktype", 8, 0)) != NULL)
        hints_s.ai_socktype = SvIV(*valp);
      if((valp = hv_fetch(hintshash, "protocol", 5, 0)) != NULL)
        hints_s.ai_protocol = SvIV(*valp);
    }

    err = getaddrinfo(host[0] ? host : NULL, service[0] ? service : NULL, &hints_s, &res);

    XPUSHs(err_to_SV(err));

    if(err)
      return;

    for(res_iter = res; res_iter; res_iter = res_iter->ai_next) {
      HV *res_hv = newHV();

      hv_store(res_hv, "family",   6, newSViv(res_iter->ai_family),   0);
      hv_store(res_hv, "socktype", 8, newSViv(res_iter->ai_socktype), 0);
      hv_store(res_hv, "protocol", 8, newSViv(res_iter->ai_protocol), 0);

      hv_store(res_hv, "addr",     4, newSVpvn((char*)res_iter->ai_addr, res_iter->ai_addrlen), 0);

      if(res_iter->ai_canonname)
        hv_store(res_hv, "canonname", 9, newSVpv(res_iter->ai_canonname, 0), 0);
      else
        hv_store(res_hv, "canonname", 9, &PL_sv_undef, 0);

      XPUSHs(newRV_noinc((SV*)res_hv));
    }

    freeaddrinfo(res);

void
real_getnameinfo(addr, flags=0)
    SV  *addr
    int  flags

  INIT:
    SV *host;
    SV *serv;
    char *addr_s;
    size_t addr_len;
    int err;

  PPCODE:
    host = newSVpvn("", 1023);
    serv = newSVpvn("", 255);

    addr_s = SvPVbyte(addr, addr_len);

    err = getnameinfo((const struct sockaddr*)addr_s, addr_len,
      SvPV_nolen(host), SvCUR(host) + 1, // Perl doesn't include final NUL
      SvPV_nolen(serv), SvCUR(serv) + 1, // Perl doesn't include final NUL
      flags);

    XPUSHs(err_to_SV(err));

    if(err)
      return;

    SvCUR_set(host, strlen(SvPV_nolen(host)));
    SvCUR_set(serv, strlen(SvPV_nolen(serv)));

    XPUSHs(host);
    XPUSHs(serv);
