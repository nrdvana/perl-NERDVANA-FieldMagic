static SV *nf_perlutil_newSVivpv(pTHX_ IV ival, const char *pval) {
   SV *s= newSVpv(pval, 0);
   SvUPGRADE(s, SVt_PVIV);
   SvIV_set(s, ival);
   SvIOK_on(s);
   return s;
}
#ifdef USE_ITHREADS
  #define nf_newSVivpv(a,b) nf_perlutil_newSVivpv(aTHX,a,b)
#else
  #define nf_newSVivpv nf_perlutil_newSVivpv
#endif

// Make one array hold all the same elements of another, respecing magic.
// Seems like there ought to be something in perlapi to do this?
// 'src' may be an AV or ref to AV, else src will be added as the array's only element.
void nf_perlutil_av_assign(pTHX_ AV *dest, AV *src) {
   size_t i;
   SV *el, **el_p;
   av_fill(dest, av_len(src));
   for (i= 0; i <= av_len(src); i++) {
      el= *av_fetch(dest, i, 1);
      el_p= av_fetch(src, i, 0);
      sv_setsv(el, el_p && *el_p? *el_p : &PL_sv_undef);
   }
}
AV* nf_perlutil_newAVav(pTHX_ AV *src) {
   AV *dest= newAV();
   nf_perlutil_av_assign(aTHX_ dest, src);
   return dest;
}
#ifdef USE_ITHREADS
  #define nf_av_assign(a,b) nf_perlutil_av_assign(aTHX_,a,b)
  #define nf_newAVav(a)     nf_perlutil_newAVav(aTHX_,a)
#else
  #define nf_av_assign nf_perlutil_av_assign
  #define nf_newAVav   nf_perlutil_newAVav
#endif

// Make a hash hold all the same elemnts of another, respecting magic.
// This is copied from newHVhv in hv.c, but without all the optimizations
// for non-magic, because those seem likely to break across perl versions.
// A shame that function isn't able to assign to an existing hash :-(
void nf_perlutil_hv_assign(pTHX_ HV *dest, HV *ohv) {
   HE *entry;
   const I32 riter = HvRITER_get(ohv);
   HE * const eiter = HvEITER_get(ohv);

   hv_clear(dest);
   hv_iterinit(ohv);
   while ((entry = hv_iternext_flags(ohv, 0))) {
      SV *val = hv_iterval(ohv,entry);
      SV * const keysv = HeSVKEY(entry);
      val = SvIMMORTAL(val) ? val : newSVsv(val);
      if (keysv)
          (void)hv_store_ent(dest, keysv, val, 0);
      else
          (void)hv_store_flags(dest, HeKEY(entry), HeKLEN(entry), val,
                           HeHASH(entry), HeKFLAGS(entry));
   }
   HvRITER_set(ohv, riter);
   HvEITER_set(ohv, eiter);
}
#ifdef USE_ITHREADS
  #define nf_hv_assign(a,b) nf_perlutil_hv_assign(aTHX_,a,b)
#else
  #define nf_hv_assign nf_perlutil_hv_assign
#endif
