#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "perl_util.c"

/* nf_fieldinfo describes one field of one class.
 * nf_fieldset is the collection of fields for one class.
 * nf_fieldstorage is the struct magically attached to any sub that uses fields
 */

struct nf_fieldset;          typedef struct nf_fieldset nf_fieldset_t;
struct nf_fieldinfo;         typedef struct nf_fieldinfo nf_fieldinfo_t;
struct nf_fieldinfo_key;     typedef struct nf_fieldinfo_key nf_fieldinfo_key_t;
struct nf_fieldstorage_map;  typedef struct nf_fieldstorage_map nf_fieldstorage_map_t;
struct nf_fieldstorage;      typedef struct nf_fieldstorage nf_fieldstorage_t;
typedef int nf_field_type_t;

struct nf_fieldset {
   /* wrapper is the HV FieldSet object whose reference count controls the
      lifespan of this struct. */
   HV *wrapper;
   /* pkg_stash is a weak-ref to the package stash which has these fields */
   SV *pkg_stash_ref;
   size_t storage_size;
   /* fields[] is an array of the fields followed by a hashtree that looks them up by name */
   size_t field_count, capacity;
   nf_fieldinfo_t **fields;
};

// Used for the _find function
struct nf_fieldinfo_key {
   SV *name;
   unsigned name_hashcode;
};
struct nf_fieldinfo {
   nf_fieldset_t *fieldset;
   size_t field_idx;
   SV *name;
   unsigned name_hashcode;
   int flags;
   #define NF_FIELD_TYPEMASK      0xFF
   #define NF_FIELD_TYPEMASK_SV   0x80
   #define NF_FIELD_TYPE_SV       0x81
   #define NF_FIELD_TYPE_AV       0x82
   #define NF_FIELD_TYPE_HV       0x83
   #define NF_FIELD_TYPEMASK_VIRT 0x40
   #define NF_FIELD_TYPE_VIRT_SV  0x41
   #define NF_FIELD_TYPE_VIRT_AV  0x42
   #define NF_FIELD_TYPE_VIRT_HV  0x43
   #define NF_FIELD_TYPEMASK_C    0x20
   #define NF_FIELD_TYPE_BOOL     0x21
   #define NF_FIELD_TYPE_IV       0x22
   #define NF_FIELD_TYPE_UV       0x23
   #define NF_FIELD_TYPE_NV       0x24
   #define NF_FIELD_TYPE_PV       0x25
   #define NF_FIELD_TYPE_STRUCT   0x26
   #define NF_FIELD_INHERITED    0x100
   #define NF_FIELD_HAS_DEFAULT  0x200
   #define NF_FIELDINFO_TYPE(x) ((x)->flags & NF_FIELD_TYPEMASK)
   union {
      SV *sv;
      AV *av;
      HV *hv;
   } def_val;
   HV *meta_class;
   size_t storage_ofs, storage_size;
};

#define NF_FIELDSET_AUTOCREATE 0x10000
#define OR_DIE 0x20000
nf_fieldset_t * nf_fieldset_alloc(pTHX_);
void nf_fieldset_extend(pTHX_ nf_fieldset_t *self, UV field_count);
nf_fieldset_t * nf_fieldset_dup(pTHX_ nf_fieldset_t *self);
void nf_fieldset_free(pTHX_ nf_fieldset_t *self);
void nf_fieldinfo_destroy(pTHX_ nf_fieldinfo_t *finf);
nf_fieldinfo_t * nf_fieldset_get_field(pTHX_ nf_fieldset_t *self, SV *name, int flags);

/* BEGIN GENERATED ENUM HEADERS */
bool nf_field_type_parse(pTHX_ SV *sv, int *dest);
const char* nf_field_type_name(pTHX_ int val);
SV* nf_field_type_wrap(pTHX_ int val);
SV* nf_field_type_wrap(pTHX_ int val);/* END GENERATED ENUM HEADERS */

struct nf_fieldstorage_map {
   size_t el_count, capacity;
   nf_fieldstorage_t *el[];
   /* Allocation size:
      sizeof(nf_fieldstorage_map_t)
       + capacity * sizeof(nf_fieldstorage_t *)
       + size of the hash tree
   */
};

struct nf_fieldstorage {
   nf_fieldset_t *fieldset;
   size_t storage_size;
   char data[];
   /* Allocation size:
      sizeof(nf_fieldstorage_t)
      + fieldset->storage_size
   */
};

nf_fieldstorage_map_t * nf_fieldstorage_map_alloc(pTHX_ size_t capacity);
void nf_fieldstorage_map_free(pTHX_ nf_fieldstorage_map_t *self);
#define NF_FIELDSTORAGE_AUTOCREATE 1
nf_fieldstorage_t * nf_fieldstorage_map_get(pTHX_ nf_fieldstorage_map_t **self_p, nf_fieldset_t *fset, int flags);
nf_fieldstorage_t * nf_fieldstorage_alloc(pTHX_ nf_fieldset_t *fset);
nf_fieldstorage_t * nf_fieldstorage_clone(pTHX_ nf_fieldstorage_t *orig);
void nf_fieldstorage_free(pTHX_ nf_fieldstorage_t *self);
SV *nf_fieldstorage_field_get(pTHX_ nf_fieldstorage_t *self, size_t field_idx);
void nf_fieldstorage_field_set(pTHX_ nf_fieldstorage_t *self, size_t field_idx, SV *value);
void nf_fieldstorage_handle_new_fields(pTHX_ nf_fieldstorage_t **self_p);

/* BEGIN GENERATED NF_HASHTREE HEADERS */
// For a given capacity, this is how many hashtable buckets will be allocated
#define NF_HASHTREE_TABLE_BUCKETS(capacity) ((capacity) + ((capacity) >> 1))
// Size of hashtree structure, not including element array that it is appended to
// This is a function of the max capacity of elements.
#define NF_HASHTREE_SIZE(capacity) ( \
   ((capacity) > 0x7FFFFFFF? 8 \
    : (capacity) > 0x7FFF? 4 \
    : (capacity) > 0x7F? 2 \
    : 1 \
   ) * ( \
     ((capacity)+1)*2 \
     + NF_HASHTREE_TABLE_BUCKETS(capacity) \
   ))
size_t nf_fieldset_hashtree_find(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, nf_fieldinfo_key_t * search_key);
bool nf_fieldset_hashtree_reindex(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t el_i, size_t last_i);
bool nf_fieldset_hashtree_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el);
void nf_hashtree_print(void *hashtree, size_t capacity, FILE *out);
size_t nf_fieldstorage_map_hashtree_find(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, nf_fieldset_t * search_key);
bool nf_fieldstorage_map_hashtree_reindex(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t el_i, size_t last_i);
bool nf_fieldstorage_map_hashtree_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el);
/* END GENERATED NF_HASHTREE HEADERS */

#include "hashtree.c"

/**********************************************************************************************\
* fieldset_t implementation
\**********************************************************************************************/

/* Magic for binding nf_fieldset_t to a FieldSet object */

// This gets called when the FieldSet object is getting garbage collected
static int nf_fieldset_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   nf_fieldset_t *fs= (nf_fieldset_t*) mg->mg_ptr;
   if (fs) {
      fs->wrapper= NULL; // wrapper is in the process of getting freed already
      nf_fieldset_free(aTHX_ fs);
   }
   return 0;
}
#ifdef USE_ITHREADS
static int nf_fieldset_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::Field");
   return 0;
};
#else
#define nf_fieldset_magic_dup NULL
#endif
static MGVTBL nf_fieldset_magic_vt= {
   NULL, NULL, NULL, NULL, nf_fieldset_magic_free,
   NULL, nf_fieldset_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

nf_fieldset_t * nf_fieldset_alloc(pTHX_) {
   nf_fieldset_t *self;
   MAGIC *magic;
   SV *ref;
   Newxz(self, 1, nf_fieldset_t);
   // The wrapper holds the refcount for this fieldset, so must be created.
   self->wrapper= newHV();
   magic= sv_magicext((SV*)self->wrapper, NULL, PERL_MAGIC_ext, &nf_fieldset_magic_vt, (char*) self, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)magic; // suppress warning
   #endif
   // Need a ref in order to call sv_bless
   // Also, causes this object to be mortal
   ref= sv_2mortal(newRV_noinc((SV*)self->wrapper));
   sv_bless(ref, gv_stashpv("NERDVANA::Field::FieldSet", GV_ADD));
   return self;
}

/* Magic for binding nf_fieldset_t to a package stash HV.
 * It basically just holds one strong reference to the FieldSet wrapper.
 */

// This only gets called when a package stash is being destroyed.
static int nf_fieldset_pkg_stash_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   nf_fieldset_t *fs= (nf_fieldset_t*) mg->mg_ptr;
   if (fs && !PL_dirty)
      SvREFCNT_dec(fs->wrapper);
   return 0;
}
#ifdef USE_ITHREADS
static int nf_fieldset_pkg_stash_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::Field");
   return 0;
};
#else
#define nf_fieldset_pkg_stash_magic_dup NULL
#endif
static MGVTBL nf_fieldset_pkg_stash_magic_vt= {
   NULL, NULL, NULL, NULL, nf_fieldset_pkg_stash_magic_free,
   NULL, nf_fieldset_pkg_stash_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

void nf_fieldset_link_to_package(pTHX_ nf_fieldset_t *self, HV *pkg_stash) {
   MAGIC *magic;
   // It's an error if we are already linked to a package stash.
   if (self->pkg_stash_ref && SvRV(self->pkg_stash_ref) && SvOK(SvRV(self->pkg_stash_ref)))
      croak("FieldSet is already linked to a package");
   // It's an error if the package stash already points to a different fieldset.
   if (SvMAGICAL((SV*)pkg_stash)) {
      for (magic= SvMAGIC((SV*)pkg_stash); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &nf_fieldset_pkg_stash_magic_vt)
            croak("package already has a FieldSet");
   }
   // magically attach 'self' to the package stash
   magic= sv_magicext((SV*) pkg_stash, NULL, PERL_MAGIC_ext, &nf_fieldset_pkg_stash_magic_vt, (char*) self, 0);
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
   // If the package stash ever gets garbage collected, *and* all objects with a nf_fieldstorage
   // using this fieldset get garbage collected, the refcount drops to 0 and the fieldset
   // also gets garbage collected.
}

void nf_fieldset_extend(pTHX_ nf_fieldset_t *self, UV count) {
   if (count > self->capacity) {
      size_t alloc= count * sizeof(nf_fieldinfo_t*) + NF_HASHTREE_SIZE(count);
      Renewc(self->fields, 1, alloc, nf_fieldinfo_t*);
      self->capacity= count;
      // Need to clear all bytes beyond the end of self->fields+self->capacity
      memset(self->fields + self->field_count, 0, alloc - self->field_count * sizeof(nf_fieldinfo_t*));
      // Now re-index all the existing elements
      if (!nf_fieldset_hashtree_reindex(self->fields + count, count, self->fields, 1, self->field_count))
         croak("Corrupt hashtree");
   }
}

void nf_fieldset_free(pTHX_ nf_fieldset_t *self) {
   IV i;
   // If the XS MAGIC destructor of the wrapper triggered this destructor, it would
   // first clear the pointer.  So it's a bad thing if the wrapper is non-null.
   if (self->wrapper)
      warn("BUG: nf_fieldset_t freed before wrapper destroyed");
   if (self->pkg_stash_ref)
      SvREFCNT_dec(self->pkg_stash_ref);
   for (i= self->field_count-1; i >= 0; i--) {
      nf_fieldinfo_destroy(aTHX_ self->fields[i]);
      // Every 8th element is a block allocation.
      if (!(i & 7))
         Safefree(self->fields[i]);
   }
   Safefree(self->fields);
   Safefree(self);
}

// This is "destroy" rather than "free" because fieldinfo are allocated in blocks
// and can't be individually freed.
void nf_fieldinfo_destroy(pTHX_ nf_fieldinfo_t *self) {
   if (self->name) {
      SvREFCNT_dec(self->name);
      self->name= NULL;
   }
}

/* BEGIN GENERATED ENUM IMPLEMENTATION */
bool nf_field_type_parse(pTHX_ SV *sv, int *dest) {
   if (looks_like_number(sv)) {
      int val= SvIV(sv);
      if (val != SvIV(sv)) // check whether type narrowing lost some of the value
         return false;
      switch (val) {
      case NF_FIELD_TYPE_AV:
      case NF_FIELD_TYPE_BOOL:
      case NF_FIELD_TYPE_HV:
      case NF_FIELD_TYPE_IV:
      case NF_FIELD_TYPE_NV:
      case NF_FIELD_TYPE_PV:
      case NF_FIELD_TYPE_STRUCT:
      case NF_FIELD_TYPE_SV:
      case NF_FIELD_TYPE_UV:
      case NF_FIELD_TYPE_VIRT_AV:
      case NF_FIELD_TYPE_VIRT_HV:
      case NF_FIELD_TYPE_VIRT_SV:
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
               test_str= "AV"; test_val= NF_FIELD_TYPE_AV;
            } else if (str[0] < 'I') {
               test_str= "HV"; test_val= NF_FIELD_TYPE_HV;
            } else {
               test_str= "IV"; test_val= NF_FIELD_TYPE_IV;
            }
         } else if (str[0] < 'S') {
            if (str[0] < 'P') {
               test_str= "NV"; test_val= NF_FIELD_TYPE_NV;
            } else {
               test_str= "PV"; test_val= NF_FIELD_TYPE_PV;
            }
         } else if (str[0] < 'U') {
            test_str= "SV"; test_val= NF_FIELD_TYPE_SV;
         } else {
            test_str= "UV"; test_val= NF_FIELD_TYPE_UV;
         }
         break;
      case 4:
         test_str= "BOOL"; test_val= NF_FIELD_TYPE_BOOL;
         break;
      case 6:
         test_str= "STRUCT"; test_val= NF_FIELD_TYPE_STRUCT;
         break;
      case 7:
         if (str[5] < 'H') {
            test_str= "VIRT_AV"; test_val= NF_FIELD_TYPE_VIRT_AV;
         } else if (str[5] < 'S') {
            test_str= "VIRT_HV"; test_val= NF_FIELD_TYPE_VIRT_HV;
         } else {
            test_str= "VIRT_SV"; test_val= NF_FIELD_TYPE_VIRT_SV;
         }
         break;
      case 13:
         if (str[11] < 'N') {
            if (str[11] < 'H') {
               test_str= "FIELD_TYPE_AV"; test_val= NF_FIELD_TYPE_AV;
            } else if (str[11] < 'I') {
               test_str= "FIELD_TYPE_HV"; test_val= NF_FIELD_TYPE_HV;
            } else {
               test_str= "FIELD_TYPE_IV"; test_val= NF_FIELD_TYPE_IV;
            }
         } else if (str[11] < 'S') {
            if (str[11] < 'P') {
               test_str= "FIELD_TYPE_NV"; test_val= NF_FIELD_TYPE_NV;
            } else {
               test_str= "FIELD_TYPE_PV"; test_val= NF_FIELD_TYPE_PV;
            }
         } else if (str[11] < 'U') {
            test_str= "FIELD_TYPE_SV"; test_val= NF_FIELD_TYPE_SV;
         } else {
            test_str= "FIELD_TYPE_UV"; test_val= NF_FIELD_TYPE_UV;
         }
         break;
      case 15:
         test_str= "FIELD_TYPE_BOOL"; test_val= NF_FIELD_TYPE_BOOL;
         break;
      case 17:
         test_str= "FIELD_TYPE_STRUCT"; test_val= NF_FIELD_TYPE_STRUCT;
         break;
      case 18:
         if (str[16] < 'H') {
            test_str= "FIELD_TYPE_VIRT_AV"; test_val= NF_FIELD_TYPE_VIRT_AV;
         } else if (str[16] < 'S') {
            test_str= "FIELD_TYPE_VIRT_HV"; test_val= NF_FIELD_TYPE_VIRT_HV;
         } else {
            test_str= "FIELD_TYPE_VIRT_SV"; test_val= NF_FIELD_TYPE_VIRT_SV;
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
const char* nf_field_type_name(pTHX_ int val) {
   switch (val) {
   case NF_FIELD_TYPE_AV: return "FIELD_TYPE_AV";
   case NF_FIELD_TYPE_BOOL: return "FIELD_TYPE_BOOL";
   case NF_FIELD_TYPE_HV: return "FIELD_TYPE_HV";
   case NF_FIELD_TYPE_IV: return "FIELD_TYPE_IV";
   case NF_FIELD_TYPE_NV: return "FIELD_TYPE_NV";
   case NF_FIELD_TYPE_PV: return "FIELD_TYPE_PV";
   case NF_FIELD_TYPE_STRUCT: return "FIELD_TYPE_STRUCT";
   case NF_FIELD_TYPE_SV: return "FIELD_TYPE_SV";
   case NF_FIELD_TYPE_UV: return "FIELD_TYPE_UV";
   case NF_FIELD_TYPE_VIRT_AV: return "FIELD_TYPE_VIRT_AV";
   case NF_FIELD_TYPE_VIRT_HV: return "FIELD_TYPE_VIRT_HV";
   case NF_FIELD_TYPE_VIRT_SV: return "FIELD_TYPE_VIRT_SV";
   default:
      return NULL;
   }
}
SV* nf_field_type_wrap(pTHX_ int val) {
   const char *pv= nf_field_type_name(val);
   return pv? nf_newSVivpv(val, pv) : newSViv(val);
}
/* END GENERATED ENUM IMPLEMENTATION */

   #define NF_FIELD_TYPEMASK      0xFF
   #define NF_FIELD_TYPEMASK_SV   0x80
   #define NF_FIELD_TYPE_SV       0x81
   #define NF_FIELD_TYPE_AV       0x82
   #define NF_FIELD_TYPE_HV       0x83
   #define NF_FIELD_TYPEMASK_VIRT 0x40
   #define NF_FIELD_TYPE_VIRT_SV  0x41
   #define NF_FIELD_TYPE_VIRT_AV  0x42
   #define NF_FIELD_TYPE_VIRT_HV  0x43
   #define NF_FIELD_TYPEMASK_C    0x20
   #define NF_FIELD_TYPE_BOOL     0x21
   #define NF_FIELD_TYPE_IV       0x22
   #define NF_FIELD_TYPE_UV       0x23
   #define NF_FIELD_TYPE_NV       0x24
   #define NF_FIELD_TYPE_PV       0x25
   #define NF_FIELD_TYPE_STRUCT   0x26
   #define NF_FIELD_INHERITED    0x100
   #define NF_FIELD_HAS_DEFAULT  0x200


nf_fieldinfo_t * nf_fieldset_add_field(pTHX_ nf_fieldset_t *self, SV *name, nf_field_type_t type, size_t align, size_t size) {
   nf_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   nf_fieldinfo_t *f;
   char *name_p= SvPV(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   if (nf_fieldset_hashtree_find(self->fields + self->capacity, self->capacity, self->fields, &key))
      croak("Field %s already exists", SvPV_nolen(name));
   if (self->field_count >= self->capacity)
      nf_fieldset_extend(aTHX_ self, (self->capacity < 48? self->capacity + 16 : self->capacity + (self->capacity >> 1)));
   // If this is a multiple of 8, allocate a new block of fieldinfo structs.
   i= self->field_count++;
   if (!(i & 7))
      Newxz(self->fields[i], 8, nf_fieldinfo_t);
   else // else find the pointer from previous
      self->fields[i]= self->fields[i-1] + 1;
   f= self->fields[i];
   f->name= name;
   SvREFCNT_inc(name);
   f->name_hashcode= key.name_hashcode;
   f->fieldset= self;
   f->field_idx= i;
   f->flags= type;
   if (align == 0) {
      switch (type) {
      case NF_FIELD_TYPE_SV: case NF_FIELD_TYPE_AV: case NF_FIELD_TYPE_HV: case NF_FIELD_TYPE_PV:
         align= size= sizeof(SV*); break;
      case NF_FIELD_TYPE_BOOL:
         align= size= sizeof(bool); break;
      case NF_FIELD_TYPE_IV:
         align= size= sizeof(IV); break;
      case NF_FIELD_TYPE_UV:
         align= size= sizeof(UV); break;
      case NF_FIELD_TYPE_NV:
         align= size= sizeof(NV); break;
      default:
         croak("Un-handled type: %ld", (long) type);
      }
   }
   if (size && align) {
      f->storage_ofs= (self->storage_size + align - 1) & ~(size_t)(align-1);
      self->storage_size= f->storage_ofs + size;
   }
   nf_fieldset_hashtree_reindex(self->fields + self->capacity, self->capacity, self->fields, i+i, i+i);
   return self->fields[i];
}

nf_fieldinfo_t * nf_fieldset_get_field(pTHX_ nf_fieldset_t *self, SV *name, int flags) {
   nf_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   char *name_p= SvPV(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   i= nf_fieldset_hashtree_find(self->fields + self->capacity, self->capacity, self->fields, &key);
   return i? self->fields[i-1] : NULL;
}

/**********************************************************************************************\
* fieldstorage_map_t implementation
\**********************************************************************************************/

nf_fieldstorage_map_t * nf_fieldstorage_map_alloc(pTHX_ size_t capacity) {
   nf_fieldstorage_map_t *self= (nf_fieldstorage_map_t *) safecalloc(
      sizeof(nf_fieldstorage_map_t)            // top-level struct info
      + sizeof(nf_fieldstorage_t*) * capacity  // element array
      + NF_HASHTREE_SIZE(capacity),            // hashtree
      1);
   self->capacity= capacity;
   return self;
}

// Take a guess that if it is being cloned, the el_count is as large as it needs to be.
//nf_fieldstorage_map_t * nf_fieldstorage_map_clone(pTHX_ nf_fieldstorage_map_t *orig) {
//   nf_fieldstorage_map_t *self= nf_fieldstorage_map_alloc(aTHX_ orig->el_count);
//   int i;
//   for (i= orig->el_count-1; i >= 0; i--)
//      self->el[i]= nf_fieldstorage_clone(aTHX_ orig->el[i]);
//   self->el_count= orig->el_count;
//   nf_fieldstorage_map_hashtree_reindex(self->el + self->capacity, self->capacity, self->el, 1, self->el_count);
//   return self;
//}

void nf_fieldstorage_map_free(pTHX_ nf_fieldstorage_map_t *self) {
   int i;
   for (i= self->el_count-1; i >= 0; i--)
      nf_fieldstorage_free(aTHX_ self->el[i]);
   Safefree(self);
}

nf_fieldstorage_t* nf_fieldstorage_map_get(pTHX_ nf_fieldstorage_map_t **self_p, nf_fieldset_t *fset, int flags) {
   nf_fieldstorage_map_t *self= *self_p, *newself;
   size_t i, capacity= self? self->capacity : 0;
   nf_fieldstorage_t *fstor;
   // If called on a NULL pointer, fieldstorage is not found.
   i= !self? 0
      : nf_fieldstorage_map_hashtree_find(self->el + capacity, capacity, self->el, fset);
   if (i) {
      --i;
      // Check for new fields added
      if (self->el[i]->storage_size != self->el[i]->fieldset->storage_size)
         nf_fieldstorage_handle_new_fields(aTHX_ self->el + i);
      return self->el[i];
   }
   else if (flags & NF_FIELDSTORAGE_AUTOCREATE) {
      // First question, is there room to add it?
      if (!self || self->el_count + 1 > capacity) {
         // Resize and re-add all
         capacity += !capacity? 7 : capacity < 50? capacity : (capacity >> 1); // 7, 14, 28, 56, 84, 126
         newself= nf_fieldstorage_map_alloc(aTHX_ capacity);
         if (self) {
            memcpy(newself->el, self->el, ((char*)(self->el + self->el_count)) - ((char*)self->el));
            newself->el_count= self->el_count;
            Safefree(self);
         }
         *self_p= self= newself;
         i= 1; // all need re-indexed; hashtree element numbers are 1-based
      } else {
         i= self->el_count+1;
      }
      // Allocate the fieldstorage and index it
      fstor= self->el[self->el_count++]= nf_fieldstorage_alloc(aTHX_ fset);
      nf_fieldstorage_map_hashtree_reindex(self->el + self->capacity, self->capacity, self->el, i, self->el_count);
      return fstor;
   }
   else return NULL;
}

/**********************************************************************************************\
* fieldstorage_t implementation
\**********************************************************************************************/

nf_fieldstorage_t * nf_fieldstorage_alloc(pTHX_ nf_fieldset_t *fset) {
   nf_fieldstorage_t *self= (nf_fieldstorage_t *) safecalloc(
      sizeof(nf_fieldstorage_t)
      + fset->storage_size,
      1);
   self->fieldset= fset;
   self->storage_size= fset->storage_size;
   SvREFCNT_inc(fset->pkg_stash_ref);
   return self;
}

void nf_fieldstorage_handle_new_fields(pTHX_ nf_fieldstorage_t **fstor) {
   nf_fieldset_t *fset= (*fstor)->fieldset;
   size_t n, diff;
   // Currently, nothing needs done aside from making sure this object
   // is allocated to include storage_size (and that all those bytes are zero)
   if ((*fstor)->storage_size < fset->storage_size) {
      n= sizeof(nf_fieldstorage_t) + fset->storage_size;
      *fstor= saferealloc(*fstor, n);
      // Zero all newly allocated bytes
      diff= fset->storage_size - (*fstor)->storage_size;
      Zero((((char*)(*fstor)) + n - diff), diff, char);
      // Update fields
      (*fstor)->storage_size= fset->storage_size;
   }
}

#if 0
nf_fieldstorage_t * nf_fieldstorage_clone(pTHX_ nf_fieldstorage_t *orig) {
   nf_fieldstorage_t *self= nf_fieldstorage_alloc(aTHX_ orig->fieldset);
   nf_fieldinfo_t *finfo;
   int i, type;
   SV **sv_p;
   for (i= orig->field_count-1; i >= 0; i--) {
      finfo= self->fieldset->fields+i;
      if (finfo->flags & NF_FIELD_TYPE_SV) {
         // TODO: when cloning for threads, is this good enough?
         // Will the new interpreter try to share CoW with the old?
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) {
            switch (NF_FIELDINFO_TYPE(finfo)) {
            case NF_FIELD_TYPE_SV: *sv_p= newSVsv(*sv_p); break;
            case NF_FIELD_TYPE_AV: *sv_p= (SV*) av_make(1+av_len((AV*) *sv_p), AvARRAY((AV*) *sv_p)); break;
            case NF_FIELD_TYPE_HV: *sv_p= (SV*) newHVhv((HV*) *sv_p); break;
            default: croak("bug");
            }
         }
      }
   }
   return self;
}
#endif
void nf_fieldstorage_free(pTHX_ nf_fieldstorage_t *self) {
   nf_fieldset_t *fset= self->fieldset;
   nf_fieldinfo_t *finfo;
   SV **sv_p;
   int i;
   for (i= fset->field_count-1; i >= 0; i--) {
      finfo= fset->fields[i];
      if ((finfo->flags & NF_FIELD_TYPE_SV) && finfo->storage_ofs < self->storage_size) {
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) SvREFCNT_dec(*sv_p);
      }
   }
   SvREFCNT_dec(fset->pkg_stash_ref);
   Safefree(self);
}

void nf_fieldstorage_field_init_default(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   int type= NF_FIELDINFO_TYPE(finfo);
   char *stor_p= self->data + finfo->storage_ofs;
   if (!(finfo->flags & NF_FIELD_HAS_DEFAULT))
      return;
   switch (type) {
   case NF_FIELD_TYPE_SV: *((SV**)stor_p)= newSVsv(finfo->def_val.sv); break;
   case NF_FIELD_TYPE_AV: *((AV**)stor_p)= nf_newAVav(finfo->def_val.av); break;
   case NF_FIELD_TYPE_HV: *((HV**)stor_p)= newHVhv(finfo->def_val.hv); break;
   default:
      croak("nf_fieldstorage_field_init_default: Unhandled type 0x%02X", type);
   }
}

bool nf_fieldstorage_field_exists(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= NF_FIELDINFO_TYPE(finfo);
   if (!(type & NF_FIELD_TYPE_SV))
      croak("Not an SV field");
   // It always exists if it has a default (even if we didn't lazy-initialize it yet)
   if (finfo->flags & NF_FIELD_HAS_DEFAULT)
      return true;
   // It exists if the pointer is assigned.
   sv_p= (SV**)(self->data + finfo->storage_ofs);
   return *sv_p != NULL;
}

// Returns the value of an object's storage for a field, in the form of an SV.
// The returned value might be the default value SV pointer itself, if the field
// has not been initialized. The returned value might also be a constant.
// It is intended that this value be assigned to another lvalue SV.
SV *nf_fieldstorage_field_rvalue(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= NF_FIELDINFO_TYPE(finfo);
   int has_default= finfo->flags & NF_FIELD_HAS_DEFAULT;
   if (type & NF_FIELD_TYPE_SV) {
      sv_p= (SV**)(self->data + finfo->storage_ofs);
      if (!*sv_p && has_default)
         nf_fieldstorage_field_init_default(aTHX_ self, finfo);
      if (*sv_p)
         return *sv_p;
   }
   else {
      croak("nf_fieldstorage_field_rvalue: unhandled type 0x%02X", type);
   }
   return &PL_sv_undef;
}

// Returns an SV directly representing the storage for the field.
// Modifications to this SV will show up for all code using the field on this object.
// If the field was not initialized, it will be after this call and 'exists' will
// return true.
SV *nf_fieldstorage_field_lvalue(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= NF_FIELDINFO_TYPE(finfo);
   int has_default= finfo->flags & NF_FIELD_HAS_DEFAULT;
   if (type & NF_FIELD_TYPE_SV) {
      sv_p= (SV**)(self->data + finfo->storage_ofs);
      if (!*sv_p) {
         if (has_default)
            nf_fieldstorage_field_init_default(aTHX_ self, finfo);
         else
            *sv_p= newSV(0);
      }
      return *sv_p;
   }
   else {
      croak("nf_fieldstorage_field_lvalue: unhandled type 0x%02X", type);
   }
}

#if 0
// Assign to the storage of a field.
void nf_fieldstorage_field_setsv(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo, SV *value) {
   SV **av_array;
   size_t av_array_n;
   int type= NF_FIELDINFO_TYPE(finfo);
   switch (type) {
   case NF_FIELD_TYPE_SV: {
         SV **sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) sv_setsv(*sv_p, value);
         else *sv_p= newSVsv(value);
      }
      break;
   case NF_FIELD_TYPE_AV: {
         AV **av_p= (AV**)(self->data + finfo->storage_ofs);
         AV *src_av= (SvTYPE(value) == SVt_PVAV)? (AV*)value
            : SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVAV? (AV*)SvRV(value)
            : NULL;
         if (src_av) {
            AV *tmp= av_make(
            
            av_clear(*av_p);
            if (src_av) {
               av_extend(*av_p, av_len(src_av));
               
         
   case NF_FIELD_TYPE_HV:
   }
}
#endif

/**********************************************************************************************\
* This code sets/gets the XS Magic to objects
\**********************************************************************************************/

/*
  - nf_fieldset_t structs are owned by NERDVANA::Field::FieldSet objects.
  - Package stashes have a magic pointer attached which acts as a strong reference
     to the FieldSet object.  (but is actually a pointer to the nf_fieldset_t)
  - FieldInfo objects are blessed arrayrefs of [ FieldSet, field_index ]
  - nf_fieldstorage_map_t are attached to arbitrary objects
  - nf_fieldstorage_t are owned by the object,
     but hold a strong reference to the FieldSet object

*/

/* Get or create nf_fieldset_t attached to package stash (or anonymous HV)
 * The expected 'sv' are either the package stash itself, or a ref to a blessed ref to it.
 */
static nf_fieldset_t* nf_fieldset_magic_get(pTHX_ SV *sv, int flags) {
   MAGIC* magic;
   if (SvROK(sv))
      sv= SvRV(sv);
   if (SvMAGICAL(sv)) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && (
               magic->mg_virtual == &nf_fieldset_magic_vt
               || magic->mg_virtual == &nf_fieldset_pkg_stash_magic_vt
            ))
            return (nf_fieldset_t*) magic->mg_ptr;
   }
   if (flags & OR_DIE)
      croak("Not a FieldSet object");
   return NULL;
}

// Called when a ::FieldInfo object gets garbage collected.  It has a strong reference
// to the nf_fieldset_t owner, so that needs released, but the fieldinfo struct
// does not get deleted.  Many Field objects can refer to the same nf_fieldinfo_t
static int nf_fieldinfo_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   nf_fieldinfo_t *finf= (nf_fieldinfo_t*) mg->mg_ptr;
   if (finf && !PL_dirty)
      SvREFCNT_dec(finf->fieldset->wrapper);
   return 0;
}
#ifdef USE_ITHREADS
static int nf_fieldinfo_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: thread support for NERDVANA::Field");
   return 0;
};
#else
#define nf_fieldinfo_magic_dup NULL
#endif
static MGVTBL nf_fieldinfo_magic_vt= {
   NULL, NULL, NULL, NULL, nf_fieldinfo_magic_free,
   NULL, nf_fieldinfo_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

static SV* nf_fieldinfo_wrap(pTHX_ nf_fieldinfo_t *finfo) {
   if (!finfo)
      return &PL_sv_undef;
   SV *sv= newSV(0);
   MAGIC *magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &nf_fieldinfo_magic_vt, (char*)finfo, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)magic;
   #endif
   SvREFCNT_inc(finfo->fieldset->wrapper); // refcnt on fieldset, not fieldinfo
   return sv_bless(newRV_noinc(sv),
      gv_stashpv("NERDVANA::Field::FieldInfo", GV_ADD));
}

static nf_fieldinfo_t* nf_fieldinfo_magic_get(pTHX_ SV *obj, int flags) {
   MAGIC* magic;
   if (SvROK(obj) && SvMAGICAL(SvRV(obj))) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(SvRV(obj)); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &nf_fieldinfo_magic_vt)
            return (nf_fieldinfo_t*) magic->mg_ptr;
   }
   if (flags & OR_DIE)
      croak("Not a FieldInfo object");
   return NULL;
}

/* Magic for binding nf_fieldstorage_map_t to an arbitrary object */

static int nf_fieldstorage_map_magic_free(pTHX_ SV* sv, MAGIC* mg) {
   nf_fieldstorage_map_t *fsm= (nf_fieldstorage_map_t*) mg->mg_ptr;
   if (fsm)
      nf_fieldstorage_map_free(aTHX_ fsm);
   return 0; // ignored anyway
}
#ifdef USE_ITHREADS
static int nf_fieldstorage_map_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   croak("TODO: support ithreads for NERDVANA::Field");
   return 0;
};
#else
#define nf_fieldstorage_map_magic_dup NULL
#endif
// magic virtual method table for nf_fieldstorage_map_t
static MGVTBL nf_fieldstorage_map_magic_vt= {
   NULL, NULL, NULL, NULL, nf_fieldstorage_map_magic_free,
   NULL, nf_fieldstorage_map_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

/* Get or create nf_fieldstorage_t for a given nf_fieldset_t attached to an arbitrary object.
 * Use AUTOCREATE to attach magic and allocate a struct if it wasn't present.
 * Use OR_DIE for a built-in croak() if the return value would be NULL.
 */
static nf_fieldstorage_t* nf_fieldstorage_magic_get(pTHX_ SV *sv, nf_fieldset_t *fs, int flags) {
   MAGIC* magic= NULL;
   if (SvMAGICAL(sv)) {
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &nf_fieldstorage_map_magic_vt)
            break;
   }
   if (!magic) {
      if (!(flags & NF_FIELDSTORAGE_AUTOCREATE))
         return NULL;
      magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &nf_fieldstorage_map_magic_vt, NULL, 0);
      #ifdef USE_ITHREADS
      magic->mg_flags |= MGf_DUP;
      #endif
   }
   return nf_fieldstorage_map_get(aTHX_ (nf_fieldstorage_map_t**) &magic->mg_ptr, fs, flags);
}

/**********************************************************************************************\
* NERDVANA::Field Public API
\**********************************************************************************************/
MODULE = NERDVANA::Field                  PACKAGE = NERDVANA::Field

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

nf_fieldset_t*
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
      RETVAL= nf_fieldset_magic_get(aTHX_ (SV*) pkg_stash, 0);
      if (!RETVAL) {
         RETVAL= nf_fieldset_alloc(aTHX_);
         nf_fieldset_link_to_package(aTHX_ RETVAL, pkg_stash);
      }
   OUTPUT:
      RETVAL

nf_fieldset_t*
new_fieldset()
   CODE:
      RETVAL= nf_fieldset_alloc(aTHX_);
   OUTPUT:
      RETVAL

void
field_type(sv)
   SV *sv;
   INIT:
      int type;
   PPCODE:
      ST(0)= nf_field_type_parse(aTHX_ sv, &type)
         ? sv_2mortal(nf_field_type_wrap(aTHX_ type))
         : &PL_sv_undef;
      XSRETURN(1);

MODULE = NERDVANA::Field                  PACKAGE = NERDVANA::Field::FieldSet
PROTOTYPES: DISABLE

void
new(cls)
   const char *cls
   INIT:
      nf_fieldset_t *self;
   PPCODE:
      self= nf_fieldset_alloc(aTHX_);
      ST(0)= sv_2mortal(newRV_inc((SV*) self->wrapper));
      // Allow it to be blessed as something else
      if (strcmp(cls, "NERDVANA::Field::FieldSet") != 0)
         sv_bless(ST(0), gv_stashpv(cls, GV_ADD));
      XSRETURN(1);

IV
field_count(self)
   nf_fieldset_t *self
   CODE:
      RETVAL= self->field_count;
   OUTPUT:
      RETVAL

void
package_name(self)
   nf_fieldset_t *self
   INIT:
      HV *pkg= self->pkg_stash_ref? (HV*) SvRV(self->pkg_stash_ref) : NULL;
   PPCODE:
      ST(0)= pkg && HvENAMELEN(pkg)? sv_2mortal(newSVpvn(HvENAME(pkg), HvENAMELEN(pkg))) : &PL_sv_undef;
      XSRETURN(1);

IV
_capacity(self)
   nf_fieldset_t *self
   CODE:
      RETVAL= self->capacity;
   OUTPUT:
      RETVAL

IV
_storage_size(self)
   nf_fieldset_t *self
   CODE:
      RETVAL= self->storage_size;
   OUTPUT:
      RETVAL

void
add_field(self, name, type, ...)
   nf_fieldset_t *self
   SV *name
   nf_field_type_t type
   INIT:
      nf_fieldinfo_t *finfo;
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
      case NF_FIELD_TYPE_SV: {
            finfo= nf_fieldset_add_field(aTHX_ self, name, type, 0, 0);
            if (def_val) {
               finfo->flags |= NF_FIELD_HAS_DEFAULT;
               finfo->def_val.sv= newSVsv(def_val);
            }
            break;
         }
      default:
         croak("Unsupported type %d", (int) type);
      }
      // Only generate the object if defined wantarray
      if (wantarray != G_VOID) {
         ST(0)= sv_2mortal(nf_fieldinfo_wrap(finfo));
         XSRETURN(1);
      }
      else XSRETURN(0);

nf_fieldinfo_t*
field(fs, name)
   nf_fieldset_t *fs
   SV *name
   INIT:
      UV field_idx;
   CODE:
      if (looks_like_number(name)) {
         field_idx= SvUV(name);
         RETVAL= (field_idx < fs->field_count)? fs->fields[field_idx] : NULL;
      } else {
         RETVAL= nf_fieldset_get_field(fs, name, 0);
      }
   OUTPUT:
      RETVAL

MODULE = NERDVANA::Field              PACKAGE = NERDVANA::Field::FieldInfo

nf_fieldset_t*
fieldset(self)
   nf_fieldinfo_t *self
   CODE:
      RETVAL= self->fieldset;
   OUTPUT:
      RETVAL

IV
field_idx(self)
   nf_fieldinfo_t *self
   CODE:
      RETVAL= self->field_idx;
   OUTPUT:
      RETVAL

SV*
name(self)
   nf_fieldinfo_t *self
   CODE:
      RETVAL= newSVsv(self->name);
   OUTPUT:
      RETVAL

nf_field_type_t
type(self)
   nf_fieldinfo_t *self
   CODE:
      RETVAL= NF_FIELDINFO_TYPE(self);
   OUTPUT:
      RETVAL

BOOT:
   HV* stash= gv_stashpv("NERDVANA::Field", GV_ADD);
   /* BEGIN GENERATED ENUM CONSTANTS */
   newCONSTSUB(stash, "FIELD_TYPE_AV", nf_newSVivpv(NF_FIELD_TYPE_AV, "FIELD_TYPE_AV"));
   newCONSTSUB(stash, "FIELD_TYPE_BOOL", nf_newSVivpv(NF_FIELD_TYPE_BOOL, "FIELD_TYPE_BOOL"));
   newCONSTSUB(stash, "FIELD_TYPE_HV", nf_newSVivpv(NF_FIELD_TYPE_HV, "FIELD_TYPE_HV"));
   newCONSTSUB(stash, "FIELD_TYPE_IV", nf_newSVivpv(NF_FIELD_TYPE_IV, "FIELD_TYPE_IV"));
   newCONSTSUB(stash, "FIELD_TYPE_NV", nf_newSVivpv(NF_FIELD_TYPE_NV, "FIELD_TYPE_NV"));
   newCONSTSUB(stash, "FIELD_TYPE_PV", nf_newSVivpv(NF_FIELD_TYPE_PV, "FIELD_TYPE_PV"));
   newCONSTSUB(stash, "FIELD_TYPE_STRUCT", nf_newSVivpv(NF_FIELD_TYPE_STRUCT, "FIELD_TYPE_STRUCT"));
   newCONSTSUB(stash, "FIELD_TYPE_SV", nf_newSVivpv(NF_FIELD_TYPE_SV, "FIELD_TYPE_SV"));
   newCONSTSUB(stash, "FIELD_TYPE_UV", nf_newSVivpv(NF_FIELD_TYPE_UV, "FIELD_TYPE_UV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_AV", nf_newSVivpv(NF_FIELD_TYPE_VIRT_AV, "FIELD_TYPE_VIRT_AV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_HV", nf_newSVivpv(NF_FIELD_TYPE_VIRT_HV, "FIELD_TYPE_VIRT_HV"));
   newCONSTSUB(stash, "FIELD_TYPE_VIRT_SV", nf_newSVivpv(NF_FIELD_TYPE_VIRT_SV, "FIELD_TYPE_VIRT_SV"));
   /* END GENERATED ENUM CONSTANTS */
