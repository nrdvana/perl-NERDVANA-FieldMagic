/**********************************************************************************************\
* fieldstorage_map_t implementation
\**********************************************************************************************/

fm_fieldstorage_map_t * fm_fieldstorage_map_alloc(pTHX_ size_t capacity) {
   fm_fieldstorage_map_t *self= (fm_fieldstorage_map_t *) safecalloc(
      sizeof(fm_fieldstorage_map_t)            // top-level struct info
      + sizeof(fm_fieldstorage_t*) * capacity  // element array
      + FM_RBHASH_SIZE(capacity),            // rbhash
      1);
   self->capacity= capacity;
   return self;
}

// Take a guess that if it is being cloned, the el_count is as large as it needs to be.
//fm_fieldstorage_map_t * fm_fieldstorage_map_clone(pTHX_ fm_fieldstorage_map_t *orig) {
//   fm_fieldstorage_map_t *self= fm_fieldstorage_map_alloc(aTHX_ orig->el_count);
//   int i;
//   for (i= orig->el_count-1; i >= 0; i--)
//      self->el[i]= fm_fieldstorage_clone(aTHX_ orig->el[i]);
//   self->el_count= orig->el_count;
//   fm_fieldstorage_map_rbhash_reindex(self->el + self->capacity, self->capacity, self->el, 1, self->el_count);
//   return self;
//}

void fm_fieldstorage_map_free(pTHX_ fm_fieldstorage_map_t *self) {
   int i;
   for (i= self->el_count-1; i >= 0; i--)
      fm_fieldstorage_free(aTHX_ self->el[i]);
   Safefree(self);
}

fm_fieldstorage_t* fm_fieldstorage_map_get(pTHX_ fm_fieldstorage_map_t **self_p, fm_fieldset_t *fset, int flags) {
   fm_fieldstorage_map_t *self= *self_p, *newself;
   size_t i, capacity= self? self->capacity : 0;
   fm_fieldstorage_t *fstor;
   // If called on a NULL pointer, fieldstorage is not found.
   i= !self? 0
      : fm_fieldstorage_map_rbhash_find(self->el + capacity, capacity, self->el, fset);
   if (i) {
      --i;
      // Check for new fields added
      if (self->el[i]->storage_size != self->el[i]->fieldset->storage_size)
         fm_fieldstorage_handle_new_fields(aTHX_ self->el + i);
      return self->el[i];
   }
   else if (flags & FM_FIELDSTORAGE_AUTOCREATE) {
      // First question, is there room to add it?
      if (!self || self->el_count + 1 > capacity) {
         // Resize and re-add all
         capacity += !capacity? 7 : capacity < 50? capacity : (capacity >> 1); // 7, 14, 28, 56, 84, 126
         newself= fm_fieldstorage_map_alloc(aTHX_ capacity);
         if (self) {
            memcpy(newself->el, self->el, ((char*)(self->el + self->el_count)) - ((char*)self->el));
            newself->el_count= self->el_count;
            Safefree(self);
         }
         *self_p= self= newself;
         i= 1; // all need re-indexed; rbhash element numbers are 1-based
      } else {
         i= self->el_count+1;
      }
      // Allocate the fieldstorage and index it
      fstor= self->el[self->el_count++]= fm_fieldstorage_alloc(aTHX_ fset);
      fm_fieldstorage_map_rbhash_reindex(self->el + self->capacity, self->capacity, self->el, i, self->el_count);
      return fstor;
   }
   else return NULL;
}

/**********************************************************************************************\
* fieldstorage_t implementation
\**********************************************************************************************/

fm_fieldstorage_t * fm_fieldstorage_alloc(pTHX_ fm_fieldset_t *fset) {
   fm_fieldstorage_t *self= (fm_fieldstorage_t *) safecalloc(
      sizeof(fm_fieldstorage_t)
      + fset->storage_size,
      1);
   self->fieldset= fset;
   self->storage_size= fset->storage_size;
   SvREFCNT_inc(fset->pkg_stash_ref);
   return self;
}

void fm_fieldstorage_handle_new_fields(pTHX_ fm_fieldstorage_t **fstor) {
   fm_fieldset_t *fset= (*fstor)->fieldset;
   size_t n, diff;
   // Currently, nothing needs done aside from making sure this object
   // is allocated to include storage_size (and that all those bytes are zero)
   if ((*fstor)->storage_size < fset->storage_size) {
      n= sizeof(fm_fieldstorage_t) + fset->storage_size;
      *fstor= saferealloc(*fstor, n);
      // Zero all newly allocated bytes
      diff= fset->storage_size - (*fstor)->storage_size;
      Zero((((char*)(*fstor)) + n - diff), diff, char);
      // Update fields
      (*fstor)->storage_size= fset->storage_size;
   }
}

#if 0
fm_fieldstorage_t * fm_fieldstorage_clone(pTHX_ fm_fieldstorage_t *orig) {
   fm_fieldstorage_t *self= fm_fieldstorage_alloc(aTHX_ orig->fieldset);
   fm_fieldinfo_t *finfo;
   int i, type;
   SV **sv_p;
   for (i= orig->field_count-1; i >= 0; i--) {
      finfo= self->fieldset->fields+i;
      if (finfo->flags & FM_FIELD_TYPEMASK_SV) {
         // TODO: when cloning for threads, is this good enough?
         // Will the new interpreter try to share CoW with the old?
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) {
            switch (FM_FIELDINFO_TYPE(finfo)) {
            case FM_FIELD_TYPE_SV: *sv_p= newSVsv(*sv_p); break;
            case FM_FIELD_TYPE_AV: *sv_p= (SV*) av_make(1+av_len((AV*) *sv_p), AvARRAY((AV*) *sv_p)); break;
            case FM_FIELD_TYPE_HV: *sv_p= (SV*) newHVhv((HV*) *sv_p); break;
            default: croak("bug");
            }
         }
      }
   }
   return self;
}
#endif
void fm_fieldstorage_free(pTHX_ fm_fieldstorage_t *self) {
   fm_fieldset_t *fset= self->fieldset;
   fm_fieldinfo_t *finfo;
   SV **sv_p;
   int i;
   for (i= fset->field_count-1; i >= 0; i--) {
      finfo= fset->fields[i];
      if ((finfo->flags & FM_FIELD_TYPEMASK_SV) && finfo->storage_ofs < self->storage_size) {
         sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) SvREFCNT_dec(*sv_p);
      }
   }
   SvREFCNT_dec(fset->pkg_stash_ref);
   Safefree(self);
}

void fm_fieldstorage_field_init_default(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo) {
   int type= FM_FIELDINFO_TYPE(finfo);
   char *stor_p= self->data + finfo->storage_ofs;
   if (!(finfo->flags & FM_FIELD_HAS_DEFAULT))
      return;
   switch (type) {
   case FM_FIELD_TYPE_SV: *((SV**)stor_p)= newSVsv(finfo->def_val.sv); break;
   case FM_FIELD_TYPE_AV: *((AV**)stor_p)= fm_newAVav(finfo->def_val.av); break;
   case FM_FIELD_TYPE_HV: *((HV**)stor_p)= newHVhv(finfo->def_val.hv); break;
   default:
      croak("fm_fieldstorage_field_init_default: Unhandled type 0x%02X", type);
   }
}

/* Returns true if the object has a value for this field.
 * BUT, if the field has a default value, this always returns true.
 */
bool fm_fieldstorage_field_exists(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= FM_FIELDINFO_TYPE(finfo);
   if (!(type & FM_FIELD_TYPEMASK_SV))
      croak("Not an SV field");
   // It always exists if it has a default (even if we didn't lazy-initialize it yet)
   if (finfo->flags & FM_FIELD_HAS_DEFAULT)
      return true;
   // It exists if the pointer is assigned.
   sv_p= (SV**)(self->data + finfo->storage_ofs);
   return *sv_p != NULL;
}

/* Returns the value of an object's storage for a field, in the form of either the
 *  raw stored SV or a mortal temporary.
 * The returned value might be the default value SV pointer itself, if the field
 * has not been initialized.  The default is read-only.
 * If the field is not assigned and has no default, this returns &PL_sv_undef.
 */
SV *fm_fieldstorage_field_rvalue(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= FM_FIELDINFO_TYPE(finfo);
   int has_default= finfo->flags & FM_FIELD_HAS_DEFAULT;
   if (type & FM_FIELD_TYPEMASK_SV) {
      sv_p= (SV**)(self->data + finfo->storage_ofs);
      if (!*sv_p && has_default)
         fm_fieldstorage_field_init_default(aTHX_ self, finfo);
      if (*sv_p)
         return *sv_p;
   }
   else {
      croak("fm_fieldstorage_field_rvalue: unhandled type 0x%02X", type);
   }
   return &PL_sv_undef;
}

/* Returns an SV directly representing the storage for the field.
 * The SV is either owned by the storage, or is a mortal magic-infused temporary.
 * Modifications to this SV will show up for all code using the field on this object.
 * If the field was not initialized, it will be after this call and 'exists' will
 * return true.
 */
SV *fm_fieldstorage_field_lvalue(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo) {
   SV **sv_p;
   int type= FM_FIELDINFO_TYPE(finfo);
   int has_default= finfo->flags & FM_FIELD_HAS_DEFAULT;
   if (type & FM_FIELD_TYPEMASK_SV) {
      sv_p= (SV**)(self->data + finfo->storage_ofs);
      if (!*sv_p) {
         if (has_default)
            fm_fieldstorage_field_init_default(aTHX_ self, finfo);
         else
            *sv_p= newSV(0);
      }
      return *sv_p;
   }
   else {
      croak("fm_fieldstorage_field_lvalue: unhandled type 0x%02X", type);
   }
}

/* Assign to the storage of a field.
 * A copy of the 'value' is stored, so 'value' does not need to continue to exist.
 */
void fm_fieldstorage_field_assign(pTHX_ fm_fieldstorage_t *self, fm_fieldinfo_t *finfo, SV *value) {
   croak("TODO");
#if 0
   SV **av_array;
   size_t av_array_n;
   int type= FM_FIELDINFO_TYPE(finfo);
   switch (type) {
   case FM_FIELD_TYPE_SV: {
         SV **sv_p= (SV**)(self->data + finfo->storage_ofs);
         if (*sv_p) sv_setsv(*sv_p, value);
         else *sv_p= newSVsv(value);
      }
      break;
   case FM_FIELD_TYPE_AV: {
         AV **av_p= (AV**)(self->data + finfo->storage_ofs);
         AV *src_av= (SvTYPE(value) == SVt_PVAV)? (AV*)value
            : SvROK(value) && SvTYPE(SvRV(value)) == SVt_PVAV? (AV*)SvRV(value)
            : NULL;
         if (src_av) {
            AV *tmp= av_make(
            
            av_clear(*av_p);
            if (src_av) {
               av_extend(*av_p, av_len(src_av));
               
         
   case FM_FIELD_TYPE_HV:
   }
#endif
}
