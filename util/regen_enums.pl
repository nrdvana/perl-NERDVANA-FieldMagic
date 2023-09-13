#! /usr/bin/env perl
use v5.36;
use FindBin;
use lib $FindBin::RealBin;
use XSEnum;

my $cgen= XSEnum->new(
   namespace => 'fm_field_type',
   enum_srcfile => "$FindBin::RealBin/../FieldMagic.h",
   enum_c_prefix => 'FM_FIELD_TYPE_',
   enum_pl_prefix => 'FIELD_TYPE_',
);
$cgen->parse_fn;
$cgen->wrap_fn;
$cgen->generate_boot_consts;
$cgen->patch_header("$FindBin::RealBin/../FieldMagic.h", "GENERATED ENUM HEADERS");
$cgen->patch_source("$FindBin::RealBin/../fm_fieldset.c", "GENERATED ENUM IMPLEMENTATION");
$cgen->patch_xs_boot("$FindBin::RealBin/../FieldMagic.xs", "GENERATED ENUM CONSTANTS");