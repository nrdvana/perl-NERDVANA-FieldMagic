/**********************************************************************************************\
* Magic
\**********************************************************************************************/

/* Magic for binding fm_fieldset_t to a FieldSet object */

// This gets called when the FieldSet object is getting garbage collected
static int fm_fieldset_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   fm_fieldset_t *fs= (fm_fieldset_t*) mg->mg_ptr;
   if (fs) {
      fs->wrapper= NULL; // wrapper is in the process of getting freed already
      fm_fieldset_free(aTHX_ fs);
   }
   return 0;
}
#ifdef USE_ITHREADS
static int fm_fieldset_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::FieldMagic");
   return 0;
};
#else
#define fm_fieldset_magic_dup NULL
#endif
static MGVTBL fm_fieldset_magic_vt= {
   NULL, NULL, NULL, NULL, fm_fieldset_magic_free,
   NULL, fm_fieldset_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

/* Magic for binding fm_fieldset_t to a package stash HV.
 * It basically just holds one strong reference to the FieldSet wrapper.
 * Since it is a simple pointer to fm_fieldset_t, the package stash objects can be
 * used in any XS API that FieldSet objects can be used.
 */

// This only gets called when a package stash is being destroyed.
static int fm_fieldset_pkg_stash_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   fm_fieldset_t *fs= (fm_fieldset_t*) mg->mg_ptr;
   if (fs && !PL_dirty)
      SvREFCNT_dec(fs->wrapper);
   return 0;
}
#ifdef USE_ITHREADS
static int fm_fieldset_pkg_stash_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::FieldMagic");
   return 0;
};
#else
#define fm_fieldset_pkg_stash_magic_dup NULL
#endif
static MGVTBL fm_fieldset_pkg_stash_magic_vt= {
   NULL, NULL, NULL, NULL, fm_fieldset_pkg_stash_magic_free,
   NULL, fm_fieldset_pkg_stash_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

/**********************************************************************************************\
* FieldSet Methods
\**********************************************************************************************/

/* Allocate a fm_fieldset_t struct paired with a FieldMagic::FieldSet blessed HV.
 */
fm_fieldset_t * fm_fieldset_alloc(pTHX) {
   fm_fieldset_t *self;
   MAGIC *magic;
   SV *ref;
   Newxz(self, 1, fm_fieldset_t);
   // The wrapper holds the refcount for this fieldset, so must be created immediately.
   // When users request FieldSet objects, just hand out references to it.
   self->wrapper= newHV();
   magic= sv_magicext((SV*)self->wrapper, NULL, PERL_MAGIC_ext, &fm_fieldset_magic_vt, (char*) self, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)magic; // suppress warning
   #endif
   // Need a ref in order to call sv_bless.  This mortal ref will also garbage collect this
   // FieldSet object unless the user receives a strong ref or unless a strong ref is held
   // by a package stash.
   ref= sv_2mortal(newRV_noinc((SV*)self->wrapper));
   sv_bless(ref, gv_stashpv("NERDVANA::FieldMagic::FieldSet", GV_ADD));
   return self;
}

/* Create a magic ref from a package stash to this FieldSet object.
 * Dies if the package already has a FieldSet or if this FieldSet already
 * has a package.
 */
void fm_fieldset_link_to_package(pTHX_ fm_fieldset_t *self, HV *pkg_stash) {
   MAGIC *magic;
   // It's an error if we are already linked to a package stash.
   if (self->pkg_stash_ref && SvRV(self->pkg_stash_ref) && SvOK(SvRV(self->pkg_stash_ref)))
      croak("FieldSet is already linked to a package");
   // It's an error if the package stash already points to a different fieldset.
   if (SvMAGICAL((SV*)pkg_stash)) {
      for (magic= SvMAGIC((SV*)pkg_stash); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &fm_fieldset_pkg_stash_magic_vt)
            croak("package already has a FieldSet");
   }
   // magically attach 'self' to the package stash
   magic= sv_magicext((SV*) pkg_stash, NULL, PERL_MAGIC_ext, &fm_fieldset_pkg_stash_magic_vt, (char*) self, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)magic; // suppress warning
   #endif
   // The package stash will now hold a strong reference to us.
   // The wrapper is where we keep the refcount for self.
   SvREFCNT_inc(self->wrapper);
   // Now create a weak-ref from self to the package stash
   self->pkg_stash_ref= newRV_inc((SV*)pkg_stash);
   sv_rvweaken(self->pkg_stash_ref);
   // If the package stash ever gets garbage collected, *and* all objects with a fm_fieldstorage
   // using this fieldset get garbage collected, the refcount drops to 0 and the fieldset
   // also gets garbage collected.
}

/* Allocate more FieldInfo entries, if needed.  This does not allocate fm_fieldinfo_t
 * structs to go along with them, just the top-level array of pointers, and the rbhash
 * used to index them..
 */
void fm_fieldset_extend(pTHX_ fm_fieldset_t *self, UV count) {
   if (count > self->capacity) {
      size_t alloc= count * sizeof(fm_fieldinfo_t*) + FM_RBHASH_SIZE(count);
      if (!self->fields)
         self->fields= (fm_fieldinfo_t**) safecalloc(alloc, 1);
      else {
         self->fields= (fm_fieldinfo_t**) saferealloc(self->fields, alloc);
         // Need to clear all bytes of the rbhash
         Zero(&self->fields[count], FM_RBHASH_SIZE(count), char);
      }
      self->capacity= count;
      // Now re-index all the existing elements
      if (!fm_fieldset_rbhash_reindex(self->fields + count, count, self->fields, 1, self->field_count))
         croak("Corrupt rbhash");
   }
}

/* Destroy and free a fm_fieldset_t struct, assuming that its wrapper is already
 * being destroyed and trigered this.
 */
void fm_fieldset_free(pTHX_ fm_fieldset_t *self) {
   IV i;
   // If the XS MAGIC destructor of the wrapper triggered this destructor, it would
   // first clear the pointer.  So it's a bad thing if the wrapper is non-null.
   if (self->wrapper)
      warn("BUG: fm_fieldset_t freed before wrapper destroyed");
   if (self->pkg_stash_ref)
      SvREFCNT_dec(self->pkg_stash_ref);
   for (i= self->field_count-1; i >= 0; i--) {
      fm_fieldinfo_destroy(aTHX_ self->fields[i]);
      // Every 8th element is a block allocation.
      if (!(i & 7))
         Safefree(self->fields[i]);
   }
   Safefree(self->fields);
   Safefree(self);
}

/* This is "destroy" rather than "free" because fieldinfo are allocated in blocks
 * and can't be individually freed.
 */
void fm_fieldinfo_destroy(pTHX_ fm_fieldinfo_t *self) {
   if (self->name) {
      SvREFCNT_dec(self->name);
   }
   if (self->flags & FM_FIELD_HAS_DEFAULT) {
      if (self->flags & FM_FIELD_TYPEMASK_SV)
         SvREFCNT_dec(self->def_val.sv);
   }
   if (self->meta_class)
      SvREFCNT_dec(self->meta_class);
}

/* The FIELD_TYPE constants are exposed to Perl,
 * and these functions convert between names and numbers.
 */
/* BEGIN GENERATED ENUM IMPLEMENTATION */
bool fm_field_type_parse(pTHX_ SV *sv, int *dest) {
   if (looks_like_number(sv)) {
      int val= SvIV(sv);
      if (val != SvIV(sv)) // check whether type narrowing lost some of the value
         return false;
      switch (val) {
      case FM_FIELD_TYPE_AV:
      case FM_FIELD_TYPE_BOOL:
      case FM_FIELD_TYPE_HV:
      case FM_FIELD_TYPE_IV:
      case FM_FIELD_TYPE_NV:
      case FM_FIELD_TYPE_PV:
      case FM_FIELD_TYPE_STRUCT:
      case FM_FIELD_TYPE_SV:
      case FM_FIELD_TYPE_UV:
      case FM_FIELD_TYPE_VIRT_AV:
      case FM_FIELD_TYPE_VIRT_HV:
      case FM_FIELD_TYPE_VIRT_SV:
         *dest= val;
         return true;
      default:
         return false;
      }
   } else {
      STRLEN len;
      const char *str= SvPV(sv, len);
      const char *test_str= NULL;
      int test_val= 0;
      switch(len) {
      case 2:
         if (str[0] < 'N') {
            if (str[0] < 'H') {
               test_str= "AV"; test_val= FM_FIELD_TYPE_AV;
            } else if (str[0] < 'I') {
               test_str= "HV"; test_val= FM_FIELD_TYPE_HV;
            } else {
               test_str= "IV"; test_val= FM_FIELD_TYPE_IV;
            }
         } else if (str[0] < 'S') {
            if (str[0] < 'P') {
               test_str= "NV"; test_val= FM_FIELD_TYPE_NV;
            } else {
               test_str= "PV"; test_val= FM_FIELD_TYPE_PV;
            }
         } else if (str[0] < 'U') {
            test_str= "SV"; test_val= FM_FIELD_TYPE_SV;
         } else {
            test_str= "UV"; test_val= FM_FIELD_TYPE_UV;
         }
         break;
      case 4:
         test_str= "BOOL"; test_val= FM_FIELD_TYPE_BOOL;
         break;
      case 6:
         test_str= "STRUCT"; test_val= FM_FIELD_TYPE_STRUCT;
         break;
      case 7:
         if (str[5] < 'H') {
            test_str= "VIRT_AV"; test_val= FM_FIELD_TYPE_VIRT_AV;
         } else if (str[5] < 'S') {
            test_str= "VIRT_HV"; test_val= FM_FIELD_TYPE_VIRT_HV;
         } else {
            test_str= "VIRT_SV"; test_val= FM_FIELD_TYPE_VIRT_SV;
         }
         break;
      case 13:
         if (str[11] < 'N') {
            if (str[11] < 'H') {
               test_str= "FIELD_TYPE_AV"; test_val= FM_FIELD_TYPE_AV;
            } else if (str[11] < 'I') {
               test_str= "FIELD_TYPE_HV"; test_val= FM_FIELD_TYPE_HV;
            } else {
               test_str= "FIELD_TYPE_IV"; test_val= FM_FIELD_TYPE_IV;
            }
         } else if (str[11] < 'S') {
            if (str[11] < 'P') {
               test_str= "FIELD_TYPE_NV"; test_val= FM_FIELD_TYPE_NV;
            } else {
               test_str= "FIELD_TYPE_PV"; test_val= FM_FIELD_TYPE_PV;
            }
         } else if (str[11] < 'U') {
            test_str= "FIELD_TYPE_SV"; test_val= FM_FIELD_TYPE_SV;
         } else {
            test_str= "FIELD_TYPE_UV"; test_val= FM_FIELD_TYPE_UV;
         }
         break;
      case 15:
         test_str= "FIELD_TYPE_BOOL"; test_val= FM_FIELD_TYPE_BOOL;
         break;
      case 17:
         test_str= "FIELD_TYPE_STRUCT"; test_val= FM_FIELD_TYPE_STRUCT;
         break;
      case 18:
         if (str[16] < 'H') {
            test_str= "FIELD_TYPE_VIRT_AV"; test_val= FM_FIELD_TYPE_VIRT_AV;
         } else if (str[16] < 'S') {
            test_str= "FIELD_TYPE_VIRT_HV"; test_val= FM_FIELD_TYPE_VIRT_HV;
         } else {
            test_str= "FIELD_TYPE_VIRT_SV"; test_val= FM_FIELD_TYPE_VIRT_SV;
         }
         break;
      }
      if (strcmp(str, test_str) == 0) {
         *dest= test_val;
         return true;
      }
   }
   return false;
}
const char* fm_field_type_name(pTHX_ int val) {
   switch (val) {
   case FM_FIELD_TYPE_AV: return "FIELD_TYPE_AV";
   case FM_FIELD_TYPE_BOOL: return "FIELD_TYPE_BOOL";
   case FM_FIELD_TYPE_HV: return "FIELD_TYPE_HV";
   case FM_FIELD_TYPE_IV: return "FIELD_TYPE_IV";
   case FM_FIELD_TYPE_NV: return "FIELD_TYPE_NV";
   case FM_FIELD_TYPE_PV: return "FIELD_TYPE_PV";
   case FM_FIELD_TYPE_STRUCT: return "FIELD_TYPE_STRUCT";
   case FM_FIELD_TYPE_SV: return "FIELD_TYPE_SV";
   case FM_FIELD_TYPE_UV: return "FIELD_TYPE_UV";
   case FM_FIELD_TYPE_VIRT_AV: return "FIELD_TYPE_VIRT_AV";
   case FM_FIELD_TYPE_VIRT_HV: return "FIELD_TYPE_VIRT_HV";
   case FM_FIELD_TYPE_VIRT_SV: return "FIELD_TYPE_VIRT_SV";
   default:
      return NULL;
   }
}
SV* fm_field_type_wrap(pTHX_ int val) {
   const char *pv= fm_field_type_name(aTHX_ val);
   return pv? fm_newSVivpv(val, pv) : newSViv(val);
}
/* END GENERATED ENUM IMPLEMENTATION */

/* Add a new field to the FieldSet.
 * The type and size must be declared, but default values and meta_class
 * can be changed later.  Field names must not include punctuation or
 * control characters, and may not be entirely numeric.
 * Fields cannot be deleted.
 */
fm_fieldinfo_t * fm_fieldset_add_field(pTHX_ fm_fieldset_t *self, SV *name, fm_field_type_t type, size_t align, size_t size) {
   fm_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   fm_fieldinfo_t *f= NULL;
   char *name_p= SvPVutf8(name, len);
   char *p0= name_p, *p1= name_p + len;
   bool valid= true;
   
   // Field name is restructed to the unicode definition of "Identifier"
   valid= isIDFIRST_utf8_safe(p0, p1);
   for (p0 += UTF8_SAFE_SKIP(p0, p1); valid && p0 < p1; p0 += UTF8_SAFE_SKIP(p0, p1)) {
      valid= isIDCONT_utf8_safe(p0, p1);
   }
   if (!valid)
      croak("Invalid field name");

   // Can't have 2 fields by the same name
   PERL_HASH(key.name_hashcode, name_p, len);
   if (fm_fieldset_rbhash_find(self->fields + self->capacity, self->capacity, self->fields, &key))
      croak("Field %s already exists", SvPV_nolen(name));

   // Reserve space
   if (self->field_count >= self->capacity)
      fm_fieldset_extend(aTHX_ self, (self->capacity < 48? self->capacity + 16 : self->capacity + (self->capacity >> 1)));
   // If this is a multiple of 8, allocate a new block of fieldinfo structs.
   i= self->field_count;
   if (!(i & 7))
      Newxz(f, 8, fm_fieldinfo_t);
   else // else find the pointer from previous allocation
      f= self->fields[i-1] + 1;
   f->name_hashcode= key.name_hashcode;
   f->fieldset= self;
   f->field_idx= i;
   f->flags= type;
   if (align == 0) {
      switch (type) {
      case FM_FIELD_TYPE_SV: case FM_FIELD_TYPE_AV: case FM_FIELD_TYPE_HV: case FM_FIELD_TYPE_PV:
         align= size= sizeof(SV*); break;
      case FM_FIELD_TYPE_BOOL:
         align= size= sizeof(bool); break;
      case FM_FIELD_TYPE_IV:
         align= size= sizeof(IV); break;
      case FM_FIELD_TYPE_UV:
         align= size= sizeof(UV); break;
      case FM_FIELD_TYPE_NV:
         align= size= sizeof(NV); break;
      default:
         if (i & 7) Safefree(f);
         croak("Un-handled type: %ld", (long) type);
      }
   }
   if (size && align) {
      f->storage_ofs= (self->storage_size + align - 1) & ~(size_t)(align-1);
      self->storage_size= f->storage_ofs + size;
   }
   // Save things that require cleanup for last, to allow croak() above
   f->name= newSVsv(name);
   SvREADONLY_on(f->name);
   self->fields[self->field_count++]= f;
   if (!fm_fieldset_rbhash_reindex(self->fields + self->capacity, self->capacity,
         self->fields, self->field_count, self->field_count))
      croak("Corrupt rbhash");
   return f;
}

/* Find an existing field by name or by number.  Return NULL if it doesn't exist.
 */
fm_fieldinfo_t * fm_fieldset_get_field(pTHX_ fm_fieldset_t *self, SV *name) {
   fm_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   char *name_p= SvPVutf8(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   i= fm_fieldset_rbhash_find(self->fields + self->capacity, self->capacity, self->fields, &key);
   return i? self->fields[i-1] : NULL;
}

