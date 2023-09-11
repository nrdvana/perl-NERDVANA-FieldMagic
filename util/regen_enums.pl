#! /usr/bin/env perl
use v5.36;
use FindBin;
use lib $FindBin::RealBin;
use XSEnum;

my $cgen= XSEnum->new(
   namespace => 'nf_field_type',
   enum_srcfile => "$FindBin::RealBin/../Field.xs",
   enum_c_prefix => 'NF_FIELD_TYPE_',
   enum_pl_prefix => 'FIELD_TYPE_',
);
$cgen->parse_fn;
$cgen->get_sv_fn;
$cgen->patch_header("$FindBin::RealBin/../Field.xs", "GENERATED ENUM HEADERS");
$cgen->patch_source("$FindBin::RealBin/../Field.xs", "GENERATED ENUM IMPLEMENTATION");
