#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

/* nf_fieldinfo describes one field of one class.
 * nf_fieldset is the collection of fields for one class.
 * nf_fieldstorage is the struct magically attached to any sub that uses fields
 */

struct nf_fieldset;          typedef struct nf_fieldset nf_fieldset_t;
struct nf_fieldinfo;         typedef struct nf_fieldinfo nf_fieldinfo_t;
struct nf_fieldinfo_key;     typedef struct nf_fieldinfo_key nf_fieldinfo_key_t;
struct nf_fieldstorage_map;  typedef struct nf_fieldstorage_map nf_fieldstorage_map_t;
struct nf_fieldstorage;      typedef struct nf_fieldstorage nf_fieldstorage_t;

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
   SV *name;
   unsigned name_hashcode;
   int flags;
   #define NF_FIELDINFO_TYPE_MASK    0xFF
   #define NF_FIELDINFO_TYPE_VIRTUAL    0
   #define NF_FIELDINFO_TYPE_SV         1
   #define NF_FIELDINFO_TYPE_AV         3
   #define NF_FIELDINFO_TYPE_HV         5
   #define NF_FIELDINFO_INHERITED   0x100
   #define NF_FIELDINFO_HAS_DEFAULT 0x200
   union {
      SV *sv;
      AV *av;
      HV *hv;
   } def_val;
   size_t storage_ofs;
};

#define NF_FIELDSET_AUTOCREATE 0x10000
#define OR_DIE 0x20000
nf_fieldset_t * nf_fieldset_alloc(pTHX_);
void nf_fieldset_extend(pTHX_ nf_fieldset_t *self, UV field_count);
nf_fieldset_t * nf_fieldset_dup(pTHX_ nf_fieldset_t *self);
void nf_fieldset_free(pTHX_ nf_fieldset_t *self);
void nf_fieldinfo_destroy(pTHX_ nf_fieldinfo_t *finf);
nf_fieldinfo_t * nf_fieldset_get_field(pTHX_ nf_fieldset_t *self, SV *name, int flags);

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

size_t nf_fieldstorage_map_hashtree_find(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, nf_fieldset_t * search_key);

bool nf_fieldstorage_map_hashtree_reindex(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t el_i, size_t last_i);

bool nf_fieldstorage_map_hashtree_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el);

/* END GENERATED NF_HASHTREE HEADERS */

#include "hashtree.c"

/**********************************************************************************************\
* fieldset_t implementation
\**********************************************************************************************/

nf_fieldset_t * nf_fieldset_alloc(pTHX_) {
   nf_fieldset_t *self;
   SV *tmp;
   Newxz(self, 1, nf_fieldset_t);
   return self;
}

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
#define nf_fieldstorage_map_magic_dup NULL
#endif
static MGVTBL nf_fieldset_magic_vt= {
   NULL, NULL, NULL, NULL,
   nf_fieldset_magic_free, NULL, nf_fieldset_magic_dup,
#ifdef MGf_LOCAL
   ,NULL
#endif
};

SV * nf_fieldset_get_wrapper(pTHX_ nf_fieldset_t *self) {
   SV *ref;
   if (!self->wrapper) {
      self->wrapper= newHV();
      magic= sv_magicext(self->wrapper, NULL, PERL_MAGIC_ext, &nf_fieldset_magic_vt, (char*) self, 0);
      #ifdef USE_ITHREADS
      magic->mg_flags |= MGf_DUP;
      #else
      (void)magic; // suppress warning
      #endif
      ref= sv_2mortal(newRV_noinc(self->wrapper));
      sv_bless(ref, gv_stashpvn("NERDVANA::Field::FieldSet", 25, GV_ADD));
   } else {
      ref= sv_2mortal(newRV_inc(self->wrapper));
   }
   return ref;
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
#define nf_fieldstorage_map_magic_dup NULL
#endif
static MGVTBL nf_fieldset_magic_vt= {
   NULL, NULL, NULL, NULL,
   nf_fieldset_pkg_stash_magic_free, NULL, nf_fieldset_pkg_stash_magic_dup,
#ifdef MGf_LOCAL
   ,NULL
#endif
};

void nf_fieldset_link_to_package(pTHX_ nf_fieldset_t *self, HV *pkg_stash) {
   MAGIC *mg;
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
   mg= sv_magicext((SV*) pkg_stash, NULL, PERL_MAGIC_ext, &nf_fieldset_pkg_stash_magic_vt, (char*) self, 0);
   #ifdef USE_ITHREADS
   magic->mg_flags |= MGf_DUP;
   #else
   (void)mg; // suppress warning
   #endif
   // The package stash will now hold a strong reference to us.
   // The wrapper is where we keep the refcount for self, so it needs to exist.
   if (!self->wrapper)
      nf_fieldset_get_wrapper(aTHX_ self);
   SvREFCNT_inc(self->wrapper);
   // Now create a weak-ref from self to the package stash
   self->pkg_stash_ref= newRV_inc(pkg_stash);
   sv_rvweaken(self->pkg_stash_ref);
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

nf_fieldinfo_t * nf_fieldset_add_field(pTHX_ nf_fieldset_t *self, SV *name) {
   nf_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   char *name_p= SvPV(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   if (nf_fieldset_hashtree_find(self->fields + self->capacity, self->capacity, self->fields, &key))
      croak("Field %s already exists", SvPV_nolen(name));
   if (self->field_count >= self->capacity)
      nf_fieldset_extend(aTHX_ self, (self->capacity < 48? self->capacity + 16 : self->capacity + (self->capacity >> 1)));
   // If this is a multiple of 8, allocate a new block of fieldinfo structs.
   i= self->field_count;
   if (!(i & 7))
      Newxz(self->fields[i], 8, nf_fieldinfo_t);
   else // else find the pointer from previous
      self->fields[i]= self->fields[i-1] + 1;
   self->field_count++;
   self->fields[i]->name= name;
   SvREFCNT_inc(name);
   self->fields[i]->name_hashcode= key.name_hashcode;
   nf_fieldset_hashtree_reindex(self->fields + self->capacity, self->capacity, self->fields, i+i, i+i);
   return NULL;
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
nf_fieldstorage_map_t * nf_fieldstorage_map_clone(pTHX_ nf_fieldstorage_map_t *orig) {
   nf_fieldstorage_map_t *self= nf_fieldstorage_map_alloc(aTHX_ orig->el_count);
   int i;
   for (i= orig->el_count-1; i >= 0; i--)
      self->el[i]= nf_fieldstorage_clone(aTHX_ orig->el[i]);
   self->el_count= orig->el_count;
   nf_fieldstorage_map_hashtree_reindex(self->el + self->capacity, self->capacity, self->el, 1, self->el_count);
   return self;
}

void nf_fieldstorage_map_free(pTHX_ nf_fieldstorage_map_t *self) {
   int i;
   for (i= self->el_count-1; i >= 0; i--)
      nf_fieldstorage_free(aTHX_ self->el[i]);
   Safefree(self);
}

nf_fieldstorage_t* nf_fieldstorage_map_get(pTHX_ nf_fieldstorage_map_t **self_p, nf_fieldset_t *fset, int flags) {
   nf_fieldstorage_map_t *self= *self_p, *newself;
   size_t i, n, capacity= self? self->capacity : 0;
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

// Make one array hold all the same elements of another, respecing magic.
// Seems like there ought to be something in perlapi to do this?
void nf_av_copy(pTHX_ AV *dest, SV *src) {
   size_t i;
   SV *el, **el_p, *s;
   AV *src_av= (SvTYPE(src) == SVt_PVAV)? (AV*)src
      : SvROK(src) && SvTYPE(SvRV(src)) == SVt_PVAV? (AV*)SvRV(src)
      : NULL;
   if (!src_av)
      croak("Expected array or arrayref");
   av_fill(dest, av_len(src_av));
   for (i= 0; i <= av_len(src_av); i++) {
      el= *av_fetch(dest, i, 1);
      el_p= av_fetch(src_av, i, 0);
      sv_setsv(el, el_p && *el_p? *el_p : &PL_sv_undef);
   }
}
AV* nf_newAVav(pTHX_ AV *src) {
   AV *dest= newAV();
   nf_av_copy(aTHX_ dest, (SV*)src);
   return dest;
}

nf_fieldstorage_t * nf_fieldstorage_alloc(pTHX_ nf_fieldset_t *fset) {
   int i;
   char *dest_p;
   nf_fieldstorage_t *self= (nf_fieldstorage_t *) safecalloc(
      sizeof(nf_fieldstorage_t)
      + fset->storage_size,
      1);
   self->fieldset= fset;
   self->storage_size= fset->storage_size;
   SvREFCNT_inc(fset->pkg_stash);
   return self;
}

void nf_fieldstorage_handle_new_fields(pTHX_ nf_fieldstorage_t **fstor) {
   nf_fieldstorage_t *tmp;
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
      if (finfo->flags & NF_FIELDINFO_TYPE_SV) {
         // TODO: when cloning for threads, is this good enough?
         // Will the new interpreter try to share CoW with the old?
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) {
            switch (finfo->flags & NF_FIELDINFO_TYPE_MASK) {
            case NF_FIELDINFO_TYPE_SV: *sv_p= newSVsv(*sv_p); break;
            case NF_FIELDINFO_TYPE_AV: *sv_p= (SV*) av_make(1+av_len((AV*) *sv_p), AvARRAY((AV*) *sv_p)); break;
            case NF_FIELDINFO_TYPE_HV: *sv_p= (SV*) newHVhv((HV*) *sv_p); break;
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
   int i, type;
   for (i= fset->field_count-1; i >= 0; i--) {
      finfo= fset->fields[i];
      if ((finfo->flags & NF_FIELDINFO_TYPE_SV) && finfo->storage_ofs < self->storage_size) {
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) SvREFCNT_dec(*sv_p);
      }
   }
   SvREFCNT_dec(fset->pkg_stash);
   Safefree(self);
}

void nf_fieldstorage_field_init_default(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   char *stor_p= self->data + finfo->storage_ofs;
   if (!(finfo->flags & NF_FIELDINFO_HAS_DEFAULT))
      return;
   switch (type) {
   case NF_FIELDINFO_TYPE_SV: *((SV**)stor_p)= newSVsv(finfo->def_val.sv); break;
   case NF_FIELDINFO_TYPE_AV: *((AV**)stor_p)= nf_newAVav(finfo->def_val.av); break;
   case NF_FIELDINFO_TYPE_HV: *((HV**)stor_p)= newHVhv(finfo->def_val.hv); break;
   default:
      croak("nf_fieldstorage_field_init_default: Unhandled type 0x%02X", type);
   }
}

bool nf_fieldstorage_field_exists(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   if (!(type & NF_FIELDINFO_TYPE_SV))
      croak("Not an SV field");
   // It always exists if it has a default (even if we didn't lazy-initialize it yet)
   if (finfo->flags & NF_FIELDINFO_HAS_DEFAULT)
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
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   int has_default= finfo->flags & NF_FIELDINFO_HAS_DEFAULT;
   if (type & NF_FIELDINFO_TYPE_SV) {
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
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   int has_default= finfo->flags & NF_FIELDINFO_HAS_DEFAULT;
   if (type & NF_FIELDINFO_TYPE_SV) {
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

// Make one hashtable equal another, respecting magic
void nf_hv_copy(pTHX_ HV *dest, SV *src) {
   HV *src_hv= (SvTYPE(src) == SVt_PVHV? (HV*)src
      : SvROK(src) && SvTYPE(SvRV(src)) == SVt_PVHV? (HV*)SvRV(src)
      : NULL;
   if (!src_hv)
      croak("Expected hash or hashref");
   hv_clear(dest);
   
}

// Assign to the storage of a field.
void nf_fieldstorage_field_setsv(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo, SV *value) {
   SV **av_array;
   size_t av_array_n;
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   switch (type) {
   case NF_FIELDINFO_TYPE_SV: {
         SV **sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) sv_setsv(*sv_p, value);
         else *sv_p= newSVsv(value);
      }
      break;
   case NF_FIELDINFO_TYPE_AV: {
         AV **av_p= (AV**)(self->data + finfo->storage_ofs);
         AV *src_av= (SvTYPE(value) == SVt_PVAV)? (AV*)value
            : SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVAV? (AV*)SvRV(value)
            : NULL;
         if (src_av) {
            AV *tmp= av_make(
            
            av_clear(*av_p);
            if (src_av) {
               av_extend(*av_p, av_len(src_av));
               
         
   case NF_FIELDINFO_TYPE_HV:
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
   nf_fieldset_t *fs;
   if (SvROK(sv) && SvMAGICAL(SvRV(sv))) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(SvRV(sv)); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && (
               magic->mg_virtual == &nf_fieldset_magic_vt
               || magic->mg_virtual == &nf_fieldset_pkg_stash_magic_vt
            ))
            return (nf_fieldset_t*) &magic->mg_ptr;
   }
   if (flags & OR_DIE)
      croak("Not a FieldSet object");
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
fieldset_for_package(pkg)
   SV *pkg
   INIT:
      HV *pkg_stash;
      UV pkg_str_len;
      const char *pkg_str;
      nf_fieldset_t *fset;
   PPCODE:
      if (SvROK(pkg) && SvTYPE(SvRV(pkg)) == SVt_PVHV && HvENAME((HV*)SvRV(pkg)))
         pkg_stash= (HV*) SvRV(pkg);
      else {
         pkg_str= SvPV(pkg, pkg_str_len);
         pkg_stash= gv_stashpvn(pkg_str, pkg_str_len, 0);
         if (!pkg_stash)
            croak("No such package '%s'", pkg_str);
      }
      fset= nf_fieldset_alloc(aTHX_);
      // create the wrapper first so that there is a refcount to clean it up if next line dies
      ST(0)= nf_fieldset_get_wrapper(aTHX_ fset);
      nf_fieldset_link_to_package(aTHX_ fset, pkg_str);
      XSRETURN(1);

//void
//field_rvalue(obj, fieldset, field_idx)
//   SV *obj
//   nf_fieldset_t *fieldset
//   UV field_idx
//   INIT:
//      nf_fieldstorage_t *fstor;
//      nf_fieldinfo_t *finf;
//   PPCODE:
//      if (!SvROK(obj))
//         croak("field_rvalue can only be called on references");
//      if (field_idx >= fieldset->field_count)
//         croak("field_idx out of bounds");
//      fstor= nf_fieldstorage_magic_get(aTHX_ SvRV(obj), fieldset, 0);
//      if (fstor && field_idx < fstor->field_count) {
//         finf= fieldset->fields[field_idx];
//         finf->

MODULE = NERDVANA::Field                  PACKAGE = NERDVANA::Field::FieldSet

void
new(cls)
   const char *cls
   INIT:
      nf_fieldset_t *fset;
   PPCODE:
      fset= nf_fieldset_alloc(aTHX_);
      ST(0)= nf_fieldset_get_wrapper(aTHX_ fset);
      if (strcmp(cls, "NERDVANA::Field::FieldSet") != 0)
         sv_bless(ST(0), gv_stashpv(cls, GV_ADD));
      XSRETURN(1);

IV
field_count(fs)
   nf_fieldset_t *fs
   CODE:
      RETVAL= fs->field_count;
   OUTPUT:
      RETVAL

//void
//field(fs, name)
//   nf_fieldset_t *fs
//   SV *name
//   INIT:
//      nf_fieldinfo_t *field= nf_fieldset_get_field(fs, name, 0);
//   PPCODE:
//      ST(0)= field? newSVuv((UV)field) : &PL_sv_undef;
//      XSRETURN(1);

