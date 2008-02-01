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

static void setup_constants(void)
{
  HV *stash;
  AV *export;

  stash = gv_stashpvn("Socket::GetAddrInfo", 19, TRUE);
  export = get_av("Socket::GetAddrInfo::EXPORT", TRUE);

#define DO_CONSTANT(c) \
  newCONSTSUB(stash, #c, newSViv(c)); \
  av_push(export, newSVpv(#c, 0));

#ifdef AI_PASSIVE
  DO_CONSTANT(AI_PASSIVE)
#endif
#ifdef AI_CANONNAME
  DO_CONSTANT(AI_CANONNAME)
#endif
#ifdef AI_NUMERICHOST
  DO_CONSTANT(AI_NUMERICHOST)
#endif
#ifdef AI_NUMERICSERV
  DO_CONSTANT(AI_NUMERICSERV)
#endif

#ifdef EAI_BADFLAGS
  DO_CONSTANT(EAI_BADFLAGS)
#endif
#ifdef EAI_NONAME
  DO_CONSTANT(EAI_NONAME)
#endif
#ifdef EAI_AGAIN
  DO_CONSTANT(EAI_AGAIN)
#endif
#ifdef EAI_FAIL
  DO_CONSTANT(EAI_FAIL)
#endif
#ifdef EAI_NODATA
  DO_CONSTANT(EAI_NODATA)
#endif
#ifdef EAI_FAMILY
  DO_CONSTANT(EAI_FAMILY)
#endif
#ifdef EAI_SOCKTYPE
  DO_CONSTANT(EAI_SOCKTYPE)
#endif
#ifdef EAI_SERVICE
  DO_CONSTANT(EAI_SERVICE)
#endif
#ifdef EAI_ADDRFAMILY
  DO_CONSTANT(EAI_ADDRFAMILY)
#endif
#ifdef EAI_MEMORY
  DO_CONSTANT(EAI_MEMORY)
#endif

#ifdef NI_NUMERICHOST
  DO_CONSTANT(NI_NUMERICHOST)
#endif
#ifdef NI_NUMERICSERV
  DO_CONSTANT(NI_NUMERICSERV)
#endif
#ifdef NI_NAMEREQD
  DO_CONSTANT(NI_NAMEREQD)
#endif
#ifdef NI_DGRAM
  DO_CONSTANT(NI_DGRAM)
#endif
}

MODULE = Socket::GetAddrInfo      PACKAGE = Socket::GetAddrInfo

BOOT:
  setup_constants();

void
getaddrinfo(host, service, hints=NULL)
    char *host
    char *service
    SV   *hints

  PREINIT:
    struct addrinfo hints_s = { 0 };
    struct addrinfo *res;
    struct addrinfo *res_iter;
    int err;
    int n_res;

  PPCODE:
    if(hints && SvOK(hints)) {
      HV *hintshash;
      SV **valp;

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
      XSRETURN(1);

    n_res = 0;
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
      n_res++;
    }

    freeaddrinfo(res);

    XSRETURN(1 + n_res);

void
getnameinfo(addr, flags=0)
    SV  *addr
    int  flags

  PREINIT:
    SV *host;
    SV *serv;
    char *addr_s;
    struct sockaddr sa;
    size_t addr_len;
    int err;

  PPCODE:
    host = newSVpvn("", 1023);
    serv = newSVpvn("", 255);

    addr_s = SvPVbyte(addr, addr_len);
    memcpy(&sa, addr_s, addr_len);
#if HAVE_SOCKADDR_SA_LEN
    sa.sa_len = addr_len;
#endif

    err = getnameinfo(&sa, addr_len,
      SvPV_nolen(host), SvCUR(host) + 1, // Perl doesn't include final NUL
      SvPV_nolen(serv), SvCUR(serv) + 1, // Perl doesn't include final NUL
      flags);

    XPUSHs(err_to_SV(err));

    if(err)
      XSRETURN(1);

    SvCUR_set(host, strlen(SvPV_nolen(host)));
    SvCUR_set(serv, strlen(SvPV_nolen(serv)));

    XPUSHs(host);
    XPUSHs(serv);

    XSRETURN(3);
