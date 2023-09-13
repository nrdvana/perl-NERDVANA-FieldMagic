#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "perl_util.c"
#include "FieldMagic.h"
#include "rbhash.c"
#include "fm_fieldset.c"
#include "fm_fieldstorage.c"

/**********************************************************************************************\
* This code sets/gets the XS Magic on objects
\**********************************************************************************************/

/*
  - fm_fieldset_t structs are owned by NERDVANA::FieldMagic::FieldSet objects.
  - Package stashes have a magic pointer attached which acts as a strong reference
     to the FieldSet object.  (but is actually a pointer to the fm_fieldset_t)
  - FieldInfo objects are blessed arrayrefs of [ FieldSet, field_index ]
  - fm_fieldstorage_map_t are attached to arbitrary objects
  - fm_fieldstorage_t are owned by the object,
     but hold a strong reference to the FieldSet object

*/

/* Get or create fm_fieldset_t attached to package stash (or anonymous HV)
 * The expected 'sv' are either the package stash itself, or a ref to a blessed ref to it.
 */
static fm_fieldset_t* fm_fieldset_magic_get(pTHX_ SV *sv, int flags) {
   MAGIC* magic;
   if (SvROK(sv))
      sv= SvRV(sv);
   if (SvMAGICAL(sv)) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && (
               magic->mg_virtual == &fm_fieldset_magic_vt
               || magic->mg_virtual == &fm_fieldset_pkg_stash_magic_vt
            ))
            return (fm_fieldset_t*) magic->mg_ptr;
   }
   if (flags & OR_DIE)
      croak("Not a FieldSet object");
   return NULL;
}

// Called when a ::FieldInfo object gets garbage collected.  It has a strong reference
// to the fm_fieldset_t owner, so that needs released, but the fieldinfo struct
// does not get deleted.  Many Field objects can refer to the same fm_fieldinfo_t
static int fm_fieldinfo_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   fm_fieldinfo_t *finf= (fm_fieldinfo_t*) mg->mg_ptr;
   if (finf && !PL_dirty)
      SvREFCNT_dec(finf->fieldset->wrapper);
   return 0;
}
#ifdef USE_ITHREADS
static int fm_fieldinfo_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::FieldMagic");
   return 0;
};
#else
#define fm_fieldinfo_magic_dup NULL
#endif
static MGVTBL fm_fieldinfo_magic_vt= {
   NULL, NULL, NULL, NULL, fm_fieldinfo_magic_free,
   NULL, fm_fieldinfo_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

static SV* fm_fieldinfo_wrap(pTHX_ fm_fieldinfo_t *finfo) {
   if (!finfo)
      return &PL_sv_undef;
   SV *sv= newSV(0);
   MAGIC *magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &fm_fieldinfo_magic_vt, (char*)finfo, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)magic;
   #endif
   SvREFCNT_inc(finfo->fieldset->wrapper); // refcnt on fieldset, not fieldinfo
   return sv_bless(newRV_noinc(sv),
      gv_stashpv("NERDVANA::FieldMagic::FieldInfo", GV_ADD));
}

static fm_fieldinfo_t* fm_fieldinfo_magic_get(pTHX_ SV *obj, int flags) {
   MAGIC* magic;
   if (SvROK(obj) && SvMAGICAL(SvRV(obj))) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(SvRV(obj)); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &fm_fieldinfo_magic_vt)
            return (fm_fieldinfo_t*) magic->mg_ptr;
   }
   if (flags & OR_DIE)
      croak("Not a FieldInfo object");
   return NULL;
}

/* Magic for binding fm_fieldstorage_map_t to an arbitrary object */

static int fm_fieldstorage_map_magic_free(pTHX_ SV* sv, MAGIC* mg) {
   fm_fieldstorage_map_t *fsm= (fm_fieldstorage_map_t*) mg->mg_ptr;
   if (fsm)
      fm_fieldstorage_map_free(aTHX_ fsm);
   return 0; // ignored anyway
}
#ifdef USE_ITHREADS
static int fm_fieldstorage_map_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: support ithreads for NERDVANA::FieldMagic");
   return 0;
};
#else
#define fm_fieldstorage_map_magic_dup NULL
#endif
// magic virtual method table for fm_fieldstorage_map_t
static MGVTBL fm_fieldstorage_map_magic_vt= {
   NULL, NULL, NULL, NULL, fm_fieldstorage_map_magic_free,
   NULL, fm_fieldstorage_map_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

/* Get or create fm_fieldstorage_t for a given fm_fieldset_t attached to an arbitrary object.
 * Use AUTOCREATE to attach magic and allocate a struct if it wasn't present.
 * Use OR_DIE for a built-in croak() if the return value would be NULL.
 */
static fm_fieldstorage_t* fm_fieldstorage_magic_get(pTHX_ SV *sv, fm_fieldset_t *fs, int flags) {
   MAGIC* magic= NULL;
   if (SvMAGICAL(sv)) {
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &fm_fieldstorage_map_magic_vt)
            break;
   }
   if (!magic) {
      if (!(flags & FM_FIELDSTORAGE_AUTOCREATE))
         return NULL;
      magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &fm_fieldstorage_map_magic_vt, NULL, 0);
      #ifdef USE_ITHREADS
      magic->mg_flags |= MGf_DUP;
      #endif
   }
   return fm_fieldstorage_map_get(aTHX_ (fm_fieldstorage_map_t**) &magic->mg_ptr, fs, flags);
}

/**********************************************************************************************\
* NERDVANA::FieldMagic Public API
\**********************************************************************************************/
MODULE = NERDVANA::FieldMagic                  PACKAGE = NERDVANA::FieldMagic

void
import(pkg, ...)
   SV *pkg
   INIT:
      const PERL_CONTEXT *cx= caller_cx(0, NULL);
      int i;
      const char *pv;
      STRLEN len;
      GV **field;
      HV *src_stash, *dest_stash;
   PPCODE:
      pv= SvPV(pkg, len);
      src_stash= gv_stashpvn(pv, len, GV_ADD);
      dest_stash= (HV*) CopSTASH(cx->blk_oldcop);
      if (dest_stash && SvTYPE((SV*)dest_stash) != SVt_PVHV)
         dest_stash= NULL;
      if (items == 1) {
         warn("TODO: enable field syntax in current scope");
      }
      else {
         for (i= 1; i < items; i++) {
            if (SvROK(ST(i)) && !sv_isobject(ST(i)))
               croak("Ref types are reserved for future use"); 
            pv= SvPV(ST(i), len);
            //if (len > 1 && *pv == '-')
            // TODO
            // else {
            // export the symbol
            if (!dest_stash)
               croak("BUG: no destination package for import");
            field= (GV**) hv_fetch(src_stash, pv, len, 0);
            if (!field || !*field)
               croak("%s is not exported by %s", pv, HvENAME(src_stash));
            if (hv_store(dest_stash, pv, len, (SV*) *field, 0))
               SvREFCNT_inc(*field);
         }
      }

fm_fieldset_t*
fieldset_for_package(pkg)
   SV *pkg
   INIT:
      HV *pkg_stash;
      UV pkg_str_len;
      const char *pkg_str;
   CODE:
      if (SvROK(pkg) && SvTYPE(SvRV(pkg)) == SVt_PVHV && HvENAMELEN((HV*)SvRV(pkg)))
         pkg_stash= (HV*) SvRV(pkg);
      else {
         pkg_str= SvPV(pkg, pkg_str_len);
         pkg_stash= gv_stashpvn(pkg_str, pkg_str_len, 0);
         if (!pkg_stash)
            croak("No such package '%s'", pkg_str);
      }
      RETVAL= fm_fieldset_magic_get(aTHX_ (SV*) pkg_stash, 0);
      if (!RETVAL) {
         RETVAL= fm_fieldset_alloc(aTHX_);
         fm_fieldset_link_to_package(aTHX_ RETVAL, pkg_stash);
      }
   OUTPUT:
      RETVAL

fm_fieldset_t*
new_fieldset()
   CODE:
      RETVAL= fm_fieldset_alloc(aTHX_);
   OUTPUT:
      RETVAL

void
field_type(sv)
   SV *sv;
   INIT:
      int type;
   PPCODE:
      ST(0)= fm_field_type_parse(aTHX_ sv, &type)
         ? sv_2mortal(fm_field_type_wrap(aTHX_ type))
         : &PL_sv_undef;
      XSRETURN(1);

MODULE = NERDVANA::FieldMagic                  PACKAGE = NERDVANA::FieldMagic::FieldSet
PROTOTYPES: DISABLE

void
new(cls)
   const char *cls
   INIT:
      fm_fieldset_t *self;
   PPCODE:
      self= fm_fieldset_alloc(aTHX_);
      ST(0)= sv_2mortal(newRV_inc((SV*) self->wrapper));
      // Allow it to be blessed as something else
      if (strcmp(cls, "NERDVANA::FieldMagic::FieldSet") != 0)
         sv_bless(ST(0), gv_stashpv(cls, GV_ADD));
      XSRETURN(1);

IV
field_count(self)
   fm_fieldset_t *self
   CODE:
      RETVAL= self->field_count;
   OUTPUT:
      RETVAL

void
allocate(self, count)
   fm_fieldset_t *self
   UV count
   PPCODE:
      fm_fieldset_extend(self, count);
      XSRETURN(0);

void
package_name(self)
   fm_fieldset_t *self
   INIT:
      HV *pkg= self->pkg_stash_ref && SvOK(self->pkg_stash_ref)? (HV*) SvRV(self->pkg_stash_ref) : NULL;
   PPCODE:
      ST(0)= pkg && HvENAMELEN(pkg)? sv_2mortal(newSVpvn(HvENAME(pkg), HvENAMELEN(pkg))) : &PL_sv_undef;
      XSRETURN(1);

IV
_capacity(self)
   fm_fieldset_t *self
   CODE:
      RETVAL= self->capacity;
   OUTPUT:
      RETVAL

IV
_storage_size(self)
   fm_fieldset_t *self
   CODE:
      RETVAL= self->storage_size;
   OUTPUT:
      RETVAL

void
add_field(self, name, type, ...)
   fm_fieldset_t *self
   SV *name
   fm_field_type_t type
   INIT:
      fm_fieldinfo_t *finfo;
      char *pv;
      STRLEN len;
      int i;
      SV *def_val= NULL;
      U8 wantarray= GIMME_V;
   PPCODE:
      // Process options
      for (i= 3; i < items; i++) {
         pv= SvPV(ST(i), len);
         if (strcmp(pv, "default") == 0) {
            if (i+1 == items) croak("Missing argument for 'default'");
            ++i;
            def_val= ST(i);
         }
         else croak("Unknown option '%s'", pv);
      }
      switch (type) {
      case FM_FIELD_TYPE_SV: {
            finfo= fm_fieldset_add_field(aTHX_ self, name, type, 0, 0);
            if (def_val) {
               finfo->flags |= FM_FIELD_HAS_DEFAULT;
               finfo->def_val.sv= newSVsv(def_val);
            }
            break;
         }
      default:
         croak("Unsupported type %d", (int) type);
      }
      // Only generate the object if defined wantarray
      if (wantarray != G_VOID) {
         ST(0)= sv_2mortal(fm_fieldinfo_wrap(finfo));
         XSRETURN(1);
      }
      else XSRETURN(0);

fm_fieldinfo_t*
field(fs, name)
   fm_fieldset_t *fs
   SV *name
   INIT:
      UV field_idx;
   CODE:
      if (looks_like_number(name)) {
         field_idx= SvUV(name);
         RETVAL= (field_idx < fs->field_count)? fs->fields[field_idx] : NULL;
      } else {
         RETVAL= fm_fieldset_get_field(fs, name);
      }
   OUTPUT:
      RETVAL

MODULE = NERDVANA::FieldMagic              PACKAGE = NERDVANA::FieldMagic::FieldInfo

fm_fieldset_t*
fieldset(self)
   fm_fieldinfo_t *self
   CODE:
      RETVAL= self->fieldset;
   OUTPUT:
      RETVAL

IV
field_idx(self)
   fm_fieldinfo_t *self
   CODE:
      RETVAL= self->field_idx;
   OUTPUT:
      RETVAL

SV*
name(self)
   fm_fieldinfo_t *self
   CODE:
      RETVAL= newSVsv(self->name);
   OUTPUT:
      RETVAL

fm_field_type_t
type(self)
   fm_fieldinfo_t *self
   CODE:
      RETVAL= FM_FIELDINFO_TYPE(self);
   OUTPUT:
      RETVAL

bool
has_value(self, obj)
   fm_fieldinfo_t *self
   SV *obj
   INIT:
      fm_fieldstorage_t *stor= fm_fieldstorage_magic_get(obj, self->fieldset, 0);
   CODE:
      RETVAL= stor && fm_fieldstorage_field_exists(aTHX_ stor, self);
   OUTPUT:
      RETVAL

void
get_value(self, obj)
   fm_fieldinfo_t *self
   SV *obj
   INIT:
      fm_fieldstorage_t *stor= fm_fieldstorage_magic_get(obj, self->fieldset, 0); 
   PPCODE:
      // TODO: handle arrayrefs and hashrefs by returning a reference
      ST(0)= !stor? &PL_sv_undef : fm_fieldstorage_field_rvalue(aTHX_ stor, self);
      XSRETURN(1);

void
get_lvalue(self, obj)
   fm_fieldinfo_t *self
   SV *obj
   INIT:
      fm_fieldstorage_t *stor= fm_fieldstorage_magic_get(obj, self->fieldset, FM_FIELDSTORAGE_AUTOCREATE); 
   PPCODE:
      // TODO: handle arrayrefs and hashrefs by returning a reference
      ST(0)= fm_fieldstorage_field_lvalue(aTHX_ stor, self);
      XSRETURN(1);

void
set_value(self, obj, val)
   fm_fieldinfo_t *self
   SV *obj
   SV *val
   INIT:
      fm_fieldstorage_t *stor= fm_fieldstorage_magic_get(obj, self->fieldset, FM_FIELDSTORAGE_AUTOCREATE); 
   PPCODE:
      // TODO: handle arrayrefs and hashrefs when assigning arrays and hashes
      fm_fieldstorage_field_assign(aTHX_ stor, self, val);
      XSRETURN(0);

BOOT:
   HV* stash= gv_stashpv("NERDVANA::FieldMagic", GV_ADD);
   /* BEGIN GENERATED ENUM CONSTANTS */
   newCONSTSUB(stash, "FIELD_TYPE_AV", fm_newSVivpv(FM_FIELD_TYPE_AV, "FIELD_TYPE_AV"));
   newCONSTSUB(stash, "FIELD_TYPE_BOOL", fm_newSVivpv(FM_FIELD_TYPE_BOOL, "FIELD_TYPE_BOOL"));
   newCONSTSUB(stash, "FIELD_TYPE_HV", fm_newSVivpv(FM_FIELD_TYPE_HV, "FIELD_TYPE_HV"));
   newCONSTSUB(stash, "FIELD_TYPE_IV", fm_newSVivpv(FM_FIELD_TYPE_IV, "FIELD_TYPE_IV"));
   newCONSTSUB(stash, "FIELD_TYPE_NV", fm_newSVivpv(FM_FIELD_TYPE_NV, "FIELD_TYPE_NV"));
   newCONSTSUB(stash, "FIELD_TYPE_PV", fm_newSVivpv(FM_FIELD_TYPE_PV, "FIELD_TYPE_PV"));
   newCONSTSUB(stash, "FIELD_TYPE_STRUCT", fm_newSVivpv(FM_FIELD_TYPE_STRUCT, "FIELD_TYPE_STRUCT"));
   newCONSTSUB(stash, "FIELD_TYPE_SV", fm_newSVivpv(FM_FIELD_TYPE_SV, "FIELD_TYPE_SV"));
   newCONSTSUB(stash, "FIELD_TYPE_UV", fm_newSVivpv(FM_FIELD_TYPE_UV, "FIELD_TYPE_UV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_AV", fm_newSVivpv(FM_FIELD_TYPE_VIRT_AV, "FIELD_TYPE_VIRT_AV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_HV", fm_newSVivpv(FM_FIELD_TYPE_VIRT_HV, "FIELD_TYPE_VIRT_HV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_SV", fm_newSVivpv(FM_FIELD_TYPE_VIRT_SV, "FIELD_TYPE_VIRT_SV"));
   /* END GENERATED ENUM CONSTANTS */
