#! /usr/bin/env perl
use v5.36;
use FindBin;
use lib $FindBin::RealBin;
use HashTree;

my $htgen= HashTree->new(
   namespace => 'nf_hashtree',
);
for (
   $htgen->with(word_type => 'uint8_t', word_size => 1),
   $htgen->with(word_type => 'uint16_t', word_size => 2),
   $htgen->with(word_type => 'IV', word_size => 'IVSIZE'),
) {
   for ($_->with(
         elem_type    => 'nf_fieldstorage_t *',
         elem_key     => '(x).fieldset',
         key_type     => 'nf_fieldset_t *',
         elem_keyhash => '(x).fieldset->hashcode',
         elem_key_cmp => '((IV)((b) - (a)))',
         reindex_fn   => 'nf_fieldstorage_map_reindex'.$_->word_suffix,
         find_fn      => 'nf_fieldstorage_map_find'.$_->word_suffix,
      )
   ) {
      $_->generate_hashtree_size_macro;
      $_->generate_hashtree_max_capacity_macro;
      $_->generate_find;
      $_->generate_reindex;
   }
}
$htgen->patch_header("$FindBin::RealBin/../Field.xs");
$htgen->patch_source("$FindBin::RealBin/../hashtree.c");