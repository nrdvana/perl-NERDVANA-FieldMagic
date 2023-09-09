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
   IV storage_id;
   size_t storage_size, known_ancestor_count;
   size_t field_count, capacity;
   nf_fieldinfo_t **fields;
   HV *pkg_stash, *blessed_ref;
};
// Used for the _find function
struct nf_fieldinfo_key {
   SV *name;
   unsigned name_hashcode;
};
struct nf_fieldinfo {
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
   } def_val;
   size_t storage_ofs;
};

#define NF_FIELDSET_AUTOCREATE 0x10000
#define OR_DIE 0x20000
nf_fieldset_t * nf_fieldset_alloc(pTHX_ HV *pkg_stash);
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
   size_t field_count;
   char data[];
   /* Allocation size:
      sizeof(nf_fieldstorage_t)
      + fieldset->storage_size
   */
};

nf_fieldstorage_map_t * nf_fieldstorage_map_alloc(pTHX_ size_t capacity);
void nf_fieldstorage_map_free(pTHX_ nf_fieldstorage_map_t *self);
#define NF_FIELDSTORAGE_AUTOCREATE 1
nf_fieldstorage_t ** nf_fieldstorage_map_get(pTHX_ nf_fieldstorage_map_t **self_p, nf_fieldset_t *fset, int flags);
nf_fieldstorage_t * nf_fieldstorage_alloc(pTHX_ nf_fieldset_t *fset);
nf_fieldstorage_t * nf_fieldstorage_clone(pTHX_ nf_fieldstorage_t *orig);
void nf_fieldstorage_free(pTHX_ nf_fieldstorage_t *self);
SV *nf_fieldstorage_field_get(pTHX_ nf_fieldstorage_t *self, size_t field_idx);
void nf_fieldstorage_field_set(pTHX_ nf_fieldstorage_t *self, size_t field_idx, SV *value);

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

size_t nf_fieldset_find(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, nf_fieldinfo_key_t * search_key);

bool nf_fieldset_reindex(void *hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t el_i, size_t last_i);

bool nf_fieldset_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldinfo_t ** elemdata, size_t max_el);

size_t nf_fieldstorage_map_find(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, nf_fieldset_t * search_key);

bool nf_fieldstorage_map_reindex(void *hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t el_i, size_t last_i);

bool nf_fieldstorage_map_structcheck(pTHX_ void* hashtree, size_t capacity, nf_fieldstorage_t ** elemdata, size_t max_el);

/* END GENERATED NF_HASHTREE HEADERS */

#include "hashtree.c"

/**********************************************************************************************\
* fieldset_t implementation
\**********************************************************************************************/

nf_fieldset_t * nf_fieldset_alloc(HV *pkg_stash) {
   nf_fieldset_t *self;
   Newxz(self, 1, nf_fieldset_t);
   self->pkg_stash= pkg_stash;
   return self;
}

void nf_fieldset_extend(pTHX_ nf_fieldset_t *self, UV count) {
   if (count > self->capacity) {
      size_t alloc= count * sizeof(nf_fieldinfo_t*) + NF_HASHTREE_SIZE(count);
      Renewc(self->fields, 1, alloc, nf_fieldinfo_t*);
      self->capacity= count;
      // Need to clear all bytes beyond the end of self->fields+self->capacity
      memset(self->fields + self->field_count, 0, alloc - self->field_count * sizeof(nf_fieldinfo_t*));
      // Now re-index all the existing elements
      if (!nf_fieldset_reindex(self->fields + count, count, self->fields, 1, self->field_count))
         croak("Corrupt hashtree");
   }
}

void nf_fieldset_free(pTHX_ nf_fieldset_t *self) {
   IV i;
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
void nf_fieldinfo_destroy(pTHX_ nf_fieldinfo_t *finf) {
   if (finf->name) {
      SvREFCNT_dec(finf->name);
      finf->name= NULL;
   }
}

nf_fieldinfo_t * nf_fieldset_add_field(pTHX_ nf_fieldset_t *self, SV *name) {
   nf_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   char *name_p= SvPV(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   if (nf_fieldset_find(self->fields + self->capacity, self->capacity, self->fields, &key))
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
   nf_fieldset_reindex(self->fields + self->capacity, self->capacity, self->fields, i+i, i+i);
   return NULL;
}

nf_fieldinfo_t * nf_fieldset_get_field(pTHX_ nf_fieldset_t *self, SV *name, int flags) {
   nf_fieldinfo_key_t key= { name, 0 };
   size_t i;
   STRLEN len;
   char *name_p= SvPV(name, len);
   PERL_HASH(key.name_hashcode, name_p, len);
   i= nf_fieldset_find(self->fields + self->capacity, self->capacity, self->fields, &key);
   return i? self->fields[i-1] : NULL;
}

bool nf_fieldset_fieldvalue_exists(pTHX_ nf_fieldset_t *self, SV *obj, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   if (!(type & NF_FIELDINFO_TYPE_SV))
      croak("Not an SV field");
   
}

// Returns SV without incrementing ref count.
// If SV is temporary it will be mortal.
SV *nf_fieldstorage_field_getsv(pTHX_ nf_fieldstorage_t *self, nf_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= finfo->flags & NF_FIELDINFO_TYPE_MASK;
   if (!(type & NF_FIELDINFO_TYPE_SV))
      croak("Not an SV field");
   sv_p= (SV**)(self->data + finfo->storage_ofs);
   // might need to apply defaults on first access
   if (!*sv_p && finfo->flags & NF_FIELDINFO_HAS_DEFAULT) {
      *sv_p= newSVsv(finfo->def_val.sv);
   }
   case NF_FIELDINFO_TYPE_SV:
   case NF_FIELDINFO_TYPE_AV: 
   case NF_FIELDINFO_TYPE_HV:
      return *sv_p? *sv_p : &PL_sv_undef;
   default:
      croak("Unhandled variable type for field_getsv");
   }
   return NULL;
}

void nf_fieldstorage_field_setsv(pTHX_ nf_fieldstorage_t *self, size_t field_idx, SV *value) {
   
}



/**********************************************************************************************\
* fieldstorage_map_t implementation
\**********************************************************************************************/

nf_fieldstorage_map_t * nf_fieldstorage_map_alloc(pTHX_ size_t capacity) {
   nf_fieldstorage_map_t *self= (nf_fieldstorage_map_t *) safecalloc(
      sizeof(nf_fieldstorage_map_t)
      + sizeof(nf_fieldstorage_t*) * capacity  // element array
      + NF_HASHTREE_SIZE(capacity),            // hashtree
      1);
   self->capacity= capacity;
   return self;
}

// Take a guess that if it is being cloned, the el_count is as large as it needs to be.
nf_fieldstorage_map_t * nf_fieldstorage_map_clone(pTHX_ nf_fieldstorage_map_t *orig) {
   nf_fieldstorage_map_t *self= nf_fieldstorage_map_alloc(aTHX_ orig->el_count);
   size_t capacity;
   int i;
   for (i= orig->el_count-1; i >= 0; i--)
      self->el[i]= nf_fieldstorage_clone(aTHX_ orig->el[i]);
   self->el_count= orig->el_count;
   capacity= self->capacity;
   if (capacity >= NF_HASHTREE_MIN_SIZE && capacity <= NF_HASHTREE_UINT8_T_MAX_CAPACITY)
      nf_fieldstorage_map_reindex_uint8_t(self->el, capacity, i, self->el_count);
   else if (capacity <= NF_HASHTREE_UINT16_T_MAX_CAPACITY)
      nf_fieldstorage_map_reindex_uint16_t(self->el, capacity, i, self->el_count);
   else
      nf_fieldstorage_map_reindex_IV(self->el, capacity, i, self->el_count);
   return self;
}

void nf_fieldstorage_map_free(pTHX_ nf_fieldstorage_map_t *self) {
   int i;
   for (i= self->el_count-1; i >= 0; i--)
      nf_fieldstorage_free(aTHX_ self->el[i]);
   Safefree(self);
}

nf_fieldstorage_t ** nf_fieldstorage_map_get(pTHX_ nf_fieldstorage_map_t **self_p, nf_fieldset_t *fset, int flags) {
   nf_fieldstorage_map_t *self, *newself;
   size_t capacity, i;
   nf_fieldstorage_t *fstmp, **found= NULL;
   int j;
   if (!(self= *self_p)) { // initial allocation
      if (!(flags & NF_FIELDSTORAGE_AUTOCREATE))
         return NULL;
      // take a guess of NF_HASHTREE_MIN_SIZE-1 or fset->inherit_count
      i= fset->known_ancestor_count;
      if (i < NF_HASHTREE_MIN_SIZE-1)
         i= NF_HASHTREE_MIN_SIZE-1;
      *self_p= self= nf_fieldstorage_map_alloc(aTHX_ i);
   }
   capacity= self->capacity;
   if (capacity < NF_HASHTREE_MIN_SIZE) {
      for (j= self->el_count-1; j >= 0; j--)
         if (self->el[j]->fieldset == fset) {
            found= self->el + j;
            break;
         }
   } else {
      j= capacity <= NF_HASHTREE_8_MAX_CAPACITY? nf_fieldstorage_map_find_8(self->el, capacity, fset)
      : capacity <= NF_HASHTREE_16_MAX_CAPACITY? nf_fieldstorage_map_find_16(self->el, capacity, fset)
      : nf_fieldstorage_map_find_IV(self->el, capacity, fset);
      if (j >= 0) found= self->el + j;
   }
   // Not found?
   if (found) {
      // Check for new fields added
      if ((*found)->field_count != (*found)->fieldset->field_count) {
         // No need to re-initialize, because the opcode does that on demand, just make sure
         // the buffer is the full size.
         if (!(fstmp= saferealloc(*found, sizeof(nf_fieldstorage_t) + (*found)->fieldset->storage_size)))
            croak("realloc %ld", (long)(sizeof(nf_fieldstorage_t) + (*found)->fieldset->storage_size));
         *found= fstmp;
      }
   } else if (flags & NF_FIELDSTORAGE_AUTOCREATE) {
      // First question, is there room to add it?
      if (self->el_count + 1 > capacity) {
         // Resize and re-add all
         capacity += capacity < 50? capacity : (capacity >> 1); // 7, 14, 28, 56, 84, 126
         newself= nf_fieldstorage_map_alloc(aTHX_ capacity);
         memcpy(newself->el, self->el, ((char*)(self->el + self->el_count)) - ((char*)self->el));
         newself->el_count= self->el_count;
         Safefree(self);
         *self_p= self= newself;
         i= 0;
      } else {
         i= self->el_count;
      }
      // Allocate the fieldstorage and index it
      found= self->el + self->el_count++;
      *found= nf_fieldstorage_alloc(aTHX_ fset);
      if (capacity >= NF_HASHTREE_MIN_SIZE && capacity <= NF_HASHTREE_8_MAX_CAPACITY)
         nf_fieldstorage_map_reindex_8(self->el, capacity, i, self->el_count);
      else if (capacity <= NF_HASHTREE_16_MAX_CAPACITY)
         nf_fieldstorage_map_reindex_16(self->el, capacity, i, self->el_count);
      else
         nf_fieldstorage_map_reindex_IV(self->el, capacity, i, self->el_count);
   }
   return found;
}

nf_fieldstorage_t * nf_fieldstorage_alloc(pTHX_ nf_fieldset_t *fset) {
   int i;
   char *dest_p;
   nf_fieldstorage_t *self= (nf_fieldstorage_t *) safecalloc(
      sizeof(nf_fieldstorage_t)
      + fset->storage_size,
      1);
   self->fieldset= fset;
   self->field_count= fset->field_count;
   SvREFCNT_inc(fset->pkg_stash);
   return self;
}

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

void nf_fieldstorage_free(pTHX_ nf_fieldstorage_t *self) {
   nf_fieldinfo_t *finfo;
   SV **sv_p;
   int i, type;
   for (i= self->field_count-1; i >= 0; i--) {
      finfo= self->fieldset->fields+i;
      if (finfo->flags & NF_FIELDINFO_TYPE_SV) {
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) SvREFCNT_dec(*sv_p);
      }
   }
   SvREFCNT_dec(self->fieldset->pkg_stash);
   Safefree(self);
}

/**********************************************************************************************\
* This code sets/gets the XS Magic to objects
\**********************************************************************************************/

// destructor for nf_space_t magic
static int nf_fieldstorage_map_magic_free(pTHX_ SV* sv, MAGIC* mg) {
   if (mg->mg_ptr) {
      nf_fieldstorage_map_free(aTHX_ (nf_fieldstorage_map_t*) mg->mg_ptr);
      mg->mg_ptr= NULL;
   }
   return 0; // ignored anyway
}
#ifdef USE_ITHREADS
// Incomplete.  Need to clone the fieldsets, or block threads from changing them.
static int nf_fieldstorage_map_magic_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param) {
   PERL_UNUSED_VAR(param);
   if (mg->mg_ptr)
      mg->mg_ptr= nf_fieldstorage_map_clone(aTHX_ (nf_fieldstorage_map_t*)mg->mg_ptr);
   return 0;
};
#else
#define nf_fieldstorage_map_magic_dup NULL
#endif

// magic virtual method table for nf_fieldstorage_map_t
// Pointer to this struct is also used as an ID for type of magic
static MGVTBL nf_fieldstorage_map_magic_vt= {
   NULL, /* get */
   NULL, /* write */
   NULL, /* length */
   NULL, /* clear */
   nf_fieldstorage_map_magic_free,
   NULL, /* copy */
   nf_fieldstorage_map_magic_dup
#ifdef MGf_LOCAL
   ,NULL
#endif
};

// Use AUTOCREATE to attach magic and allocate a struct if it wasn't present.
// Use OR_DIE for a built-in croak() if the return value would be NULL.
static nf_fieldstorage_t* nf_fieldstorage_magic_get(pTHX_ SV *sv, nf_fieldset_t *fs, int flags) {
   MAGIC* magic;
   nf_fieldstorage_t **fs_p= NULL;
   if (SvMAGICAL(sv)) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &nf_fieldstorage_map_magic_vt) {
            /* Null is a valid value for nf_fieldstorage_map_get */
            fs_p= nf_fieldstorage_map_get((nf_fieldstorage_map_t**) &magic->mg_ptr, fs, flags);
            return fs_p? *fs_p : NULL;
         }
   }
   if (flags & NF_FIELDSTORAGE_AUTOCREATE) {
      magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &nf_fieldstorage_map_magic_vt, NULL, 0);
      #ifdef USE_ITHREADS
      magic->mg_flags |= MGf_DUP;
      #endif
      fs_p= nf_fieldstorage_map_get(aTHX_ (nf_fieldstorage_map_t**) &magic->mg_ptr, fs, flags);
   }
   return fs_p? *fs_p : NULL;
}

static int nf_fieldset_magic_free(pTHX_ SV *sv, MAGIC *mg) {
   if (mg->mg_ptr) {
      nf_fieldset_free(aTHX_ (nf_fieldset_t*) mg->mg_ptr);
      mg->mg_ptr= NULL;
   }
   return 0;
}
static MGVTBL nf_fieldset_magic_vt= {
   NULL, /* get */
   NULL, /* write */
   NULL, /* length */
   NULL, /* clear */
   nf_fieldset_magic_free,
   NULL, /* copy */
   NULL
#ifdef MGf_LOCAL
   ,NULL
#endif
};

static nf_fieldset_t* nf_fieldset_magic_get(pTHX_ SV *sv, int flags) {
   MAGIC* magic;
   nf_fieldset_t *fs;
   // The magic is attached to the package stash HV.
   // The blessed objects we hand out to userland are refs to blessed refs to the package stash.
   if (sv_isobject(sv) && SvROK(SvRV(sv)))
      sv= SvRV(SvRV(sv));
   // obj should now be pointing at a package stash with extension magic attached
   if (SvMAGICAL(sv)) {
      /* Iterate magic attached to this scalar, looking for one with our vtable */
      for (magic= SvMAGIC(sv); magic; magic = magic->mg_moremagic)
         if (magic->mg_type == PERL_MAGIC_ext && magic->mg_virtual == &nf_fieldset_magic_vt)
            return (nf_fieldset_t*) &magic->mg_ptr;
   }
   if (flags & NF_FIELDSET_AUTOCREATE) {
      fs= nf_fieldset_alloc((HV*) sv);
      magic= sv_magicext(sv, NULL, PERL_MAGIC_ext, &nf_fieldset_magic_vt, (char*) fs, 0);
      #ifdef USE_ITHREADS
      //magic->mg_flags |= MGf_DUP;
      #else
      (void)magic; // suppress warning
      #endif
      return fs;
   }
   if (flags & OR_DIE)
      croak("Not a FieldSet object or package stash");
   return NULL;
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
      const char *pkg_str= SvPV(pkg, pkg_str_len);
      nf_fieldset_t *fs;
   PPCODE:
      pkg_stash= gv_stashpvn(pkg_str, pkg_str_len, 0);
      if (!pkg_stash)
         croak("No such package '%s'", pkg_str);
      fs= nf_fieldset_magic_get(aTHX_ (SV*) pkg_stash, NF_FIELDSET_AUTOCREATE);
      (void)fs;
      ST(0)= sv_2mortal(newRV_noinc(newRV_inc((SV*) pkg_stash)));
      sv_bless(ST(0), gv_stashpvn("NERDVANA::Field::FieldSet", 25, GV_ADD));
      XSRETURN(1);

void
read_field(obj, fieldset, field_idx)
   SV *obj
   nf_fieldset_t *fieldset
   UV field_idx
   INIT:
      nf_fieldstorage_t *fstor;
      nf_fieldinfo_t *finf;
   PPCODE:
      if (!sv_isobject(obj))
         croak("read_field can only be called on objects");
      fstor= nf_fieldstorage_magic_get(aTHX_ SvRV(obj), fieldset, 0);
      if (fstor && field_idx < fstor->field_count) {
         finf= fieldset->fields + field_idx;
         finf->

MODULE = NERDVANA::Field                  PACKAGE = NERDVANA::Field::FieldSet

IV
field_count(fs)
   nf_fieldset_t *fs
   CODE:
      RETVAL= fs->field_count;
   OUTPUT:
      RETVAL

void
get_field(fs, name)
   nf_fieldset_t *fs
   SV *name
   INIT:
      nf_fieldinfo_t *field= nf_fieldset_get_field(fs, name, 0);
   PPCODE:
      ST(0)= field? newSVuv((UV)field) : &PL_sv_undef;
      XSRETURN(1);

