#! /usr/bin/env perl
use v5.36;
use FindBin;
use lib $FindBin::RealBin;
use HashTree;

my $htgen= HashTree->new(
   namespace => 'nf_hashtree',
   common_namespace => 'nf_hashtree',
);
$htgen->macro_hashtree_size('capacity');
for (
   $htgen->override(
      namespace     => 'nf_fieldset_hashtree',
      elemdata_type => 'nf_fieldinfo_t **',
      key_type      => 'nf_fieldinfo_key_t *',
      macro_elem_hashcode => sub($self, $eldata, $el) {
         "( ($eldata)[($el)-1]->name_hashcode )"
      },
      macro_key_hashcode => sub($self, $key) {
         "( ($key)->name_hashcode )"
      },
      macro_cmp_key_elem => sub($self, $key, $eldata, $el) {
         "( sv_cmp(($key)->name, ($eldata)[($el)-1]->name) )"
      },
      macro_cmp_elem_elem => sub($self, $eldata, $el1, $el2) {
         "( sv_cmp(($eldata)[($el1)-1]->name, ($eldata)[($el2)-1]->name) )"
      }
   ),
   $htgen->override(
      namespace     => 'nf_fieldstorage_map_hashtree',
      elemdata_type => 'nf_fieldstorage_t **',
      key_type      => 'nf_fieldset_t *',
      macro_elem_hashcode => sub($self, $eldata, $el) {
         "( (size_t)(($eldata)[($el)-1]->fieldset) )"
      },
      macro_key_hashcode => sub($self, $key) {
         "( (size_t)($key) )"
      },
      macro_cmp_key_elem => sub($self, $key, $eldata, $el) {
         "( ($key) < (($eldata)[($el)-1]->fieldset)? -1 : ($key) == (($eldata)[($el)-1]->fieldset)? 0 : 1 )"
      },
      macro_cmp_elem_elem => sub($self, $eldata, $el1, $el2) {
         "( (($eldata)[($el1)-1]->fieldset) < (($eldata)[($el2)-1]->fieldset)? -1 : (($eldata)[($el1)-1]->fieldset) == (($eldata)[($el2)-1]->fieldset)? 0 : 1 )"
      }
   ),
) {
   $_->find_fn;
   $_->reindex_fn;
   $_->structcheck_fn;
   $_->print_fn;
}
$htgen->patch_header("$FindBin::RealBin/../Field.xs");
$htgen->patch_source("$FindBin::RealBin/../hashtree.c");