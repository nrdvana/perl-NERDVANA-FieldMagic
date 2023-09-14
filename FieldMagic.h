#ifndef FIELDMAGIC_H
#define FIELDMAGIC_H

/* fm_fieldinfo describes one field of one class.
 * fm_fieldset is the collection of fields for one class.
 * fm_fieldstorage is the struct magically attached to any sub that uses fields
 */

struct fm_fieldset;          typedef struct fm_fieldset fm_fieldset_t;
struct fm_fieldinfo;         typedef struct fm_fieldinfo fm_fieldinfo_t;
struct fm_fieldinfo_key;     typedef struct fm_fieldinfo_key fm_fieldinfo_key_t;
struct fm_fieldstorage_map;  typedef struct fm_fieldstorage_map fm_fieldstorage_map_t;
struct fm_fieldstorage;      typedef struct fm_fieldstorage fm_fieldstorage_t;
typedef int fm_field_type_t;

struct fm_fieldset {
   /* wrapper is the HV FieldSet object whose reference count controls the
      lifespan of this struct. */
   HV *wrapper;
   /* pkg_stash is a weak-ref to the package stash which has these fields */
   SV *pkg_stash_ref;
   size_t storage_size;
   /* fields[] is an array of the fields followed by a rbhash that looks them up by name */
   size_t field_count, capacity;
   fm_fieldinfo_t **fields;
};

// Used for the _find function
struct fm_fieldinfo_key {
   SV *name;
   unsigned name_hashcode;
};
struct fm_fieldinfo {
   fm_fieldset_t *fieldset;
   size_t field_idx;
   SV *name;
   unsigned name_hashcode;
   int flags;
   #define FM_FIELD_TYPEMASK      0xFF
   #define FM_FIELD_TYPEMASK_SV   0x80
   #define FM_FIELD_TYPE_SV       0x81
   #define FM_FIELD_TYPE_AV       0x82
   #define FM_FIELD_TYPE_HV       0x83
   #define FM_FIELD_TYPEMASK_VIRT 0x40
   #define FM_FIELD_TYPE_VIRT_SV  0x41
   #define FM_FIELD_TYPE_VIRT_AV  0x42
   #define FM_FIELD_TYPE_VIRT_HV  0x43
   #define FM_FIELD_TYPEMASK_C    0x20
   #define FM_FIELD_TYPE_BOOL     0x21
   #define FM_FIELD_TYPE_IV       0x22
   #define FM_FIELD_TYPE_UV       0x23
   #define FM_FIELD_TYPE_NV       0x24
   #define FM_FIELD_TYPE_PV       0x25
   #define FM_FIELD_TYPE_STRUCT   0x26
   #define FM_FIELD_INHERITED    0x100
   #define FM_FIELD_HAS_DEFAULT  0x200
   #define FM_FIELDINFO_TYPE(x) ((x)->flags & FM_FIELD_TYPEMASK)
   union {
      SV *sv;
      AV *av;
      HV *hv;
   } def_val;
   HV *meta_class;
   size_t storage_ofs, storage_size;
};
bool fm_field_type_parse(pTHX_ SV *sv, int *dest);
const char* fm_field_type_name(pTHX_ int val);
SV* fm_field_type_wrap(pTHX_ int val);

#define FM_FIELDSET_AUTOCREATE 0x10000
#define OR_DIE 0x20000
fm_fieldset_t * fm_fieldset_alloc(pTHX);
void fm_fieldset_extend(pTHX_ fm_fieldset_t *self, UV field_count);
fm_fieldset_t * fm_fieldset_dup(pTHX_ fm_fieldset_t *self);
void fm_fieldset_free(pTHX_ fm_fieldset_t *self);
void fm_fieldinfo_destroy(pTHX_ fm_fieldinfo_t *finf);
fm_fieldinfo_t * fm_fieldset_get_field(pTHX_ fm_fieldset_t *self, SV *name);

/* BEGIN GENERATED ENUM HEADERS */
bool fm_field_type_parse(pTHX_ SV *sv, int *dest);
const char* fm_field_type_name(pTHX_ int val);
SV* fm_field_type_wrap(pTHX_ int val);
SV* fm_field_type_wrap(pTHX_ int val);/* END GENERATED ENUM HEADERS */

struct fm_fieldstorage_map {
   size_t el_count, capacity;
   fm_fieldstorage_t *el[];
   /* Allocation size:
      sizeof(fm_fieldstorage_map_t)
       + capacity * sizeof(fm_fieldstorage_t *)
       + size of the hash tree
   */
};

struct fm_fieldstorage {
   fm_fieldset_t *fieldset;
   size_t storage_size;
   char data[];
   /* Allocation size:
      sizeof(fm_fieldstorage_t)
      + fieldset->storage_size
   */
};

fm_fieldstorage_map_t * fm_fieldstorage_map_alloc(pTHX_ size_t capacity);
void fm_fieldstorage_map_free(pTHX_ fm_fieldstorage_map_t *self);
#define FM_FIELDSTORAGE_AUTOCREATE 1
fm_fieldstorage_t * fm_fieldstorage_map_get(pTHX_ fm_fieldstorage_map_t **self_p, fm_fieldset_t *fset, int flags);
fm_fieldstorage_t * fm_fieldstorage_alloc(pTHX_ fm_fieldset_t *fset);
fm_fieldstorage_t * fm_fieldstorage_clone(pTHX_ fm_fieldstorage_t *orig);
void fm_fieldstorage_free(pTHX_ fm_fieldstorage_t *self);
void fm_fieldstorage_handle_new_fields(pTHX_ fm_fieldstorage_t **self_p);
bool fm_fieldstorage_field_exists(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo);
SV *fm_fieldstorage_field_rvalue(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo);
SV *fm_fieldstorage_field_lvalue(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo);
void fm_fieldstorage_field_assign(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo, SV *value);

/* BEGIN GENERATED FM_RBHASH HEADERS */
// For a given capacity, this is how many hashtable buckets will be allocated
#define FM_RBHASH_TABLE_BUCKETS(capacity) ((capacity) + ((capacity) >> 1))
// Size of rbhash structure, not including element array that it is appended to
// This is a function of the max capacity of elements.
#define FM_RBHASH_SIZE(capacity) ( \
   ((capacity) > 0x7FFFFFFF? 8 \
    : (capacity) > 0x7FFF? 4 \
    : (capacity) > 0x7F? 2 \
    : 1 \
   ) * ( \
     ((capacity)+1)*2 \
     + FM_RBHASH_TABLE_BUCKETS(capacity) \
   ))
size_t fm_fieldset_rbhash_find(void *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, fm_fieldinfo_key_t * search_key);
bool fm_fieldset_rbhash_reindex(void *rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t el_i, size_t last_i);
bool fm_fieldset_rbhash_structcheck(pTHX_ void* rbhash, size_t capacity, fm_fieldinfo_t ** elemdata, size_t max_el);
void fm_rbhash_print(void *rbhash, size_t capacity, FILE *out);
size_t fm_fieldstorage_map_rbhash_find(void *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, fm_fieldset_t * search_key);
bool fm_fieldstorage_map_rbhash_reindex(void *rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t el_i, size_t last_i);
bool fm_fieldstorage_map_rbhash_structcheck(pTHX_ void* rbhash, size_t capacity, fm_fieldstorage_t ** elemdata, size_t max_el);
/* END GENERATED FM_RBHASH HEADERS */

#endif
